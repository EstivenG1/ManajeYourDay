import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import '../supabase/supabase_config.dart';

/// Servicio de notificaciones locales de MYD.
/// Las notificaciones se programan y muestran directamente en el dispositivo.
class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _listo = false;

  /// Inicializa el sistema de notificaciones.
  static Future<void> init() async {
    tz_data.initializeTimeZones();

    // Zona horaria de Colombia.
    tz.setLocalLocation(tz.getLocation('America/Bogota'));

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(settings);

    // Solicitar permiso para Android.
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    // Solicitar permiso para iOS.
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );

    _listo = true;
  }

  // Canal para recordatorios de tareas.
  static const AndroidNotificationDetails _canalTareas =
      AndroidNotificationDetails(
    'tareas_channel',
    'Recordatorios de tareas',
    channelDescription: 'Avisos antes de que venza una tarea',
    importance: Importance.high,
    priority: Priority.high,
  );

  // Canal para alertas de presupuesto.
  static const AndroidNotificationDetails _canalPresupuestos =
      AndroidNotificationDetails(
    'presupuestos_channel',
    'Alertas de presupuesto',
    channelDescription:
        'Avisos al acercarte o superar un presupuesto',
    importance: Importance.high,
    priority: Priority.high,
  );

  /// Programa un recordatorio 15 minutos antes
  /// de que venza una tarea.
  static Future<void> programarRecordatorioTarea({
    required String tareaId,
    required String titulo,
    required DateTime fechaLimite,
  }) async {
    if (!_listo) return;

    final momento =
        fechaLimite.subtract(const Duration(minutes: 15));

    // Si el momento del recordatorio ya pasó, no hacemos nada.
    if (momento.isBefore(DateTime.now())) return;

    await _plugin.zonedSchedule(
      tareaId.hashCode,
      'Tarea próxima a vencer ⏰',
      titulo,
      tz.TZDateTime.from(momento, tz.local),
      const NotificationDetails(
        android: _canalTareas,
        iOS: DarwinNotificationDetails(),
      ),

      // Android.
      androidScheduleMode:
          AndroidScheduleMode.inexactAllowWhileIdle,

      // Compatibilidad con versiones que requieren
      // interpretación de fecha para iOS.
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Cancela el recordatorio de una tarea.
  static Future<void> cancelarRecordatorioTarea(
    String tareaId,
  ) async {
    await _plugin.cancel(tareaId.hashCode);
  }

  /// Muestra inmediatamente una notificación.
  static Future<void> _mostrarAhora({
    required int id,
    required String titulo,
    required String cuerpo,
  }) async {
    if (!_listo) return;

    await _plugin.show(
      id,
      titulo,
      cuerpo,
      const NotificationDetails(
        android: _canalPresupuestos,
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  /// Revisa el presupuesto activo de una categoría.
  ///
  /// Notifica cuando:
  /// - Se alcanza el 80%.
  /// - Se supera el 100%.
  static Future<void> revisarPresupuesto({
    required int categoriaId,
    required String nombreCategoria,
  }) async {
    try {
      final user = supabase.auth.currentUser;

      // Si no hay usuario conectado, no hacemos nada.
      if (user == null) return;

      final userId = user.id;

      final hoy = DateTime.now();

      final hoyStr =
          '${hoy.year}-'
          '${hoy.month.toString().padLeft(2, '0')}-'
          '${hoy.day.toString().padLeft(2, '0')}';

      // Buscar presupuesto activo.
      final presupuesto = await supabase
          .from('presupuestos')
          .select(
            'id, monto_limite, fecha_inicio, fecha_fin',
          )
          .eq('usuario_id', userId)
          .eq('categoria_id', categoriaId)
          .lte('fecha_inicio', hoyStr)
          .gte('fecha_fin', hoyStr)
          .maybeSingle();

      if (presupuesto == null) return;

      // Buscar gastos del periodo.
      final gastado = await supabase
          .from('movimientos')
          .select('monto')
          .eq('usuario_id', userId)
          .eq('categoria_id', categoriaId)
          .eq('tipo', 'gasto')
          .gte(
            'fecha',
            presupuesto['fecha_inicio'],
          )
          .lte(
            'fecha',
            presupuesto['fecha_fin'],
          );

      final total = (gastado as List).fold<double>(
        0,
        (acumulado, movimiento) =>
            acumulado +
            (movimiento['monto'] as num).toDouble(),
      );

      final limite =
          (presupuesto['monto_limite'] as num).toDouble();

      final porcentaje =
          limite == 0 ? 0.0 : (total / limite) * 100;

      // Presupuesto superado.
      if (porcentaje >= 100) {
        await _mostrarAhora(
          id: ('presupuesto_100_$categoriaId').hashCode,
          titulo: '⚠️ Presupuesto superado',
          cuerpo:
              'Superaste el presupuesto de '
              '"$nombreCategoria" para este periodo.',
        );
      }

      // 80% del presupuesto.
      else if (porcentaje >= 80) {
        await _mostrarAhora(
          id: ('presupuesto_80_$categoriaId').hashCode,
          titulo: '🔔 Cerca del límite',
          cuerpo:
              'Ya usaste el '
              '${porcentaje.toStringAsFixed(0)}% del presupuesto '
              'de "$nombreCategoria".',
        );
      }
    } catch (_) {
      // Un error en las notificaciones no debe
      // impedir guardar un gasto.
    }
  }
}

