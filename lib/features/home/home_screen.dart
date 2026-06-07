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

  // 日付 → その日のレコード一覧
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
      builder: (_) => _DaySheet(
        day: day,
        records: list,
        onEdit: (r) async {
          Navigator.pop(context);
          final result = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => RecordFormScreen(existing: r)),
          );
          if (result == true) _load();
        },
        onAdd: () {
          Navigator.pop(context);
          Navigator.of(context).push<bool>(
            MaterialPageRoute(
              fullscreenDialog: true,
              builder: (_) => RecordFormScreen(initialDate: day),
            ),
          ).then((r) { if (r == true) _load(); });
        },
      ),
    );
  }

  void _tapEmptyDay(DateTime day) {
    // 空の日をタップ → その日付で記録追加
    Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => RecordFormScreen(initialDate: day),
      ),
    ).then((r) { if (r == true) _load(); });
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
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final weekProfit = _records
        .where((r) {
          final d = DateTime(r.date.year, r.date.month, r.date.day);
          return !d.isBefore(weekStart) && !d.isAfter(today);
        })
        .fold(0, (s, r) => s + r.profit);
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
                  // ─── AppBar ───────────────────────────────────
                  SliverAppBar(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    floating: true,
                    title: const Text('スロット収支', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
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
                        // ─── ヒーローカード ───────────────────────
                        _HeroCard(
                          month: _focusedMonth,
                          profit: monthProfit,
                          winRate: winRate,
                          count: count,
                          avgProfit: avgProfit,
                        ),

                        // ─── 2×2 統計グリッド ─────────────────────
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

                        // ─── カレンダー ───────────────────────────
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Card(
                            child: Column(
                              children: [
                                // 月ナビヘッダー
                                _CalendarHeader(
                                  month: _focusedMonth,
                                  totalProfit: monthProfit,
                                  onPrev: () {
                                    setState(() => _focusedMonth = DateTime(
                                        _focusedMonth.year, _focusedMonth.month - 1));
                                    _load();
                                  },
                                  onNext: () {
                                    setState(() => _focusedMonth = DateTime(
                                        _focusedMonth.year, _focusedMonth.month + 1));
                                    _load();
                                  },
                                ),
                                TableCalendar<RecordModel>(
                                  locale: 'ja_JP',
                                  firstDay: DateTime(2020),
                                  lastDay: DateTime(2030, 12, 31),
                                  focusedDay: _focusedMonth,
                                  currentDay: today,
                                  headerVisible: false,
                                  rowHeight: 72,
                                  eventLoader: _recordsForDay,
                                  onDaySelected: (selected, _) {
                                    final recs = _recordsForDay(selected);
                                    if (recs.isNotEmpty) {
                                      _showDaySheet(selected);
                                    } else {
                                      _tapEmptyDay(selected);
                                    }
                                  },
                                  calendarBuilders: CalendarBuilders(
                                    defaultBuilder: (_, day, __) => _DayCell(
                                      day: day,
                                      isToday: isSameDay(day, today),
                                      isOutside: false,
                                      profit: _dayProfitMap[DateTime(day.year, day.month, day.day)],
                                      records: _recordsForDay(day),
                                    ),
                                    todayBuilder: (_, day, __) => _DayCell(
                                      day: day,
                                      isToday: true,
                                      isOutside: false,
                                      profit: _dayProfitMap[DateTime(day.year, day.month, day.day)],
                                      records: _recordsForDay(day),
                                    ),
                                    selectedBuilder: (_, day, __) => _DayCell(
                                      day: day,
                                      isToday: isSameDay(day, today),
                                      isOutside: false,
                                      profit: _dayProfitMap[DateTime(day.year, day.month, day.day)],
                                      records: _recordsForDay(day),
                                    ),
                                    outsideBuilder: (_, day, __) => _DayCell(
                                      day: day,
                                      isToday: false,
                                      isOutside: true,
                                      profit: null,
                                      records: const [],
                                    ),
                                  ),
                                  calendarStyle: const CalendarStyle(
                                    outsideDaysVisible: true,
                                    markersMaxCount: 0,
                                    cellMargin: EdgeInsets.zero,
                                    cellPadding: EdgeInsets.zero,
                                  ),
                                  daysOfWeekStyle: DaysOfWeekStyle(
                                    dowTextFormatter: (date, locale) =>
                                        ['日', '月', '火', '水', '木', '金', '土'][date.weekday % 7],
                                    weekdayStyle: const TextStyle(fontSize: 12, color: AppColors.onSurfaceMuted, fontWeight: FontWeight.w500),
                                    weekendStyle: TextStyle(fontSize: 12, color: AppColors.loss.withValues(alpha: 0.8), fontWeight: FontWeight.w500),
                                  ),
                                ),
                                const SizedBox(height: 8),
                              ],
                            ),
                          ),
                        ),

                        // 凡例
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          child: Row(
                            children: [
                              _Legend(color: AppColors.win.withValues(alpha: 0.18), label: '勝ち'),
                              const SizedBox(width: 12),
                              _Legend(color: AppColors.loss.withValues(alpha: 0.15), label: '負け'),
                              const SizedBox(width: 12),
                              _Legend(color: AppColors.even.withValues(alpha: 0.15), label: 'トントン'),
                              const Spacer(),
                              const Text('タップで詳細', style: TextStyle(color: AppColors.onSurfaceMuted, fontSize: 11)),
                            ],
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

// ─── カレンダーヘッダー ─────────────────────────────────────────
class _CalendarHeader extends StatelessWidget {
  final DateTime month;
  final int totalProfit;
  final VoidCallback onPrev, onNext;

  const _CalendarHeader({
    required this.month,
    required this.totalProfit,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final color = totalProfit > 0 ? AppColors.win : totalProfit < 0 ? AppColors.loss : AppColors.onSurface;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, size: 22),
            onPressed: onPrev,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${month.year}年 ${month.month}月',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                if (totalProfit != 0) ...[
                  const SizedBox(width: 8),
                  Text(
                    formatProfit(totalProfit),
                    style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, size: 22),
            onPressed: onNext,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ],
      ),
    );
  }
}

