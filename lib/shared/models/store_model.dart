class StoreModel {
  final String id;
  final String userId;
  final String name;
  final String? region;
  final String? memo;
  final int medalPrice; // 1枚あたりの金額（円）

  const StoreModel({
    required this.id,
    required this.userId,
    required this.name,
    this.region,
    this.memo,
    this.medalPrice = 0,
  });

  factory StoreModel.fromMap(Map<String, dynamic> m) => StoreModel(
        id: m['id'] as String,
        userId: m['user_id'] as String,
        name: m['name'] as String,
        region: m['region'] as String?,
        memo: m['memo'] as String?,
        medalPrice: m['medal_price'] as int? ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'user_id': userId,
        'name': name,
        'region': region,
        'memo': memo,
        'medal_price': medalPrice,
      };
}
