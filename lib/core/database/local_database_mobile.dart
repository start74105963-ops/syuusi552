import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';

class LocalDatabase {
  static final LocalDatabase _instance = LocalDatabase._();
  factory LocalDatabase() => _instance;
  LocalDatabase._();

  Database? _db;

  Future<Database> get db async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'slot_manager.db');
    return openDatabase(
      path,
      version: 3,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE records (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        date TEXT NOT NULL,
        store_name TEXT NOT NULL,
        machine_name TEXT NOT NULL,
        machine_number INTEGER,
        start_time TEXT,
        end_time TEXT,
        investment INTEGER NOT NULL DEFAULT 0,
        collection INTEGER NOT NULL DEFAULT 0,
        profit INTEGER NOT NULL DEFAULT 0,
        investment_medals INTEGER NOT NULL DEFAULT 0,
        investment_cash INTEGER NOT NULL DEFAULT 0,
        collection_medals INTEGER NOT NULL DEFAULT 0,
        collection_cash INTEGER NOT NULL DEFAULT 0,
        medal_price INTEGER NOT NULL DEFAULT 0,
        memo TEXT,
        aim TEXT,
        is_synced INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE stores (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        name TEXT NOT NULL,
        region TEXT,
        memo TEXT,
        medal_price INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE machines (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        maker TEXT,
        category TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE savings (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        store_name TEXT NOT NULL,
        amount INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE savings_history (
        id TEXT PRIMARY KEY,
        savings_id TEXT NOT NULL,
        delta INTEGER NOT NULL,
        type TEXT NOT NULL,
        created_at TEXT NOT NULL,
        memo TEXT
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE records ADD COLUMN investment_medals INTEGER NOT NULL DEFAULT 0');
      await db.execute('ALTER TABLE records ADD COLUMN investment_cash INTEGER NOT NULL DEFAULT 0');
      await db.execute('ALTER TABLE records ADD COLUMN collection_medals INTEGER NOT NULL DEFAULT 0');
      await db.execute('ALTER TABLE records ADD COLUMN collection_cash INTEGER NOT NULL DEFAULT 0');
      await db.execute('ALTER TABLE records ADD COLUMN medal_price INTEGER NOT NULL DEFAULT 0');
      await db.execute('ALTER TABLE stores ADD COLUMN medal_price INTEGER NOT NULL DEFAULT 0');
      await db.execute('UPDATE records SET investment_medals = investment, collection_medals = collection');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE records ADD COLUMN aim TEXT');
    }
  }

  // Records CRUD
  Future<List<Map<String, dynamic>>> getRecords(String userId) async {
    final d = await db;
    return d.query('records', where: 'user_id = ?', whereArgs: [userId], orderBy: 'date DESC');
  }

  Future<List<Map<String, dynamic>>> getRecordsByMonth(String userId, int year, int month) async {
    final d = await db;
    final from = '$year-${month.toString().padLeft(2, '0')}-01';
    final to = '$year-${month.toString().padLeft(2, '0')}-31';
    return d.query(
      'records',
      where: 'user_id = ? AND date >= ? AND date <= ?',
      whereArgs: [userId, from, to],
      orderBy: 'date DESC',
    );
  }

  Future<void> insertRecord(Map<String, dynamic> record) async {
    final d = await db;
    await d.insert('records', record, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateRecord(Map<String, dynamic> record) async {
    final d = await db;
    await d.update('records', record, where: 'id = ?', whereArgs: [record['id']]);
  }

  Future<void> deleteRecord(String id) async {
    final d = await db;
    await d.delete('records', where: 'id = ?', whereArgs: [id]);
  }

  // Stores CRUD
  Future<List<Map<String, dynamic>>> getStores(String userId) async {
    final d = await db;
    return d.query('stores', where: 'user_id = ?', whereArgs: [userId], orderBy: 'name ASC');
  }

  Future<void> insertStore(Map<String, dynamic> store) async {
    final d = await db;
    await d.insert('stores', store, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteStore(String id) async {
    final d = await db;
    await d.delete('stores', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> getStoreMedalPrice(String userId, String storeName) async {
    final d = await db;
    final rows = await d.query(
      'stores',
      columns: ['medal_price'],
      where: 'user_id = ? AND name = ?',
      whereArgs: [userId, storeName],
      limit: 1,
    );
    if (rows.isEmpty) return 0;
    return rows.first['medal_price'] as int? ?? 0;
  }

  Future<void> upsertStoreMedalPrice(String userId, String storeName, int price) async {
    final d = await db;
    final rows = await d.query(
      'stores',
      where: 'user_id = ? AND name = ?',
      whereArgs: [userId, storeName],
      limit: 1,
    );
    if (rows.isEmpty) {
      await d.insert('stores', {
        'id': const Uuid().v4(),
        'user_id': userId,
        'name': storeName,
        'medal_price': price,
      });
    } else {
      await d.update(
        'stores',
        {'medal_price': price},
        where: 'user_id = ? AND name = ?',
        whereArgs: [userId, storeName],
      );
    }
  }

  // Machines
  Future<List<Map<String, dynamic>>> getMachines() async {
    final d = await db;
    return d.query('machines', orderBy: 'name ASC');
  }

  Future<void> insertMachine(Map<String, dynamic> machine) async {
    final d = await db;
    await d.insert('machines', machine, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // Savings
  Future<List<Map<String, dynamic>>> getSavings(String userId) async {
    final d = await db;
    return d.query('savings', where: 'user_id = ?', whereArgs: [userId]);
  }

  Future<void> upsertSavings(Map<String, dynamic> savings) async {
    final d = await db;
    await d.insert('savings', savings, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getSavingsHistory(String savingsId) async {
    final d = await db;
    return d.query(
      'savings_history',
      where: 'savings_id = ?',
      whereArgs: [savingsId],
      orderBy: 'created_at DESC',
      limit: 50,
    );
  }

  Future<void> insertSavingsHistory(Map<String, dynamic> history) async {
    final d = await db;
    await d.insert('savings_history', history, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getUnsyncedRecords(String userId) async {
    final d = await db;
    return d.query('records', where: 'user_id = ? AND is_synced = 0', whereArgs: [userId]);
  }

  Future<void> markSynced(String id) async {
    final d = await db;
    await d.update('records', {'is_synced': 1}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteAllData() async {
    final d = await db;
    await d.delete('records');
    await d.delete('savings');
    await d.delete('savings_history');
  }
}