// ─── 改善版 日付セル ────────────────────────────────────────────
class _DayCell extends StatelessWidget {
  final DateTime day;
  final bool isToday;
  final bool isOutside;
  final int? profit;
  final List<RecordModel> records;

  const _DayCell({
    required this.day,
    required this.isToday,
    required this.isOutside,
    required this.profit,
    required this.records,
  });

  @override
  Widget build(BuildContext context) {
    final hasRecord = profit != null;
    final isWin  = hasRecord && profit! > 0;
    final isLoss = hasRecord && profit! < 0;
    final isEven = hasRecord && profit! == 0;

    // 背景色
    Color? bgColor;
    if (!isOutside && hasRecord) {
      if (isWin)  bgColor = AppColors.win.withValues(alpha: 0.13);
      if (isLoss) bgColor = AppColors.loss.withValues(alpha: 0.10);
      if (isEven) bgColor = AppColors.even.withValues(alpha: 0.10);
    }

    // 日付テキスト色
    Color dayTextColor = AppColors.onSurface;
    if (isOutside) {
      dayTextColor = AppColors.cardBorder;
    } else if (day.weekday == 7) {
      // 日曜
      dayTextColor = AppColors.loss.withValues(alpha: 0.8);
    } else if (day.weekday == 6) {
      // 土曜
      dayTextColor = AppColors.primary.withValues(alpha: 0.9);
    }

    // 収支テキスト色
    Color profitColor = AppColors.onSurface;
    if (isWin)  profitColor = AppColors.win;
    if (isLoss) profitColor = AppColors.loss;
    if (isEven) profitColor = AppColors.even;

    // 機種名（最初の1件、省略）
    String? machineName;
    if (!isOutside && records.isNotEmpty) {
      final name = records.first.machineName;
      machineName = name.length > 5 ? '${name.substring(0, 5)}…' : name;
      if (records.length > 1) machineName = '${records.length}件';
    }

    return Container(
      margin: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        color: bgColor,
        border: isToday
            ? Border.all(color: AppColors.primary, width: 1.5)
            : Border.all(color: AppColors.cardBorder.withValues(alpha: 0.4), width: 0.3),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 日付
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 3, bottom: 1),
            decoration: isToday
                ? const BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(3),
                      topRight: Radius.circular(3),
                    ),
                  )
                : null,
            child: Text(
              '${day.day}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                color: isToday ? Colors.white : dayTextColor,
                height: 1.1,
              ),
            ),
          ),

          // 機種名
          if (machineName != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
              child: Text(
                machineName,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 8.5, color: AppColors.onSurfaceMuted, height: 1.1),
              ),
            ),

          // 収支
          if (hasRecord && !isOutside)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(
                _compactProfit(profit!),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: profitColor,
                  height: 1.2,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // 金額を短縮表示（例: +22,250 → +2.2万）
  String _compactProfit(int v) {
    final sign = v >= 0 ? '+' : '';
    if (v.abs() >= 10000) {
      final man = v / 10000;
      return '$sign${man.toStringAsFixed(man.abs() < 10 ? 1 : 0)}万';
    }
    return '$sign${v.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+\$)'), (m) => '${m[1]},')}';
  }
}

