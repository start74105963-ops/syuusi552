class SavingsModel {
  final String id;
  final String userId;
  final String storeName;
  final int amount;
  final DateTime updatedAt;

  const SavingsModel({
    required this.id,
    required this.userId,
    required this.storeName,
    required this.amount,
    required this.updatedAt,
  });

  factory SavingsModel.fromMap(Map<String, dynamic> m) => SavingsModel(
        id: m['id'] as String,
        userId: m['user_id'] as String,
        storeName: m['store_name'] as String,
        amount: m['amount'] as int,
        updatedAt: DateTime.parse(m['updated_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'user_id': userId,
        'store_name': storeName,
        'amount': amount,
        'updated_at': updatedAt.toIso8601String(),
      };
}

class SavingsHistoryModel {
  final String id;
  final String savingsId;
  final int delta;
  final String type; // 'add' | 'use'
  final DateTime createdAt;
  final String? memo;

  const SavingsHistoryModel({
    required this.id,
    required this.savingsId,
    required this.delta,
    required this.type,
    required this.createdAt,
    this.memo,
  });

  factory SavingsHistoryModel.fromMap(Map<String, dynamic> m) => SavingsHistoryModel(
        id: m['id'] as String,
        savingsId: m['savings_id'] as String,
        delta: m['delta'] as int,
        type: m['type'] as String,
        createdAt: DateTime.parse(m['created_at'] as String),
        memo: m['memo'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'savings_id': savingsId,
        'delta': delta,
        'type': type,
        'created_at': createdAt.toIso8601String(),
        'memo': memo,
      };
}
