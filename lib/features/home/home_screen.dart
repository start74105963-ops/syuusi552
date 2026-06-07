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
  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);
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
    final records = await RecordRepository(LocalDatabase())
        .getByMonth(_userId, _focusedMonth.year, _focusedMonth.month);
    if (mounted) setState(() { _records = records; _loading = false; });
  }

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
    return _records.where((r) => DateTime(r.date.year, r.date.month, r.date.day) == d).toList();
  }

  void _openForm({DateTime? date, RecordModel? existing}) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => RecordFormScreen(existing: existing, initialDate: date ?? DateTime.now()),
      ),
    );
    if (result == true) _load();
  }

  void _showDaySheet(DateTime day) {
    final list = _recordsForDay(day);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _DaySheet(
        day: day,
        records: list,
        onEdit: (r) { Navigator.pop(context); _openForm(existing: r); },
        onAdd:  ()  { Navigator.pop(context); _openForm(date: day); },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monthProfit = _records.fold(0, (s, r) => s + r.profit);
    final count   = _records.length;
    final wins    = _records.where((r) => r.profit > 0).length;
    final winRate = count > 0 ? wins * 100 ~/ count : 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      // ─── 月収支ヘッダー ───────────────────────────────
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: Container(
          color: AppColors.primary,
          child: SafeArea(
            bottom: false,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 月ナビ
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left, color: Colors.white),
                      onPressed: () {
                        setState(() => _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1));
                        _load();
                      },
                    ),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '${_focusedMonth.year}年 ${_focusedMonth.month}月',
                            style: const TextStyle(color: Colors.white70, fontSize: 14),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            formatProfit(monthProfit),
                            style: TextStyle(
                              color: monthProfit >= 0
                                  ? const Color(0xFF86EFAC) // 明るい緑
                                  : const Color(0xFFFCA5A5), // 明るい赤
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right, color: Colors.white),
                      onPressed: () {
                        setState(() => _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1));
                        _load();
                      },
                    ),
                  ],
                ),
                // 小さなサマリー
                if (count > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _HeaderChip('$count回'),
                        const SizedBox(width: 8),
                        _HeaderChip('勝率 $winRate%'),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),

      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Column(
              children: [
                // ─── カレンダー（メイン） ─────────────────────
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        // 曜日ヘッダー付きカレンダー
                        Container(
                          color: AppColors.surface,
                          child: TableCalendar<RecordModel>(
                            locale: 'ja_JP',
                            firstDay: DateTime(2020),
                            lastDay: DateTime(2030, 12, 31),
                            focusedDay: _focusedMonth,
                            currentDay: today,
                            headerVisible: false,
                            rowHeight: 80,
                            eventLoader: _recordsForDay,
                            onDaySelected: (selected, _) => _showDaySheet(selected),
                            calendarBuilders: CalendarBuilders(
                              defaultBuilder: (_, day, __) => _DayCell(
                                day: day, isToday: isSameDay(day, today),
                                isOutside: false,
                                profit: _dayProfitMap[DateTime(day.year, day.month, day.day)],
                                records: _recordsForDay(day),
                              ),
                              todayBuilder: (_, day, __) => _DayCell(
                                day: day, isToday: true, isOutside: false,
                                profit: _dayProfitMap[DateTime(day.year, day.month, day.day)],
                                records: _recordsForDay(day),
                              ),
                              selectedBuilder: (_, day, __) => _DayCell(
                                day: day, isToday: isSameDay(day, today),
                                isOutside: false,
                                profit: _dayProfitMap[DateTime(day.year, day.month, day.day)],
                                records: _recordsForDay(day),
                              ),
                              outsideBuilder: (_, day, __) => _DayCell(
                                day: day, isToday: false, isOutside: true,
                                profit: null, records: const [],
                              ),
                            ),
                            calendarStyle: const CalendarStyle(
                              outsideDaysVisible: true,
                              markersMaxCount: 0,
                              cellMargin: EdgeInsets.zero,
                              cellPadding: EdgeInsets.zero,
                            ),
                            daysOfWeekStyle: DaysOfWeekStyle(
                              dowTextFormatter: (date, _) =>
                                  ['日', '月', '火', '水', '木', '金', '土'][date.weekday % 7],
                              weekdayStyle: const TextStyle(
                                  fontSize: 12, color: AppColors.onSurfaceMuted, fontWeight: FontWeight.w500),
                              weekendStyle: const TextStyle(
                                  fontSize: 12, color: AppColors.loss, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ),

                        // 凡例
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Row(
                            children: [
                              _Legend(color: AppColors.win.withValues(alpha: 0.18), label: '勝ち'),
                              const SizedBox(width: 12),
                              _Legend(color: AppColors.loss.withValues(alpha: 0.15), label: '負け'),
                              const SizedBox(width: 12),
                              _Legend(color: AppColors.even.withValues(alpha: 0.15), label: 'トントン'),
                              const Spacer(),
                              const Text('タップで詳細/追加', style: TextStyle(color: AppColors.onSurfaceMuted, fontSize: 11)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ),
              ],
            ),

      // ─── 右下 FAB ─────────────────────────────────────
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
    );
  }
}

// ─── ヘッダー内チップ ─────────────────────────────────────────
class _HeaderChip extends StatelessWidget {
  final String label;
  const _HeaderChip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11)),
    );
  }
}

