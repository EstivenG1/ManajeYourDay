import 'package:flutter/material.dart';

import '../localization/app_text.dart';
import '../theme/app_theme.dart';
import 'home_utils.dart';

Future<void> mostrarTourGuiado({
  required BuildContext context,
  required String storageKey,
  required List<TutorialStep> steps,
  bool force = false,
}) async {
  if (steps.isEmpty ||
      (!force && !await debeMostrarTutorial(storageKey)) ||
      !context.mounted) {
    return;
  }

  final completado = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Tour guiado',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, animation, secondaryAnimation) =>
        _GuidedTour(steps: steps),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(opacity: animation, child: child);
    },
  );

  if (completado == true) {
    await marcarTutorialMostrado(storageKey);
  }
}

class _GuidedTour extends StatefulWidget {
  final List<TutorialStep> steps;

  const _GuidedTour({required this.steps});

  @override
  State<_GuidedTour> createState() => _GuidedTourState();
}

class _GuidedTourState extends State<_GuidedTour> {
  int _index = 0;

  void _siguiente() {
    if (_index == widget.steps.length - 1) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() => _index++);
  }

  void _saltar() => Navigator.of(context).pop(true);

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[_index];
    final renderObject = step.target.currentContext?.findRenderObject();
    final renderBox = renderObject is RenderBox ? renderObject : null;
    final targetRect = renderBox != null && renderBox.hasSize
        ? renderBox.localToGlobal(Offset.zero) & renderBox.size
        : Rect.fromCenter(
            center: MediaQuery.sizeOf(context).center(Offset.zero),
            width: 1,
            height: 1,
          );
    final spotlight = targetRect.inflate(8);
    final showCardBelow =
        spotlight.center.dy < MediaQuery.sizeOf(context).height / 2;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _SpotlightPainter(
                spotlight: spotlight,
                accent: step.color,
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: showCardBelow
                  ? Alignment.bottomCenter
                  : Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: _TourCard(
                  step: step,
                  index: _index,
                  total: widget.steps.length,
                  onSkip: _saltar,
                  onNext: _siguiente,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TourCard extends StatelessWidget {
  final TutorialStep step;
  final int index;
  final int total;
  final VoidCallback onSkip;
  final VoidCallback onNext;

  const _TourCard({
    required this.step,
    required this.index,
    required this.total,
    required this.onSkip,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final ultimoPaso = index == total - 1;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.xl2),
          border: Border.all(color: AppColors.borderSoft),
          boxShadow: AppColors.sombraPremium(Colors.black, blur: 28, dy: 12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: step.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(step.icon, color: step.color, size: 23),
                ),
                const Spacer(),
                Text(
                  appText(
                    context,
                    '${index + 1} de $total',
                    '${index + 1} of $total',
                  ),
                  style: AppTypography.secondary.copyWith(
                    color: step.color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                IconButton(
                  tooltip: appText(context, 'Saltar recorrido', 'Skip tour'),
                  onPressed: onSkip,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              step.title,
              style: AppTypography.itemTitle.copyWith(fontSize: 20),
            ),
            const SizedBox(height: 8),
            Text(step.description, style: AppTypography.secondary),
            const SizedBox(height: 18),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (index + 1) / total,
                minHeight: 4,
                backgroundColor: AppColors.borderSoft,
                color: step.color,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                TextButton(
                  onPressed: onSkip,
                  child: Text(appText(context, 'Saltar', 'Skip')),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: onNext,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: Colors.white,
                  ),
                  icon: Icon(
                    ultimoPaso
                        ? Icons.check_rounded
                        : Icons.arrow_forward_rounded,
                    size: 18,
                  ),
                  label: Text(
                    ultimoPaso
                        ? appText(context, 'Empezar', 'Get started')
                        : appText(context, 'Siguiente', 'Next'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  final Rect spotlight;
  final Color accent;

  const _SpotlightPainter({required this.spotlight, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final overlay = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(RRect.fromRectAndRadius(spotlight, const Radius.circular(18)));
    canvas.drawPath(
      overlay,
      Paint()..color = Colors.black.withValues(alpha: 0.72),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(spotlight, const Radius.circular(18)),
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(_SpotlightPainter oldDelegate) =>
      oldDelegate.spotlight != spotlight || oldDelegate.accent != accent;
}
