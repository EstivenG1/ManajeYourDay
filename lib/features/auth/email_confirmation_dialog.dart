import 'package:flutter/material.dart';

import '../../core/localization/app_text.dart';
import '../../core/theme/app_theme.dart';

class EmailConfirmationDialog extends StatelessWidget {
  final String email;

  const EmailConfirmationDialog({super.key, required this.email});

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
                  child: Icon(
                    Icons.mark_email_read_rounded,
                    color: AppColors.goldDeep,
                    size: 32,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                appText(
                  context,
                  '¡Tu cuenta casi está lista!',
                  'Your account is almost ready!',
                ),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                appText(
                  context,
                  'Confirma tu correo para poder ingresar a MYD.',
                  'Confirm your email to sign in to MYD.',
                ),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: AppColors.textSecondary, height: 1.45),
              ),
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
                        email,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _PasoConfirmacion(
                numero: '1',
                texto: appText(
                  context,
                  'Ve al correo de la cuenta que ingresaste.',
                  'Open the inbox for the email address you entered.',
                ),
              ),
              _PasoConfirmacion(
                numero: '2',
                texto: appText(
                  context,
                  'Busca el correo de confirmación de cuenta de MYD. Si no aparece, revisa Spam o Promociones.',
                  'Find the MYD account confirmation email. If it is missing, check Spam or Promotions.',
                ),
              ),
              _PasoConfirmacion(
                numero: '3',
                texto: appText(
                  context,
                  'Abre el enlace de confirmación desde cualquier dispositivo con navegador. No necesitas tener MYD instalada en ese dispositivo.',
                  'Open the confirmation link on any device with a browser. MYD does not need to be installed there.',
                ),
              ),
              _PasoConfirmacion(
                numero: '4',
                texto: appText(
                  context,
                  'Vuelve a MYD e inicia sesión con tu correo y contraseña.',
                  'Return to MYD and sign in with your email and password.',
                ),
              ),
              const SizedBox(height: 14),
              FilledButton(
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

class _PasoConfirmacion extends StatelessWidget {
  final String numero;
  final String texto;

  const _PasoConfirmacion({required this.numero, required this.texto});

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
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                texto,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: AppColors.textSecondary, height: 1.4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
