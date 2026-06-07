import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/machine_data.dart';
import '../../core/database/local_database.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format_utils.dart';
import '../../shared/models/record_model.dart';
import '../../shared/repositories/record_repository.dart';
import '../../services/pworld_service.dart';

// ─── メダル単価の選択肢 ────────────────────────────────────────
class _MedalRate {
  final int medals;
  final String label;
  const _MedalRate(this.medals, this.label);
}

const _kMedalRates = [
  _MedalRate(46, '46枚（21.74円/枚）'),
  _MedalRate(47, '47枚（21.28円/枚）'),
  _MedalRate(50, '50枚（20.00円/枚）'),
  _MedalRate(51, '51枚（19.61円/枚）'),
  _MedalRate(52, '52枚（19.23円/枚）'),
  _MedalRate(55, '55枚（18.18円/枚）'),
  _MedalRate(60, '60枚（16.67円/枚）'),
];

int _medalsToYen(int medals, int ratePerThousand) {
  if (ratePerThousand <= 0) return 0;
  return (medals * 1000.0 / ratePerThousand).round();
}

// ─── 画面本体 ───────────────────────────────────────────────────
class RecordFormScreen extends ConsumerStatefulWidget {
  final RecordModel? existing;
  final DateTime? initialDate;

  const RecordFormScreen({super.key, this.existing, this.initialDate});

  @override
  ConsumerState<RecordFormScreen> createState() => _RecordFormScreenState();
}

