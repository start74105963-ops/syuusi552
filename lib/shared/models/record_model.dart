class RecordModel {
  final String id;
  final String userId;
  final DateTime date;
  final String storeName;
  final String machineName;
  final int? machineNumber;
  final DateTime? startTime;
  final DateTime? endTime;
  final int investment;
  final int collection;
  final int profit;
  final String? memo;
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
    this.memo,
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
        investment: m['investment'] as int,
        collection: m['collection'] as int,
        profit: m['profit'] as int,
        memo: m['memo'] as String?,
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
        'memo': memo,
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
    int? investment,
    int? collection,
    int? profit,
    String? memo,
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
        investment: investment ?? this.investment,
        collection: collection ?? this.collection,
        profit: profit ?? this.profit,
        memo: memo ?? this.memo,
        isSynced: isSynced ?? this.isSynced,
      );
}
