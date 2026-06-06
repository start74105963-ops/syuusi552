import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import 'auth_provider.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),
              // ロゴ・タイトル
              const Icon(Icons.casino, size: 72, color: AppColors.primary),
              const SizedBox(height: 24),
              const Text(
                'スロット収支管理',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                '入力の手間を極限まで減らした\n収支管理アプリ',
                style: TextStyle(color: AppColors.onSurfaceMuted, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const Spacer(flex: 2),
              // Google ログイン
              _GoogleSignInButton(
                onPressed: authState.isLoading
                    ? null
                    : () => ref.read(authProvider.notifier).signInWithGoogle(),
              ),
              const SizedBox(height: 16),
              // ゲストログイン
              OutlinedButton.icon(
                onPressed: authState.isLoading
                    ? null
                    : () => ref.read(authProvider.notifier).signInAsGuest(),
                icon: const Icon(Icons.person_outline),
                label: const Text('ゲストとして使う'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.onSurfaceMuted,
                  side: const BorderSide(color: AppColors.cardBorder),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
              if (authState.hasError)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    'ログインに失敗しました',
                    style: const TextStyle(color: AppColors.loss),
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 12),
              const Text(
                'ゲストモードではデータはこの端末にのみ保存されます',
                style: TextStyle(color: AppColors.onSurfaceMuted, fontSize: 11),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoogleSignInButton extends StatelessWidget {
  final VoidCallback? onPressed;
  const _GoogleSignInButton({this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Googleロゴの代替アイコン
          Icon(Icons.g_mobiledata, size: 28, color: Colors.blue),
          SizedBox(width: 8),
          Text('Googleでログイン', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