class _RecordFormScreenState extends ConsumerState<RecordFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late DateTime _date;
  String _storeName = '';
  String _machineName = '';
  DateTime? _startTime;
  DateTime? _endTime;
  String _aim = '';
  int _medalPrice = 0;

  int _investmentMedals = 0;
  int _investmentCash   = 0;
  int _collectionMedals = 0;
  int _collectionCash   = 0;

  // 任意項目（新規追加分）
  int? _setting;
  bool _showOptional = false;
  final _diffCtrl   = TextEditingController();
  final _startGCtrl = TextEditingController();
  final _endGCtrl   = TextEditingController();
  final _bbCtrl     = TextEditingController();
  final _rbCtrl     = TextEditingController();
  final _atCtrl     = TextEditingController();
  final _memoCtrl   = TextEditingController();

  final _storeCtrl       = TextEditingController();
  final _machineCtrl     = TextEditingController();
  final _investMedalsCtrl = TextEditingController();
  final _investCashCtrl  = TextEditingController();
  final _collectMedalsCtrl = TextEditingController();
  final _collectCashCtrl = TextEditingController();
  final _aimCtrl         = TextEditingController();

  List<String> _storeSuggestions   = [];
  List<String> _machineSuggestions = [];

  // 収支計算
  int get _investYen   => _medalsToYen(_investmentMedals, _medalPrice) + _investmentCash;
  int get _collectYen  => _medalsToYen(_collectionMedals, _medalPrice) + _collectionCash;
  int get _medalDiff   => _collectionMedals - _investmentMedals;
  int get _cashDiff    => _collectionCash - _investmentCash;
  int get _totalProfit => _medalPrice > 0 ? _collectYen - _investYen : _medalDiff;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _date = e?.date ?? widget.initialDate ?? DateTime.now();
    _storeName   = e?.storeName ?? '';
    _machineName = e?.machineName ?? '';
    _startTime   = e?.startTime;
    _endTime     = e?.endTime;
    _aim         = e?.aim ?? '';
    _medalPrice  = e?.medalPrice ?? 0;
    _investmentMedals = e?.investmentMedals ?? 0;
    _investmentCash   = e?.investmentCash   ?? 0;
    _collectionMedals = e?.collectionMedals ?? 0;
    _collectionCash   = e?.collectionCash   ?? 0;
    _setting     = e?.setting;

    _storeCtrl.text        = _storeName;
    _machineCtrl.text      = _machineName;
    _investMedalsCtrl.text = _investmentMedals > 0 ? _investmentMedals.toString() : '';
    _investCashCtrl.text   = _investmentCash   > 0 ? _investmentCash.toString()   : '';
    _collectMedalsCtrl.text = _collectionMedals > 0 ? _collectionMedals.toString() : '';
    _collectCashCtrl.text  = _collectionCash   > 0 ? _collectionCash.toString()   : '';
    _aimCtrl.text          = _aim;

    if (e != null) {
      _diffCtrl.text   = e.diffMedals?.toString() ?? '';
      _startGCtrl.text = e.startG?.toString() ?? '';
      _endGCtrl.text   = e.endG?.toString() ?? '';
      _bbCtrl.text     = e.bbCount?.toString() ?? '';
      _rbCtrl.text     = e.rbCount?.toString() ?? '';
      _atCtrl.text     = e.atCount?.toString() ?? '';
      _memoCtrl.text   = e.memo ?? '';
      if (_setting != null || _diffCtrl.text.isNotEmpty || _startGCtrl.text.isNotEmpty) {
        _showOptional = true;
      }
    }

    _loadSuggestions();
  }

  @override
  void dispose() {
    for (final c in [
      _storeCtrl, _machineCtrl, _investMedalsCtrl, _investCashCtrl,
      _collectMedalsCtrl, _collectCashCtrl, _aimCtrl,
      _diffCtrl, _startGCtrl, _endGCtrl, _bbCtrl, _rbCtrl, _atCtrl, _memoCtrl,
    ]) { c.dispose(); }
    super.dispose();
  }

  Future<void> _loadSuggestions() async {
    const userId = 'local_guest';
    final storeRows = await LocalDatabase().getStores(userId);
    final machineNames = kMachineData.map((m) => m['name']!).toList();
    if (mounted) {
      setState(() {
        _storeSuggestions   = storeRows.map((r) => r['name'] as String).toList();
        _machineSuggestions = machineNames;
      });
    }
  }

  Future<void> _loadMedalPrice(String storeName) async {
    if (storeName.isEmpty) return;
    final price = await LocalDatabase().getStoreMedalPrice('local_guest', storeName);
    if (mounted) setState(() => _medalPrice = price);
  }

  Future<void> _editMedalPrice() async {
    int currentIndex = _kMedalRates.indexWhere((r) => r.medals == _medalPrice);
    if (currentIndex < 0) currentIndex = 2;
    final result = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _MedalRatePicker(initialIndex: currentIndex),
    );
    if (result != null) {
      setState(() => _medalPrice = result);
      if (_storeName.isNotEmpty) {
        await LocalDatabase().upsertStoreMedalPrice('local_guest', _storeName, result);
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030, 12, 31),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(primary: AppColors.primary)),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime(bool isStart) async {
    final now = DateTime.now();
    final initial = isStart
        ? (_startTime != null ? TimeOfDay.fromDateTime(_startTime!) : TimeOfDay.fromDateTime(now))
        : (_endTime   != null ? TimeOfDay.fromDateTime(_endTime!)   : TimeOfDay.fromDateTime(now));
    final picked = await showTimePicker(
      context: context, initialTime: initial,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(primary: AppColors.primary)),
        child: child!,
      ),
    );
    if (picked == null) return;
    final dt = DateTime(_date.year, _date.month, _date.day, picked.hour, picked.minute);
    setState(() { if (isStart) { _startTime = dt; } else { _endTime = dt; } });
  }

  void _setNow(bool isStart) {
    final now = DateTime.now();
    final dt = DateTime(_date.year, _date.month, _date.day, now.hour, now.minute);
    setState(() { if (isStart) { _startTime = dt; } else { _endTime = dt; } });
  }

  Future<void> _openStoreSearch() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _SearchDialog(
          title: 'ホール検索',
          hint: 'ホール名で検索',
          localSuggestions: _storeSuggestions,
          remoteSearch: PWorldService.searchHalls,
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() => _storeName = result);
      _storeCtrl.text = result;
      await _loadMedalPrice(result);
    }
  }

  Future<void> _openMachineSearch() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _SearchDialog(
          title: '機種検索',
          hint: '機種名で検索',
          localSuggestions: _machineSuggestions,
          remoteSearch: PWorldService.searchMachines,
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() => _machineName = result);
      _machineCtrl.text = result;
    }
  }

  void _addInvestMedals(int v) {
    setState(() => _investmentMedals += v);
    _investMedalsCtrl.text = _investmentMedals.toString();
  }
  void _addInvestCash(int v) {
    setState(() => _investmentCash += v);
    _investCashCtrl.text = _investmentCash.toString();
  }
  void _addCollectCash(int v) {
    setState(() => _collectionCash += v);
    _collectCashCtrl.text = _collectionCash.toString();
  }

  Future<void> _save() async {
    final store   = _storeName.isNotEmpty ? _storeName : _storeCtrl.text.trim();
    final machine = _machineName.isNotEmpty ? _machineName : _machineCtrl.text.trim();
    if (store.isEmpty || machine.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('店舗名と機種名は必須です')));
      return;
    }

    const userId = 'local_guest';
    final repo = RecordRepository(LocalDatabase());
    final record = RecordModel(
      id:           widget.existing?.id ?? const Uuid().v4(),
      userId:       userId,
      date:         _date,
      storeName:    store,
      machineName:  machine,
      startTime:    _startTime,
      endTime:      _endTime,
      investmentMedals: _investmentMedals,
      investmentCash:   _investmentCash,
      collectionMedals: _collectionMedals,
      collectionCash:   _collectionCash,
      medalPrice:   _medalPrice,
      investment:   _medalPrice > 0 ? _investYen   : _investmentMedals,
      collection:   _medalPrice > 0 ? _collectYen  : _collectionMedals,
      profit:       _totalProfit,
      aim:          _aim.isEmpty ? null : _aim,
      setting:      _setting,
      diffMedals:   int.tryParse(_diffCtrl.text),
      startG:       int.tryParse(_startGCtrl.text),
      endG:         int.tryParse(_endGCtrl.text),
      bbCount:      int.tryParse(_bbCtrl.text),
      rbCount:      int.tryParse(_rbCtrl.text),
      atCount:      int.tryParse(_atCtrl.text),
      memo:         _memoCtrl.text.trim().isEmpty ? null : _memoCtrl.text.trim(),
    );

    if (widget.existing == null) {
      await repo.insert(record);
    } else {
      await repo.update(record);
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('削除しますか？'),
        content: const Text('この記録を削除します。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('キャンセル')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('削除', style: TextStyle(color: AppColors.loss))),
        ],
      ),
    );
    if (ok == true && mounted) {
      await RecordRepository(LocalDatabase()).delete(widget.existing!.id);
      if (mounted) Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.existing == null ? '実践を記録' : '実践を編集'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('保存', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [

            // ─── 日付 ─────────────────────────────────
            const _SectionLabel('日付'),
            _DateTile(date: _date, onTap: _pickDate),
            const SizedBox(height: 20),

            // ─── 店舗 ─────────────────────────────────
            const _SectionLabel('店舗'),
            _FieldWithSearch(
              controller: _storeCtrl,
              label: '店舗名',
              onChanged: (v) => _storeName = v,
              onSearchTap: _openStoreSearch,
            ),
            const SizedBox(height: 8),
            _MedalPriceTile(medalPrice: _medalPrice, onEdit: _editMedalPrice),
            const SizedBox(height: 20),

            // ─── 機種 ─────────────────────────────────
            const _SectionLabel('機種'),
            _FieldWithSearch(
              controller: _machineCtrl,
              label: '機種名',
              onChanged: (v) => _machineName = v,
              onSearchTap: _openMachineSearch,
            ),
            const SizedBox(height: 20),

            // ─── 投資 ─────────────────────────────────
            const _SectionLabel('投資'),
            Row(children: [
              Expanded(child: _NumTextField(
                controller: _investMedalsCtrl, label: 'メダル', suffix: '枚',
                onChanged: (v) => setState(() => _investmentMedals = int.tryParse(v) ?? 0),
              )),
              const SizedBox(width: 12),
              Expanded(child: _NumTextField(
                controller: _investCashCtrl, label: '現金', suffix: '円',
                onChanged: (v) => setState(() => _investmentCash = int.tryParse(v) ?? 0),
              )),
            ]),
            const SizedBox(height: 8),
            _ShortcutRow(
              labels: const ['460枚', '500枚', '1000枚'],
              onTaps: [() => _addInvestMedals(460), () => _addInvestMedals(500), () => _addInvestMedals(1000)],
            ),
            const SizedBox(height: 6),
            _ShortcutRow(
              labels: const ['¥1,000', '¥5,000', '¥10,000'],
              onTaps: [() => _addInvestCash(1000), () => _addInvestCash(5000), () => _addInvestCash(10000)],
            ),
            const SizedBox(height: 20),

            // ─── 回収 ─────────────────────────────────
            const _SectionLabel('回収'),
            Row(children: [
              Expanded(child: _NumTextField(
                controller: _collectMedalsCtrl, label: 'メダル', suffix: '枚',
                onChanged: (v) => setState(() => _collectionMedals = int.tryParse(v) ?? 0),
              )),
              const SizedBox(width: 12),
              Expanded(child: _NumTextField(
                controller: _collectCashCtrl, label: '現金', suffix: '円',
                onChanged: (v) => setState(() => _collectionCash = int.tryParse(v) ?? 0),
              )),
            ]),
            const SizedBox(height: 8),
            _ShortcutRow(
              labels: const ['¥1,000', '¥5,000', '¥10,000'],
              onTaps: [() => _addCollectCash(1000), () => _addCollectCash(5000), () => _addCollectCash(10000)],
            ),
            const SizedBox(height: 16),

            // ─── 収支プレビュー ────────────────────────
            _ProfitPreview(
              medalDiff: _medalDiff,
              cashDiff: _cashDiff,
              totalProfit: _totalProfit,
              medalPrice: _medalPrice,
            ),
            const SizedBox(height: 20),

            // ─── 打った時間 ────────────────────────────
            const _SectionLabel('打った時間'),
            Row(children: [
              Expanded(child: Column(children: [
                _TimeTile(label: '開始', time: _startTime, onTap: () => _pickTime(true)),
                const SizedBox(height: 6),
                _NowButton(onTap: () => _setNow(true)),
              ])),
              const SizedBox(width: 12),
              Expanded(child: Column(children: [
                _TimeTile(label: '終了', time: _endTime, onTap: () => _pickTime(false)),
                const SizedBox(height: 6),
                _NowButton(onTap: () => _setNow(false)),
              ])),
            ]),
            const SizedBox(height: 20),

            // ─── 狙い目 ────────────────────────────────
            const _SectionLabel('狙い目'),
            TextFormField(
              controller: _aimCtrl,
              decoration: const InputDecoration(hintText: '例: 据え置き狙い・高設定確定演出あり'),
              maxLines: 2,
              onChanged: (v) => _aim = v,
            ),
            const SizedBox(height: 20),

            // ─── 任意項目（折りたたみ） ────────────────
            GestureDetector(
              onTap: () => setState(() => _showOptional = !_showOptional),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.cardBorder, width: 0.5),
                ),
                child: Row(children: [
                  const Text('詳細情報を追加',
                      style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Icon(_showOptional ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      color: AppColors.primary),
                ]),
              ),
            ),

            if (_showOptional) ...[
              const SizedBox(height: 12),
              // 設定
              const _SectionLabel('設定'),
              Wrap(
                spacing: 8,
                children: [
                  ...List.generate(6, (i) => i + 1).map((s) => ChoiceChip(
                    label: Text('$s'),
                    selected: _setting == s,
                    onSelected: (_) => setState(() => _setting = _setting == s ? null : s),
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                        color: _setting == s ? Colors.white : AppColors.onSurface,
                        fontWeight: FontWeight.w600),
                  )),
                  ChoiceChip(
                    label: const Text('不明'),
                    selected: _setting == 0,
                    onSelected: (_) => setState(() => _setting = _setting == 0 ? null : 0),
                    selectedColor: AppColors.even,
                    labelStyle: TextStyle(color: _setting == 0 ? Colors.white : AppColors.onSurface),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 差枚数
              const _SectionLabel('差枚数'),
              _NumTextField(controller: _diffCtrl, label: '差枚数', suffix: '枚', signed: true),
              const SizedBox(height: 12),

              // G数
              const _SectionLabel('G数'),
              Row(children: [
                Expanded(child: _NumTextField(controller: _startGCtrl, label: '開始G数', suffix: 'G')),
                const SizedBox(width: 12),
                Expanded(child: _NumTextField(controller: _endGCtrl, label: '終了G数', suffix: 'G')),
              ]),
              const SizedBox(height: 12),

              // BB/RB/AT
              const _SectionLabel('ボーナス回数'),
              Row(children: [
                Expanded(child: _NumTextField(controller: _bbCtrl, label: 'BB')),
                const SizedBox(width: 8),
                Expanded(child: _NumTextField(controller: _rbCtrl, label: 'RB')),
                const SizedBox(width: 8),
                Expanded(child: _NumTextField(controller: _atCtrl, label: 'AT/ART')),
              ]),
              const SizedBox(height: 12),

              // メモ
              const _SectionLabel('メモ'),
              TextField(
                controller: _memoCtrl,
                decoration: const InputDecoration(hintText: '自由記入'),
                maxLines: 3,
              ),
              const SizedBox(height: 20),
            ],

            // ─── 保存ボタン ────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                child: const Text('保存する'),
              ),
            ),

            if (widget.existing != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _delete,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.loss,
                  side: const BorderSide(color: AppColors.loss),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('この記録を削除'),
              ),
            ],

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// ─── 共通 Widgets ──────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(
                color: AppColors.onSurfaceMuted, fontSize: 12, fontWeight: FontWeight.w500)),
      );
}

