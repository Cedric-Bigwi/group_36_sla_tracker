import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/router/app_router.dart';
import '../../core/utils/ui_helpers.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/states.dart';
import '../../data/models/enums.dart';
import '../../data/models/team_member.dart';
import '../../domain/permissions.dart';
import '../../state/member_provider.dart';
import '../../state/session_provider.dart';

/// One form for three jobs:
///  * `signUp: true`   – public self sign-up (Member role only, then signs in)
///  * no [memberId]    – a manager adds a member
///  * with [memberId]  – edit an existing member
class MemberFormScreen extends StatefulWidget {
  const MemberFormScreen({super.key, this.memberId, this.signUp = false});

  final String? memberId;
  final bool signUp;

  @override
  State<MemberFormScreen> createState() => _MemberFormScreenState();
}

class _MemberFormScreenState extends State<MemberFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _job = TextEditingController();
  final _pin = TextEditingController();
  final _confirm = TextEditingController();
  MemberRole _role = MemberRole.member;
  bool _saving = false;
  bool _loaded = false;
  TeamMember? _existing;

  bool get _isEdit => widget.memberId != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    if (_isEdit) {
      _existing = context.read<MemberProvider>().byId(widget.memberId);
      final m = _existing;
      if (m != null) {
        _name.text = m.name;
        _email.text = m.email;
        _job.text = m.jobTitle;
        _role = m.role;
      }
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _email, _job, _pin, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final members = context.read<MemberProvider>();
    final session = context.read<SessionProvider>();
    final router = GoRouter.of(context);

    TeamMember? created;
    final ok = await runAction(
      context,
      () async {
        if (_isEdit) {
          await members.update(
            _existing!.copyWith(
              name: _name.text.trim(),
              email: _email.text.trim().toLowerCase(),
              jobTitle: _job.text.trim(),
              role: _role,
            ),
          );
        } else {
          created = await members.create(
            name: _name.text,
            email: _email.text,
            jobTitle: _job.text,
            role: widget.signUp ? MemberRole.member : _role,
            pin: _pin.text,
          );
        }
      },
      success: _isEdit
          ? 'Member updated'
          : (widget.signUp ? null : 'Member added'),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (!ok) return;
    if (widget.signUp && created != null) {
      await session.startSession(created!); // router redirects to /home
    } else if (router.canPop()) {
      router.pop();
    } else {
      router.go(Routes.team);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<SessionProvider>().user;
    if (_isEdit && _existing == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(
          icon: Icons.person_off_outlined,
          title: 'Member not found',
          message: 'They may have been removed.',
        ),
      );
    }
    // Public sign-up can't see managers' powers; add/edit require them (edit
    // also allowed for yourself, but then the role stays locked).
    if (!widget.signUp && !_isEdit && !Permissions.canManageMembers(me)) {
      return Scaffold(
        appBar: AppBar(title: const Text('Add member')),
        body: const EmptyState(
          icon: Icons.lock_outline,
          title: 'Managers only',
          message: 'Only managers can add team members.',
        ),
      );
    }
    final canPickRole = !widget.signUp && Permissions.canManageMembers(me);
    final title = widget.signUp
        ? 'Create account'
        : (_isEdit ? 'Edit member' : 'Add member');

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: widget.signUp
            ? IconButton(
                tooltip: 'Back to sign in',
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go(Routes.signIn),
              )
            : null,
      ),
      body: SafeArea(
        child: Center(
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
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'Full name'),
                    validator: Validators.name,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator: Validators.email,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _job,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Job title',
                      hintText: 'e.g. UI/UX Designer',
                    ),
                    validator: (v) => Validators.required(v, 'Job title'),
                  ),
                  const SizedBox(height: 16),
                  Text('Role', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  SegmentedButton<MemberRole>(
                    segments: [
                      const ButtonSegment(
                        value: MemberRole.member,
                        label: Text('Member'),
                        icon: Icon(Icons.person_outline),
                      ),
                      ButtonSegment(
                        value: MemberRole.manager,
                        label: const Text('Manager'),
                        icon: const Icon(Icons.shield_outlined),
                        // Only managers can create managers.
                        enabled:
                            Permissions.canCreateRole(me, MemberRole.manager) &&
                            canPickRole,
                      ),
                    ],
                    selected: {widget.signUp ? MemberRole.member : _role},
                    onSelectionChanged: canPickRole
                        ? (s) => setState(() => _role = s.first)
                        : null,
                  ),
                  if (widget.signUp)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'New accounts are created as Members. A manager can promote you.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  if (!_isEdit) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _pin,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                      ],
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: '4-digit PIN',
                      ),
                      validator: Validators.pin,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirm,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Confirm PIN',
                      ),
                      validator: (v) => Validators.confirmPin(v, _pin.text),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            _isEdit
                                ? 'Save changes'
                                : (widget.signUp
                                      ? 'Create account'
                                      : 'Add member'),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
