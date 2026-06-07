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

class RecordFormScreen extends ConsumerStatefulWidget {
  final RecordModel? existing;
  final DateTime? initialDate;

  const RecordFormScreen({super.key, this.existing, this.initialDate});

  @override
  ConsumerState<RecordFormScreen> createState() => _RecordFormScreenState();
}

class _RecordFormScreenState extends ConsumerState<RecordFormScreen> {
  late DateTime _date;
  final _storeCtrl    = TextEditingController();
  final _machineCtrl  = TextEditingController();
  final _investCtrl   = TextEditingController();
  final _recoverCtrl  = TextEditingController();

  // 任意項目
  int?  _setting;
  final _diffCtrl  = TextEditingController();
  final _startGCtrl = TextEditingController();
  final _endGCtrl  = TextEditingController();
  final _bbCtrl    = TextEditingController();
  final _rbCtrl    = TextEditingController();
  final _atCtrl    = TextEditingController();
  final _memoCtrl  = TextEditingController();

  bool _showOptional = false;
  bool _saving = false;

  List<String> _storeSuggestions  = [];
  List<String> _machineSuggestions = [];

  int get _invest  => int.tryParse(_investCtrl.text)  ?? 0;
  int get _recover => int.tryParse(_recoverCtrl.text) ?? 0;
  int get _profit  => _recover - _invest;

