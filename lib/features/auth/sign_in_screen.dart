import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/router/app_router.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/avatar_circle.dart';
import '../../core/widgets/chips.dart';
import '../../core/widgets/states.dart';
import '../../data/db/seed_data.dart';
import '../../data/models/team_member.dart';
import '../../state/member_provider.dart';
import '../../state/session_provider.dart';
import 'pin_pad.dart';

/// Two-step sign in: (1) pick who you are (or type an email), (2) enter PIN.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen>
    with SingleTickerProviderStateMixin {
  TeamMember? _selected;
  bool _emailMode = false;
  String _pin = '';
  String? _error;
  bool _busy = false;
  Timer? _lockTimer;

  final _emailCtrl = TextEditingController();
  final _emailKey = GlobalKey<FormState>();

  // Shake animation for wrong PINs. Created eagerly in initState: a lazy
  // `late final` would first run inside dispose() if it was never used.
  late final AnimationController _shake;

  @override
  void initState() {
    super.initState();
    _shake = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    // If the lock is still running (e.g. user went back and returned), resume it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.read<SessionProvider>().isLocked) _startLockTimer();
    });
  }

  @override
  void dispose() {
    _lockTimer?.cancel();
    _shake.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  void _startLockTimer() {
    _lockTimer?.cancel();
    _lockTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      final locked = context.read<SessionProvider>().isLocked;
      setState(() {
        if (!locked) {
          t.cancel();
          _error = null;
        }
      });
    });
  }

  Future<void> _onDigit(String d) async {
    if (_busy || _pin.length >= 4) return;
    setState(() {
      _pin += d;
      _error = null;
    });
    if (_pin.length == 4) await _submit();
  }

  Future<void> _submit() async {
    final session = context.read<SessionProvider>();
    setState(() => _busy = true);
    final result = await session.signIn(_selected!, _pin);
    if (!mounted) return;
    switch (result) {
      case SignInResult.success:
        // The router redirect moves us to /home.
        break;
      case SignInResult.wrongPin:
        _shake.forward(from: 0);
        setState(() {
          _error =
              'Incorrect PIN. ${session.attemptsLeft} '
              '${session.attemptsLeft == 1 ? 'attempt' : 'attempts'} left.';
          _pin = '';
        });
      case SignInResult.locked:
        _shake.forward(from: 0);
        setState(() {
          _pin = '';
          _error = null;
        });
        _startLockTimer();
    }
    if (mounted) setState(() => _busy = false);
  }

  void _lookupEmail() {
    if (!(_emailKey.currentState?.validate() ?? false)) return;
    final email = _emailCtrl.text.trim().toLowerCase();
    final match = context
        .read<MemberProvider>()
        .members
        .where((m) => m.email.toLowerCase() == email)
        .firstOrNull;
    if (match == null) {
      setState(() => _error = 'No account found for that email.');
      return;
    }
    setState(() {
      _selected = match;
      _error = null;
    });
  }

  void _back() => setState(() {
    _selected = null;
    _pin = '';
    _error = null;
  });

  @override
  Widget build(BuildContext context) {
    final members = context.watch<MemberProvider>();
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _selected == null
                  ? _buildPicker(context, members)
                  : _buildPin(context),
            ),
          ),
        ),
      ),
    );
  }

  // ── Step 1 ────────────────────────────────────────────────────────────────
  Widget _buildPicker(BuildContext context, MemberProvider members) {
    final theme = Theme.of(context);
    if (members.isLoading) return const LoadingState();
    if (members.error != null) {
      return ErrorState(message: members.error!, onRetry: members.load);
    }
    return SingleChildScrollView(
      key: const ValueKey('picker'),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          Icon(Icons.track_changes, size: 48, color: theme.colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            _emailMode ? 'Sign in with email' : "Who's working today?",
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            _emailMode
                ? 'Enter the email you registered with.'
                : 'Pick your name to continue.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          if (_emailMode)
            ..._emailForm(context)
          else
            ..._memberGrid(context, members),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => setState(() {
              _emailMode = !_emailMode;
              _error = null;
            }),
            child: Text(
              _emailMode
                  ? 'Choose from the team instead'
                  : 'Sign in with email',
            ),
          ),
          TextButton(
            onPressed: () => context.go(Routes.signUp),
            child: const Text('New here? Create an account'),
          ),
        ],
      ),
    );
  }

  List<Widget> _memberGrid(BuildContext context, MemberProvider members) {
    final theme = Theme.of(context);
    return [
      Wrap(
        alignment: WrapAlignment.center,
        spacing: 16,
        runSpacing: 16,
        children: [
          for (final m in members.members)
            Semantics(
              button: true,
              label: 'Sign in as ${m.name}, ${m.jobTitle}',
              excludeSemantics: true,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => setState(() {
                  _selected = m;
                  _error = null;
                }),
                child: SizedBox(
                  width: 128,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      children: [
                        AvatarCircle.member(m, size: 64),
                        const SizedBox(height: 8),
                        Text(
                          m.firstName,
                          style: theme.textTheme.titleSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          m.jobTitle,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        RoleBadge(role: m.role),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: 24),
      _demoHint(context),
    ];
  }

  List<Widget> _emailForm(BuildContext context) => [
    Form(
      key: _emailKey,
      child: TextFormField(
        controller: _emailCtrl,
        keyboardType: TextInputType.emailAddress,
        autofillHints: const [AutofillHints.email],
        textInputAction: TextInputAction.done,
        decoration: const InputDecoration(
          labelText: 'Email',
          prefixIcon: Icon(Icons.mail_outline),
        ),
        validator: Validators.email,
        onFieldSubmitted: (_) => _lookupEmail(),
      ),
    ),
    if (_error != null)
      Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Text(
          _error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
    const SizedBox(height: 16),
    FilledButton(onPressed: _lookupEmail, child: const Text('Continue')),
    const SizedBox(height: 16),
    _demoHint(context),
  ];

  Widget _demoHint(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.info_outline,
            size: 18,
            color: theme.colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'Demo: PIN is ${DemoSeed.demoPin}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 2 ────────────────────────────────────────────────────────────────
  Widget _buildPin(BuildContext context) {
    final theme = Theme.of(context);
    final session = context.watch<SessionProvider>();
    final member = _selected!;
    final locked = session.isLocked;
    return SingleChildScrollView(
      key: const ValueKey('pin'),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              tooltip: 'Back',
              onPressed: _back,
              icon: const Icon(Icons.arrow_back),
            ),
          ),
          AvatarCircle.member(member, size: 80),
          const SizedBox(height: 12),
          Text(member.name, style: theme.textTheme.titleLarge),
          Text(
            member.jobTitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          Text(locked ? 'Too many attempts' : 'Enter your 4-digit PIN'),
          const SizedBox(height: 16),
          AnimatedBuilder(
            animation: _shake,
            builder: (_, child) {
              final t = _shake.value;
              final dx = math.sin(t * math.pi * 6) * 12 * (1 - t);
              return Transform.translate(offset: Offset(dx, 0), child: child);
            },
            child: PinDots(
              filled: _pin.length,
              error: _error != null || locked,
            ),
          ),
          SizedBox(
            height: 48,
            child: Center(
              child: locked
                  ? Text(
                      'Locked. Try again in ${session.lockRemaining.inSeconds + 1} s',
                      style: TextStyle(color: theme.colorScheme.error),
                    )
                  : _error != null
                  ? Semantics(
                      liveRegion: true,
                      child: Text(
                        _error!,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    )
                  : null,
            ),
          ),
          PinPad(
            enabled: !locked && !_busy,
            onDigit: _onDigit,
            onBackspace: () {
              if (_pin.isNotEmpty) {
                setState(() => _pin = _pin.substring(0, _pin.length - 1));
              }
            },
          ),
          const SizedBox(height: 16),
          _demoHint(context),
        ],
      ),
    );
  }
}
