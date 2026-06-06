import 'package:uuid/uuid.dart';
import '../models/savings_model.dart';
import '../../core/database/local_database.dart';

class SavingsRepository {
  final LocalDatabase _db;
  static const _uuid = Uuid();

  SavingsRepository(this._db);

  Future<List<SavingsModel>> getAll(String userId) async {
    final rows = await _db.getSavings(userId);
    return rows.map(SavingsModel.fromMap).toList();
  }

  Future<SavingsModel> upsert(SavingsModel savings) async {
    final s = SavingsModel(
      id: savings.id.isEmpty ? _uuid.v4() : savings.id,
      userId: savings.userId,
      storeName: savings.storeName,
      amount: savings.amount,
      updatedAt: DateTime.now(),
    );
    await _db.upsertSavings(s.toMap());
    return s;
  }

  Future<void> addHistory(String savingsId, int delta, String type, String? memo) async {
    await _db.insertSavingsHistory({
      'id': _uuid.v4(),
      'savings_id': savingsId,
      'delta': delta,
      'type': type,
      'created_at': DateTime.now().toIso8601String(),
      'memo': memo,
    });
  }

  Future<List<SavingsHistoryModel>> getHistory(String savingsId) async {
    final rows = await _db.getSavingsHistory(savingsId);
    return rows.map(SavingsHistoryModel.fromMap).toList();
  }
}
