class RecordModel {
  final String id;
  final String userId;
  final DateTime date;
  final String storeName;
  final String machineName;
  final int? machineNumber;
  final DateTime? startTime;
  final DateTime? endTime;

  // 収支（円）
  final int investment;
  final int collection;
  final int profit;

  // 任意項目
  final int? setting;      // 1〜6
  final int? diffMedals;   // 差枚数
  final int? startG;
  final int? endG;
  final int? bbCount;
  final int? rbCount;
  final int? atCount;
  final String? memo;

  // 後方互換（旧メダル方式）
  final int investmentMedals;
  final int investmentCash;
  final int collectionMedals;
  final int collectionCash;
  final int medalPrice;
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
    required this.investment,
    required this.collection,
    required this.profit,
    this.setting,
    this.diffMedals,
    this.startG,
    this.endG,
    this.bbCount,
    this.rbCount,
    this.atCount,
    this.memo,
    this.investmentMedals = 0,
    this.investmentCash = 0,
    this.collectionMedals = 0,
    this.collectionCash = 0,
    this.medalPrice = 0,
    this.aim,
    this.isSynced = false,
  });

  int get playMinutes {
    if (startTime == null || endTime == null) return 0;
    return endTime!.difference(startTime!).inMinutes;
  }

  int get totalG => (endG ?? 0) - (startG ?? 0);

  factory RecordModel.fromMap(Map<String, dynamic> m) => RecordModel(
        id: m['id'] as String,
        userId: m['user_id'] as String,
        date: DateTime.parse(m['date'] as String),
        storeName: m['store_name'] as String,
        machineName: m['machine_name'] as String,
        machineNumber: m['machine_number'] as int?,
        startTime: m['start_time'] != null ? DateTime.parse(m['start_time'] as String) : null,
        endTime: m['end_time'] != null ? DateTime.parse(m['end_time'] as String) : null,
        investment: m['investment'] as int? ?? 0,
        collection: m['collection'] as int? ?? 0,
        profit: m['profit'] as int? ?? 0,
        setting: m['setting'] as int?,
        diffMedals: m['diff_medals'] as int?,
        startG: m['start_g'] as int?,
        endG: m['end_g'] as int?,
        bbCount: m['bb_count'] as int?,
        rbCount: m['rb_count'] as int?,
        atCount: m['at_count'] as int?,
        memo: m['memo'] as String?,
        investmentMedals: m['investment_medals'] as int? ?? 0,
        investmentCash: m['investment_cash'] as int? ?? 0,
        collectionMedals: m['collection_medals'] as int? ?? 0,
        collectionCash: m['collection_cash'] as int? ?? 0,
        medalPrice: m['medal_price'] as int? ?? 0,
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
        'investment': investment,
        'collection': collection,
        'profit': profit,
        'setting': setting,
        'diff_medals': diffMedals,
        'start_g': startG,
        'end_g': endG,
        'bb_count': bbCount,
        'rb_count': rbCount,
        'at_count': atCount,
        'memo': memo,
        'investment_medals': investmentMedals,
        'investment_cash': investmentCash,
        'collection_medals': collectionMedals,
        'collection_cash': collectionCash,
        'medal_price': medalPrice,
        'aim': aim,
        'is_synced': isSynced ? 1 : 0,
      };

  RecordModel copyWith({
    String? id, String? userId, DateTime? date,
    String? storeName, String? machineName, int? machineNumber,
    DateTime? startTime, DateTime? endTime,
    int? investment, int? collection, int? profit,
    int? setting, int? diffMedals,
    int? startG, int? endG,
    int? bbCount, int? rbCount, int? atCount,
    String? memo, String? aim, bool? isSynced,
    int? investmentMedals, int? investmentCash,
    int? collectionMedals, int? collectionCash, int? medalPrice,
  }) => RecordModel(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        date: date ?? this.date,
        storeName: storeName ?? this.storeName,
        machineName: machineName ?? this.machineName,
        machineNumber: machineNumber ?? this.machineNumber,
        startTime: startTime ?? this.startTime,
        endTime: endTime ?? this.endTime,
        investment: investment ?? this.investment,
        collection: collection ?? this.collection,
        profit: profit ?? this.profit,
        setting: setting ?? this.setting,
        diffMedals: diffMedals ?? this.diffMedals,
        startG: startG ?? this.startG,
        endG: endG ?? this.endG,
        bbCount: bbCount ?? this.bbCount,
        rbCount: rbCount ?? this.rbCount,
        atCount: atCount ?? this.atCount,
        memo: memo ?? this.memo,
        aim: aim ?? this.aim,
        isSynced: isSynced ?? this.isSynced,
        investmentMedals: investmentMedals ?? this.investmentMedals,
        investmentCash: investmentCash ?? this.investmentCash,
        collectionMedals: collectionMedals ?? this.collectionMedals,
        collectionCash: collectionCash ?? this.collectionCash,
        medalPrice: medalPrice ?? this.medalPrice,
      );
}