  bool get _canSave =>
      _storeCtrl.text.trim().isNotEmpty &&
      _machineCtrl.text.trim().isNotEmpty &&
      _investCtrl.text.isNotEmpty &&
      _recoverCtrl.text.isNotEmpty;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _date = e?.date ?? widget.initialDate ?? DateTime.now();
    if (e != null) {
      _storeCtrl.text   = e.storeName;
      _machineCtrl.text = e.machineName;
      _investCtrl.text  = e.investment.toString();
      _recoverCtrl.text = e.collection.toString();
      _setting          = e.setting;
      _diffCtrl.text    = e.diffMedals?.toString() ?? '';
      _startGCtrl.text  = e.startG?.toString() ?? '';
      _endGCtrl.text    = e.endG?.toString() ?? '';
      _bbCtrl.text      = e.bbCount?.toString() ?? '';
      _rbCtrl.text      = e.rbCount?.toString() ?? '';
      _atCtrl.text      = e.atCount?.toString() ?? '';
      _memoCtrl.text    = e.memo ?? '';
      if (_setting != null || _diffCtrl.text.isNotEmpty || _startGCtrl.text.isNotEmpty) {
        _showOptional = true;
      }
    }
    _loadSuggestions();
    for (final c in [_investCtrl, _recoverCtrl]) {
      c.addListener(() => setState(() {}));
    }
    _storeCtrl.addListener(() => setState(() {}));
    _machineCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    for (final c in [
      _storeCtrl, _machineCtrl, _investCtrl, _recoverCtrl,
      _diffCtrl, _startGCtrl, _endGCtrl, _bbCtrl, _rbCtrl, _atCtrl, _memoCtrl,
    ]) { c.dispose(); }
    super.dispose();
  }

  Future<void> _loadSuggestions() async {
    final storeRows = await LocalDatabase().getStores('local_guest');
    final machines  = kMachineData.map((m) => m['name']!).toSet().toList();
    if (mounted) {
      setState(() {
        _storeSuggestions   = storeRows.map((r) => r['name'] as String).toList();
        _machineSuggestions = machines;
      });
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
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_canSave || _saving) return;
    setState(() => _saving = true);
    try {
      final existing = widget.existing;
      final repo = RecordRepository(LocalDatabase());
      final record = RecordModel(
        id:         existing?.id ?? const Uuid().v4(),
        userId:     'local_guest',
        date:       _date,
        storeName:  _storeCtrl.text.trim(),
        machineName: _machineCtrl.text.trim(),
        investment: _invest,
        collection: _recover,
        profit:     _profit,
        investmentCash: _invest,
        collectionCash: _recover,
        setting:    _setting,
        diffMedals: int.tryParse(_diffCtrl.text),
        startG:     int.tryParse(_startGCtrl.text),
        endG:       int.tryParse(_endGCtrl.text),
        bbCount:    int.tryParse(_bbCtrl.text),
        rbCount:    int.tryParse(_rbCtrl.text),
        atCount:    int.tryParse(_atCtrl.text),
        memo:       _memoCtrl.text.trim().isEmpty ? null : _memoCtrl.text.trim(),
      );
      if (existing != null) {
        await repo.update(record);
      } else {
        await repo.insert(record);
        // 店舗を保存
        if (_storeCtrl.text.trim().isNotEmpty) {
          await LocalDatabase().insertStore({
            'id': const Uuid().v4(),
            'user_id': 'local_guest',
            'name': _storeCtrl.text.trim(),
            'medal_price': 0,
          });
        }
      }
      if (mounted) Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profitColor = _profit > 0 ? AppColors.win : _profit < 0 ? AppColors.loss : AppColors.even;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.existing != null ? '実践を編集' : '実践を記録'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _saving
                ? const SizedBox(
                    width: 24, height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                  )
                : TextButton(
                    onPressed: _canSave ? _save : null,
                    child: Text(
                      '保存',
                      style: TextStyle(
                        color: _canSave ? AppColors.primary : AppColors.cardBorder,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ─── 必須項目 ─────────────────────────────────
          _Section(title: '必須項目', children: [
            // 日付
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today_outlined, color: AppColors.primary, size: 20),
              title: const Text('遊技日', style: TextStyle(color: AppColors.onSurfaceMuted, fontSize: 12)),
              subtitle: Text(formatDate(_date),
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: AppColors.onSurface)),
              onTap: _pickDate,
              trailing: const Icon(Icons.edit_outlined, size: 18, color: AppColors.onSurfaceMuted),
            ),
            const Divider(),

            // 店舗名
            _AutocompleteField(
              label: '店舗名',
              controller: _storeCtrl,
              suggestions: _storeSuggestions,
              icon: Icons.store_outlined,
            ),
            const SizedBox(height: 12),

            // 機種名
            _AutocompleteField(
              label: '機種名',
              controller: _machineCtrl,
              suggestions: _machineSuggestions,
              icon: Icons.casino_outlined,
            ),
            const SizedBox(height: 16),

            // 投資・回収
            Row(children: [
              Expanded(
                child: _AmountField(
                  label: '投資額（円）',
                  controller: _investCtrl,
                  color: AppColors.loss,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _AmountField(
                  label: '回収額（円）',
                  controller: _recoverCtrl,
                  color: AppColors.win,
                ),
              ),
            ]),
            const SizedBox(height: 16),

            // 収支（自動計算）
            if (_investCtrl.text.isNotEmpty || _recoverCtrl.text.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: profitColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: profitColor.withValues(alpha: 0.3)),
                ),
                child: Row(children: [
                  const Text('収支', style: TextStyle(color: AppColors.onSurfaceMuted, fontSize: 13)),
                  const Spacer(),
                  Text(
                    formatProfit(_profit),
                    style: TextStyle(color: profitColor, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ]),
              ),
          ]),

          const SizedBox(height: 16),

          // ─── 任意項目 ─────────────────────────────────
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
                const Text('詳細を追加', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                const Spacer(),
                Icon(
                  _showOptional ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: AppColors.primary,
                ),
              ]),
            ),
          ),

          if (_showOptional) ...[
            const SizedBox(height: 12),
            _Section(title: '任意項目', children: [
              // 設定
              const Text('設定', style: TextStyle(color: AppColors.onSurfaceMuted, fontSize: 12)),
              const SizedBox(height: 8),
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
                      fontWeight: FontWeight.w600,
                    ),
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
              _NumField(label: '差枚数', controller: _diffCtrl),
              const SizedBox(height: 12),

              // G数
              Row(children: [
                Expanded(child: _NumField(label: '開始G数', controller: _startGCtrl)),
                const SizedBox(width: 12),
                Expanded(child: _NumField(label: '終了G数', controller: _endGCtrl)),
              ]),
              const SizedBox(height: 12),

              // BB/RB/AT
              Row(children: [
                Expanded(child: _NumField(label: 'BB', controller: _bbCtrl)),
                const SizedBox(width: 8),
                Expanded(child: _NumField(label: 'RB', controller: _rbCtrl)),
                const SizedBox(width: 8),
                Expanded(child: _NumField(label: 'AT/ART', controller: _atCtrl)),
              ]),
              const SizedBox(height: 12),

              // メモ
              TextField(
                controller: _memoCtrl,
                decoration: const InputDecoration(
                  labelText: 'メモ',
                  prefixIcon: Icon(Icons.notes_outlined, size: 20),
                ),
                maxLines: 3,
                textInputAction: TextInputAction.newline,
              ),
            ]),
          ],

          const SizedBox(height: 32),

          // 保存ボタン
          ElevatedButton(
            onPressed: _canSave ? _save : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _canSave ? AppColors.primary : AppColors.cardBorder,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _saving
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('保存する', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),

          if (widget.existing != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => _confirmDelete(),
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
    );
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('削除しますか？'),
        content: const Text('この実践記録を削除します。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('キャンセル')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('削除', style: TextStyle(color: AppColors.loss)),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await RecordRepository(LocalDatabase()).delete(widget.existing!.id);
      if (mounted) Navigator.of(context).pop(true);
    }
  }
}

// ─── 共通 Widgets ──────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 8),
          child: Text(title,
              style: const TextStyle(
                  color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.cardBorder, width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    );
  }
}

class _AutocompleteField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final List<String> suggestions;
  final IconData icon;

  const _AutocompleteField({
    required this.label,
    required this.controller,
    required this.suggestions,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      initialValue: TextEditingValue(text: controller.text),
      optionsBuilder: (v) => suggestions.where(
          (s) => s.toLowerCase().contains(v.text.toLowerCase())),
      onSelected: (s) => controller.text = s,
      fieldViewBuilder: (_, ctrl, focus, __) {
        // コントローラを同期
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (ctrl.text != controller.text) {
            ctrl.text = controller.text;
          }
        });
        ctrl.addListener(() => controller.text = ctrl.text);
        return TextField(
          controller: ctrl,
          focusNode: focus,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon, size: 20),
          ),
          textInputAction: TextInputAction.next,
        );
      },
    );
  }
}

class _AmountField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final Color color;

  const _AmountField({required this.label, required this.controller, required this.color});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: label,
        prefixText: '¥ ',
        prefixStyle: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _NumField extends StatelessWidget {
  final String label;
  final TextEditingController controller;

  const _NumField({required this.label, required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(signed: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'-?\d*'))],
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(labelText: label),
    );
  }
}
