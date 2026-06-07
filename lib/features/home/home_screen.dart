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
  DateTime? _selectedDay;
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
    return _records.where((r) =>
        DateTime(r.date.year, r.date.month, r.date.day) == d).toList();
  }

  void _onDayTap(DateTime day) {
    setState(() {
      _selectedDay = day;
    });
  }

  void _openForm({DateTime? date, RecordModel? existing}) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => RecordFormScreen(
          existing: existing,
          initialDate: date ?? _selectedDay ?? DateTime.now(),
        ),
      ),
    );
    if (result == true) _load();
  }

  void _shiftDay(int delta) {
    if (_selectedDay == null) return;
    final next = _selectedDay!.add(Duration(days: delta));
    // 月をまたぐ場合は月データをリロード
    if (next.month != _focusedMonth.month || next.year != _focusedMonth.year) {
      setState(() {
        _focusedMonth = DateTime(next.year, next.month);
        _selectedDay = next;
      });
      _load();
    } else {
      setState(() => _selectedDay = next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monthProfit = _records.fold(0, (s, r) => s + r.profit);
    final count   = _records.length;
    final wins    = _records.where((r) => r.profit > 0).length;
    final winRate = count > 0 ? wins * 100 ~/ count : 0;

    final selectedRecords = _selectedDay != null ? _recordsForDay(_selectedDay!) : <RecordModel>[];

    return Scaffold(
      backgroundColor: AppColors.background,

      // ─── 月収支ヘッダー ─────────────────────────
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(72),
        child: Container(
          color: AppColors.primary,
          child: SafeArea(
            bottom: false,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left, color: Colors.white),
                    onPressed: () {
                      setState(() {
                        _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1);
                        _selectedDay = null;
                      });
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
                                ? const Color(0xFF86EFAC)
                                : const Color(0xFFFCA5A5),
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
                      setState(() {
                        _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
                        _selectedDay = null;
                      });
                      _load();
                    },
                  ),
                ]),
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
                // ─── カレンダー（スクロール外） ────────────
                Container(
                  color: AppColors.surface,
                  child: TableCalendar<RecordModel>(
                    locale: 'ja_JP',
                    firstDay: DateTime(2020),
                    lastDay: DateTime(2030, 12, 31),
                    focusedDay: _focusedMonth,
                    selectedDayPredicate: (day) =>
                        _selectedDay != null && isSameDay(day, _selectedDay!),
                    currentDay: today,
                    headerVisible: false,
                    rowHeight: 68,
                    eventLoader: _recordsForDay,
                    // ← スワイプで月が変わる
                    onPageChanged: (focusedDay) {
                      setState(() {
                        _focusedMonth = DateTime(focusedDay.year, focusedDay.month);
                        _selectedDay = null;
                      });
                      _load();
                    },
                    onDaySelected: (selected, _) => _onDayTap(selected),
                    calendarBuilders: CalendarBuilders(
                      defaultBuilder: (_, day, __) => _DayCell(
                        day: day, isToday: isSameDay(day, today),
                        isOutside: false, isSelected: _selectedDay != null && isSameDay(day, _selectedDay!),
                        profit: _dayProfitMap[DateTime(day.year, day.month, day.day)],
                        records: _recordsForDay(day),
                      ),
                      todayBuilder: (_, day, __) => _DayCell(
                        day: day, isToday: true, isOutside: false,
                        isSelected: _selectedDay != null && isSameDay(day, _selectedDay!),
                        profit: _dayProfitMap[DateTime(day.year, day.month, day.day)],
                        records: _recordsForDay(day),
                      ),
                      selectedBuilder: (_, day, __) => _DayCell(
                        day: day, isToday: isSameDay(day, today),
                        isOutside: false, isSelected: true,
                        profit: _dayProfitMap[DateTime(day.year, day.month, day.day)],
                        records: _recordsForDay(day),
                      ),
                      outsideBuilder: (_, day, __) => _DayCell(
                        day: day, isToday: false, isOutside: true,
                        isSelected: false, profit: null, records: const [],
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
                Container(
                  color: AppColors.surface,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Row(children: [
                    _Legend(color: AppColors.win.withValues(alpha: 0.18), label: '勝ち'),
                    const SizedBox(width: 12),
                    _Legend(color: AppColors.loss.withValues(alpha: 0.15), label: '負け'),
                    const SizedBox(width: 12),
                    _Legend(color: AppColors.even.withValues(alpha: 0.15), label: 'トントン'),
                  ]),
                ),

                const Divider(height: 1, color: AppColors.cardBorder),

                // ─── 選択日パネル（下スペース） ────────────
                Expanded(
                  child: _DayPanel(
                    selectedDay: _selectedDay,
                    records: selectedRecords,
                    onPrev: () => _shiftDay(-1),
                    onNext: () => _shiftDay(1),
                    onEdit: (r) => _openForm(existing: r),
                    onAdd:  () => _openForm(date: _selectedDay),
                    onTapEmpty: () {}, // 日付未選択
                  ),
                ),
              ],
            ),

      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
    );
  }
}

// ─── 選択日パネル ───────────────────────────────────────────────
class _DayPanel extends StatelessWidget {
  final DateTime? selectedDay;
  final List<RecordModel> records;
  final VoidCallback onPrev, onNext, onTapEmpty;
  final void Function(RecordModel) onEdit;
  final VoidCallback onAdd;

  const _DayPanel({
    required this.selectedDay,
    required this.records,
    required this.onPrev,
    required this.onNext,
    required this.onEdit,
    required this.onAdd,
    required this.onTapEmpty,
  });

