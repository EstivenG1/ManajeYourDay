import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Theme.of(context).extension<AuthTheme>()!;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: auth.gradienteFondoSplash,
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Anillo decorativo giratorio, muy sutil, detrás del logo.
              Positioned(
                top: 60,
                child: SpinSlow(
                  child: Container(
                    width: 210,
                    height: 210,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.gold.withValues(alpha: 0.18),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FadeSlideIn(
                      delay: AppMotion.escalon(0),
                      child: _badgePill(),
                    ),
                    const SizedBox(height: 22),

                    FadeSlideIn(
                      delay: AppMotion.escalon(1),
                      child: PulseSoft(
                        child: Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            color: AppColors.gold,
                            borderRadius: BorderRadius.circular(AppRadii.xl2),
                            boxShadow: AppColors.sombraPremium(AppColors.gold),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            'M',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),

                    FadeSlideIn(
                      delay: AppMotion.escalon(2),
                      child: Text('MYD', style: AppTypography.heroTitle),
                    ),
                    const SizedBox(height: 4),
                    FadeSlideIn(
                      delay: AppMotion.escalon(2),
                      child: Text(
                        'MANEJA TU DÍA',
                        style: AppTypography.sectionLabel.copyWith(
                          color: AppColors.goldDeep,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    FadeSlideIn(
                      delay: AppMotion.escalon(3),
                      child: Text(
                        'Finanzas, tareas y notificaciones inteligentes — '
                        'todo en un solo lugar.',
                        textAlign: TextAlign.center,
                        style: AppTypography.bodyBase.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const SizedBox(height: 26),

                    FadeSlideIn(
                      delay: AppMotion.escalon(4),
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 10,
                        runSpacing: 10,
                        children: const [
                          _FeatureChip(emoji: '💰', label: 'Finanzas'),
                          _FeatureChip(emoji: '✅', label: 'Tareas'),
                          _FeatureChip(emoji: '🔔', label: 'Alertas'),
                          _FeatureChip(emoji: '📊', label: 'Reportes'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),

                    FadeSlideIn(
                      delay: AppMotion.escalon(5),
                      child: SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: auth.gradienteLogo,
                            borderRadius: BorderRadius.circular(auth.radioBotones),
                            boxShadow: AppColors.sombraPremium(AppColors.gold),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(auth.radioBotones),
                              onTap: () => Navigator.pushNamed(context, '/login'),
                              child: const Center(
                                child: Text(
                                  'Comenzar ahora  →',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badgePill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.goldChipBg,
        borderRadius: BorderRadius.circular(AppRadii.full),
        border: Border.all(color: AppColors.goldBorder),
      ),
      child: Text(
        '✦ Gestión personal inteligente',
        style: AppTypography.secondary.copyWith(
          color: AppColors.goldDeep,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  final String emoji;
  final String label;
  const _FeatureChip({required this.emoji, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.goldChipBg,
        borderRadius: BorderRadius.circular(AppRadii.full),
        border: Border.all(color: AppColors.goldBorder),
      ),
      child: Text(
        '$emoji $label',
        style: AppTypography.secondary.copyWith(
          color: AppColors.goldDeep,
          fontWeight: FontWeight.w600,
          fontSize: 12.5,
        ),
      ),
    );
  }
}