class _DateTile extends StatelessWidget {
  final DateTime date;
  final VoidCallback onTap;
  const _DateTile({required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Row(children: [
            const Icon(Icons.calendar_today, size: 20, color: AppColors.primary),
            const SizedBox(width: 12),
            Text(formatDate(date), style: const TextStyle(fontSize: 16)),
            const Spacer(),
            const Icon(Icons.chevron_right, color: AppColors.onSurfaceMuted),
          ]),
        ),
      );
}

class _FieldWithSearch extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final ValueChanged<String> onChanged;
  final VoidCallback onSearchTap;
  const _FieldWithSearch({required this.controller, required this.label,
      required this.onChanged, required this.onSearchTap});

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: IconButton(
            icon: const Icon(Icons.search, color: AppColors.primary),
            tooltip: '検索',
            onPressed: onSearchTap,
          ),
        ),
        onChanged: onChanged,
      );
}

class _MedalPriceTile extends StatelessWidget {
  final int medalPrice;
  final VoidCallback onEdit;
  const _MedalPriceTile({required this.medalPrice, required this.onEdit});

  String get _label {
    if (medalPrice <= 0) return '1枚あたりの金額を設定';
    final rate = _kMedalRates.where((r) => r.medals == medalPrice).firstOrNull;
    return rate?.label ?? '$medalPrice枚/¥1000';
  }

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Row(children: [
            const Icon(Icons.monetization_on_outlined, size: 18, color: AppColors.primary),
            const SizedBox(width: 10),
            Text(_label,
                style: TextStyle(
                    color: medalPrice > 0 ? AppColors.onSurface : AppColors.onSurfaceMuted,
                    fontSize: 13)),
            const Spacer(),
            const Icon(Icons.edit_outlined, size: 15, color: AppColors.onSurfaceMuted),
          ]),
        ),
      );
}

