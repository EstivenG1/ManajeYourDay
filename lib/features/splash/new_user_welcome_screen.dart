import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class NewUserWelcomeScreen extends StatefulWidget {
  final Future<void> Function() onContinue;

  const NewUserWelcomeScreen({super.key, required this.onContinue});

  @override
  State<NewUserWelcomeScreen> createState() => _NewUserWelcomeScreenState();
}

class _NewUserWelcomeScreenState extends State<NewUserWelcomeScreen> {
  bool _continuing = false;

  Future<void> _continue() async {
    if (_continuing) return;
    setState(() => _continuing = true);
    await widget.onContinue();
    if (mounted) setState(() => _continuing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 112,
                    height: 112,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Image.asset('assets/icon/icon.png'),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'TU NUEVO COMIENZO',
                    style: AppTypography.sectionLabel.copyWith(
                      color: AppColors.gold,
                      letterSpacing: 2.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Bienvenido a\nManage Your Day',
                    textAlign: TextAlign.center,
                    style: AppTypography.heroTitle.copyWith(fontSize: 29),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Aquí podrás transformar la manera en que manejas tu tiempo, tu dinero y tus metas.',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyBase.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const _WelcomeFeature(
                    icon: Icons.access_time_rounded,
                    title: 'Recupera tu tiempo',
                    description: 'Organiza prioridades y convierte tus planes en avances reales.',
                  ),
                  const SizedBox(height: 10),
                  const _WelcomeFeature(
                    icon: Icons.attach_money_rounded,
                    title: 'Domina tu dinero',
                    description: 'Entiende tus ingresos y gastos para decidir con tranquilidad.',
                  ),
                  const SizedBox(height: 10),
                  const _WelcomeFeature(
                    icon: Icons.auto_awesome_rounded,
                    title: 'Mejora cada día',
                    description: 'Recibe recomendaciones según tu progreso.',
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton(
                      onPressed: _continuing ? null : _continue,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.goldDeep,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadii.xl2),
                        ),
                      ),
                      child: _continuing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Empezar a manejar mi día →',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
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

class _WelcomeFeature extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _WelcomeFeature({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.xl2),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.goldChipBg,
              borderRadius: BorderRadius.circular(AppRadii.xl),
            ),
            child: Icon(icon, color: AppColors.goldDeep, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.itemTitle),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: AppTypography.secondary.copyWith(height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
