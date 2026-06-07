import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/local_database.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format_utils.dart';
import '../../shared/models/record_model.dart';
import '../../shared/repositories/record_repository.dart';
import '../../shared/widgets/profit_chip.dart';

enum _Period { thisMonth, lastMonth, threeMonths, allTime }

extension _PeriodLabel on _Period {
  String get label {
    switch (this) {
      case _Period.thisMonth:    return '今月';
      case _Period.lastMonth:    return '前月';
      case _Period.threeMonths:  return '3ヶ月';
      case _Period.allTime:      return '全期間';
    }
  }
}

class AnalysisScreen extends ConsumerStatefulWidget {
  const AnalysisScreen({super.key});

  @override
  ConsumerState<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends ConsumerState<AnalysisScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  List<RecordModel> _allRecords = [];
  _Period _period = _Period.thisMonth;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    const userId = 'local_guest';
    final records = await RecordRepository(LocalDatabase()).getAll(userId);
    if (mounted) {
      setState(() {
        _allRecords = records;
        _loading = false;
      });
    }
  }

  List<RecordModel> get _filtered {
    final now = DateTime.now();
    switch (_period) {
      case _Period.thisMonth:
        return _allRecords.where((r) =>
            r.date.year == now.year && r.date.month == now.month).toList();
      case _Period.lastMonth:
        final last = DateTime(now.year, now.month - 1);
        return _allRecords.where((r) =>
            r.date.year == last.year && r.date.month == last.month).toList();
      case _Period.threeMonths:
        final cutoff = DateTime(now.year, now.month - 2, 1);
        return _allRecords.where((r) =>
            !r.date.isBefore(cutoff)).toList();
      case _Period.allTime:
        return _allRecords;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('分析'),
        bottom: TabBar(
          controller: _tab,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.onSurfaceMuted,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: '月間'),
            Tab(text: '店舗別'),
            Tab(text: '機種別'),
          ],
        ),
      ),
      body: Column(
        children: [
          // ─── 期間タブ ─────────────────────────────
          _PeriodSelector(
            selected: _period,
            onChanged: (p) => setState(() => _period = p),
          ),

          // ─── コンテンツ ───────────────────────────
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : TabBarView(
                    controller: _tab,
                    children: [
                      _MonthlyTab(records: _filtered, period: _period),
                      _StoreTab(records: _filtered),
                      _MachineTab(records: _filtered),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── 期間セレクター ─────────────────────────────────────────────
class _PeriodSelector extends StatelessWidget {
  final _Period selected;
  final ValueChanged<_Period> onChanged;

  const _PeriodSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      child: Row(
        children: _Period.values.map((p) {
          final isSelected = p == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(p),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isSelected ? AppColors.primary : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  p.label,
                  style: TextStyle(
                    color: isSelected ? AppColors.primary : AppColors.onSurfaceMuted,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── 月間タブ ───────────────────────────────────────────────────
class _MonthlyTab extends StatelessWidget {
  final List<RecordModel> records;
  final _Period period;
  const _MonthlyTab({required this.records, required this.period});

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return const Center(
        child: Text('この期間の記録はありません', style: TextStyle(color: AppColors.onSurfaceMuted)),
      );
    }

    final totalProfit     = records.fold(0, (s, r) => s + r.profit);
    final totalInvestment = records.fold(0, (s, r) => s + r.investment);
    final totalCollection = records.fold(0, (s, r) => s + r.collection);
    final wins = records.where((r) => r.profit > 0).length;
    final total = records.length;

    // グラフデータ
    final isMultiMonth = period == _Period.threeMonths || period == _Period.allTime;
    final Map<String, int> chartMap = {};
    for (final r in records) {
      final key = isMultiMonth
          ? '${r.date.year}/${r.date.month}'
          : '${r.date.day}';
      chartMap[key] = (chartMap[key] ?? 0) + r.profit;
    }
    final sortedKeys = chartMap.keys.toList()
      ..sort((a, b) {
        if (isMultiMonth) {
          final ap = a.split('/').map(int.parse).toList();
          final bp = b.split('/').map(int.parse).toList();
          final ad = DateTime(ap[0], ap[1]);
          final bd = DateTime(bp[0], bp[1]);
          return ad.compareTo(bd);
        }
        return int.parse(a).compareTo(int.parse(b));
      });

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // サマリーカード
        _SummaryCard(
          totalProfit: totalProfit,
          totalInvestment: totalInvestment,
          totalCollection: totalCollection,
          wins: wins,
          total: total,
        ),
        const SizedBox(height: 16),

        // 収支グラフ
        if (sortedKeys.isNotEmpty) ...[
          Text(
            isMultiMonth ? '月別収支' : '日別収支',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Container(
            height: 200,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.cardBorder, width: 0.5),
            ),
            child: BarChart(
              BarChartData(
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      getTitlesWidget: (v, _) {
                        final idx = v.toInt();
                        if (idx < 0 || idx >= sortedKeys.length) return const SizedBox();
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            sortedKeys[idx],
                            style: const TextStyle(fontSize: 9, color: AppColors.onSurfaceMuted),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: List.generate(sortedKeys.length, (i) {
                  final v = chartMap[sortedKeys[i]]!;
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: v.toDouble(),
                        color: v >= 0 ? AppColors.win : AppColors.loss,
                        width: isMultiMonth ? 24 : 10,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final int totalProfit, totalInvestment, totalCollection, wins, total;
  const _SummaryCard({
    required this.totalProfit, required this.totalInvestment,
    required this.totalCollection, required this.wins, required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final winRate = total > 0 ? wins * 100.0 / total : 0.0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('期間収支', style: TextStyle(color: AppColors.onSurfaceMuted)),
                ProfitChip(profit: totalProfit, fontSize: 20),
              ],
            ),
            const Divider(color: AppColors.cardBorder, height: 24),
            _Row('総投資',  '¥${formatAmount(totalInvestment)}'),
            _Row('総回収',  '¥${formatAmount(totalCollection)}'),
            _Row('実践回数', '$total 回'),
            _Row('勝率',   '${winRate.toStringAsFixed(1)}%  ($wins/$total)'),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label, value;
  const _Row(this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: AppColors.onSurfaceMuted, fontSize: 13)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
          ],
        ),
      );
}

// ─── 店舗別タブ ─────────────────────────────────────────────────
class _StoreTab extends StatelessWidget {
  final List<RecordModel> records;
  const _StoreTab({required this.records});

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return const Center(child: Text('データがありません', style: TextStyle(color: AppColors.onSurfaceMuted)));
    }
    final byStore = RecordRepository(LocalDatabase()).byStore(records);
    final sorted = byStore.entries.toList()
      ..sort((a, b) => (b.value['totalProfit'] as int).compareTo(a.value['totalProfit'] as int));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sorted.length,
      itemBuilder: (_, i) {
        final entry = sorted[i];
        final s = entry.value;
        final profit = s['totalProfit'] as int;
        final count = records.where((r) => r.storeName == entry.key).length;
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text('${i + 1}',
                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('$count回 / ${s['days']}日',
                        style: const TextStyle(color: AppColors.onSurfaceMuted, fontSize: 12)),
                  ],
                ),
              ),
              ProfitChip(profit: profit),
            ]),
          ),
        );
      },
    );
  }
}

// ─── 機種別タブ ─────────────────────────────────────────────────
class _MachineTab extends StatelessWidget {
  final List<RecordModel> records;
  const _MachineTab({required this.records});

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return const Center(child: Text('データがありません', style: TextStyle(color: AppColors.onSurfaceMuted)));
    }
    final byMachine = RecordRepository(LocalDatabase()).byMachine(records);
    final sorted = byMachine.entries.toList()
      ..sort((a, b) => (b.value['totalProfit'] as int).compareTo(a.value['totalProfit'] as int));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sorted.length,
      itemBuilder: (_, i) {
        final entry = sorted[i];
        final s = entry.value;
        final profit = s['totalProfit'] as int;
        final count = records.where((r) => r.machineName == entry.key).length;
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(child: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold))),
                  ProfitChip(profit: profit),
                ]),
                const SizedBox(height: 6),
                Row(children: [
                  Text('$count回',
                      style: const TextStyle(color: AppColors.onSurfaceMuted, fontSize: 12)),
                  const SizedBox(width: 12),
                  Text('勝率: ${((s['winRate'] as double) * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(color: AppColors.onSurfaceMuted, fontSize: 12)),
                  const SizedBox(width: 12),
                  Text('平均: ${formatProfit(count > 0 ? profit ~/ count : 0)}',
                      style: const TextStyle(color: AppColors.onSurfaceMuted, fontSize: 12)),
                ]),
              ],
            ),
          ),
        );
      },
    );
  }
}
