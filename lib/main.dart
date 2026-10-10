import 'package:flutter/material.dart';
import 'models/member.dart';
import 'screens/home_shell.dart';
import 'screens/sign_in_screen.dart';
import 'services/storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final me = await Storage.getSession(); // stay logged in after restart
  runApp(TrackerApp(me: me));
}

class TrackerApp extends StatelessWidget {
  final Member? me;
  const TrackerApp({super.key, this.me});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'SLA Tracker',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: const Color(0xFF4F46E5),
          scaffoldBackgroundColor: const Color(0xFFF6F7FB),
        ),
        home: me == null ? const SignInScreen() : HomeShell(me: me!),
      );
}