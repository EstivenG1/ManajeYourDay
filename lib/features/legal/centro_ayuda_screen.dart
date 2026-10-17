import 'package:flutter/material.dart';

import '../../core/localization/app_text.dart';
import '../../core/theme/app_theme.dart';
import 'legal_info_screen.dart';

class CentroAyudaScreen extends StatelessWidget {
  final Future<void> Function()? onReplayTour;

  const CentroAyudaScreen({super.key, this.onReplayTour});

  static final _guias = [
    _HelpGuide(
      titleEs: 'Inicio',
      titleEn: 'Home',
      descriptionEs: 'Consulta balance, actividad semanal, metas de ahorro y tareas prioritarias en un solo lugar.',
      descriptionEn: 'Review your balance, weekly activity, savings goals, and priority tasks in one place.',
      icon: Icons.home_rounded,
      color: AppColors.gold,
    ),
    _HelpGuide(
      titleEs: 'Finanzas',
      titleEn: 'Finance',
      descriptionEs: 'Registra ingresos y gastos, organiza presupuestos y consulta tus metas de ahorro.',
      descriptionEn: 'Record income and expenses, manage budgets, and review savings goals.',
      icon: Icons.account_balance_wallet_rounded,
      color: AppColors.green,
    ),
    _HelpGuide(
      titleEs: 'Tareas',
      titleEn: 'Tasks',
      descriptionEs: 'Crea tareas, asigna prioridades, filtra por fecha y usa el modo enfoque para decidir qué sigue.',
      descriptionEn: 'Create tasks, set priorities, filter by date, and use Focus mode to decide what comes next.',
      icon: Icons.task_alt_rounded,
      color: AppColors.gold,
    ),
    _HelpGuide(
      titleEs: 'Reportes',
      titleEn: 'Reports',
      descriptionEs: 'Compara periodos y revisa tendencias de ingresos, gastos y actividad.',
      descriptionEn:
          'Compare periods and review income, expense, and activity trends.',
      icon: Icons.bar_chart_rounded,
      color: AppColors.amber,
    ),
    _HelpGuide(
      titleEs: 'Perfil y preferencias',
      titleEn: 'Profile and preferences',
      descriptionEs: 'Actualiza tus datos, idioma, moneda, apariencia, accesibilidad y notificaciones.',
      descriptionEn: 'Update your details, language, currency, appearance, accessibility, and notifications.',
      icon: Icons.person_rounded,
      color: AppColors.red,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: Text(appText(context, 'Centro de ayuda', 'Help center')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: AppColors.goldGradient,
              borderRadius: BorderRadius.circular(AppRadii.xl2),
              boxShadow: AppColors.sombraPremium(AppColors.gold),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.lightbulb_outline_rounded,
                  color: Colors.white,
                ),
                const SizedBox(height: 10),
                Text(
                  appText(context, 'Conoce mejor MYD', 'Get to know MYD'),
                  style: AppTypography.itemTitle.copyWith(
                    color: Colors.white,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  appText(
                    context,
                    'Revisa una sección o vuelve a recorrer la guía completa cuando quieras.',
                    'Review a section or replay the complete tour whenever you want.',
                  ),
                  style: AppTypography.secondary.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: onReplayTour == null
                      ? null
                      : () => _repetirTour(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white70),
                  ),
                  icon: const Icon(Icons.replay_rounded),
                  label: Text(
                    appText(
                      context,
                      'Repetir recorrido completo',
                      'Replay full tour',
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Text(
            appText(context, 'GUÍAS POR SECCIÓN', 'SECTION GUIDES'),
            style: AppTypography.sectionLabel,
          ),
          const SizedBox(height: 8),
          ..._guias.map(
            (guide) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(guide.icon, color: guide.color),
                title: Text(appText(context, guide.titleEs, guide.titleEn)),
                subtitle: Text(
                  appText(context, guide.descriptionEs, guide.descriptionEn),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _mostrarGuia(context, guide),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            appText(context, 'INFORMACIÓN LEGAL', 'LEGAL INFORMATION'),
            style: AppTypography.sectionLabel,
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.gavel_rounded, color: AppColors.gold),
                  title: Text(
                    appText(
                      context,
                      'Términos y condiciones',
                      'Terms and conditions',
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _abrirLegal(context, LegalDocument.terms),
                ),
                Divider(height: 1, color: AppColors.borderSoft),
                ListTile(
                  leading: Icon(
                    Icons.privacy_tip_outlined,
                    color: AppColors.gold,
                  ),
                  title: Text(
                    appText(
                      context,
                      'Política de privacidad',
                      'Privacy policy',
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _abrirLegal(context, LegalDocument.privacy),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _repetirTour(BuildContext context) async {
    Navigator.of(context).popUntil((route) => route.isFirst);
    await Future<void>.delayed(const Duration(milliseconds: 350));
    await onReplayTour?.call();
  }

  void _abrirLegal(BuildContext context, LegalDocument document) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LegalInfoScreen(initialDocument: document),
      ),
    );
  }

  void _mostrarGuia(BuildContext context, _HelpGuide guide) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl3)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(guide.icon, color: guide.color, size: 30),
            const SizedBox(height: 14),
            Text(
              appText(context, guide.titleEs, guide.titleEn),
              style: AppTypography.screenTitle,
            ),
            const SizedBox(height: 8),
            Text(
              appText(context, guide.descriptionEs, guide.descriptionEn),
              style: AppTypography.secondary,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: Text(appText(context, 'Entendido', 'Got it')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HelpGuide {
  final String titleEs;
  final String titleEn;
  final String descriptionEs;
  final String descriptionEn;
  final IconData icon;
  final Color color;

  const _HelpGuide({
    required this.titleEs,
    required this.titleEn,
    required this.descriptionEs,
    required this.descriptionEn,
    required this.icon,
    required this.color,
  });
}