  @override
  Widget build(BuildContext context) {
    if (selectedDay == null) {
      return const Center(
        child: Text('日付をタップして記録を表示',
            style: TextStyle(color: AppColors.onSurfaceMuted, fontSize: 13)),
      );
    }

    final total = records.fold(0, (s, r) => s + r.profit);
    final totalColor = total > 0 ? AppColors.win : total < 0 ? AppColors.loss : AppColors.even;

    return Column(
      children: [
        // 日付ナビバー
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          color: AppColors.surfaceVariant,
          child: Row(children: [
            IconButton(
              icon: const Icon(Icons.chevron_left, size: 20),
              onPressed: onPrev,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
            Expanded(
              child: Text(
                formatDate(selectedDay!),
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
            if (records.isNotEmpty)
              Text(formatProfit(total),
                  style: TextStyle(fontWeight: FontWeight.bold, color: totalColor, fontSize: 15)),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.chevron_right, size: 20),
              onPressed: onNext,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          ]),
        ),

        // 記録リスト
        Expanded(
          child: records.isEmpty
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('記録なし', style: TextStyle(color: AppColors.onSurfaceMuted, fontSize: 13)),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: onAdd,
                      icon: const Icon(Icons.add),
                      label: const Text('この日の記録を追加'),
                    ),
                  ],
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                  children: [
                    ...records.map((r) => _RecordItem(record: r, onTap: () => onEdit(r))),
                    const SizedBox(height: 8),
                    Center(
                      child: TextButton.icon(
                        onPressed: onAdd,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('この日に追加'),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _RecordItem extends StatelessWidget {
  final RecordModel record;
  final VoidCallback onTap;
  const _RecordItem({required this.record, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final profit = record.profit;
    final profitColor = profit > 0 ? AppColors.win : profit < 0 ? AppColors.loss : AppColors.even;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(record.machineName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 3),
                  Row(children: [
                    const Icon(Icons.store_outlined, size: 13, color: AppColors.onSurfaceMuted),
                    const SizedBox(width: 3),
                    Text(record.storeName,
                        style: const TextStyle(color: AppColors.onSurfaceMuted, fontSize: 12)),
                    if (record.setting != null) ...[
                      const SizedBox(width: 8),
                      Text('設${record.setting == 0 ? '不明' : record.setting}',
                          style: const TextStyle(color: AppColors.primary, fontSize: 12)),
                    ],
                  ]),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(formatProfit(profit),
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16, color: profitColor)),
                Text('投資 ¥${formatAmount(record.investment)}',
                    style: const TextStyle(color: AppColors.onSurfaceMuted, fontSize: 11)),
              ],
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 18, color: AppColors.cardBorder),
          ]),
        ),
      ),
    );
  }
}

// ─── ヘッダーチップ ────────────────────────────────────────────
class _HeaderChip extends StatelessWidget {
  final String label;
  const _HeaderChip(this.label);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11)),
      );
}

// ─── 日付セル ───────────────────────────────────────────────────
class _DayCell extends StatelessWidget {
  final DateTime day;
  final bool isToday, isOutside, isSelected;
  final int? profit;
  final List<RecordModel> records;

  const _DayCell({
    required this.day, required this.isToday, required this.isOutside,
    required this.isSelected, required this.profit, required this.records,
  });

  @override
  Widget build(BuildContext context) {
    final hasRecord = profit != null && !isOutside;
    final isWin  = hasRecord && profit! > 0;
    final isLoss = hasRecord && profit! < 0;
    final isEven = hasRecord && profit! == 0;

    Color? bgColor;
    if (hasRecord) {
      if (isWin)  { bgColor = AppColors.win.withValues(alpha: 0.13); }
      if (isLoss) { bgColor = AppColors.loss.withValues(alpha: 0.10); }
      if (isEven) { bgColor = AppColors.even.withValues(alpha: 0.10); }
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

    String? subText;
    if (hasRecord && records.isNotEmpty) {
      subText = records.length > 1
          ? '${records.length}件'
          : (records.first.machineName.length > 6
              ? records.first.machineName.substring(0, 6)
              : records.first.machineName);
    }

    // 選択中は枠を強調
    final border = isSelected
        ? Border.all(color: AppColors.primary, width: 2)
        : isToday
            ? Border.all(color: AppColors.primary, width: 1.5)
            : Border.all(color: AppColors.cardBorder.withValues(alpha: 0.5), width: 0.3);

    return Container(
      margin: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primary.withValues(alpha: 0.08) : bgColor,
        border: border,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 4, bottom: 2),
            decoration: isToday && !isSelected
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
                fontWeight: (isToday || isSelected) ? FontWeight.bold : FontWeight.normal,
                color: (isToday && !isSelected) ? Colors.white : dayNumColor,
                height: 1.1,
              ),
            ),
          ),
          if (subText != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(subText,
                  textAlign: TextAlign.center, maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 8.5, color: AppColors.onSurfaceMuted, height: 1.1)),
            ),
          if (hasRecord)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: Text(_compact(profit!),
                  textAlign: TextAlign.center, maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold,
                      color: profitColor, height: 1.2)),
            ),
        ],
      ),
    );
  }

  String _compact(int v) {
    final sign = v >= 0 ? '+' : '';
    if (v.abs() >= 10000) {
      return '$sign${(v / 10000).toStringAsFixed(v.abs() < 100000 ? 1 : 0)}万';
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
  Widget build(BuildContext context) => Row(children: [
        Container(width: 12, height: 12,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3),
                border: Border.all(color: color.withValues(alpha: 0.6)))),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceMuted)),
      ]);
}
