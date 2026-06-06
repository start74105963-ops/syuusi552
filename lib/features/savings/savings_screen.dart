import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/database/local_database.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format_utils.dart';
import '../../shared/models/savings_model.dart';
import '../../shared/repositories/savings_repository.dart';
import '../../shared/widgets/empty_state.dart';
import '../auth/auth_provider.dart';

class SavingsScreen extends ConsumerStatefulWidget {
  const SavingsScreen({super.key});

  @override
  ConsumerState<SavingsScreen> createState() => _SavingsScreenState();
}

class _SavingsScreenState extends ConsumerState<SavingsScreen> {
  List<SavingsModel> _savings = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final userId = ref.read(authProvider).value?.id ?? 'local';
    final repo = SavingsRepository(LocalDatabase());
    final list = await repo.getAll(userId);
    setState(() {
      _savings = list;
      _loading = false;
    });
  }

  Future<void> _add() async {
    final nameCtrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('新規店舗追加'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(labelText: '店舗名'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('キャンセル')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('追加'),
          ),
        ],
      ),
    );
    if (result == true && nameCtrl.text.isNotEmpty) {
      final userId = ref.read(authProvider).value?.id ?? 'local';
      final repo = SavingsRepository(LocalDatabase());
      await repo.upsert(SavingsModel(
        id: const Uuid().v4(),
        userId: userId,
        storeName: nameCtrl.text,
        amount: 0,
        updatedAt: DateTime.now(),
      ));
      _load();
    }
  }

  Future<void> _updateAmount(SavingsModel savings, bool isAdd) async {
    final ctrl = TextEditingController();
    final memoCtrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(isAdd ? '貯玉追加' : '貯玉使用'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(savings.storeName, style: const TextStyle(color: AppColors.onSurfaceMuted, fontSize: 13)),
            const SizedBox(height: 8),
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(labelText: '枚数'),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              autofocus: true,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: memoCtrl,
              decoration: const InputDecoration(labelText: 'メモ（任意）'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('キャンセル')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('確定')),
        ],
      ),
    );

    if (result == true && ctrl.text.isNotEmpty) {
      final delta = int.tryParse(ctrl.text) ?? 0;
      if (delta <= 0) return;
      final newAmount = isAdd ? savings.amount + delta : (savings.amount - delta).clamp(0, 9999999);
      final repo = SavingsRepository(LocalDatabase());
      final updated = await repo.upsert(SavingsModel(
        id: savings.id,
        userId: savings.userId,
        storeName: savings.storeName,
        amount: newAmount,
        updatedAt: DateTime.now(),
      ));
      await repo.addHistory(
        updated.id,
        isAdd ? delta : -delta,
        isAdd ? 'add' : 'use',
        memoCtrl.text.isEmpty ? null : memoCtrl.text,
      );
      _load();
    }
  }

  Future<void> _showHistory(SavingsModel savings) async {
    final repo = SavingsRepository(LocalDatabase());
    final history = await repo.getHistory(savings.id);
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('${savings.storeName} - 履歴', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          Expanded(
            child: history.isEmpty
                ? const Center(child: Text('履歴がありません', style: TextStyle(color: AppColors.onSurfaceMuted)))
                : ListView.builder(
                    itemCount: history.length,
                    itemBuilder: (_, i) {
                      final h = history[i];
                      final isAdd = h.type == 'add';
                      return ListTile(
                        leading: Icon(
                          isAdd ? Icons.add_circle_outline : Icons.remove_circle_outline,
                          color: isAdd ? AppColors.win : AppColors.loss,
                        ),
                        title: Text(
                          '${isAdd ? '+' : ''}${formatAmount(h.delta)}枚',
                          style: TextStyle(color: isAdd ? AppColors.win : AppColors.loss, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          formatDate(h.createdAt),
                          style: const TextStyle(color: AppColors.onSurfaceMuted, fontSize: 12),
                        ),
                        trailing: h.memo != null ? Text(h.memo!, style: const TextStyle(color: AppColors.onSurfaceMuted, fontSize: 12)) : null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('貯玉管理')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _savings.isEmpty
              ? EmptyState(
                  message: '貯玉を管理する店舗がありません',
                  icon: Icons.savings_outlined,
                  actionLabel: '店舗を追加',
                  onAction: _add,
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _savings.length,
                  itemBuilder: (_, i) => _SavingsTile(
                    savings: _savings[i],
                    onAdd: () => _updateAmount(_savings[i], true),
                    onUse: () => _updateAmount(_savings[i], false),
                    onHistory: () => _showHistory(_savings[i]),
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _add,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _SavingsTile extends StatelessWidget {
  final SavingsModel savings;
  final VoidCallback onAdd;
  final VoidCallback onUse;
  final VoidCallback onHistory;

  const _SavingsTile({
    required this.savings,
    required this.onAdd,
    required this.onUse,
    required this.onHistory,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(savings.storeName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                TextButton(
                  onPressed: onHistory,
                  child: const Text('履歴', style: TextStyle(color: AppColors.onSurfaceMuted, fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.toll, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  '${formatAmount(savings.amount)}枚',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '最終更新: ${formatDate(savings.updatedAt)}',
              style: const TextStyle(color: AppColors.onSurfaceMuted, fontSize: 11),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onAdd,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('追加'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.win,
                      side: const BorderSide(color: AppColors.win),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onUse,
                    icon: const Icon(Icons.remove, size: 16),
                    label: const Text('使用'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.loss,
                      side: const BorderSide(color: AppColors.loss),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
