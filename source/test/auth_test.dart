import 'dart:convert';
import 'dart:io';

import 'package:environmental_challenges/core/l10n/app_strings.dart';
import 'package:environmental_challenges/features/profile/profile_screen.dart';
import 'package:environmental_challenges/providers/auth_provider.dart';
import 'package:environmental_challenges/providers/locale_provider.dart';
import 'package:environmental_challenges/services/firebase_auth_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:environmental_challenges/services/token_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

const ar = S(true);

/// Fake Firebase REST server. Records requests; returns canned Firebase-shaped replies.
class Fake {
  late HttpServer server;
  final reqs = <String>[];
  final bodies = <Map<String, dynamic>>[];
  Map<String, String> users = {}; // email -> password
  String get base => 'http://127.0.0.1:${server.port}';
  Future<void> start() async {
    server = await HttpServer.bind('127.0.0.1', 0);
    server.listen((r) async {
      final raw = await utf8.decoder.bind(r).join();
      final path = r.uri.path;
      reqs.add('${path}?key=${r.uri.queryParameters['key']}');
      Map<String, dynamic> b;
      if ((r.headers.contentType?.mimeType ?? '').contains('json')) {
        b = jsonDecode(raw) as Map<String, dynamic>;
      } else {
        b = Uri.splitQueryString(raw);
      }
      bodies.add(b);
      void reply(int code, Object o) {
        r.response.statusCode = code;
        r.response.headers.contentType = ContentType.json;
        r.response.write(jsonEncode(o));
      }

      Map<String, dynamic> ok(String e) => {'localId': 'uid_$e', 'email': e, 'idToken': 'id_$e', 'refreshToken': 'rt_$e'};
      if (path.endsWith('accounts:signUp')) {
        final e = b['email'] as String;
        if (users.containsKey(e)) {
          reply(400, {'error': {'message': 'EMAIL_EXISTS'}});
        } else {
          users[e] = b['password'] as String;
          reply(200, ok(e));
        }
      } else if (path.endsWith('accounts:signInWithPassword')) {
        final e = b['email'] as String;
        if (users[e] != b['password']) {
          reply(400, {'error': {'message': 'INVALID_LOGIN_CREDENTIALS'}});
        } else {
          reply(200, ok(e));
        }
      } else if (path.endsWith('/token')) {
        reply(200, {'user_id': 'uid_x', 'id_token': 'id2', 'refresh_token': 'rt2'});
      } else if (path.endsWith('accounts:delete')) {
        reply(200, {});
      } else if (path.endsWith('accounts:sendOobCode')) {
        reply(200, {'email': b['email']});
      } else {
        reply(404, {});
      }
      await r.response.close();
    });
  }
}

Widget wrap(AuthProvider a) => MultiProvider(
    providers: [ChangeNotifierProvider(create: (_) => LocaleProvider()), ChangeNotifierProvider.value(value: a)],
    child: const MaterialApp(home: ProfileScreen()));

