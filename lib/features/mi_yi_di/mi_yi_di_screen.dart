import 'package:flutter/material.dart';

import '../../core/localization/app_text.dart';
import '../../core/theme/app_theme.dart';

class MiYiDiScreen extends StatelessWidget {
  const MiYiDiScreen({super.key});

  void _mostrarInformacion(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Text('🤖', style: TextStyle(fontSize: 36)),
        title: const Text('MiYiDi'),
        content: Text(
          appText(
            context,
            'Tu chat personal con IA está en proceso de creación. La idea es que puedas consultar tus finanzas, tareas, productividad y balances; recibir consejos; y pedir ayuda para crear tareas, movimientos y metas de ahorro. Te avisaremos cuando esté disponible.',
            'Your personal AI chat is being built. You will be able to ask about your finances, tasks, productivity, and balances; get advice; and request help creating tasks, transactions, and savings goals. We will let you know when it is available.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(appText(context, 'Entendido', 'Got it')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: const Text('MiYiDi'),
        actions: [
          IconButton(
            tooltip: appText(context, 'Información', 'Information'),
            onPressed: () => _mostrarInformacion(context),
            icon: const Icon(Icons.info_outline_rounded),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 112,
                height: 112,
                decoration: BoxDecoration(
                  color: AppColors.goldSoftBg,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.goldBorder),
                ),
                alignment: Alignment.center,
                child: const Text('🤖', style: TextStyle(fontSize: 58)),
              ),
              const SizedBox(height: 22),
              Text(
                appText(context, 'Hola, soy MiYiDi', 'Hi, I’m MiYiDi'),
                style: AppTypography.screenTitle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                appText(
                  context,
                  'Tu asistente personal para organizar tu día está en camino.',
                  'Your personal assistant for organizing your day is on the way.',
                ),
                style: AppTypography.secondary,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: AppColors.goldSoftBg,
                  borderRadius: BorderRadius.circular(AppRadii.full),
                  border: Border.all(color: AppColors.goldBorder),
                ),
                child: Text(
                  appText(context, 'En proceso de creación', 'Coming soon'),
                  style: AppTypography.secondary.copyWith(
                    color: AppColors.goldDeep,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () => _mostrarInformacion(context),
                icon: const Icon(Icons.info_outline_rounded),
                label: Text(
                  appText(context, '¿Qué podré hacer?', 'Learn more'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
