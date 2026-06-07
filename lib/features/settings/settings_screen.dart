import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/local_database.dart';
import '../../core/theme/app_theme.dart';
import '../auth/auth_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.valueOrNull;
    final isGuest = user == null || user.id == 'local_guest';
    final displayName = user?.displayName ?? 'ゲストユーザー';
    final email = user?.email ?? 'ログインしていません';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        children: [
          // ─── ユーザーカード ────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cardBorder, width: 0.5),
              ),
              child: Row(children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.primaryLight,
                  child: Text(
                    isGuest ? 'G' : displayName.substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(displayName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 2),
                      Text(email,
                          style: const TextStyle(color: AppColors.onSurfaceMuted, fontSize: 13)),
                      if (isGuest) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('ゲストモード',
                              style: TextStyle(color: AppColors.onSurfaceMuted, fontSize: 11)),
                        ),
                      ],
                    ],
                  ),
                ),
              ]),
            ),
          ),

          // ─── アカウント ────────────────────────────
          const _SectionHeader(title: 'アカウント'),
          if (!isGuest)
            ListTile(
              leading: const Icon(Icons.logout, color: AppColors.loss),
              title: const Text('ログアウト'),
              onTap: () => _confirmLogout(context, ref),
            )
          else
            ListTile(
              leading: const Icon(Icons.login, color: AppColors.primary),
              title: const Text('ログイン / 新規登録'),
              subtitle: const Text('データをクラウドに保存できます',
                  style: TextStyle(color: AppColors.onSurfaceMuted, fontSize: 12)),
              trailing: const Icon(Icons.chevron_right, color: AppColors.onSurfaceMuted),
              onTap: () {}, // 未実装
            ),

          // ─── データ管理 ────────────────────────────
          const _SectionHeader(title: 'データ管理'),
          ListTile(
            leading: const Icon(Icons.download_outlined, color: AppColors.primary),
            title: const Text('CSVエクスポート'),
            subtitle: const Text('実践記録をCSV形式で出力',
                style: TextStyle(color: AppColors.onSurfaceMuted, fontSize: 12)),
            onTap: () => _exportCsv(context, ref),
          ),
          const Divider(color: AppColors.cardBorder, indent: 16, endIndent: 16, height: 1),
          ListTile(
            leading: const Icon(Icons.delete_forever_outlined, color: AppColors.loss),
            title: const Text('全データを削除',
                style: TextStyle(color: AppColors.loss)),
            subtitle: const Text('すべての実践記録・貯玉データを削除します',
                style: TextStyle(color: AppColors.onSurfaceMuted, fontSize: 12)),
            onTap: () => _confirmDeleteAll(context, ref),
          ),

          // ─── アプリ情報 ────────────────────────────
          const _SectionHeader(title: 'アプリ情報'),
          const ListTile(
            leading: Icon(Icons.info_outline, color: AppColors.onSurfaceMuted),
            title: Text('バージョン'),
            trailing: Text('1.0.0', style: TextStyle(color: AppColors.onSurfaceMuted)),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ログアウト'),
        content: const Text('ログアウトしますか？\nローカルデータは保持されます。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('キャンセル')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ログアウト', style: TextStyle(color: AppColors.loss)),
          ),
        ],
      ),
    );
    if (ok == true) {
      // Google Sign Out はここに実装
    }
  }

  Future<void> _exportCsv(BuildContext context, WidgetRef ref) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('CSV出力機能は近日公開予定です')),
    );
  }

  Future<void> _confirmDeleteAll(BuildContext context, WidgetRef ref) async {
    // 1段階目
    final step1 = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('全データ削除'),
        content: const Text('すべての実践記録・貯玉データを削除します。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('キャンセル')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('次へ', style: TextStyle(color: AppColors.loss)),
          ),
        ],
      ),
    );
    if (step1 != true || !context.mounted) return;

    // 2段階目
    final step2 = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('本当に削除しますか？'),
        content: const Text('この操作は取り消せません。\nすべてのデータが完全に消去されます。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('やめる')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.loss),
            child: const Text('完全に削除する'),
          ),
        ],
      ),
    );
    if (step2 == true) {
      await LocalDatabase().deleteAllData();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('すべてのデータを削除しました')),
        );
      }
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(title,
            style: const TextStyle(
                color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
      );
}
