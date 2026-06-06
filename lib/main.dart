import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/constants/machine_data.dart';
import 'core/database/local_database.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _seedMachines();
  runApp(const ProviderScope(child: SlotManagerApp()));
}

Future<void> _seedMachines() async {
  final db = LocalDatabase();
  final existing = await db.getMachines();
  if (existing.isNotEmpty) return;
  for (final m in kMachineData) {
    await db.insertMachine(m);
  }
}
