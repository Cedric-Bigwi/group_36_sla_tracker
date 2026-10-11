import 'package:flutter/material.dart';
import '../services/seed_data.dart';
import '../services/storage.dart';
import 'home_shell.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});
  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _form = GlobalKey<FormState>();
  final _user = TextEditingController();
  final _pass = TextEditingController();
  bool _hide = true;
  String? _error;

  Future<void> _login() async {
    setState(() => _error = null);
    if (!_form.currentState!.validate()) return;
    final me = SeedData.login(_user.text, _pass.text);
    if (me == null) {
      setState(() => _error = 'Invalid username or password');
      return;
    }
    await Storage.setSession(me.username);
    if (!mounted) return;
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => HomeShell(me: me)));
  }

  InputDecoration _dec(String label, IconData icon, {Widget? suffix}) =>
      InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Form(
              key: _form,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SizedBox(height: 32),
                const Icon(Icons.task_alt, size: 56, color: Color(0xFF4F46E5)),
                const SizedBox(height: 16),
                const Text('SLA Tracker',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                Text('Sign in to your team.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _user,
                  decoration: _dec('Username', Icons.person_outline),
                  validator: (v) =>
                      (v?.trim().isEmpty ?? true) ? 'Enter your username' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _pass,
                  obscureText: _hide,
                  decoration: _dec('Password', Icons.lock_outline,
                      suffix: IconButton(
                          icon: Icon(_hide ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _hide = !_hide))),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter your password';
                    if (v.length < 4) return 'Password is too short';
                    return null;
                  },
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(_error!, style: const TextStyle(color: Colors.red)),
                  ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(onPressed: _login, child: const Text('Sign in')),
                ),
                const SizedBox(height: 16),
                ExpansionTile(
                  title: const Text('Demo accounts (tap to fill)'),
                  children: SeedData.members
                      .map((m) => ListTile(
                            dense: true,
                            leading: CircleAvatar(radius: 14, child: Text(m.name[0])),
                            title: Text('${m.name}${m.isCaptain ? '  ★ captain' : ''}'),
                            subtitle: Text('${m.team} · ${m.username} / ${m.password}'),
                            onTap: () => setState(() {
                              _user.text = m.username;
                              _pass.text = m.password;
                            }),
                          ))
                      .toList(),
                ),
              ]),
            ),
          ),
        ),
      );
}