// ─── 凡例 ───────────────────────────────────────────────────────
class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 14, height: 14,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3),
            border: Border.all(color: color.withValues(alpha: 0.5))),
      ),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceMuted)),
    ]);
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
            style: const TextStyle(
              color: Colors.white,
              fontSize: 40,
              fontWeight: FontWeight.bold,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            _Chip(label: '勝率 $winRate%'),
            const SizedBox(width: 8),
            _Chip(label: '$count 回'),
            const SizedBox(width: 8),
            _Chip(label: '平均 ${formatProfit(avgProfit)}'),
          ]),
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
        _StatCard(label: '今日の収支', value: formatProfit(todayProfit), valueColor: _c(todayProfit)),
        _StatCard(label: '今週の収支', value: formatProfit(weekProfit),  valueColor: _c(weekProfit)),
        _StatCard(label: '差枚数合計', value: totalDiff != 0 ? '${totalDiff > 0 ? '+' : ''}$totalDiff枚' : '-', valueColor: _c(totalDiff)),
        _StatCard(label: '実践回数',   value: '$monthCount 回', valueColor: AppColors.onSurface),
      ],
    );
  }

  Color _c(int v) => v > 0 ? AppColors.win : v < 0 ? AppColors.loss : AppColors.onSurface;
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

// ─── 日付タップのボトムシート ──────────────────────────────────
class _DaySheet extends StatelessWidget {
  final DateTime day;
  final List<RecordModel> records;
  final void Function(RecordModel) onEdit;
  final VoidCallback onAdd;

  const _DaySheet({
    required this.day,
    required this.records,
    required this.onEdit,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final total = records.fold(0, (s, r) => s + r.profit);
    final totalColor = total > 0 ? AppColors.win : total < 0 ? AppColors.loss : AppColors.even;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(formatDate(day), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Spacer(),
            Text(formatProfit(total),
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: totalColor)),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('追加'),
            ),
          ]),
          const Divider(),
          ...records.map((r) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(r.machineName,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                subtitle: Row(children: [
                  const Icon(Icons.store_outlined, size: 13, color: AppColors.onSurfaceMuted),
                  const SizedBox(width: 3),
                  Text(r.storeName, style: const TextStyle(color: AppColors.onSurfaceMuted, fontSize: 13)),
                  if (r.setting != null) ...[
                    const SizedBox(width: 8),
                    Text('設${r.setting == 0 ? '不明' : r.setting}',
                        style: const TextStyle(color: AppColors.primary, fontSize: 12)),
                  ],
                ]),
                trailing: Text(
                  formatProfit(r.profit),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
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
