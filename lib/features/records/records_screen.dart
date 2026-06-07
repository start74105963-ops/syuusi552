import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/local_database.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format_utils.dart';
import '../../shared/models/record_model.dart';
import '../../shared/repositories/record_repository.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/profit_chip.dart';
import 'record_form_screen.dart';

class RecordsScreen extends ConsumerStatefulWidget {
  const RecordsScreen({super.key});

  @override
  ConsumerState<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends ConsumerState<RecordsScreen> {
  List<RecordModel> _allRecords = [];
  bool _loading = true;
  // null = 全期間, DateTime = 指定月
  DateTime? _selectedMonth;

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    const userId = 'local_guest';
    final repo = RecordRepository(LocalDatabase());
    final records = await repo.getAll(userId);
    if (mounted) {
      setState(() {
        _allRecords = records;
        _loading = false;
      });
    }
  }

  List<RecordModel> get _filtered {
    if (_selectedMonth == null) return _allRecords;
    return _allRecords.where((r) =>
      r.date.year == _selectedMonth!.year &&
      r.date.month == _selectedMonth!.month,
    ).toList();
  }

  // 月の選択肢（全期間 + 最大12ヶ月）
  List<DateTime?> get _monthOptions {
    if (_allRecords.isEmpty) return [null];
    final months = <DateTime>{};
    for (final r in _allRecords) {
      months.add(DateTime(r.date.year, r.date.month));
    }
    final sorted = months.toList()..sort((a, b) => b.compareTo(a));
    return [null, ...sorted];
  }

  Future<void> _openForm([RecordModel? existing]) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => RecordFormScreen(existing: existing)),
    );
    if (result == true) _load();
  }

  Future<void> _delete(RecordModel record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('削除確認'),
        content: Text('${record.storeName} / ${record.machineName} の記録を削除しますか？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('キャンセル')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('削除', style: TextStyle(color: AppColors.loss)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await RecordRepository(LocalDatabase()).delete(record.id);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final records = _filtered;
    final totalProfit = records.fold(0, (s, r) => s + r.profit);
    final wins = records.where((r) => r.profit > 0).length;
    final winRate = records.isNotEmpty ? wins * 100 ~/ records.length : 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('実践履歴'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Column(
              children: [
                // ─── 月フィルター ─────────────────────────
                _MonthFilter(
                  options: _monthOptions,
                  selected: _selectedMonth,
                  onChanged: (m) => setState(() => _selectedMonth = m),
                ),

                // ─── 月サマリー ───────────────────────────
                if (records.isNotEmpty)
                  _MonthlySummary(
                    totalProfit: totalProfit,
                    count: records.length,
                    winRate: winRate,
                  ),

                // ─── リスト ───────────────────────────────
                Expanded(
                  child: records.isEmpty
                      ? EmptyState(
                          message: '記録がありません\n＋ボタンから追加しましょう',
                          icon: Icons.casino_outlined,
                          actionLabel: '記録を追加',
                          onAction: () => _openForm(),
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          color: AppColors.primary,
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                            itemCount: records.length,
                            itemBuilder: (_, i) => _RecordTile(
                              record: records[i],
                              onTap: () => _openForm(records[i]),
                              onDelete: () => _delete(records[i]),
                            ),
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}

// ─── 月フィルターチップ ────────────────────────────────────────
class _MonthFilter extends StatelessWidget {
  final List<DateTime?> options;
  final DateTime? selected;
  final ValueChanged<DateTime?> onChanged;

  const _MonthFilter({required this.options, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: options.map((m) {
            final isSelected = m == null ? selected == null : (selected?.year == m.year && selected?.month == m.month);
            final label = m == null ? '全期間' : formatMonth(m);
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(label),
                selected: isSelected,
                onSelected: (_) => onChanged(m),
                selectedColor: AppColors.primary,
                checkmarkColor: Colors.white,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : AppColors.onSurface,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
                backgroundColor: AppColors.surfaceVariant,
                side: BorderSide(
                  color: isSelected ? AppColors.primary : AppColors.cardBorder,
                  width: 0.5,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ─── 月サマリーバー ─────────────────────────────────────────────
class _MonthlySummary extends StatelessWidget {
  final int totalProfit, count, winRate;
  const _MonthlySummary({required this.totalProfit, required this.count, required this.winRate});

  @override
  Widget build(BuildContext context) {
    final color = totalProfit > 0 ? AppColors.win : totalProfit < 0 ? AppColors.loss : AppColors.even;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      color: AppColors.surface,
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('収支合計', style: TextStyle(color: AppColors.onSurfaceMuted, fontSize: 11)),
              Text(formatProfit(totalProfit),
                  style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 20)),
            ],
          ),
          const Spacer(),
          _SumItem(label: '回数', value: '$count 回'),
          const SizedBox(width: 20),
          _SumItem(label: '勝率', value: '$winRate%'),
        ],
      ),
    );
  }
}

class _SumItem extends StatelessWidget {
  final String label, value;
  const _SumItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(label, style: const TextStyle(color: AppColors.onSurfaceMuted, fontSize: 11)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        ],
      );
}

// ─── 実践タイル ─────────────────────────────────────────────────
class _RecordTile extends StatelessWidget {
  final RecordModel record;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _RecordTile({required this.record, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(record.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.loss.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: AppColors.loss),
      ),
      confirmDismiss: (_) async {
        onDelete();
        return false;
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(formatDate(record.date),
                      style: const TextStyle(color: AppColors.onSurfaceMuted, fontSize: 12)),
                  if (record.setting != null) ...[
                    const SizedBox(width: 8),
                    _SettingBadge(setting: record.setting!),
                  ],
                  const Spacer(),
                  ProfitChip(profit: record.profit),
                ]),
                const SizedBox(height: 8),
                Text(record.machineName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.store_outlined, size: 14, color: AppColors.onSurfaceMuted),
                  const SizedBox(width: 4),
                  Text(record.storeName,
                      style: const TextStyle(color: AppColors.onSurfaceMuted, fontSize: 13)),
                  const Spacer(),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  _StatItem(label: '投資', value: '¥${formatAmount(record.investment)}'),
                  const SizedBox(width: 16),
                  _StatItem(label: '回収', value: '¥${formatAmount(record.collection)}'),
                  if (record.diffMedals != null) ...[
                    const SizedBox(width: 16),
                    _StatItem(
                      label: '差枚',
                      value: '${record.diffMedals! > 0 ? '+' : ''}${record.diffMedals}枚',
                    ),
                  ],
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingBadge extends StatelessWidget {
  final int setting;
  const _SettingBadge({required this.setting});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        setting == 0 ? '不明' : '設$setting',
        style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Text('$label: ', style: const TextStyle(color: AppColors.onSurfaceMuted, fontSize: 12)),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      );
}
