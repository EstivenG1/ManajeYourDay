import 'package:flutter/material.dart';
import '../../core/localization/app_text.dart';
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
                    MaterialPageRoute(builder: (_) => const PerfilScreen()),
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
            icon: Icon(Icons.home_outlined, color: AppColors.textTertiary),
            selectedIcon: Icon(Icons.home, color: AppColors.gold),
            label: appText(context, 'Inicio', 'Home'),
          ),
          NavigationDestination(
            icon: Icon(Icons.attach_money_outlined, color: AppColors.textTertiary),
            selectedIcon: Icon(Icons.attach_money, color: AppColors.gold),
            label: appText(context, 'Finanzas', 'Finance'),
          ),
          NavigationDestination(
            icon: Icon(Icons.check_circle_outline, color: AppColors.textTertiary),
            selectedIcon: Icon(Icons.check_circle, color: AppColors.gold),
            label: appText(context, 'Tareas', 'Tasks'),
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined, color: AppColors.textTertiary),
            selectedIcon: Icon(Icons.bar_chart, color: AppColors.gold),
            label: appText(context, 'Reportes', 'Reports'),
          ),
        ],
      ),
    );
  }
}
