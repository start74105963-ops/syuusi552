import 'package:intl/intl.dart';

final _currencyFmt = NumberFormat('#,##0');
final _dateFmt = DateFormat('yyyy/MM/dd');
final _monthFmt = DateFormat('yyyy年M月');
final _timeFmt = DateFormat('HH:mm');

String formatProfit(int value) {
  final s = _currencyFmt.format(value.abs());
  if (value > 0) return '+$s';
  if (value < 0) return '-$s';
  return '±0';
}

String formatAmount(int value) => _currencyFmt.format(value);

String formatDate(DateTime d) => _dateFmt.format(d);

String formatMonth(DateTime d) => _monthFmt.format(d);

String formatTime(DateTime d) => _timeFmt.format(d);

String formatMinutes(int minutes) {
  if (minutes <= 0) return '-';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '${m}分';
  return '${h}時間${m > 0 ? '${m}分' : ''}';
}
