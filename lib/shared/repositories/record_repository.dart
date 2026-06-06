import 'package:uuid/uuid.dart';
import '../models/record_model.dart';
import '../../core/database/local_database.dart';

class RecordRepository {
  final LocalDatabase _db;
  static const _uuid = Uuid();

  RecordRepository(this._db);

  Future<List<RecordModel>> getAll(String userId) async {
    final rows = await _db.getRecords(userId);
    return rows.map(RecordModel.fromMap).toList();
  }

  Future<List<RecordModel>> getByMonth(String userId, int year, int month) async {
    final rows = await _db.getRecordsByMonth(userId, year, month);
    return rows.map(RecordModel.fromMap).toList();
  }

  Future<RecordModel> insert(RecordModel record) async {
    final r = record.copyWith(id: record.id.isEmpty ? _uuid.v4() : record.id);
    await _db.insertRecord(r.toMap());
    return r;
  }

  Future<void> update(RecordModel record) async {
    await _db.updateRecord(record.toMap());
  }

  Future<void> delete(String id) async {
    await _db.deleteRecord(id);
  }

  // 月間集計
  Map<String, dynamic> summarize(List<RecordModel> records) {
    final totalProfit = records.fold(0, (s, r) => s + r.profit);
    final totalInvestment = records.fold(0, (s, r) => s + r.investment);
    final totalCollection = records.fold(0, (s, r) => s + r.collection);
    final wins = records.where((r) => r.profit > 0).length;
    final totalMinutes = records.fold(0, (s, r) => s + r.playMinutes);
    return {
      'totalProfit': totalProfit,
      'totalInvestment': totalInvestment,
      'totalCollection': totalCollection,
      'days': records.map((r) => r.date.toIso8601String().split('T').first).toSet().length,
      'wins': wins,
      'winRate': records.isEmpty ? 0.0 : wins / records.length,
      'totalMinutes': totalMinutes,
    };
  }

  // 店舗別集計
  Map<String, Map<String, dynamic>> byStore(List<RecordModel> records) {
    final map = <String, List<RecordModel>>{};
    for (final r in records) {
      map.putIfAbsent(r.storeName, () => []).add(r);
    }
    return map.map((store, list) => MapEntry(store, summarize(list)));
  }

  // 機種別集計
  Map<String, Map<String, dynamic>> byMachine(List<RecordModel> records) {
    final map = <String, List<RecordModel>>{};
    for (final r in records) {
      map.putIfAbsent(r.machineName, () => []).add(r);
    }
    return map.map((machine, list) => MapEntry(machine, summarize(list)));
  }
}
