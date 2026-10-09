import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';

/// Botón "Registra tus finanzas y tareas en WhatsApp". Abre el chat de
/// WhatsApp del número de negocio de MYD, con "/login" ya escrito, así
/// el asistente arranca el flujo de vinculación de una vez.
class BotonWhatsapp extends StatelessWidget {
  // Reemplaza esto por el número real de tu WhatsApp Business, en
  // formato internacional SIN "+" ni espacios (ej: "573001234567").
  static const _numeroNegocio = '15551588244';

  const BotonWhatsapp({super.key});

  Future<void> _abrirWhatsapp() async {
    final uri = Uri.parse('https://wa.me/$_numeroNegocio?text=%2Flogin');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadii.xl2),
      onTap: _abrirWhatsapp,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF25D366), Color(0xFF128C7E)]),
          borderRadius: BorderRadius.circular(AppRadii.xl2),
          boxShadow: AppColors.sombraPremium(const Color(0xFF25D366)),
        ),
        child: Row(
          children: [
            const Text('💬', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Registra tus finanzas y tareas en WhatsApp',
                      style: AppTypography.itemTitle.copyWith(color: Colors.white, fontSize: 13.5)),
                  const SizedBox(height: 2),
                  Text('Escríbele al asistente de MYD',
                      style: AppTypography.secondary.copyWith(color: Colors.white70, fontSize: 11)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }
}
