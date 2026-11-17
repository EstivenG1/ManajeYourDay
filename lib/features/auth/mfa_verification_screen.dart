import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/localization/app_text.dart';
import '../../core/supabase/supabase_config.dart';
import '../../core/theme/app_theme.dart';

class MfaVerificationScreen extends StatefulWidget {
  final String factorId;
  final VoidCallback onVerified;

  const MfaVerificationScreen({
    super.key,
    required this.factorId,
    required this.onVerified,
  });

  @override
  State<MfaVerificationScreen> createState() => _MfaVerificationScreenState();
}

class _MfaVerificationScreenState extends State<MfaVerificationScreen> {
  final _codeController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = _codeController.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() {
        _error = appText(
          context,
          'Escribe el código de 6 dígitos de tu app autenticadora.',
          'Enter the 6-digit code from your authenticator app.',
        );
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final challenge = await supabase.auth.mfa.challenge(
        factorId: widget.factorId,
      );
      await supabase.auth.mfa.verify(
        factorId: widget.factorId,
        challengeId: challenge.id,
        code: code,
      );
      widget.onVerified();
    } on AuthException catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = appText(
            context,
            'No se pudo verificar el código: ${error.message}',
            'The code could not be verified: ${error.message}',
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(
                        Icons.verified_user_outlined,
                        color: AppColors.goldDeep,
                        size: 56,
                      ),
                      const SizedBox(height: 18),
                      Text(
                        appText(
                          context,
                          'Verificación en dos pasos',
                          'Two-step verification',
                        ),
                        textAlign: TextAlign.center,
                        style: AppTypography.screenTitle,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        appText(
                          context,
                          'Abre tu app autenticadora y escribe el código de 6 dígitos para continuar.',
                          'Open your authenticator app and enter the 6-digit code to continue.',
                        ),
                        textAlign: TextAlign.center,
                        style: AppTypography.secondary,
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _codeController,
                        autofocus: true,
                        enabled: !_loading,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          labelText: appText(context, 'Código', 'Code'),
                          errorText: _error,
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _loading ? null : _verify,
                        child: _loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                appText(
                                  context,
                                  'Verificar y continuar',
                                  'Verify and continue',
                                ),
                              ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        appText(
                          context,
                          'MYD nunca te pedirá este código por correo, chat o teléfono.',
                          'MYD will never ask for this code by email, chat, or phone.',
                        ),
                        textAlign: TextAlign.center,
                        style: AppTypography.secondary,
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
}
