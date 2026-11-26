import 'package:flutter/foundation.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../services/firebase_auth_client.dart';
import '../services/token_store.dart';

enum AuthMode { signIn, signUp }

/// Holds the signed-in user. Only the refresh token and email are stored on the phone,
/// in Keystore-backed secure storage (never the password).
class AuthProvider extends ChangeNotifier {
  final FirebaseAuthClient client;
  AuthSession? session;
  DateTime? _sessionAt;
  String? errorCode;
  bool busy = false;
  String? info; // 'resetSent'

  final TokenStore store;
  AuthProvider({FirebaseAuthClient? client, TokenStore? store})
      : client = client ?? FirebaseAuthClient(),
        store = store ?? SecureTokenStore();

  static const _kRefresh = 'auth_refresh', _kEmail = 'auth_email';

  /// Older builds kept the token and email in plain SharedPreferences. Move them into the secure store
  /// (if it has none yet) and delete the plaintext copy. Values are never logged.
  Future<void> _migrateLegacy() async {
    try {
      final p = await SharedPreferences.getInstance();
      final r = p.getString(_kRefresh), e = p.getString(_kEmail);
      if (r == null && e == null) return;
      if (r != null && e != null && await store.read(_kRefresh) == null) {
        await store.write(_kRefresh, r);
        await store.write(_kEmail, e);
      }
      await p.remove(_kRefresh);
      await p.remove(_kEmail);
    } catch (_) {}
  }

  Future<void> restore() async {
    await _migrateLegacy();
    try {
      final r = await store.read(_kRefresh), e = await store.read(_kEmail);
      if (r == null || e == null) return;
      session = await client.refresh(r, e);
      await _save();
    } on AuthException catch (e) {
      // Token revoked or account deleted: forget it. A network error keeps the saved token for next time.
      if (e.code != 'NETWORK') await _forget();
    } catch (_) {}
    notifyListeners();
  }

  /// ID token valid for use now: refreshed when older than 50 minutes (Firebase tokens last 60).
  Future<String?> freshIdToken() async {
    final s = session;
    if (s == null) return null;
    final at = _sessionAt ?? DateTime.now();
    if (DateTime.now().difference(at) > const Duration(minutes: 50)) {
      try {
        session = await client.refresh(s.refreshToken, s.email);
        _sessionAt = DateTime.now();
        await _save();
      } catch (_) {}
    }
    return session?.idToken;
  }

  Future<void> _save() async {
    _sessionAt = DateTime.now();
    try {
      await store.write(_kRefresh, session!.refreshToken);
      await store.write(_kEmail, session!.email);
    } catch (_) {} // session stays valid for this run; it just won't persist
  }

  Future<void> _forget() async {
    session = null;
    try {
      final p = await SharedPreferences.getInstance();
      await p.remove(_kRefresh);
      await p.remove(_kEmail);
    } catch (_) {} // legacy plaintext copy
    try {
      await store.delete(_kRefresh);
      await store.delete(_kEmail);
    } catch (_) {} // a broken secure store must not block signing out
  }

  /// Local checks before any request (Firebase requires 6+ chars for the password).
  static String? validate(String email, String password) {
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email.trim())) return 'INVALID_EMAIL';
    if (password.length < 6) return 'WEAK_PASSWORD';
    return null;
  }

  Future<bool> submit(AuthMode mode, String email, String password) async {
    final v = validate(email, password);
    if (v != null) {
      errorCode = v;
      notifyListeners();
      return false;
    }
    busy = true;
    errorCode = null;
    info = null;
    notifyListeners();
    try {
      session = mode == AuthMode.signUp ? await client.signUp(email.trim(), password) : await client.signIn(email.trim(), password);
      await _save();
    } on AuthException catch (e) {
      errorCode = e.code;
    }
    busy = false;
    notifyListeners();
    return session != null;
  }

  Future<void> resetPassword(String email) async {
    if (validate(email, 'xxxxxx') == 'INVALID_EMAIL') {
      errorCode = 'INVALID_EMAIL';
      notifyListeners();
      return;
    }
    try {
      await client.sendPasswordReset(email.trim());
      info = 'resetSent';
      errorCode = null;
    } on AuthException catch (e) {
      errorCode = e.code;
    }
    notifyListeners();
  }

  Future<void> signOut() async {
    await _forget();
    notifyListeners();
  }

  /// Deletes the Firebase account itself (privacy), then signs out locally.
  Future<void> deleteAccount() async {
    if (session == null) return;
    try {
      await client.deleteAccount(session!.idToken);
      await _forget();
      errorCode = null;
    } on AuthException catch (e) {
      errorCode = e.code; // e.g. CREDENTIAL_TOO_OLD_LOGIN_AGAIN: user must sign in again first
    }
    notifyListeners();
  }
}
