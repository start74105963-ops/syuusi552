class StoreModel {
  final String id;
  final String userId;
  final String name;
  final String? region;
  final String? memo;

  const StoreModel({
    required this.id,
    required this.userId,
    required this.name,
    this.region,
    this.memo,
  });

  factory StoreModel.fromMap(Map<String, dynamic> m) => StoreModel(
        id: m['id'] as String,
        userId: m['user_id'] as String,
        name: m['name'] as String,
        region: m['region'] as String?,
        memo: m['memo'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'user_id': userId,
        'name': name,
        'region': region,
        'memo': memo,
      };
}