class _NumTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? suffix;
  final ValueChanged<String>? onChanged;
  final bool signed;

  const _NumTextField({
    required this.controller,
    required this.label,
    this.suffix,
    this.onChanged,
    this.signed = false,
  });

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: controller,
        keyboardType: signed
            ? const TextInputType.numberWithOptions(signed: true)
            : TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.allow(signed ? RegExp(r'-?\d*') : RegExp(r'\d*')),
        ],
        textInputAction: TextInputAction.next,
        decoration: InputDecoration(labelText: label, suffixText: suffix),
        onChanged: onChanged,
      );
}

class _ShortcutRow extends StatelessWidget {
  final List<String> labels;
  final List<VoidCallback> onTaps;
  const _ShortcutRow({required this.labels, required this.onTaps});

  @override
  Widget build(BuildContext context) => Row(
        children: List.generate(labels.length, (i) => Expanded(
          child: Padding(
            padding: EdgeInsets.only(left: i > 0 ? 6 : 0),
            child: OutlinedButton(
              onPressed: onTaps[i],
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 6),
                side: const BorderSide(color: AppColors.cardBorder),
                foregroundColor: AppColors.onSurface,
                textStyle: const TextStyle(fontSize: 12),
              ),
              child: Text(labels[i]),
            ),
          ),
        )),
      );
}

