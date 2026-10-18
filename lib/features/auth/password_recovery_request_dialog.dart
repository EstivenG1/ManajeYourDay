import 'package:flutter/material.dart';

import '../../core/auth/auth_errors.dart';
import '../../core/localization/app_text.dart';
import '../../core/theme/app_theme.dart';

class PasswordRecoveryRequestDialog extends StatefulWidget {
  final String initialEmail;
  final Future<void> Function(String email) onSend;

  const PasswordRecoveryRequestDialog({
    super.key,
    this.initialEmail = '',
    required this.onSend,
  });

  @override
  State<PasswordRecoveryRequestDialog> createState() =>
      _PasswordRecoveryRequestDialogState();
}

class _PasswordRecoveryRequestDialogState
    extends State<PasswordRecoveryRequestDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _emailController = TextEditingController(
    text: widget.initialEmail,
  );
  bool _loading = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await widget.onSend(_emailController.text.trim());
      if (mounted) setState(() => _sent = true);
    } catch (error) {
      if (mounted) {
        setState(() => _error = mensajeErrorAuth(error));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: Icon(Icons.lock_reset_rounded, color: AppColors.goldDeep),
      title: Text(
        appText(context, 'Recuperar contraseña', 'Reset password'),
      ),
      content: _sent ? _successContent(context) : _requestContent(context),
      actions: _sent
          ? [
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(appText(context, 'Entendido', 'Got it')),
              ),
            ]
          : [
              TextButton(
                onPressed: _loading ? null : () => Navigator.of(context).pop(),
                child: Text(appText(context, 'Cancelar', 'Cancel')),
              ),
              FilledButton(
                onPressed: _loading ? null : _send,
                child: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(appText(context, 'Enviar enlace', 'Send link')),
              ),
            ],
    );
  }

  Widget _requestContent(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            appText(
              context,
              'Ingresa el correo de tu cuenta y te enviaremos un enlace para restablecer tu contraseña.',
              'Enter your account email and we will send you a password reset link.',
            ),
          ),
          const SizedBox(height: 18),
          TextFormField(
            key: const ValueKey('recovery-email'),
            controller: _emailController,
            autofocus: true,
            enabled: !_loading,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: appText(
                context,
                'Correo de tu cuenta',
                'Account email',
              ),
              hintText: 'tu@email.com',
            ),
            validator: (value) {
              final email = value?.trim() ?? '';
              if (!RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$').hasMatch(email)) {
                return appText(
                  context,
                  'Ingresa un correo válido.',
                  'Enter a valid email address.',
                );
              }
              return null;
            },
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }

  Widget _successContent(BuildContext context) {
    return Text(
      appText(
        context,
        'Si la cuenta existe, recibirás un correo con los pasos para cambiar tu contraseña.',
        'If the account exists, you will receive an email with steps to change your password.',
      ),
    );
  }
}
