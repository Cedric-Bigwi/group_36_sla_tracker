import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/utils/ui_helpers.dart';
import '../../core/utils/validators.dart';
import '../../state/member_provider.dart';
import '../../state/session_provider.dart';

/// Edit own name / job title and (optionally) change the PIN.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _job;
  final _oldPin = TextEditingController();
  final _newPin = TextEditingController();
  final _confirmPin = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<SessionProvider>().user;
    _name = TextEditingController(text: user?.name);
    _job = TextEditingController(text: user?.jobTitle);
  }

  @override
  void dispose() {
    for (final c in [_name, _job, _oldPin, _newPin, _confirmPin]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _changingPin =>
      _oldPin.text.isNotEmpty ||
      _newPin.text.isNotEmpty ||
      _confirmPin.text.isNotEmpty;

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final members = context.read<MemberProvider>();
    final session = context.read<SessionProvider>();
    final me = session.user!;
    setState(() => _saving = true);
    final ok = await runAction(context, () async {
      // PIN first: if the old PIN is wrong nothing else is saved.
      if (_changingPin) await members.changeOwnPin(_oldPin.text, _newPin.text);
      final current = session.user ?? me;
      await members.update(
        current.copyWith(name: _name.text.trim(), jobTitle: _job.text.trim()),
      );
    }, success: 'Profile updated');
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) context.pop();
  }

  static final _digits = [
    FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(4),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Full name'),
                  validator: Validators.name,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _job,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Job title'),
                  validator: (v) => Validators.required(v, 'Job title'),
                ),
                const SizedBox(height: 24),
                Text('Change PIN', style: theme.textTheme.titleMedium),
                Text(
                  'Leave blank to keep your current PIN.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _oldPin,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: _digits,
                  decoration: const InputDecoration(labelText: 'Current PIN'),
                  validator: (v) => _changingPin ? Validators.pin(v) : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _newPin,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: _digits,
                  decoration: const InputDecoration(labelText: 'New PIN'),
                  validator: (v) => _changingPin ? Validators.pin(v) : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmPin,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: _digits,
                  decoration: const InputDecoration(
                    labelText: 'Confirm new PIN',
                  ),
                  validator: (v) => _changingPin
                      ? Validators.confirmPin(v, _newPin.text)
                      : null,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : const Text('Save changes'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
