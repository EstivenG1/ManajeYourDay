import 'package:flutter/material.dart';

import '../../core/localization/app_text.dart';
import '../../core/theme/app_theme.dart';

class EmailChangeRequestDialog extends StatefulWidget {
  final String initialEmail;

  const EmailChangeRequestDialog({super.key, required this.initialEmail});

  @override
  State<EmailChangeRequestDialog> createState() =>
      _EmailChangeRequestDialogState();
}

class _EmailChangeRequestDialogState extends State<EmailChangeRequestDialog> {
  late final TextEditingController _emailController;
  late final TextEditingController _confirmationController;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
    _confirmationController = TextEditingController();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  void _continue() {
    final email = _emailController.text.trim();
    if (!_isValidEmail(email) || email != _confirmationController.text.trim()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            appText(
              context,
              'Escribe un correo válido y confírmalo correctamente.',
              'Enter a valid email address and confirm it correctly.',
            ),
          ),
        ),
      );
      return;
    }

    Navigator.of(context).pop(email);
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$').hasMatch(email);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        appText(context, 'Cambiar dirección de correo', 'Change email address'),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: appText(context, 'Nuevo correo', 'New email'),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _confirmationController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: appText(
                context,
                'Confirmar nuevo correo',
                'Confirm new email',
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(appText(context, 'Cancelar', 'Cancel')),
        ),
        FilledButton(
          onPressed: _continue,
          child: Text(appText(context, 'Continuar', 'Continue')),
        ),
      ],
    );
  }
}

class EmailChangeConfirmationDialog extends StatelessWidget {
  final String email;

  const EmailChangeConfirmationDialog({super.key, required this.email});

  @override
  Widget build(BuildContext context) {
    return _PerfilMessageDialog(
      icon: Icons.mark_email_read_rounded,
      title: appText(
        context,
        'Confirma el cambio de correo',
        'Confirm email change',
      ),
      description: appText(
        context,
        'Te enviamos mensajes de confirmación al correo actual y al nuevo. Puedes abrir los enlaces desde cualquier dispositivo con navegador.',
        'We sent confirmation messages to your current and new email addresses. You can open the links on any device with a browser.',
      ),
      highlightedText: email,
      steps: [
        appText(
          context,
          'Revisa las bandejas de entrada del correo actual y del nuevo.',
          'Check the inboxes for both your current and new email addresses.',
        ),
        appText(
          context,
          'Abre el enlace de confirmación de ambos mensajes. No necesitas tener MYD instalada en ese dispositivo.',
          'Open the confirmation link in both messages. MYD does not need to be installed on that device.',
        ),
        appText(
          context,
          'Cuando ambos correos estén confirmados, inicia sesión con la dirección nueva.',
          'After both emails are confirmed, sign in with your new address.',
        ),
      ],
    );
  }
}

class PasswordChangedDialog extends StatelessWidget {
  const PasswordChangedDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return _PerfilMessageDialog(
      icon: Icons.lock_reset_rounded,
      title: appText(context, 'Contraseña actualizada', 'Password updated'),
      description: appText(
        context,
        'Tu contraseña se cambió correctamente. Usa la nueva contraseña la próxima vez que inicies sesión.',
        'Your password was updated. Use the new password the next time you sign in.',
      ),
      steps: [
        appText(
          context,
          'No compartas tu contraseña con otras personas.',
          'Do not share your password with anyone else.',
        ),
        appText(
          context,
          'Si no reconoces este cambio, restablece tu contraseña y revisa la seguridad de tu cuenta.',
          'If you do not recognize this change, reset your password and review your account security.',
        ),
      ],
    );
  }
}

class InviteUsersDialog extends StatelessWidget {
  final VoidCallback onShare;

  const InviteUsersDialog({super.key, required this.onShare});

  @override
  Widget build(BuildContext context) {
    return _PerfilMessageDialog(
      icon: Icons.person_add_alt_1_rounded,
      title: appText(
        context,
        'Invita a alguien a MYD',
        'Invite someone to MYD',
      ),
      description: appText(
        context,
        'Comparte MYD con una persona de confianza para que también pueda organizar sus tareas, finanzas y metas.',
        'Share MYD with someone you trust so they can organize tasks, finances, and goals too.',
      ),
      steps: [
        appText(
          context,
          'La invitación abre la versión web oficial de MYD.',
          'The invitation opens the official MYD web app.',
        ),
        appText(
          context,
          'No compartiremos tus datos ni los de la persona invitada.',
          'We will not share your data or the invited person’s data.',
        ),
      ],
      actionLabel: appText(context, 'Compartir invitación', 'Share invite'),
      onAction: onShare,
    );
  }
}

class MfaMethodAddedDialog extends StatelessWidget {
  const MfaMethodAddedDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return _PerfilMessageDialog(
      icon: Icons.verified_user_rounded,
      title: appText(context, 'MFA activado', 'MFA enabled'),
      description: appText(
        context,
        'Se agregó una app autenticadora a tu cuenta. MYD pedirá un código al iniciar sesión desde una sesión que aún no esté verificada.',
        'An authenticator app was added to your account. MYD will ask for a code when signing in from a session that is not verified yet.',
      ),
      steps: [
        appText(
          context,
          'Guarda el acceso a tu app autenticadora.',
          'Keep access to your authenticator app.',
        ),
        appText(
          context,
          'No compartas códigos de verificación.',
          'Do not share verification codes.',
        ),
      ],
    );
  }
}

class MfaMethodRemovedDialog extends StatelessWidget {
  const MfaMethodRemovedDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return _PerfilMessageDialog(
      icon: Icons.gpp_maybe_outlined,
      title: appText(context, 'MFA desactivado', 'MFA disabled'),
      description: appText(
        context,
        'Se eliminó el método de autenticación de dos pasos de tu cuenta.',
        'The two-step authentication method was removed from your account.',
      ),
      steps: [
        appText(
          context,
          'Puedes volver a activarlo cuando quieras desde Perfil.',
          'You can enable it again anytime from Profile.',
        ),
        appText(
          context,
          'Si no reconoces este cambio, cambia tu contraseña de inmediato.',
          'If you do not recognize this change, change your password immediately.',
        ),
      ],
    );
  }
}

class _PerfilMessageDialog extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String? highlightedText;
  final List<String> steps;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _PerfilMessageDialog({
    required this.icon,
    required this.title,
    required this.description,
    this.highlightedText,
    required this.steps,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(color: AppColors.borderSoft),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.goldSoftBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: AppColors.goldDeep, size: 32),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                description,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: AppColors.textSecondary, height: 1.45),
              ),
              if (highlightedText != null) ...[
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.goldSoftBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.goldBorder),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.alternate_email_rounded,
                        color: AppColors.goldDeep,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          highlightedText!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              for (var index = 0; index < steps.length; index++)
                _PasoPerfil(numero: '${index + 1}', texto: steps[index]),
              const SizedBox(height: 14),
              if (actionLabel != null)
                FilledButton(onPressed: onAction, child: Text(actionLabel!)),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(appText(context, 'Entendido', 'Got it')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PasoPerfil extends StatelessWidget {
  final String numero;
  final String texto;

  const _PasoPerfil({required this.numero, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.goldChipBg,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.goldBorder),
            ),
            child: Text(
              numero,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppColors.goldDeep,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                texto,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: AppColors.textPrimary, height: 1.35),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
