import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppUser {
  final String id;
  final String email;
  final String? displayName;
  final String? photoUrl;

  const AppUser({
    required this.id,
    required this.email,
    this.displayName,
    this.photoUrl,
  });
}

class AuthNotifier extends AsyncNotifier<AppUser?> {
  static final _googleSignIn = GoogleSignIn(scopes: ['email']);

  @override
  Future<AppUser?> build() async {
    // ゲストモードで自動ログイン（オフライン対応）
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('guest_user_id');
    if (userId != null) {
      return AppUser(
        id: userId,
        email: prefs.getString('guest_email') ?? 'guest@local',
        displayName: prefs.getString('guest_name') ?? 'ゲスト',
      );
    }
    return null;
  }

  Future<void> signInWithGoogle() async {
    state = const AsyncLoading();
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        state = const AsyncData(null);
        return;
      }
      final user = AppUser(
        id: account.id,
        email: account.email,
        displayName: account.displayName,
        photoUrl: account.photoUrl,
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('guest_user_id', user.id);
      await prefs.setString('guest_email', user.email);
      if (user.displayName != null) await prefs.setString('guest_name', user.displayName!);
      state = AsyncData(user);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
    }
  }

  Future<void> signInAsGuest() async {
    state = const AsyncLoading();
    const guestId = 'local_guest';
    const user = AppUser(id: guestId, email: 'guest@local', displayName: 'ゲスト');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('guest_user_id', guestId);
    await prefs.setString('guest_email', 'guest@local');
    await prefs.setString('guest_name', 'ゲスト');
    state = const AsyncData(user);
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('guest_user_id');
    await prefs.remove('guest_email');
    await prefs.remove('guest_name');
    state = const AsyncData(null);
  }
}

final authProvider = AsyncNotifierProvider<AuthNotifier, AppUser?>(AuthNotifier.new);
