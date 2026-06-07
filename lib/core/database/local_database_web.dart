import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class LocalDatabase {
  static final LocalDatabase _instance = LocalDatabase._();
  factory LocalDatabase() => _instance;
  LocalDatabase._();

  Future<List<Map<String, dynamic>>> _getList(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(key);
    if (json == null) return [];
    final list = jsonDecode(json) as List;
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> _saveList(String key, List<Map<String, dynamic>> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(list));
  }

  // Records CRUD
  Future<List<Map<String, dynamic>>> getRecords(String userId) async {
    final all = await _getList('db_records');
    final filtered = all.where((r) => r['user_id'] == userId).toList();
    filtered.sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));
    return filtered;
  }

  Future<List<Map<String, dynamic>>> getRecordsByMonth(String userId, int year, int month) async {
    final all = await getRecords(userId);
    final from = '$year-${month.toString().padLeft(2, '0')}-01';
    final to = '$year-${month.toString().padLeft(2, '0')}-31';
    return all.where((r) {
      final date = r['date'] as String;
      return date.compareTo(from) >= 0 && date.compareTo(to) <= 0;
    }).toList();
  }

  Future<void> insertRecord(Map<String, dynamic> record) async {
    final all = await _getList('db_records');
    final idx = all.indexWhere((r) => r['id'] == record['id']);
    if (idx >= 0) {
      all[idx] = record;
    } else {
      all.add(record);
    }
    await _saveList('db_records', all);
  }

  Future<void> updateRecord(Map<String, dynamic> record) async {
    await insertRecord(record);
  }

  Future<void> deleteRecord(String id) async {
    final all = await _getList('db_records');
    all.removeWhere((r) => r['id'] == id);
    await _saveList('db_records', all);
  }

  // Stores CRUD
  Future<List<Map<String, dynamic>>> getStores(String userId) async {
    final all = await _getList('db_stores');
    final filtered = all.where((s) => s['user_id'] == userId).toList();
    filtered.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
    return filtered;
  }

  Future<void> insertStore(Map<String, dynamic> store) async {
    final all = await _getList('db_stores');
    final idx = all.indexWhere((s) => s['id'] == store['id']);
    if (idx >= 0) {
      all[idx] = store;
    } else {
      all.add(store);
    }
    await _saveList('db_stores', all);
  }

  Future<void> deleteStore(String id) async {
    final all = await _getList('db_stores');
    all.removeWhere((s) => s['id'] == id);
    await _saveList('db_stores', all);
  }

  Future<int> getStoreMedalPrice(String userId, String storeName) async {
    final all = await _getList('db_stores');
    final matches = all.where((s) => s['user_id'] == userId && s['name'] == storeName).toList();
    if (matches.isEmpty) return 0;
    return matches.first['medal_price'] as int? ?? 0;
  }

  Future<void> upsertStoreMedalPrice(String userId, String storeName, int price) async {
    final all = await _getList('db_stores');
    final idx = all.indexWhere((s) => s['user_id'] == userId && s['name'] == storeName);
    if (idx < 0) {
      all.add({
        'id': const Uuid().v4(),
        'user_id': userId,
        'name': storeName,
        'medal_price': price,
      });
    } else {
      all[idx] = {...all[idx], 'medal_price': price};
    }
    await _saveList('db_stores', all);
  }

  // Machines
  Future<List<Map<String, dynamic>>> getMachines() async {
    final all = await _getList('db_machines');
    all.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
    return all;
  }

  Future<void> insertMachine(Map<String, dynamic> machine) async {
    final all = await _getList('db_machines');
    final idx = all.indexWhere((m) => m['id'] == machine['id']);
    if (idx >= 0) {
      all[idx] = machine;
    } else {
      all.add(machine);
    }
    await _saveList('db_machines', all);
  }

  // Savings
  Future<List<Map<String, dynamic>>> getSavings(String userId) async {
    final all = await _getList('db_savings');
    return all.where((s) => s['user_id'] == userId).toList();
  }

  Future<void> upsertSavings(Map<String, dynamic> savings) async {
    final all = await _getList('db_savings');
    final idx = all.indexWhere((s) => s['id'] == savings['id']);
    if (idx >= 0) {
      all[idx] = savings;
    } else {
      all.add(savings);
    }
    await _saveList('db_savings', all);
  }

  Future<List<Map<String, dynamic>>> getSavingsHistory(String savingsId) async {
    final all = await _getList('db_savings_history');
    final filtered = all.where((h) => h['savings_id'] == savingsId).toList();
    filtered.sort((a, b) => (b['created_at'] as String).compareTo(a['created_at'] as String));
    return filtered.take(50).toList();
  }

  Future<void> insertSavingsHistory(Map<String, dynamic> history) async {
    final all = await _getList('db_savings_history');
    all.add(history);
    await _saveList('db_savings_history', all);
  }

  Future<List<Map<String, dynamic>>> getUnsyncedRecords(String userId) async {
    final all = await getRecords(userId);
    return all.where((r) => (r['is_synced'] as int? ?? 0) == 0).toList();
  }

  Future<void> markSynced(String id) async {
    final all = await _getList('db_records');
    final idx = all.indexWhere((r) => r['id'] == id);
    if (idx >= 0) {
      all[idx] = {...all[idx], 'is_synced': 1};
      await _saveList('db_records', all);
    }
  }

  Future<void> deleteAllData() async {
    await _saveList('db_records', []);
    await _saveList('db_savings', []);
    await _saveList('db_savings_history', []);
  }
}