class _ProfitPreview extends StatelessWidget {
  final int medalDiff, cashDiff, totalProfit, medalPrice;
  const _ProfitPreview({required this.medalDiff, required this.cashDiff,
      required this.totalProfit, required this.medalPrice});

  Color _c(int v) => v > 0 ? AppColors.win : v < 0 ? AppColors.loss : AppColors.even;
  String _sm(int v) => '${v > 0 ? '+' : ''}$v枚';
  String _sc(int v) => '${v >= 0 ? '+' : ''}$v円';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _c(medalPrice > 0 ? totalProfit : medalDiff)),
      ),
      child: Column(children: [
        if (medalPrice > 0) ...[
          _PRow('メダル収支', Text(_sm(medalDiff),
              style: TextStyle(color: _c(medalDiff), fontWeight: FontWeight.w500))),
          const SizedBox(height: 6),
          _PRow('現金収支', Text(_sc(cashDiff),
              style: TextStyle(color: _c(cashDiff), fontWeight: FontWeight.w500))),
          Divider(color: AppColors.cardBorder.withValues(alpha: 0.5), height: 16),
          _PRow('合計収支', Text('${formatProfit(totalProfit)}円',
              style: TextStyle(color: _c(totalProfit), fontSize: 22, fontWeight: FontWeight.bold))),
        ] else ...[
          _PRow('メダル収支', Text(_sm(medalDiff),
              style: TextStyle(color: _c(medalDiff), fontSize: 20, fontWeight: FontWeight.bold))),
          if (cashDiff != 0) ...[
            const SizedBox(height: 6),
            _PRow('現金収支', Text(_sc(cashDiff),
                style: TextStyle(color: _c(cashDiff), fontWeight: FontWeight.w500))),
          ],
          const SizedBox(height: 4),
          const Text('1枚あたりの金額を設定すると円換算が表示されます',
              style: TextStyle(color: AppColors.onSurfaceMuted, fontSize: 10)),
        ],
      ]),
    );
  }
}

