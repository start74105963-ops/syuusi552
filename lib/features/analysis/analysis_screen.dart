import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/local_database.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format_utils.dart';
import '../../shared/models/record_model.dart';
import '../../shared/repositories/record_repository.dart';
import '../../shared/widgets/profit_chip.dart';

class AnalysisScreen extends ConsumerStatefulWidget {
  const AnalysisScreen({super.key});

  @override
  ConsumerState<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends ConsumerState<AnalysisScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  List<RecordModel> _records = [];
  DateTime _selectedMonth = DateTime.now();
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
    final repo = RecordRepository(LocalDatabase());
    final records = await repo.getByMonth(userId, _selectedMonth.year, _selectedMonth.month);
    setState(() {
      _records = records;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          _MonthSelector(
            month: _selectedMonth,
            onPrev: () {
              _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
              _load();
            },
            onNext: () {
              final next = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
              if (next.isBefore(DateTime.now().add(const Duration(days: 32)))) {
                _selectedMonth = next;
                _load();
              }
            },
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tab,
                    children: [
                      _MonthlyTab(records: _records),
                      _StoreTab(records: _records),
                      _MachineTab(records: _records),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _MonthSelector extends StatelessWidget {
  final DateTime month;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const _MonthSelector({required this.month, required this.onPrev, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(icon: const Icon(Icons.chevron_left), onPressed: onPrev),
          Text(formatMonth(month), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          IconButton(icon: const Icon(Icons.chevron_right), onPressed: onNext),
        ],
      ),
    );
  }
}

class _MonthlyTab extends StatelessWidget {
  final List<RecordModel> records;
  const _MonthlyTab({required this.records});

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return const Center(child: Text('この月の記録はありません', style: TextStyle(color: AppColors.onSurfaceMuted)));
    }

    final repo = RecordRepository(LocalDatabase());
    final summary = repo.summarize(records);
    final totalProfit = summary['totalProfit'] as int;
    final days = summary['days'] as int;
    final totalMinutes = summary['totalMinutes'] as int;

    // 日別収支チャート用データ
    final dayMap = <int, int>{};
    for (final r in records) {
      dayMap[r.date.day] = (dayMap[r.date.day] ?? 0) + r.profit;
    }
    final spots = dayMap.entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.toDouble()))
        .toList()
      ..sort((a, b) => a.x.compareTo(b.x));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 月間サマリーカード
        _SummaryCard(
          totalProfit: totalProfit,
          totalInvestment: summary['totalInvestment'] as int,
          totalCollection: summary['totalCollection'] as int,
          wins: summary['wins'] as int,
          total: records.length,
          days: days,
          totalMinutes: totalMinutes,
        ),
        const SizedBox(height: 16),
        // 日別収支グラフ
        if (spots.isNotEmpty) ...[
          const Text('日別収支', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                backgroundColor: AppColors.surface,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) => Text('${v.toInt()}', style: const TextStyle(fontSize: 9, color: AppColors.onSurfaceMuted)),
                    ),
                  ),
                ),
                barGroups: dayMap.entries.map((e) {
                  final isWin = e.value >= 0;
                  return BarChartGroupData(
                    x: e.key,
                    barRods: [
                      BarChartRodData(
                        toY: e.value.toDouble(),
                        color: isWin ? AppColors.win : AppColors.loss,
                        width: 8,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final int totalProfit, totalInvestment, totalCollection, wins, total, days, totalMinutes;
  const _SummaryCard({
    required this.totalProfit, required this.totalInvestment, required this.totalCollection,
    required this.wins, required this.total, required this.days, required this.totalMinutes,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('月間収支', style: TextStyle(color: AppColors.onSurfaceMuted)),
                ProfitChip(profit: totalProfit, fontSize: 20),
              ],
            ),
            const Divider(color: AppColors.cardBorder, height: 24),
            _Row('総投資', '${formatAmount(totalInvestment)}枚'),
            _Row('総回収', '${formatAmount(totalCollection)}枚'),
            _Row('稼働日数', '$days日'),
            _Row('勝率', total == 0 ? '-' : '${(wins / total * 100).toStringAsFixed(1)}% ($wins/$total)'),
            _Row('総稼働時間', formatMinutes(totalMinutes)),
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

class _StoreTab extends StatelessWidget {
  final List<RecordModel> records;
  const _StoreTab({required this.records});

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) return const Center(child: Text('データがありません', style: TextStyle(color: AppColors.onSurfaceMuted)));
    final repo = RecordRepository(LocalDatabase());
    final byStore = repo.byStore(records);
    final sorted = byStore.entries.toList()
      ..sort((a, b) => (b.value['totalProfit'] as int).compareTo(a.value['totalProfit'] as int));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sorted.length,
      itemBuilder: (_, i) {
        final entry = sorted[i];
        final s = entry.value;
        final profit = s['totalProfit'] as int;
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(child: Text('${i + 1}', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('${s['days']}日 / ${records.where((r) => r.storeName == entry.key).length}回', style: const TextStyle(color: AppColors.onSurfaceMuted, fontSize: 12)),
                    ],
                  ),
                ),
                ProfitChip(profit: profit),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MachineTab extends StatelessWidget {
  final List<RecordModel> records;
  const _MachineTab({required this.records});

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) return const Center(child: Text('データがありません', style: TextStyle(color: AppColors.onSurfaceMuted)));
    final repo = RecordRepository(LocalDatabase());
    final byMachine = repo.byMachine(records);
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
                Row(
                  children: [
                    Expanded(child: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold))),
                    ProfitChip(profit: profit),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text('${count}回', style: const TextStyle(color: AppColors.onSurfaceMuted, fontSize: 12)),
                    const SizedBox(width: 12),
                    Text('勝率: ${((s['winRate'] as double) * 100).toStringAsFixed(0)}%', style: const TextStyle(color: AppColors.onSurfaceMuted, fontSize: 12)),
                    const SizedBox(width: 12),
                    Text('平均: ${formatProfit(count > 0 ? profit ~/ count : 0)}', style: const TextStyle(color: AppColors.onSurfaceMuted, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
