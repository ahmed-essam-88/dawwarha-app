import 'dart:convert';
import 'dart:io';

import '../core/firebase_config.dart';

class AuthException implements Exception {
  final String code; // Firebase error code, e.g. EMAIL_EXISTS, or 'NETWORK'
  AuthException(this.code);
  @override
  String toString() => code;
}

class AuthSession {
  final String uid, email, idToken, refreshToken;
  const AuthSession(this.uid, this.email, this.idToken, this.refreshToken);
}

/// Firebase Authentication over its public REST API (email + password).
/// Users created here appear in the Firebase console under Authentication > Users.
class FirebaseAuthClient {
  final String apiKey;
  final String identityHost;
  final String tokenHost;
  FirebaseAuthClient({String? apiKey, String? identityHost, String? tokenHost})
      : apiKey = apiKey ?? FirebaseConfig.apiKey,
        identityHost = identityHost ?? FirebaseConfig.identityHost,
        tokenHost = tokenHost ?? FirebaseConfig.tokenHost;

  Future<Map<String, dynamic>> _post(String url, Map<String, dynamic> body, {bool form = false}) async {
    final c = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final req = await c.postUrl(Uri.parse(url));
      if (form) {
        req.headers.set('Content-Type', 'application/x-www-form-urlencoded');
        req.add(utf8.encode(body.entries.map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent('${e.value}')}').join('&')));
      } else {
        req.headers.set('Content-Type', 'application/json');
        req.add(utf8.encode(jsonEncode(body)));
      }
      final res = await req.close().timeout(const Duration(seconds: 15));
      final text = await res.transform(utf8.decoder).join();
      Map<String, dynamic> json = {};
      try {
        json = jsonDecode(text) as Map<String, dynamic>;
      } catch (_) {}
      if (res.statusCode != 200) {
        final msg = (json['error'] is Map ? (json['error'] as Map)['message'] : null) as String? ?? 'HTTP_${res.statusCode}';
        throw AuthException(msg.split(' ').first); // e.g. "WEAK_PASSWORD : Password should be..."
      }
      return json;
    } on AuthException {
      rethrow;
    } catch (_) {
      throw AuthException('NETWORK');
    } finally {
      c.close();
    }
  }

  AuthSession _session(Map<String, dynamic> j, String fallbackEmail) =>
      AuthSession(j['localId'] as String, (j['email'] as String?) ?? fallbackEmail, j['idToken'] as String, j['refreshToken'] as String);

  Future<AuthSession> signUp(String email, String password) async => _session(
      await _post('$identityHost/v1/accounts:signUp?key=$apiKey', {'email': email, 'password': password, 'returnSecureToken': true}), email);

  Future<AuthSession> signIn(String email, String password) async => _session(
      await _post('$identityHost/v1/accounts:signInWithPassword?key=$apiKey', {'email': email, 'password': password, 'returnSecureToken': true}),
      email);

  Future<AuthSession> refresh(String refreshToken, String email) async {
    final j = await _post('$tokenHost/v1/token?key=$apiKey', {'grant_type': 'refresh_token', 'refresh_token': refreshToken}, form: true);
    return AuthSession(j['user_id'] as String, email, j['id_token'] as String, j['refresh_token'] as String);
  }

  Future<void> sendPasswordReset(String email) =>
      _post('$identityHost/v1/accounts:sendOobCode?key=$apiKey', {'requestType': 'PASSWORD_RESET', 'email': email});

  Future<void> deleteAccount(String idToken) => _post('$identityHost/v1/accounts:delete?key=$apiKey', {'idToken': idToken});
}
