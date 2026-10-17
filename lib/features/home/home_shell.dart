import 'package:flutter/material.dart';
import '../../core/localization/app_text.dart';
import '../../core/services/guided_tour.dart';
import '../../core/services/home_utils.dart';
import '../../core/theme/app_theme.dart';
import '../../core/supabase/supabase_config.dart';
import 'home_tab.dart';
import '../finanzas/finanzas_screen.dart';
import '../tareas/tareas_screen.dart';
import '../reportes/reportes_screen.dart';
import '../perfil/perfil_screen.dart';
import '../historial/historial_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tabActual = 0;
  Map<String, dynamic>? _perfil;
  final GlobalKey _inicioTourKey = GlobalKey();
  final GlobalKey _finanzasTourKey = GlobalKey();
  final GlobalKey _tareasTourKey = GlobalKey();
  final GlobalKey _reportesTourKey = GlobalKey();
  final GlobalKey _perfilTourKey = GlobalKey();

  List<String> _titulos(BuildContext context) => [
        appText(context, 'Inicio', 'Home'),
        appText(context, 'Finanzas', 'Finance'),
        appText(context, 'Tareas', 'Tasks'),
        appText(context, 'Reportes', 'Reports'),
      ];

  @override
  void initState() {
    super.initState();
    _cargarPerfil();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _iniciarTour();
    });
  }

  Future<void> _repetirTour() async {
    Navigator.of(context).popUntil((route) => route.isFirst);
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (mounted) await _iniciarTour(force: true);
  }

  Future<void> _iniciarTour({bool force = false}) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await mostrarTourGuiado(
        context: context,
        storageKey: 'guided_tour_v1_$userId',
        force: force,
        steps: [
          TutorialStep(
            target: _inicioTourKey,
            title: appText(context, 'Tu centro de control', 'Your dashboard'),
            description: appText(
              context,
              'Inicio reúne tu balance, tus prioridades y el avance de la semana para ayudarte a decidir qué sigue.',
              'Home brings together your balance, priorities, and weekly progress so you can decide what to do next.',
            ),
            icon: Icons.home_rounded,
            color: AppColors.gold,
          ),
          TutorialStep(
            target: _finanzasTourKey,
            title: appText(context, 'Finanzas bajo control', 'Your finances'),
            description: appText(
              context,
              'Registra ingresos y gastos, define presupuestos y sigue tus metas de ahorro desde esta sección.',
              'Record income and expenses, set budgets, and track your savings goals in this section.',
            ),
            icon: Icons.account_balance_wallet_rounded,
            color: AppColors.green,
          ),
          TutorialStep(
            target: _tareasTourKey,
            title: appText(context, 'Prioriza lo importante', 'Prioritize what matters'),
            description: appText(
              context,
              'Organiza tus tareas, filtra por fecha o prioridad y usa el modo enfoque para elegir qué hacer primero.',
              'Organize tasks, filter by date or priority, and use Focus mode to choose what to tackle first.',
            ),
            icon: Icons.task_alt_rounded,
            color: AppColors.gold,
          ),
          TutorialStep(
            target: _reportesTourKey,
            title: appText(context, 'Entiende tu progreso', 'Understand your progress'),
            description: appText(
              context,
              'Consulta tendencias y comparativos para identificar cómo evolucionan tus finanzas y hábitos.',
              'Review trends and comparisons to see how your finances and habits are changing.',
            ),
            icon: Icons.bar_chart_rounded,
            color: AppColors.amber,
          ),
          TutorialStep(
            target: _perfilTourKey,
            title: appText(context, 'Tu cuenta y preferencias', 'Your account and preferences'),
            description: appText(
              context,
              'Desde aquí accedes a tu perfil, historial de actividad y opciones para cerrar sesión.',
              'Access your profile, activity history, and sign-out options here.',
            ),
            icon: Icons.person_rounded,
            color: AppColors.red,
          ),
        ],
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo iniciar la guía: $error')),
      );
    }
  }

  Future<void> _cargarPerfil() async {
    try {
      final userId = supabase.auth.currentUser!.id;
      final data =
          await supabase.from('perfiles').select().eq('id', userId).single();
      if (mounted) setState(() => _perfil = data);
    } catch (_) {}
  }

  void _irATab(int index) => setState(() => _tabActual = index);

  Future<void> _cerrarSesion() async {
    try {
      await supabase.auth.signOut();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo cerrar la sesión: $e')),
      );
    }
  }

  void _mostrarMenuPerfil() {
    final nombre = _perfil?['nombre'] ?? '';
    final correo = _perfil?['correo'] ?? supabase.auth.currentUser?.email ?? '';

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl3)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.gold,
                    backgroundImage: _perfil?['avatar_url'] != null
                        ? NetworkImage(_perfil!['avatar_url'])
                        : null,
                    child: _perfil?['avatar_url'] == null
                        ? Text(
                            nombre.isNotEmpty ? nombre[0].toUpperCase() : '👤',
                            style: const TextStyle(
                                color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
                          )
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(nombre,
                            style: AppTypography.itemTitle.copyWith(fontSize: 16)),
                        Text(correo, style: AppTypography.secondary),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Divider(color: AppColors.borderSoft),
              const SizedBox(height: 8),
              ListTile(
                leading: Icon(Icons.person_outline, color: AppColors.gold),
                title: Text(appText(context, 'Mi perfil', 'My profile'),
                    style: AppTypography.itemTitle),
                onTap: () async {
                  Navigator.pop(context);
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          PerfilScreen(onReplayTour: _repetirTour),
                    ),
                  );
                  _cargarPerfil(); // refresca por si cambió el nombre/foto
                },
              ),
              ListTile(
                leading: Icon(Icons.history, color: AppColors.gold),
                title: Text(
                    appText(context, 'Historial de actividad', 'Activity history'),
                    style: AppTypography.itemTitle),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const HistorialScreen()),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.logout, color: AppColors.red),
                title: Text(appText(context, 'Cerrar sesión', 'Sign out'),
                    style: AppTypography.itemTitle.copyWith(color: AppColors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _cerrarSesion();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nombre = _perfil?['nombre'] as String?;
    final avatarUrl = _perfil?['avatar_url'] as String?;

    final tabs = [
      HomeTab(nombre: nombre, onVerTareas: () => _irATab(2)),
      const FinanzasScreen(),
      const TareasScreen(),
      const ReportesScreen(),
    ];

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: Text(_titulos(context)[_tabActual]),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              key: _perfilTourKey,
              onTap: _mostrarMenuPerfil,
              child: CircleAvatar(
                backgroundColor: AppColors.gold,
                backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                child: avatarUrl == null
                    ? Text(
                        (nombre != null && nombre.isNotEmpty) ? nombre[0].toUpperCase() : '👤',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      )
                    : null,
              ),
            ),
          ),
        ],
      ),
      body: IndexedStack(index: _tabActual, children: tabs),
      bottomNavigationBar: NavigationBar(
        height: 76,
        backgroundColor: AppColors.navBlurBg,
        selectedIndex: _tabActual,
        onDestinationSelected: _irATab,
        indicatorColor: AppColors.goldChipBg,
        surfaceTintColor: Colors.transparent,
        destinations: [
          NavigationDestination(
            key: _inicioTourKey,
            icon: Icon(Icons.home_outlined, color: AppColors.textTertiary),
            selectedIcon: Icon(Icons.home, color: AppColors.gold),
            label: appText(context, 'Inicio', 'Home'),
          ),
          NavigationDestination(
            key: _finanzasTourKey,
            icon: Icon(Icons.attach_money_outlined, color: AppColors.textTertiary),
            selectedIcon: Icon(Icons.attach_money, color: AppColors.gold),
            label: appText(context, 'Finanzas', 'Finance'),
          ),
          NavigationDestination(
            key: _tareasTourKey,
            icon: Icon(Icons.check_circle_outline, color: AppColors.textTertiary),
            selectedIcon: Icon(Icons.check_circle, color: AppColors.gold),
            label: appText(context, 'Tareas', 'Tasks'),
          ),
          NavigationDestination(
            key: _reportesTourKey,
            icon: Icon(Icons.bar_chart_outlined, color: AppColors.textTertiary),
            selectedIcon: Icon(Icons.bar_chart, color: AppColors.gold),
            label: appText(context, 'Reportes', 'Reports'),
          ),
        ],
      ),
    );
  }
}