void main() {
  setUp(() {
    HttpOverrides.global = null;
    SharedPreferences.setMockInitialValues({});
  });

  test('validation', () {
    expect(AuthProvider.validate('nope', 'abcdef'), 'INVALID_EMAIL');
    expect(AuthProvider.validate('a@b.co', 'abc'), 'WEAK_PASSWORD');
    expect(AuthProvider.validate('a@b.co', 'abcdef'), isNull);
  });

  test('sign up, duplicate, wrong password, sign in, persistence without password, restore, delete', () async {
    final f = Fake();
    await f.start();
    final client = FirebaseAuthClient(apiKey: 'K', identityHost: f.base, tokenHost: f.base);
    final mem = MemoryTokenStore();
    final a = AuthProvider(client: client, store: mem);
    expect(await a.submit(AuthMode.signUp, 'user@example.test', 'secret1'), true);
    expect(a.session!.uid, 'uid_user@example.test');
    expect(f.reqs.first, '/v1/accounts:signUp?key=K');
    expect(mem.data['auth_refresh'], 'rt_user@example.test');
    expect(mem.data.values.every((v) => !v.contains('secret1')), true); // password never stored
    await a.signOut();
    expect(a.session, isNull);
    expect(mem.data, isEmpty);
    expect(await a.submit(AuthMode.signUp, 'user@example.test', 'secret1'), false);
    expect(a.errorCode, 'EMAIL_EXISTS');
    expect(await a.submit(AuthMode.signIn, 'user@example.test', 'wrongpw'), false);
    expect(a.errorCode, 'INVALID_LOGIN_CREDENTIALS');
    expect(await a.submit(AuthMode.signIn, 'user@example.test', 'secret1'), true);
    // restore in a fresh provider from the stored refresh token
    final b = AuthProvider(client: client, store: mem);
    await b.restore();
    expect(b.session!.idToken, 'id2');
    expect(f.bodies.last['grant_type'], 'refresh_token');
    await a.deleteAccount();
    expect(a.session, isNull);
    expect(mem.data, isEmpty); // delete clears stored session material
    expect(f.reqs.last, '/v1/accounts:delete?key=K');
    await f.server.close(force: true);
  });

  test('network failure maps to NETWORK and keeps saved token on restore', () async {
    final mem = MemoryTokenStore()..data.addAll({'auth_refresh': 'r', 'auth_email': 'e@e.co'});
    final a = AuthProvider(store: mem, client: FirebaseAuthClient(apiKey: 'K', identityHost: 'http://127.0.0.1:1', tokenHost: 'http://127.0.0.1:1'));
    await a.restore();
    expect(a.session, isNull);
    expect(mem.data['auth_refresh'], 'r');
    expect(await a.submit(AuthMode.signIn, 'e@e.co', 'abcdef'), false);
    expect(a.errorCode, 'NETWORK');
  });

  testWidgets('profile screen: invalid input error, sign up shows signed-in state, sign out', (t) async {
    final f = Fake();
    await t.runAsync(f.start);
    final a = AuthProvider(store: MemoryTokenStore(), client: FirebaseAuthClient(apiKey: 'K', identityHost: f.base, tokenHost: f.base));
    await t.pumpWidget(wrap(a));
    await t.tap(find.byKey(const Key('authToggle')));
    await t.pump();
    await t.enterText(find.byKey(const Key('email')), 'bad');
    await t.enterText(find.byKey(const Key('password')), 'secret1');
    await t.tap(find.byKey(const Key('authSubmit')));
    await t.pump();
    expect(find.text(ar.t('auth_INVALID_EMAIL')), findsOneWidget);
    await t.enterText(find.byKey(const Key('email')), 'ui@example.test');
    await t.runAsync(() async {
      await t.tap(find.byKey(const Key('authSubmit')));
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await t.pump();
    expect(find.byKey(const Key('signedInAs')), findsOneWidget);
    expect(find.text('ui@example.test'), findsOneWidget);
    await t.tap(find.byKey(const Key('signOut')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('authSubmit')), findsOneWidget);
    await t.runAsync(() => f.server.close(force: true));
  });

  test('upgrade: legacy plaintext token moves to the secure store and is removed from SharedPreferences', () async {
    final f = Fake();
    await f.start();
    SharedPreferences.setMockInitialValues({'auth_refresh': 'rt_old@example.test', 'auth_email': 'old@example.test'});
    final mem = MemoryTokenStore();
    final a = AuthProvider(store: mem, client: FirebaseAuthClient(apiKey: 'K', identityHost: f.base, tokenHost: f.base));
    await a.restore();
    final p = await SharedPreferences.getInstance();
    expect(p.containsKey('auth_refresh'), false);
    expect(p.containsKey('auth_email'), false);
    expect(a.session?.email, 'old@example.test'); // restored through the migrated token
    expect(mem.data['auth_refresh'], isNotNull);
    await a.signOut();
    expect(mem.data, isEmpty);
    expect(p.getKeys().where((k) => k.startsWith('auth_')), isEmpty);
    await f.server.close(force: true);
  });

  test('upgrade: legacy copy is removed even when the secure store already has a session, and logout clears a re-planted legacy copy', () async {
    SharedPreferences.setMockInitialValues({'auth_refresh': 'legacy', 'auth_email': 'l@e.co'});
    final mem = MemoryTokenStore()..data.addAll({'auth_refresh': 'secure', 'auth_email': 's@e.co'});
    final a = AuthProvider(store: mem, client: FirebaseAuthClient(apiKey: 'K', identityHost: 'http://127.0.0.1:1', tokenHost: 'http://127.0.0.1:1'));
    await a.restore();
    final p = await SharedPreferences.getInstance();
    expect(p.getKeys().where((k) => k.startsWith('auth_')), isEmpty);
    expect(mem.data['auth_refresh'], 'secure'); // secure copy wins, not overwritten
    expect(mem.data['auth_email'], 's@e.co');
  });

  test('broken secure store: migration keeps the legacy token, restore does not crash, sign-out still works', () async {
    SharedPreferences.setMockInitialValues({'auth_refresh': 'legacy', 'auth_email': 'l@e.co'});
    final a = AuthProvider(store: _BrokenStore(), client: FirebaseAuthClient(apiKey: 'K', identityHost: 'http://127.0.0.1:1', tokenHost: 'http://127.0.0.1:1'));
    await a.restore(); // must not throw
    expect(a.session, isNull);
    final p = await SharedPreferences.getInstance();
    expect(p.getString('auth_refresh'), 'legacy'); // write failed, so the only copy is NOT deleted
    await a.signOut(); // must not throw
    expect(a.session, isNull);
  });
}

class _BrokenStore implements TokenStore {
  @override
  Future<String?> read(String key) async => throw StateError('keystore');
  @override
  Future<void> write(String key, String value) async => throw StateError('keystore');
  @override
  Future<void> delete(String key) async => throw StateError('keystore');
}
