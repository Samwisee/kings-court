/// Signing in, from the menu (platform/account.dart): Google or a
/// passkey; signed in, the name others see, another way in, signing out.
library;

import 'package:flutter/material.dart';

import '../../platform/account.dart';
import '../../skin/skin_scope.dart';

Future<void> showAccount(BuildContext context) => Navigator.of(context).push<void>(PageRouteBuilder(
      opaque: false,
      pageBuilder: (context, a, b) => const AccountSheet(),
      transitionsBuilder: (context, a, b, child) =>
          FadeTransition(opacity: CurvedAnimation(parent: a, curve: Curves.easeOut), child: child),
    ));

class AccountSheet extends StatefulWidget {
  const AccountSheet({super.key});

  @override
  State<AccountSheet> createState() => _AccountSheetState();
}

class _AccountSheetState extends State<AccountSheet> {
  late final _name = TextEditingController(text: Account.me.value?.name ?? '');
  bool _busy = false;
  bool _making = false;
  String? _said;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _do(Future<String?> Function() job, {String? done}) async {
    setState(() {
      _busy = true;
      _said = null;
    });
    final err = await job();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _said = err ?? done;
      if (err == null) {
        _making = false;
        _name.text = Account.me.value?.name ?? _name.text;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return ValueListenableBuilder<Me?>(
      valueListenable: Account.me,
      builder: (context, me, _) => Scaffold(
        backgroundColor: skin.feltDeep,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      Expanded(child: Text(me == null ? 'Sign in' : 'Your account', style: skin.dialogTitle)),
                      IconButton(
                        key: const ValueKey('accountClose'),
                        tooltip: 'Close',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    ...me == null ? _signedOut(context) : _signedIn(context, me),
                    if (_said != null) ...[
                      const SizedBox(height: 14),
                      Text(_said!, key: const ValueKey('accountSaid'), style: skin.dialogBody),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _signedOut(BuildContext context) {
    final skin = context.skin;
    final passkeys = Account.passkeys;
    return [
      Text('You never need an account to play. Signing in keeps the looks you own and wear '
          'on every device you play on.', style: skin.dialogNote),
      const SizedBox(height: 18),
      if (Account.google) ...[
        FilledButton.icon(
          key: const ValueKey('signInGoogle'),
          onPressed: _busy ? null : Account.signInWithGoogle,
          icon: const Icon(Icons.login_rounded),
          label: const Text('Continue with Google'),
        ),
        const SizedBox(height: 10),
      ],
      if (passkeys) ...[
        OutlinedButton.icon(
          key: const ValueKey('signInPasskey'),
          onPressed: _busy ? null : () => _do(Account.signInWithPasskey),
          icon: const Icon(Icons.key_rounded),
          label: const Text('Sign in with a passkey'),
        ),
        const SizedBox(height: 18),
        if (!_making)
          TextButton(
            key: const ValueKey('newPasskey'),
            onPressed: _busy ? null : () => setState(() => _making = true),
            child: const Text('New here? Make a passkey'),
          )
        else ...[
          Text('A passkey signs you in with your fingerprint, face or screen lock. '
              'No password, and no email address.', style: skin.dialogNote),
          const SizedBox(height: 10),
          TextField(
            key: const ValueKey('accountName'),
            controller: _name,
            autofocus: true,
            maxLength: Account.nameMax,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Your name at the table'),
            onChanged: (_) => setState(() {}),
          ),
          FilledButton(
            key: const ValueKey('makePasskey'),
            onPressed: _busy || _name.text.trim().isEmpty ? null : () => _do(() => Account.makePasskey(name: _name.text)),
            child: Text(_busy ? 'Making it…' : 'Make my passkey'),
          ),
        ],
      ] else if (!Account.google)
        Text('This browser can’t use passkeys.', style: skin.dialogBody),
    ];
  }

  List<Widget> _signedIn(BuildContext context, Me me) {
    final skin = context.skin;
    final ways = [if (me.hasGoogle) 'Google', if (me.hasPasskey) 'a passkey'];
    return [
      Text('Signed in${ways.isEmpty ? '' : ' with ${ways.join(' and ')}'}.', style: skin.dialogNote),
      const SizedBox(height: 14),
      TextField(
        key: const ValueKey('accountName'),
        controller: _name,
        maxLength: Account.nameMax,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(labelText: 'Your name at the table'),
        onChanged: (_) => setState(() {}),
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: FilledButton(
          key: const ValueKey('saveName'),
          onPressed: _busy || _name.text.trim().isEmpty || _name.text.trim() == me.name
              ? null
              : () => _do(() => Account.rename(_name.text), done: 'Saved'),
          child: const Text('Save'),
        ),
      ),
      const SizedBox(height: 18),
      if (!me.hasPasskey && Account.passkeys) ...[
        OutlinedButton.icon(
          key: const ValueKey('addPasskey'),
          onPressed: _busy ? null : () => _do(Account.makePasskey, done: 'Passkey added'),
          icon: const Icon(Icons.key_rounded),
          label: const Text('Add a passkey'),
        ),
        const SizedBox(height: 10),
      ],
      OutlinedButton.icon(
        key: const ValueKey('signOut'),
        onPressed: _busy ? null : () => _do(() async {
          await Account.signOut();
          return null;
        }, done: 'Signed out'),
        icon: const Icon(Icons.logout_rounded),
        label: const Text('Sign out'),
      ),
    ];
  }
}
