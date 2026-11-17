import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/auth/auth_errors.dart';
import '../../core/localization/app_text.dart';
import '../../core/supabase/supabase_config.dart';
import '../../core/theme/app_theme.dart';

class PasswordRecoveryScreen extends StatefulWidget {
  final VoidCallback onCompleted;
  final Future<void> Function(String password)? updatePassword;

  const PasswordRecoveryScreen({
    super.key,
    required this.onCompleted,
    this.updatePassword,
  });

  @override
  State<PasswordRecoveryScreen> createState() => _PasswordRecoveryScreenState();
}

class _PasswordRecoveryScreenState extends State<PasswordRecoveryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _mfaCodeController = TextEditingController();

  bool _loading = false;
  bool _completed = false;
  bool _mfaLoading = true;
  String? _mfaFactorId;
  String? _mfaError;

  @override
  void initState() {
    super.initState();
    if (widget.updatePassword == null) {
      _loadMfaFactor();
    } else {
      _mfaLoading = false;
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _mfaCodeController.dispose();
    super.dispose();
  }

  Future<void> _loadMfaFactor() async {
    try {
      final factors = await supabase.auth.mfa.listFactors();
      if (!mounted) return;
      setState(() {
        _mfaFactorId = factors.totp
            .where((factor) => factor.status == FactorStatus.verified)
            .firstOrNull
            ?.id;
        _mfaLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _mfaLoading = false;
        _mfaError = mensajeErrorAuth(error);
      });
    }
  }

  Future<void> _savePassword() async {
    if (!_formKey.currentState!.validate()) return;
    if (_mfaLoading) return;
    if (_mfaError != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_mfaError!)));
      return;
    }
    final mfaCode = _mfaCodeController.text.trim();
    if (_mfaFactorId != null && !RegExp(r'^\d{6}$').hasMatch(mfaCode)) {
      setState(() {});
      return;
    }
    setState(() => _loading = true);

    try {
      if (_mfaFactorId != null) {
        final challenge = await supabase.auth.mfa.challenge(
          factorId: _mfaFactorId!,
        );
        await supabase.auth.mfa.verify(
          factorId: _mfaFactorId!,
          challengeId: challenge.id,
          code: mfaCode,
        );
      }
      final updatePassword =
          widget.updatePassword ??
          (password) async {
            await supabase.auth.updateUser(UserAttributes(password: password));
          };
      await updatePassword(_passwordController.text);
      if (!mounted) return;
      setState(() => _completed = true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(mensajeErrorAuth(error))));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: Text(appText(context, 'Recuperar contraseña', 'Reset password')),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: _completed
                  ? _successContent(context)
                  : _formContent(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _formContent(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.lock_reset_rounded, size: 56, color: AppColors.goldDeep),
          const SizedBox(height: 18),
          Text(
            appText(
              context,
              'Crea una nueva contraseña',
              'Create a new password',
            ),
            textAlign: TextAlign.center,
            style: AppTypography.screenTitle,
          ),
          const SizedBox(height: 8),
          Text(
            appText(
              context,
              'Elige una contraseña nueva para volver a entrar a tu cuenta.',
              'Choose a new password to get back into your account.',
            ),
            textAlign: TextAlign.center,
            style: AppTypography.secondary,
          ),
          const SizedBox(height: 28),
          TextFormField(
            key: const ValueKey('new-password'),
            controller: _passwordController,
            obscureText: true,
            enabled: !_loading,
            decoration: InputDecoration(
              labelText: appText(context, 'Nueva contraseña', 'New password'),
            ),
            validator: (value) {
              if (value == null || value.length < 6) {
                return appText(
                  context,
                  'La contraseña debe tener al menos 6 caracteres.',
                  'Password must contain at least 6 characters.',
                );
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            key: const ValueKey('confirm-password'),
            controller: _confirmPasswordController,
            obscureText: true,
            enabled: !_loading,
            decoration: InputDecoration(
              labelText: appText(
                context,
                'Confirmar contraseña',
                'Confirm password',
              ),
            ),
            validator: (value) {
              if (value != _passwordController.text) {
                return appText(
                  context,
                  'Las contraseñas no coinciden.',
                  'Passwords do not match.',
                );
              }
              return null;
            },
          ),
          if (_mfaLoading) ...[
            const SizedBox(height: 16),
            const Center(child: CircularProgressIndicator()),
          ],
          if (_mfaFactorId != null) ...[
            const SizedBox(height: 16),
            TextFormField(
              key: const ValueKey('recovery-mfa-code'),
              controller: _mfaCodeController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              enabled: !_loading,
              decoration: InputDecoration(
                labelText: appText(context, 'Código MFA', 'MFA code'),
                helperText: appText(
                  context,
                  'Confirma tu identidad antes de cambiar la contraseña.',
                  'Confirm your identity before changing the password.',
                ),
              ),
              validator: (value) {
                if (!RegExp(r'^\d{6}$').hasMatch(value?.trim() ?? '')) {
                  return appText(
                    context,
                    'Escribe el código de 6 dígitos de tu autenticador.',
                    'Enter the 6-digit code from your authenticator.',
                  );
                }
                return null;
              },
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _loading ? null : _savePassword,
            child: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(appText(context, 'Guardar contraseña', 'Save password')),
          ),
        ],
      ),
    );
  }

  Widget _successContent(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.check_circle_outline_rounded,
          size: 56,
          color: AppColors.green,
        ),
        const SizedBox(height: 18),
        Text(
          appText(context, 'Contraseña actualizada', 'Password updated'),
          textAlign: TextAlign.center,
          style: AppTypography.screenTitle,
        ),
        const SizedBox(height: 8),
        Text(
          appText(
            context,
            'Tu contraseña fue actualizada. Continúa para iniciar sesión con ella.',
            'Your password was updated. Continue to sign in with it.',
          ),
          textAlign: TextAlign.center,
          style: AppTypography.secondary,
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: widget.onCompleted,
            child: Text(appText(context, 'Continuar', 'Continue')),
          ),
        ),
      ],
    );
  }
}