class _PRow extends StatelessWidget {
  final String label;
  final Widget child;
  const _PRow(this.label, this.child);

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.onSurfaceMuted, fontSize: 13)),
          child,
        ],
      );
}

class _TimeTile extends StatelessWidget {
  final String label;
  final DateTime? time;
  final VoidCallback onTap;
  const _TimeTile({required this.label, this.time, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Row(children: [
            const Icon(Icons.access_time, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(color: AppColors.onSurfaceMuted, fontSize: 11)),
              Text(time != null ? formatTime(time!) : '--:--',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            ]),
          ]),
        ),
      );
}

class _NowButton extends StatelessWidget {
  final VoidCallback onTap;
  const _NowButton({required this.onTap});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: onTap,
          icon: const Icon(Icons.access_time, size: 14),
          label: const Text('今', style: TextStyle(fontSize: 12)),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 6),
            side: const BorderSide(color: AppColors.cardBorder),
            foregroundColor: AppColors.onSurface,
          ),
        ),
      );
}

// ─── メダル単価ピッカー ─────────────────────────────────────────
class _MedalRatePicker extends StatefulWidget {
  final int initialIndex;
  const _MedalRatePicker({required this.initialIndex});

  @override
  State<_MedalRatePicker> createState() => _MedalRatePickerState();
}

