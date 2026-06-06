import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/local_database.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format_utils.dart';
import '../../shared/models/record_model.dart';
import '../../shared/repositories/record_repository.dart';
import '../../shared/widgets/profit_chip.dart';
import '../auth/auth_provider.dart';
import '../records/record_form_screen.dart';
import '../records/records_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  List<RecordModel> _todayRecords = [];
  List<RecordModel> _monthRecords = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final userId = ref.read(authProvider).value?.id ?? 'local';
    final repo = RecordRepository(LocalDatabase());
    final now = DateTime.now();
    final monthRecords = await repo.getByMonth(userId, now.year, now.month);
    final today = DateTime(now.year, now.month, now.day);
    setState(() {
      _monthRecords = monthRecords;
      _todayRecords = monthRecords.where((r) {
        final d = DateTime(r.date.year, r.date.month, r.date.day);
        return d == today;
      }).toList();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final user = ref.watch(authProvider).value;
    final monthSummary = RecordRepository(LocalDatabase()).summarize(_monthRecords);
    final todayProfit = _todayRecords.fold(0, (s, r) => s + r.profit);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ホーム'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ユーザー挨拶
                  Text(
                    'こんにちは、${user?.displayName ?? 'ゲスト'}さん',
                    style: const TextStyle(color: AppColors.onSurfaceMuted, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(formatDate(now), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 20),

                  // 今日の収支カード
                  _TodayCard(profit: todayProfit, records: _todayRecords),
                  const SizedBox(height: 12),

                  // 今月サマリーカード
                  _MonthCard(
                    month: now,
                    summary: monthSummary,
                    records: _monthRecords,
                  ),
                  const SizedBox(height: 20),

                  // 最近の実践
                  if (_monthRecords.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('最近の実践', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        TextButton(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const RecordsScreen()),
                          ),
                          child: const Text('すべて見る', style: TextStyle(color: AppColors.primary)),
                        ),
                      ],
                    ),
                    ...(_monthRecords.take(3).map((r) => _RecentTile(record: r, onRefresh: _load))),
                  ],
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const RecordFormScreen()),
          );
          if (result == true) _load();
        },
        icon: const Icon(Icons.add),
        label: const Text('実践を記録'),
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  final int profit;
  final List<RecordModel> records;
  const _TodayCard({required this.profit, required this.records});

  @override
  Widget build(BuildContext context) {
    final color = profit > 0 ? AppColors.win : profit < 0 ? AppColors.loss : AppColors.even;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('今日の収支', style: TextStyle(color: AppColors.onSurfaceMuted, fontSize: 13)),
          const SizedBox(height: 8),
          Text(
            formatProfit(profit),
            style: TextStyle(color: color, fontSize: 36, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            records.isEmpty ? '本日の実践なし' : '${records.length}回実践',
            style: const TextStyle(color: AppColors.onSurfaceMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _MonthCard extends StatelessWidget {
  final DateTime month;
  final Map<String, dynamic> summary;
  final List<RecordModel> records;
  const _MonthCard({required this.month, required this.summary, required this.records});

  @override
  Widget build(BuildContext context) {
    final totalProfit = summary['totalProfit'] as int? ?? 0;
    final days = summary['days'] as int? ?? 0;
    final wins = summary['wins'] as int? ?? 0;
    final count = records.length;
    final winRate = count > 0 ? wins / count * 100 : 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(formatMonth(month), style: const TextStyle(color: AppColors.onSurfaceMuted, fontSize: 13)),
                const Spacer(),
                ProfitChip(profit: totalProfit),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _StatBox(label: '稼働日数', value: '$days日'),
                _StatBox(label: '勝率', value: '${winRate.toStringAsFixed(0)}%'),
                _StatBox(label: '総稼働', value: formatMinutes(summary['totalMinutes'] as int? ?? 0)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label, value;
  const _StatBox({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          children: [
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(label, style: const TextStyle(color: AppColors.onSurfaceMuted, fontSize: 11)),
          ],
        ),
      );
}

class _RecentTile extends StatelessWidget {
  final RecordModel record;
  final VoidCallback onRefresh;
  const _RecentTile({required this.record, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Text(record.machineName, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${record.storeName} · ${formatDate(record.date)}',
          style: const TextStyle(color: AppColors.onSurfaceMuted, fontSize: 12),
        ),
        trailing: ProfitChip(profit: record.profit),
        onTap: () async {
          final result = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => RecordFormScreen(existing: record)),
          );
          if (result == true) onRefresh();
        },
      ),
    );
  }
}
