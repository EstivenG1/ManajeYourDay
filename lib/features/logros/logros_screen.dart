import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/gamificacion_service.dart';

class LogrosScreen extends StatefulWidget {
  const LogrosScreen({super.key});

  @override
  State<LogrosScreen> createState() => _LogrosScreenState();
}

class _LogrosScreenState extends State<LogrosScreen> {
  EstadisticasGamificacion? _datos;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final datos = await GamificacionService.cargar();
      if (mounted) setState(() => _datos = datos);
    } catch (_) {
      // deja _datos como estaba
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _datos;

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(title: const Text('Mis logros')),
      body: _cargando || d == null
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : RefreshIndicator(
              color: AppColors.gold,
              onRefresh: _cargar,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _tarjetaRacha(d),
                  const SizedBox(height: 18),
                  _filaEstadisticas(d),
                  const SizedBox(height: 26),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('LOGROS', style: AppTypography.sectionLabel),
                      Text('${d.logrosDesbloqueados} de ${d.logros.length}',
                          style: AppTypography.secondary.copyWith(
                              color: AppColors.goldDeep, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...d.logros.map(_tarjetaLogro),
                  const SizedBox(height: 12),
                ],
              ),
            ),
    );
  }

  Widget _tarjetaRacha(EstadisticasGamificacion d) {
    final enRacha = d.rachaActual > 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.gold, AppColors.goldDark]),
        borderRadius: BorderRadius.circular(AppRadii.xl3),
        boxShadow: AppColors.sombraPremium(AppColors.gold, blur: 24, dy: 10),
      ),
      child: Column(
        children: [
          Text(enRacha ? '🔥' : '💤', style: const TextStyle(fontSize: 38)),
          const SizedBox(height: 8),
          Text('${d.rachaActual}',
              style: const TextStyle(color: Colors.white, fontSize: 46, fontWeight: FontWeight.w900)),
          Text(
            d.rachaActual == 1 ? 'día seguido' : 'días seguidos',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 14),
          Divider(color: Colors.white.withValues(alpha: 0.3)),
          const SizedBox(height: 12),
          Text(
            enRacha
                ? 'Tu mejor racha: ${d.rachaMaxima} días. ¡Sigue así!'
                : 'Registra algo hoy para empezar una nueva racha.\nTu récord es de ${d.rachaMaxima} días.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _filaEstadisticas(EstadisticasGamificacion d) {
    return Row(
      children: [
        Expanded(child: _estadistica('✅', '${d.tareasCompletadas}', 'Tareas')),
        const SizedBox(width: 10),
        Expanded(child: _estadistica('💸', '${d.movimientosRegistrados}', 'Movimientos')),
        const SizedBox(width: 10),
        Expanded(child: _estadistica('📅', '${d.diasActivos}', 'Días activos')),
      ],
    );
  }

  Widget _estadistica(String emoji, String valor, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.xl2),
        border: Border.all(color: AppColors.borderSoft, width: AppRadii.borderWidth),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 4),
          Text(valor, style: AppTypography.kpiNumber.copyWith(fontSize: 18)),
          Text(label,
              style: AppTypography.secondary.copyWith(fontSize: 10.5),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _tarjetaLogro(Logro l) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: l.desbloqueado ? AppColors.goldSoftBg : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.xl2),
        border: Border.all(
          color: l.desbloqueado ? AppColors.goldBorder : AppColors.borderSoft,
          width: AppRadii.borderWidth,
        ),
      ),
      child: Row(
        children: [
          Opacity(
            opacity: l.desbloqueado ? 1 : 0.35,
            child: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: l.desbloqueado ? AppColors.goldChipBg : AppColors.borderSoft,
                borderRadius: BorderRadius.circular(AppRadii.xl),
              ),
              alignment: Alignment.center,
              child: Text(l.emoji, style: const TextStyle(fontSize: 21)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(l.titulo,
                          style: AppTypography.itemTitle.copyWith(
                            color: l.desbloqueado ? AppColors.goldDeep : AppColors.textPrimary,
                          )),
                    ),
                    if (l.desbloqueado)
                      const Icon(Icons.verified, color: AppColors.gold, size: 17)
                    else
                      Text('${l.progreso}/${l.meta}',
                          style: AppTypography.secondary.copyWith(fontSize: 11.5)),
                  ],
                ),
                const SizedBox(height: 3),
                Text(l.descripcion,
                    style: AppTypography.secondary.copyWith(fontSize: 11.5)),
                if (!l.desbloqueado) ...[
                  const SizedBox(height: 7),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadii.full),
                    child: LinearProgressIndicator(
                      value: l.porcentaje,
                      minHeight: 5,
                      backgroundColor: AppColors.borderSoft,
                      color: AppColors.gold,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
