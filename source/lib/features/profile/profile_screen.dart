import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../providers/auth_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  AuthMode _mode = AuthMode.signIn;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final a = context.watch<AuthProvider>();
    return Scaffold(
      appBar: AppBar(title: Text(s.t('tabProfile'))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (a.session != null) ...[
          ListTile(key: const Key('signedInAs'), leading: const Icon(Icons.account_circle, size: 40), title: Text(a.session!.email), subtitle: Text(s.t('signedIn'))),
          Text(s.t('privacyNote'), style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 12),
          OutlinedButton(key: const Key('signOut'), onPressed: a.signOut, child: Text(s.t('signOut'))),
          const SizedBox(height: 8),
          TextButton(
            key: const Key('deleteAccount'),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  content: Text(s.t('deleteConfirm')),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(c, false), child: Text(s.t('cancel'))),
                    TextButton(key: const Key('confirmDelete'), onPressed: () => Navigator.pop(c, true), child: Text(s.t('deleteAccount'))),
                  ],
                ),
              );
              if (ok == true) await a.deleteAccount();
            },
            child: Text(s.t('deleteAccount'), style: TextStyle(color: Colors.red.shade800)),
          ),
        ] else ...[
          Text(_mode == AuthMode.signIn ? s.t('signIn') : s.t('signUp'), style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          TextField(key: const Key('email'), controller: _email, keyboardType: TextInputType.emailAddress, decoration: InputDecoration(labelText: s.t('email'))),
          TextField(key: const Key('password'), controller: _pass, obscureText: true, decoration: InputDecoration(labelText: s.t('password'))),
          const SizedBox(height: 12),
          FilledButton(
            key: const Key('authSubmit'),
            onPressed: a.busy ? null : () => a.submit(_mode, _email.text, _pass.text),
            child: Text(_mode == AuthMode.signIn ? s.t('signIn') : s.t('signUp')),
          ),
          TextButton(
            key: const Key('authToggle'),
            onPressed: () => setState(() => _mode = _mode == AuthMode.signIn ? AuthMode.signUp : AuthMode.signIn),
            child: Text(_mode == AuthMode.signIn ? s.t('toSignUp') : s.t('toSignIn')),
          ),
          TextButton(key: const Key('forgot'), onPressed: () => a.resetPassword(_email.text), child: Text(s.t('forgotPassword'))),
        ],
        if (a.errorCode != null)
          Text(s.t('auth_${a.errorCode}') == 'auth_${a.errorCode}' ? s.t('auth_OTHER') : s.t('auth_${a.errorCode}'),
              key: const Key('authError'), style: TextStyle(color: Colors.red.shade800)),
        if (a.info != null) Text(s.t(a.info!), key: const Key('authInfo')),
      ]),
    );
  }
}

