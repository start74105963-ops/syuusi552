class RecordModel {
  final String id;
  final String userId;
  final DateTime date;
  final String storeName;
  final String machineName;
  final int? machineNumber;
  final DateTime? startTime;
  final DateTime? endTime;

  // メダル・現金の内訳
  final int investmentMedals; // 投資メダル枚数
  final int investmentCash;   // 投資現金（円）
  final int collectionMedals; // 回収メダル枚数
  final int collectionCash;   // 回収現金（円）
  final int medalPrice;       // 記録時の1枚あたりの金額（0=未設定）

  // 集計用（medalPrice>0の場合は円換算、0の場合はメダル枚数）
  final int investment;
  final int collection;
  final int profit;

  final String? memo;
  final String? aim;
  final bool isSynced;

  const RecordModel({
    required this.id,
    required this.userId,
    required this.date,
    required this.storeName,
    required this.machineName,
    this.machineNumber,
    this.startTime,
    this.endTime,
    this.investmentMedals = 0,
    this.investmentCash = 0,
    this.collectionMedals = 0,
    this.collectionCash = 0,
    this.medalPrice = 0,
    required this.investment,
    required this.collection,
    required this.profit,
    this.memo,
    this.aim,
    this.isSynced = false,
  });

  int get playMinutes {
    if (startTime == null || endTime == null) return 0;
    return endTime!.difference(startTime!).inMinutes;
  }

  factory RecordModel.fromMap(Map<String, dynamic> m) => RecordModel(
        id: m['id'] as String,
        userId: m['user_id'] as String,
        date: DateTime.parse(m['date'] as String),
        storeName: m['store_name'] as String,
        machineName: m['machine_name'] as String,
        machineNumber: m['machine_number'] as int?,
        startTime: m['start_time'] != null ? DateTime.parse(m['start_time'] as String) : null,
        endTime: m['end_time'] != null ? DateTime.parse(m['end_time'] as String) : null,
        investmentMedals: m['investment_medals'] as int? ?? 0,
        investmentCash: m['investment_cash'] as int? ?? 0,
        collectionMedals: m['collection_medals'] as int? ?? 0,
        collectionCash: m['collection_cash'] as int? ?? 0,
        medalPrice: m['medal_price'] as int? ?? 0,
        investment: m['investment'] as int,
        collection: m['collection'] as int,
        profit: m['profit'] as int,
        memo: m['memo'] as String?,
        aim: m['aim'] as String?,
        isSynced: (m['is_synced'] as int? ?? 0) == 1,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'user_id': userId,
        'date': date.toIso8601String().split('T').first,
        'store_name': storeName,
        'machine_name': machineName,
        'machine_number': machineNumber,
        'start_time': startTime?.toIso8601String(),
        'end_time': endTime?.toIso8601String(),
        'investment_medals': investmentMedals,
        'investment_cash': investmentCash,
        'collection_medals': collectionMedals,
        'collection_cash': collectionCash,
        'medal_price': medalPrice,
        'investment': investment,
        'collection': collection,
        'profit': profit,
        'memo': memo,
        'aim': aim,
        'is_synced': isSynced ? 1 : 0,
      };

  RecordModel copyWith({
    String? id,
    String? userId,
    DateTime? date,
    String? storeName,
    String? machineName,
    int? machineNumber,
    DateTime? startTime,
    DateTime? endTime,
    int? investmentMedals,
    int? investmentCash,
    int? collectionMedals,
    int? collectionCash,
    int? medalPrice,
    int? investment,
    int? collection,
    int? profit,
    String? memo,
    String? aim,
    bool? isSynced,
  }) =>
      RecordModel(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        date: date ?? this.date,
        storeName: storeName ?? this.storeName,
        machineName: machineName ?? this.machineName,
        machineNumber: machineNumber ?? this.machineNumber,
        startTime: startTime ?? this.startTime,
        endTime: endTime ?? this.endTime,
        investmentMedals: investmentMedals ?? this.investmentMedals,
        investmentCash: investmentCash ?? this.investmentCash,
        collectionMedals: collectionMedals ?? this.collectionMedals,
        collectionCash: collectionCash ?? this.collectionCash,
        medalPrice: medalPrice ?? this.medalPrice,
        investment: investment ?? this.investment,
        collection: collection ?? this.collection,
        profit: profit ?? this.profit,
        memo: memo ?? this.memo,
        aim: aim ?? this.aim,
        isSynced: isSynced ?? this.isSynced,
      );
}
