import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/local_database.dart';
import '../../core/theme/app_theme.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        children: [
          const _SectionHeader(title: 'データ管理'),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: AppColors.loss),
            title: const Text('全データを削除'),
            subtitle: const Text('すべての実践記録を削除します', style: TextStyle(color: AppColors.onSurfaceMuted, fontSize: 12)),
            onTap: () => _confirmDeleteAll(context, ref),
          ),
          const Divider(color: AppColors.cardBorder, indent: 16, endIndent: 16),
          const _SectionHeader(title: 'アプリ情報'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('バージョン'),
            trailing: Text('1.0.0', style: TextStyle(color: AppColors.onSurfaceMuted)),
          ),
          const ListTile(
            leading: Icon(Icons.description_outlined),
            title: Text('プライバシーポリシー'),
          ),
          const ListTile(
            leading: Icon(Icons.article_outlined),
            title: Text('利用規約'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteAll(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('全データ削除'),
        content: const Text('すべての実践記録・貯玉データを削除します。\nこの操作は取り消せません。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('キャンセル')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.loss),
            child: const Text('削除する'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final db = await LocalDatabase().db;
      await db.delete('records');
      await db.delete('savings');
      await db.delete('savings_history');
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(title, style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
      );
}