// ─── 日付セル ───────────────────────────────────────────────────
class _DayCell extends StatelessWidget {
  final DateTime day;
  final bool isToday, isOutside;
  final int? profit;
  final List<RecordModel> records;

  const _DayCell({
    required this.day, required this.isToday, required this.isOutside,
    required this.profit, required this.records,
  });

  @override
  Widget build(BuildContext context) {
    final hasRecord = profit != null && !isOutside;
    final isWin  = hasRecord && profit! > 0;
    final isLoss = hasRecord && profit! < 0;
    final isEven = hasRecord && profit! == 0;

    Color? bgColor;
    if (hasRecord) {
      if (isWin)  bgColor = AppColors.win.withValues(alpha: 0.13);
      if (isLoss) bgColor = AppColors.loss.withValues(alpha: 0.10);
      if (isEven) bgColor = AppColors.even.withValues(alpha: 0.10);
    }

    Color dayNumColor = AppColors.onSurface;
    if (isOutside) {
      dayNumColor = AppColors.cardBorder;
    } else if (day.weekday == 7) {
      dayNumColor = AppColors.loss;
    } else if (day.weekday == 6) {
      dayNumColor = AppColors.primary;
    }

    Color profitColor = AppColors.even;
    if (isWin)  { profitColor = AppColors.win; }
    if (isLoss) { profitColor = AppColors.loss; }

    // 表示テキスト: 複数件は「n件」、1件は機種名省略
    String? subText;
    if (hasRecord && records.isNotEmpty) {
      if (records.length > 1) {
        subText = '${records.length}件';
      } else {
        final name = records.first.machineName;
        subText = name.length > 6 ? name.substring(0, 6) : name;
      }
    }

    return Container(
      margin: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        color: bgColor,
        border: isToday
            ? Border.all(color: AppColors.primary, width: 1.5)
            : Border.all(color: AppColors.cardBorder.withValues(alpha: 0.5), width: 0.3),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 日付数字（今日は青背景ヘッダー）
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 4, bottom: 2),
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
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isToday ? Colors.white : dayNumColor,
                height: 1.1,
              ),
            ),
          ),

          const SizedBox(height: 2),

          // 機種名 or 件数
          if (subText != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(
                subText,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 9, color: AppColors.onSurfaceMuted, height: 1.1),
              ),
            ),

          // 収支金額
          if (hasRecord)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: Text(
                _compact(profit!),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
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

  String _compact(int v) {
    final sign = v >= 0 ? '+' : '';
    if (v.abs() >= 10000) {
      final man = v / 10000;
      return '$sign${man.toStringAsFixed(man.abs() < 10 ? 1 : 0)}万';
    }
    if (v.abs() >= 1000) {
      return '$sign${(v / 1000).toStringAsFixed(1)}千';
    }
    return '$sign$v';
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
        width: 13, height: 13,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: color.withValues(alpha: 0.6)),
        ),
      ),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceMuted)),
    ]);
  }
}

// ─── 日付タップシート ───────────────────────────────────────────
class _DaySheet extends StatelessWidget {
  final DateTime day;
  final List<RecordModel> records;
  final void Function(RecordModel) onEdit;
  final VoidCallback onAdd;

  const _DaySheet({
    required this.day, required this.records,
    required this.onEdit, required this.onAdd,
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
            if (records.isNotEmpty)
              Text(formatProfit(total),
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: totalColor)),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('追加'),
            ),
          ]),
          if (records.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text('${day.month}/${day.day} の記録はありません',
                    style: const TextStyle(color: AppColors.onSurfaceMuted)),
              ),
            )
          else ...[
            const Divider(),
            ...records.map((r) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(r.machineName,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  subtitle: Row(children: [
                    const Icon(Icons.store_outlined, size: 13, color: AppColors.onSurfaceMuted),
                    const SizedBox(width: 3),
                    Text(r.storeName,
                        style: const TextStyle(color: AppColors.onSurfaceMuted, fontSize: 13)),
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
        ],
      ),
    );
  }
}
