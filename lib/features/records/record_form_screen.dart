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
import '../auth/auth_provider.dart';

class RecordFormScreen extends ConsumerStatefulWidget {
  final RecordModel? existing;

  const RecordFormScreen({super.key, this.existing});

  @override
  ConsumerState<RecordFormScreen> createState() => _RecordFormScreenState();
}

class _RecordFormScreenState extends ConsumerState<RecordFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _date;
  String _storeName = '';
  String _machineName = '';
  int? _machineNumber;
  DateTime? _startTime;
  DateTime? _endTime;
  int _investment = 0;
  int _collection = 0;
  String _memo = '';
  bool _showMore = false;

  final _storeCtrl = TextEditingController();
  final _machineCtrl = TextEditingController();
  final _machineNumCtrl = TextEditingController();
  final _investCtrl = TextEditingController();
  final _collectionCtrl = TextEditingController();
  final _memoCtrl = TextEditingController();

  List<String> _storeSuggestions = [];
  List<String> _machineSuggestions = [];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _date = e?.date ?? DateTime.now();
    _storeName = e?.storeName ?? '';
    _machineName = e?.machineName ?? '';
    _machineNumber = e?.machineNumber;
    _startTime = e?.startTime;
    _endTime = e?.endTime;
    _investment = e?.investment ?? 0;
    _collection = e?.collection ?? 0;
    _memo = e?.memo ?? '';

    _storeCtrl.text = _storeName;
    _machineCtrl.text = _machineName;
    _machineNumCtrl.text = _machineNumber?.toString() ?? '';
    _investCtrl.text = _investment > 0 ? _investment.toString() : '';
    _collectionCtrl.text = _collection > 0 ? _collection.toString() : '';
    _memoCtrl.text = _memo;

    _loadSuggestions();
  }

  Future<void> _loadSuggestions() async {
    final userId = ref.read(authProvider).value?.id ?? '';
    final storeRows = await LocalDatabase().getStores(userId);
    final machineNames = kMachineData.map((m) => m['name']!).toList();
    setState(() {
      _storeSuggestions = storeRows.map((r) => r['name'] as String).toList();
      _machineSuggestions = machineNames;
    });
  }

  int get _profit => _collection - _investment;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime(bool isStart) async {
    final now = DateTime.now();
    final initial = isStart
        ? (_startTime != null ? TimeOfDay.fromDateTime(_startTime!) : TimeOfDay.fromDateTime(now))
        : (_endTime != null ? TimeOfDay.fromDateTime(_endTime!) : TimeOfDay.fromDateTime(now));

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    final dt = DateTime(_date.year, _date.month, _date.day, picked.hour, picked.minute);
    setState(() {
      if (isStart) _startTime = dt;
      else _endTime = dt;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    final userId = ref.read(authProvider).value?.id ?? 'local';
    final repo = RecordRepository(LocalDatabase());
    final record = RecordModel(
      id: widget.existing?.id ?? const Uuid().v4(),
      userId: userId,
      date: _date,
      storeName: _storeName,
      machineName: _machineName,
      machineNumber: _machineNumber,
      startTime: _startTime,
      endTime: _endTime,
      investment: _investment,
      collection: _collection,
      profit: _profit,
      memo: _memo.isEmpty ? null : _memo,
    );

    if (widget.existing == null) {
      await repo.insert(record);
    } else {
      await repo.update(record);
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? '新規実践登録' : '実践編集'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('保存', style: TextStyle(color: AppColors.primary, fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 日付
            _SectionLabel(label: '日付'),
            _DateTile(date: _date, onTap: _pickDate),
            const SizedBox(height: 16),

            // 店舗
            _SectionLabel(label: '店舗'),
            _AutocompleteField(
              controller: _storeCtrl,
              label: '店舗名',
              suggestions: _storeSuggestions,
              validator: (v) => (v == null || v.isEmpty) ? '店舗名を入力してください' : null,
              onSaved: (v) => _storeName = v ?? '',
            ),
            const SizedBox(height: 12),

            // 機種
            _SectionLabel(label: '機種'),
            _AutocompleteField(
              controller: _machineCtrl,
              label: '機種名',
              suggestions: _machineSuggestions,
              validator: (v) => (v == null || v.isEmpty) ? '機種名を入力してください' : null,
              onSaved: (v) => _machineName = v ?? '',
            ),
            const SizedBox(height: 16),

            // 投資・回収
            _SectionLabel(label: '投資 / 回収'),
            Row(
              children: [
                Expanded(
                  child: _AmountField(
                    controller: _investCtrl,
                    label: '投資（枚）',
                    onChanged: (v) => setState(() => _investment = int.tryParse(v) ?? 0),
                    onSaved: (v) => _investment = int.tryParse(v ?? '') ?? 0,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _AmountField(
                    controller: _collectionCtrl,
                    label: '回収（枚）',
                    onChanged: (v) => setState(() => _collection = int.tryParse(v) ?? 0),
                    onSaved: (v) => _collection = int.tryParse(v ?? '') ?? 0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 収支プレビュー
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _profit > 0 ? AppColors.win : _profit < 0 ? AppColors.loss : AppColors.cardBorder,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('収支', style: TextStyle(color: AppColors.onSurfaceMuted)),
                  Text(
                    formatProfit(_profit),
                    style: TextStyle(
                      color: _profit > 0 ? AppColors.win : _profit < 0 ? AppColors.loss : AppColors.even,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 時間（折りたたみ）
            GestureDetector(
              onTap: () => setState(() => _showMore = !_showMore),
              child: Row(
                children: [
                  const Text('時間・その他', style: TextStyle(color: AppColors.onSurfaceMuted)),
                  const Spacer(),
                  Icon(
                    _showMore ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.onSurfaceMuted,
                  ),
                ],
              ),
            ),
            if (_showMore) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _TimeTile(label: '開始', time: _startTime, onTap: () => _pickTime(true))),
                  const SizedBox(width: 12),
                  Expanded(child: _TimeTile(label: '終了', time: _endTime, onTap: () => _pickTime(false))),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _machineNumCtrl,
                decoration: const InputDecoration(labelText: '台番号'),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onSaved: (v) => _machineNumber = int.tryParse(v ?? ''),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _memoCtrl,
                decoration: const InputDecoration(labelText: 'メモ', hintText: '自由記入'),
                maxLines: 2,
                onSaved: (v) => _memo = v ?? '',
              ),
            ],
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(label, style: const TextStyle(color: AppColors.onSurfaceMuted, fontSize: 12, fontWeight: FontWeight.w500)),
      );
}

class _DateTile extends StatelessWidget {
  final DateTime date;
  final VoidCallback onTap;
  const _DateTile({required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, size: 20, color: AppColors.primary),
            const SizedBox(width: 12),
            Text(formatDate(date), style: const TextStyle(fontSize: 16)),
            const Spacer(),
            const Icon(Icons.chevron_right, color: AppColors.onSurfaceMuted),
          ],
        ),
      ),
    );
  }
}

class _TimeTile extends StatelessWidget {
  final String label;
  final DateTime? time;
  final VoidCallback onTap;
  const _TimeTile({required this.label, this.time, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          children: [
            const Icon(Icons.access_time, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: AppColors.onSurfaceMuted, fontSize: 11)),
                Text(
                  time != null ? formatTime(time!) : '--:--',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AmountField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final ValueChanged<String> onChanged;
  final FormFieldSetter<String> onSaved;

  const _AmountField({
    required this.controller,
    required this.label,
    required this.onChanged,
    required this.onSaved,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: onChanged,
      onSaved: onSaved,
    );
  }
}

class _AutocompleteField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final List<String> suggestions;
  final FormFieldValidator<String>? validator;
  final FormFieldSetter<String>? onSaved;

  const _AutocompleteField({
    required this.controller,
    required this.label,
    required this.suggestions,
    this.validator,
    this.onSaved,
  });

  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      optionsBuilder: (textEditingValue) {
        if (textEditingValue.text.isEmpty) return const [];
        return suggestions.where(
          (s) => s.toLowerCase().contains(textEditingValue.text.toLowerCase()),
        );
      },
      onSelected: (s) => controller.text = s,
      fieldViewBuilder: (context, fieldController, focusNode, onFieldSubmitted) {
        // sync external controller text to field controller
        if (fieldController.text != controller.text && controller.text.isNotEmpty) {
          fieldController.text = controller.text;
        }
        return TextFormField(
          controller: fieldController,
          focusNode: focusNode,
          decoration: InputDecoration(labelText: label),
          validator: validator,
          onSaved: (v) {
            controller.text = v ?? '';
            onSaved?.call(v);
          },
          onChanged: (v) => controller.text = v,
        );
      },
      optionsViewBuilder: (context, onSelected, options) => Align(
        alignment: Alignment.topLeft,
        child: Material(
          color: AppColors.surface,
          elevation: 4,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: MediaQuery.of(context).size.width - 32,
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 4),
              shrinkWrap: true,
              children: options.map((o) => ListTile(
                title: Text(o),
                dense: true,
                onTap: () => onSelected(o),
              )).toList(),
            ),
          ),
        ),
      ),
    );
  }
}
