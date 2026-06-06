import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../core/database/local_database.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format_utils.dart';
import '../../shared/models/record_model.dart';
import '../../shared/repositories/record_repository.dart';
import '../../shared/widgets/profit_chip.dart';
import '../records/record_form_screen.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<RecordModel>> _events = {};
  List<RecordModel> _selectedRecords = [];
  bool _loading = true;
  DateTime? _lastTapDay;
  DateTime? _lastTapTime;

  @override
  void initState() {
    super.initState();
    _load();
  }

  DateTime _normalize(DateTime d) => DateTime(d.year, d.month, d.day);

  Future<void> _load() async {
    setState(() => _loading = true);
    const userId = 'local_guest';
    final repo = RecordRepository(LocalDatabase());
    final records = await repo.getByMonth(userId, _focusedDay.year, _focusedDay.month);
    final map = <DateTime, List<RecordModel>>{};
    for (final r in records) {
      final key = _normalize(r.date);
      map.putIfAbsent(key, () => []).add(r);
    }
    setState(() {
      _events = map;
      _loading = false;
      if (_selectedDay != null) {
        _selectedRecords = map[_normalize(_selectedDay!)] ?? [];
      }
    });
  }

  Future<void> _openForm(DateTime date) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => RecordFormScreen(initialDate: date)),
    );
    if (result == true) _load();
  }

  void _onDayTapped(DateTime selected, DateTime focused) {
    final now = DateTime.now();
    final isDoubleTap = _lastTapDay != null &&
        isSameDay(_lastTapDay!, selected) &&
        _lastTapTime != null &&
        now.difference(_lastTapTime!).inMilliseconds < 500;

    if (isDoubleTap) {
      _lastTapDay = null;
      _lastTapTime = null;
      _openForm(selected);
    } else {
      _lastTapDay = selected;
      _lastTapTime = now;
      setState(() {
        _selectedDay = selected;
        _focusedDay = focused;
        _selectedRecords = _getEventsForDay(selected);
      });
    }
  }

  List<RecordModel> _getEventsForDay(DateTime day) {
    return _events[_normalize(day)] ?? [];
  }

  Color? _dayColor(DateTime day) {
    final records = _getEventsForDay(day);
    if (records.isEmpty) return null;
    final total = records.fold(0, (s, r) => s + r.profit);
    if (total > 0) return AppColors.win;
    if (total < 0) return AppColors.loss;
    return AppColors.even;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(formatMonth(_focusedDay))),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(_selectedDay ?? DateTime.now()),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          TableCalendar<RecordModel>(
            locale: 'ja_JP',
            firstDay: DateTime(2020),
            lastDay: DateTime.now().add(const Duration(days: 1)),
            focusedDay: _focusedDay,
            selectedDayPredicate: (d) => isSameDay(_selectedDay, d),
            eventLoader: _getEventsForDay,
            onDaySelected: _onDayTapped,
            onPageChanged: (focused) {
              _focusedDay = focused;
              _load();
            },
            calendarStyle: CalendarStyle(
              outsideDaysVisible: false,
              defaultTextStyle: const TextStyle(color: AppColors.onSurface),
              weekendTextStyle: const TextStyle(color: AppColors.onSurface),
              todayDecoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              selectedDecoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              markerDecoration: const BoxDecoration(
                color: Colors.transparent,
                shape: BoxShape.circle,
              ),
              markersMaxCount: 0,
            ),
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              leftChevronIcon: Icon(Icons.chevron_left, color: AppColors.onSurface),
              rightChevronIcon: Icon(Icons.chevron_right, color: AppColors.onSurface),
              titleTextStyle: TextStyle(color: AppColors.onSurface, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            daysOfWeekStyle: const DaysOfWeekStyle(
              weekdayStyle: TextStyle(color: AppColors.onSurfaceMuted, fontSize: 12),
              weekendStyle: TextStyle(color: AppColors.onSurfaceMuted, fontSize: 12),
            ),
            calendarBuilders: CalendarBuilders(
              defaultBuilder: (ctx, day, focused) => _DayCell(
                day: day,
                color: _dayColor(day),
                records: _getEventsForDay(day),
              ),
              todayBuilder: (ctx, day, focused) => _DayCell(
                day: day,
                color: _dayColor(day),
                records: _getEventsForDay(day),
                isToday: true,
              ),
              selectedBuilder: (ctx, day, focused) => _DayCell(
                day: day,
                color: _dayColor(day),
                records: _getEventsForDay(day),
                isSelected: true,
              ),
            ),
          ),
          const Divider(color: AppColors.cardBorder),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _selectedDay == null
                    ? const Center(child: Text('日付をタップして詳細を表示', style: TextStyle(color: AppColors.onSurfaceMuted)))
                    : _selectedRecords.isEmpty
                        ? const Center(child: Text('この日の記録はありません', style: TextStyle(color: AppColors.onSurfaceMuted)))
                        : _DayDetail(records: _selectedRecords, date: _selectedDay!, onRefresh: _load),
          ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  final DateTime day;
  final Color? color;
  final List<RecordModel> records;
  final bool isToday;
  final bool isSelected;

  const _DayCell({
    required this.day,
    this.color,
    required this.records,
    this.isToday = false,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final total = records.fold(0, (s, r) => s + r.profit);
    return Container(
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.primary
            : isToday
                ? AppColors.primary.withValues(alpha: 0.2)
                : color?.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: color != null && !isSelected
            ? Border.all(color: color!.withValues(alpha: 0.5), width: 1)
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${day.day}',
            style: TextStyle(
              color: isSelected ? Colors.white : AppColors.onSurface,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (records.isNotEmpty)
            Text(
              formatProfit(total),
              style: TextStyle(
                fontSize: 8,
                color: isSelected
                    ? Colors.white70
                    : total > 0
                        ? AppColors.win
                        : total < 0
                            ? AppColors.loss
                            : AppColors.even,
              ),
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }
}

class _DayDetail extends StatelessWidget {
  final List<RecordModel> records;
  final DateTime date;
  final VoidCallback onRefresh;

  const _DayDetail({required this.records, required this.date, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final totalProfit = records.fold(0, (s, r) => s + r.profit);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text(formatDate(date), style: const TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              Text('合計: ', style: const TextStyle(color: AppColors.onSurfaceMuted, fontSize: 12)),
              ProfitChip(profit: totalProfit),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: records.length,
            itemBuilder: (_, i) {
              final r = records[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(r.machineName),
                  subtitle: Text(r.storeName, style: const TextStyle(color: AppColors.onSurfaceMuted, fontSize: 12)),
                  trailing: ProfitChip(profit: r.profit),
                  onTap: () async {
                    final result = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(builder: (_) => RecordFormScreen(existing: r)),
                    );
                    if (result == true) onRefresh();
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
