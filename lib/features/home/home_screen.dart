import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../core/database/local_database.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format_utils.dart';
import '../../shared/models/record_model.dart';
import '../../shared/repositories/record_repository.dart';
import '../auth/auth_provider.dart';
import '../records/record_form_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  DateTime _focusedMonth = DateTime.now();
  List<RecordModel> _records = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String get _userId => ref.read(authProvider).value?.id ?? 'local_guest';

  Future<void> _load() async {
    setState(() => _loading = true);
    final repo = RecordRepository(LocalDatabase());
    final records = await repo.getByMonth(_userId, _focusedMonth.year, _focusedMonth.month);
    if (mounted) setState(() { _records = records; _loading = false; });
  }

  // 日付 → その日の収支合計
  Map<DateTime, int> get _dayProfitMap {
    final map = <DateTime, int>{};
    for (final r in _records) {
      final key = DateTime(r.date.year, r.date.month, r.date.day);
      map[key] = (map[key] ?? 0) + r.profit;
    }
    return map;
  }

  List<RecordModel> _recordsForDay(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    return _records.where((r) {
      final rd = DateTime(r.date.year, r.date.month, r.date.day);
      return rd == d;
    }).toList();
  }

  void _showDaySheet(DateTime day) {
    final list = _recordsForDay(day);
    if (list.isEmpty) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _DaySheet(day: day, records: list, onEdit: (r) async {
        Navigator.pop(context);
        await Navigator.of(context).push<bool>(
          MaterialPageRoute(builder: (_) => RecordFormScreen(existing: r)),
        );
        _load();
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monthProfit = _records.fold(0, (s, r) => s + r.profit);
    final wins = _records.where((r) => r.profit > 0).length;
    final count = _records.length;
    final winRate = count > 0 ? wins * 100 ~/ count : 0;
    final avgProfit = count > 0 ? monthProfit ~/ count : 0;

    final todayRecords = _recordsForDay(today);
    final todayProfit = todayRecords.fold(0, (s, r) => s + r.profit);

    // 今週（月曜〜今日）
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final weekRecords = _records.where((r) {
      final d = DateTime(r.date.year, r.date.month, r.date.day);
      return !d.isBefore(weekStart) && !d.isAfter(today);
    }).toList();
    final weekProfit = weekRecords.fold(0, (s, r) => s + r.profit);

    final totalDiff = _records.fold(0, (s, r) => s + (r.diffMedals ?? 0));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.primary,
              child: CustomScrollView(
                slivers: [
                  // ─── AppBar ───────────────────────────
                  SliverAppBar(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    floating: true,
                    title: Text(formatMonth(_focusedMonth),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.white),
                        onPressed: _load,
                      ),
                    ],
                  ),

                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        // ─── ヒーローカード ───────────────
                        _HeroCard(
                          month: _focusedMonth,
                          profit: monthProfit,
                          winRate: winRate,
                          count: count,
                          avgProfit: avgProfit,
                        ),

                        // ─── 2×2 統計グリッド ─────────────
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                          child: _StatsGrid(
                            todayProfit: todayProfit,
                            weekProfit: weekProfit,
                            totalDiff: totalDiff,
                            monthCount: count,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // ─── カレンダー ───────────────────
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Card(
                            child: Column(
                              children: [
                                // 月ナビ
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  child: Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.chevron_left),
                                        onPressed: () {
                                          _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1);
                                          _load();
                                        },
                                      ),
                                      const Spacer(),
                                      Text(formatMonth(_focusedMonth),
                                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                                      const Spacer(),
                                      IconButton(
                                        icon: const Icon(Icons.chevron_right),
                                        onPressed: () {
                                          _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
                                          _load();
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                TableCalendar<RecordModel>(
                                  locale: 'ja_JP',
                                  firstDay: DateTime(2020),
                                  lastDay: DateTime(2030, 12, 31),
                                  focusedDay: _focusedMonth,
                                  currentDay: today,
                                  headerVisible: false,
                                  eventLoader: _recordsForDay,
                                  onDaySelected: (selected, _) => _showDaySheet(selected),
                                  calendarBuilders: CalendarBuilders(
                                    defaultBuilder: (_, day, __) => _DayCell(
                                      day: day,
                                      isToday: isSameDay(day, today),
                                      profit: _dayProfitMap[DateTime(day.year, day.month, day.day)],
                                    ),
                                    todayBuilder: (_, day, __) => _DayCell(
                                      day: day,
                                      isToday: true,
                                      profit: _dayProfitMap[DateTime(day.year, day.month, day.day)],
                                    ),
                                    selectedBuilder: (_, day, __) => _DayCell(
                                      day: day,
                                      isToday: isSameDay(day, today),
                                      profit: _dayProfitMap[DateTime(day.year, day.month, day.day)],
                                    ),
                                    outsideBuilder: (_, day, __) => _DayCell(
                                      day: day,
                                      isOutside: true,
                                      profit: null,
                                    ),
                                  ),
                                  calendarStyle: const CalendarStyle(
                                    outsideDaysVisible: true,
                                    markersMaxCount: 0,
                                  ),
                                  daysOfWeekStyle: const DaysOfWeekStyle(
                                    weekdayStyle: TextStyle(fontSize: 12, color: AppColors.onSurfaceMuted),
                                    weekendStyle: TextStyle(fontSize: 12, color: AppColors.loss),
                                  ),
                                ),
                                const SizedBox(height: 8),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

// ─── ヒーローカード ─────────────────────────────────────────────
class _HeroCard extends StatelessWidget {
  final DateTime month;
  final int profit, winRate, count, avgProfit;
  const _HeroCard({required this.month, required this.profit,
      required this.winRate, required this.count, required this.avgProfit});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.primary,
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('今月の収支', style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 6),
          Text(
            formatProfit(profit),
            style: TextStyle(
              color: Colors.white,
              fontSize: 40,
              fontWeight: FontWeight.bold,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _Chip(label: '勝率 $winRate%'),
              const SizedBox(width: 8),
              _Chip(label: '$count 回'),
              const SizedBox(width: 8),
              _Chip(label: '平均 ${formatProfit(avgProfit)}'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  const _Chip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
    );
  }
}

// ─── 2×2 統計グリッド ──────────────────────────────────────────
class _StatsGrid extends StatelessWidget {
  final int todayProfit, weekProfit, totalDiff, monthCount;
  const _StatsGrid({required this.todayProfit, required this.weekProfit,
      required this.totalDiff, required this.monthCount});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 2.4,
      children: [
        _StatCard(label: '今日の収支', value: formatProfit(todayProfit),
            valueColor: _profitColor(todayProfit)),
        _StatCard(label: '今週の収支', value: formatProfit(weekProfit),
            valueColor: _profitColor(weekProfit)),
        _StatCard(label: '差枚数合計', value: totalDiff != 0 ? '${totalDiff > 0 ? '+' : ''}$totalDiff枚' : '-',
            valueColor: _profitColor(totalDiff)),
        _StatCard(label: '実践回数', value: '$monthCount 回',
            valueColor: AppColors.onSurface),
      ],
    );
  }

  Color _profitColor(int v) =>
      v > 0 ? AppColors.win : v < 0 ? AppColors.loss : AppColors.onSurface;
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final Color valueColor;
  const _StatCard({required this.label, required this.value, required this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: const TextStyle(color: AppColors.onSurfaceMuted, fontSize: 11)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(color: valueColor, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
      ),
    );
  }
}

// ─── カレンダーのセル ────────────────────────────────────────────
class _DayCell extends StatelessWidget {
  final DateTime day;
  final bool isToday;
  final bool isOutside;
  final int? profit;

  const _DayCell({required this.day, this.isToday = false, this.isOutside = false, this.profit});

  @override
  Widget build(BuildContext context) {
    Color? dotColor;
    if (profit != null) {
      dotColor = profit! > 0 ? AppColors.win : profit! < 0 ? AppColors.loss : AppColors.even;
    }

    return Container(
      margin: const EdgeInsets.all(3),
      decoration: isToday
          ? BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary, width: 1.5),
            )
          : null,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${day.day}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
              color: isOutside ? AppColors.cardBorder : isToday ? AppColors.primary : AppColors.onSurface,
            ),
          ),
          if (dotColor != null)
            Container(
              width: 5, height: 5,
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
            ),
        ],
      ),
    );
  }
}

// ─── 日付タップのボトムシート ──────────────────────────────────
class _DaySheet extends StatelessWidget {
  final DateTime day;
  final List<RecordModel> records;
  final void Function(RecordModel) onEdit;

  const _DaySheet({required this.day, required this.records, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final total = records.fold(0, (s, r) => s + r.profit);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(formatDate(day), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const Spacer(),
              Text(formatProfit(total),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: total > 0 ? AppColors.win : total < 0 ? AppColors.loss : AppColors.even,
                  )),
            ],
          ),
          const SizedBox(height: 12),
          ...records.map((r) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(r.machineName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                subtitle: Text(r.storeName, style: const TextStyle(color: AppColors.onSurfaceMuted, fontSize: 13)),
                trailing: Text(
                  formatProfit(r.profit),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: r.profit > 0 ? AppColors.win : r.profit < 0 ? AppColors.loss : AppColors.even,
                  ),
                ),
                onTap: () => onEdit(r),
              )),
        ],
      ),
    );
  }
}
