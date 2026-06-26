import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../domain/auth_repository.dart';

/// Forced first-login password change for newly-created staff accounts.
class SetPasswordScreen extends ConsumerStatefulWidget {
  const SetPasswordScreen({super.key});

  @override
  ConsumerState<SetPasswordScreen> createState() => _SetPasswordScreenState();
}

class _SetPasswordScreenState extends ConsumerState<SetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final auth = ref.read(authRepositoryProvider);
      await auth.changePassword(
        currentPassword: _current.text,
        newPassword: _next.text,
      );
      await auth.markPasswordChanged();
      // Auth stream updates -> router redirects to the dashboard.
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Card(
              margin: const EdgeInsets.all(16),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.lock_reset,
                          size: 40, color: AppColors.teal),
                      const SizedBox(height: 12),
                      Text('Set your password',
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(color: AppColors.teal)),
                      const SizedBox(height: 4),
                      Text(
                        'Welcome${user != null ? ', ${user.displayName}' : ''}. '
                        'For security, please replace your temporary password.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 22),
                      _field(_current, 'Temporary password'),
                      _field(_next, 'New password', minLen: 6),
                      _field(_confirm, 'Confirm new password', match: _next),
                      if (_error != null) ...[
                        const SizedBox(height: 10),
                        Text(_error!,
                            style: const TextStyle(color: AppColors.error)),
                      ],
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _busy ? null : _submit,
                        child: _busy
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Text('Save & continue'),
                      ),
                      TextButton(
                        onPressed: () =>
                            ref.read(authRepositoryProvider).signOut(),
                        child: const Text('Sign out'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label,
      {int? minLen, TextEditingController? match}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        obscureText: true,
        decoration: InputDecoration(labelText: label),
        validator: (v) {
          if (v == null || v.isEmpty) return '$label is required';
          if (minLen != null && v.length < minLen) {
            return 'At least $minLen characters';
          }
          if (match != null && v != match.text) return 'Passwords do not match';
          return null;
        },
      ),
    );
  }
}
