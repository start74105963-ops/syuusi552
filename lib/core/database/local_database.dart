import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

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
    return openDatabase(path, version: 1, onCreate: _onCreate);
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
        investment INTEGER NOT NULL,
        collection INTEGER NOT NULL,
        profit INTEGER NOT NULL,
        memo TEXT,
        is_synced INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE stores (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        name TEXT NOT NULL,
        region TEXT,
        memo TEXT
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

  // Unsynced records
  Future<List<Map<String, dynamic>>> getUnsyncedRecords(String userId) async {
    final d = await db;
    return d.query('records', where: 'user_id = ? AND is_synced = 0', whereArgs: [userId]);
  }

  Future<void> markSynced(String id) async {
    final d = await db;
    await d.update('records', {'is_synced': 1}, where: 'id = ?', whereArgs: [id]);
  }
}