class _MedalRatePickerState extends State<_MedalRatePicker> {
  late int _selectedIndex;
  late FixedExtentScrollController _ctrl;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _ctrl = FixedExtentScrollController(initialItem: _selectedIndex);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 340,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(children: [
        Container(
          margin: const EdgeInsets.symmetric(vertical: 12),
          width: 40, height: 4,
          decoration: BoxDecoration(color: AppColors.cardBorder, borderRadius: BorderRadius.circular(2)),
        ),
        const Text('1000円あたりのメダル枚数',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const Text('設定は店舗に紐づいて保存されます',
            style: TextStyle(color: AppColors.onSurfaceMuted, fontSize: 11)),
        const SizedBox(height: 8),
        Expanded(
          child: CupertinoPicker(
            scrollController: _ctrl,
            itemExtent: 52,
            onSelectedItemChanged: (i) => setState(() => _selectedIndex = i),
            children: List.generate(_kMedalRates.length, (i) => Center(
              child: Text(_kMedalRates[i].label,
                  style: TextStyle(
                    fontSize: i == _selectedIndex ? 19 : 16,
                    fontWeight: i == _selectedIndex ? FontWeight.bold : FontWeight.normal,
                    color: i == _selectedIndex ? AppColors.primary : AppColors.onSurfaceMuted,
                  )),
            )),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, _kMedalRates[_selectedIndex].medals),
              child: const Text('決定'),
            ),
          ),
        ),
      ]),
    );
  }
}

// ─── P-WORLD 検索ダイアログ ────────────────────────────────────
class _SearchDialog extends StatefulWidget {
  final String title, hint;
  final List<String> localSuggestions;
  final Future<List<String>> Function(String) remoteSearch;

  const _SearchDialog({
    required this.title, required this.hint,
    required this.localSuggestions, required this.remoteSearch,
  });

  @override
  State<_SearchDialog> createState() => _SearchDialogState();
}

class _SearchDialogState extends State<_SearchDialog> {
  final _ctrl = TextEditingController();
  List<String> _remoteResults = [];
  bool _loading = false;
  Timer? _debounce;

  @override
  void dispose() { _debounce?.cancel(); _ctrl.dispose(); super.dispose(); }

  void _onChanged(String value) {
    _debounce?.cancel();
    if (value.trim().length < 2) {
      setState(() { _remoteResults = []; _loading = false; });
      return;
    }
    setState(() => _loading = true);
    _debounce = Timer(const Duration(milliseconds: 700), () async {
      final results = await widget.remoteSearch(value.trim());
      if (mounted) setState(() { _remoteResults = results; _loading = false; });
    });
  }

  List<String> get _filteredLocal {
    final q = _ctrl.text.toLowerCase();
    if (q.isEmpty) return widget.localSuggestions;
    return widget.localSuggestions.where((s) => s.toLowerCase().contains(q)).toList();
  }

  List<String> get _combined {
    final seen = <String>{};
    final result = <String>[];
    for (final s in [..._filteredLocal, ..._remoteResults]) {
      if (seen.add(s)) result.add(s);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final items = _combined;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _ctrl,
            autofocus: true,
            decoration: InputDecoration(
              hintText: widget.hint,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2)))
                  : null,
            ),
            onChanged: _onChanged,
          ),
        ),
        if (!_loading && _ctrl.text.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '過去に登録した名前は 🕐 で表示されます。\n初めての店舗は手動入力 → 次回から候補に出ます。',
              style: TextStyle(color: AppColors.onSurfaceMuted, fontSize: 12),
            ),
          ),
        Expanded(
          child: items.isEmpty && _ctrl.text.isNotEmpty && !_loading
              ? const Center(child: Text('検索結果がありません',
                    style: TextStyle(color: AppColors.onSurfaceMuted)))
              : ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final isRemote = !_filteredLocal.contains(items[i]) &&
                        _remoteResults.contains(items[i]);
                    return ListTile(
                      leading: Icon(isRemote ? Icons.public : Icons.history,
                          size: 16,
                          color: isRemote ? AppColors.primary : AppColors.onSurfaceMuted),
                      title: Text(items[i]),
                      onTap: () => Navigator.of(context).pop(items[i]),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}
