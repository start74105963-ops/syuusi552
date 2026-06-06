import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/local_database.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format_utils.dart';
import '../../shared/models/record_model.dart';
import '../../shared/repositories/record_repository.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/profit_chip.dart';
import 'record_form_screen.dart';

class RecordsScreen extends ConsumerStatefulWidget {
  const RecordsScreen({super.key});

  @override
  ConsumerState<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends ConsumerState<RecordsScreen> {
  List<RecordModel> _records = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    const userId = 'local_guest';
    final repo = RecordRepository(LocalDatabase());
    final records = await repo.getAll(userId);
    setState(() {
      _records = records;
      _loading = false;
    });
  }

  Future<void> _openForm([RecordModel? existing]) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => RecordFormScreen(existing: existing)),
    );
    if (result == true) _load();
  }

  Future<void> _delete(RecordModel record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('削除確認'),
        content: Text('${record.storeName} / ${record.machineName} の記録を削除しますか？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('キャンセル')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('削除', style: TextStyle(color: AppColors.loss)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await RecordRepository(LocalDatabase()).delete(record.id);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('実践履歴')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _records.isEmpty
              ? EmptyState(
                  message: '実践記録がありません\n＋ボタンから追加しましょう',
                  icon: Icons.casino_outlined,
                  actionLabel: '記録を追加',
                  onAction: () => _openForm(),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                    itemCount: _records.length,
                    itemBuilder: (_, i) => _RecordTile(
                      record: _records[i],
                      onTap: () => _openForm(_records[i]),
                      onDelete: () => _delete(_records[i]),
                    ),
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _RecordTile extends StatelessWidget {
  final RecordModel record;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _RecordTile({required this.record, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(record.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.loss.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: AppColors.loss),
      ),
      confirmDismiss: (_) async {
        onDelete();
        return false;
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      formatDate(record.date),
                      style: const TextStyle(color: AppColors.onSurfaceMuted, fontSize: 12),
                    ),
                    const Spacer(),
                    ProfitChip(profit: record.profit),
                  ],
                ),
                const SizedBox(height: 8),
                Text(record.machineName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.store_outlined, size: 14, color: AppColors.onSurfaceMuted),
                    const SizedBox(width: 4),
                    Text(record.storeName, style: const TextStyle(color: AppColors.onSurfaceMuted, fontSize: 13)),
                    if (record.machineNumber != null) ...[
                      const SizedBox(width: 8),
                      Text('${record.machineNumber}番台', style: const TextStyle(color: AppColors.onSurfaceMuted, fontSize: 13)),
                    ],
                    const Spacer(),
                    if (record.playMinutes > 0)
                      Text(formatMinutes(record.playMinutes), style: const TextStyle(color: AppColors.onSurfaceMuted, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _StatItem(label: '投資', value: '${formatAmount(record.investment)}枚'),
                    const SizedBox(width: 16),
                    _StatItem(label: '回収', value: '${formatAmount(record.collection)}枚'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Text('$label: ', style: const TextStyle(color: AppColors.onSurfaceMuted, fontSize: 12)),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      );
}
