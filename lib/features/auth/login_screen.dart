import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

import '../../core/auth/auth_errors.dart';
import '../../core/services/google_auth_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/supabase/supabase_config.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _correoCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _mostrarPassword = false;
  bool _cargando = false;

  @override
  void dispose() {
    _correoCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _iniciarSesion() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _cargando = true);

    try {
      final respuesta = await supabase.auth.signInWithPassword(
        email: _correoCtrl.text.trim(),
        password: _passwordCtrl.text,
      );

      if (!mounted) return;

      if (respuesta.session != null) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo iniciar sesión. Intenta de nuevo.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(mensajeErrorAuth(e))));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _iniciarConGoogle() async {
    if (_cargando) return;
    setState(() => _cargando = true);

    try {
      final inicioExitoso = await GoogleAuthService.iniciarSesion();
      if (!mounted || !inicioExitoso) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(mensajeErrorAuth(e))));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _proximamente(String proveedor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Inicio con $proveedor muy pronto ✨')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _header(),
                      const SizedBox(height: 28),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadii.xl2),
                          border: Border.all(color: AppColors.borderSoft, width: AppRadii.borderWidth),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.gold.withValues(alpha: 0.08),
                              blurRadius: 24,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Inicia sesión',
                                style: AppTypography.screenTitle,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Gestiona tus tareas, dinero y metas desde un solo lugar.',
                                textAlign: TextAlign.center,
                                style: AppTypography.secondary.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 24),
                              _campoEtiqueta('CORREO ELECTRÓNICO'),
                              TextFormField(
                                controller: _correoCtrl,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                autocorrect: false,
                                enableSuggestions: false,
                                decoration: const InputDecoration(hintText: 'tu@email.com'),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Ingresa tu correo';
                                  }
                                  final regex = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');
                                  if (!regex.hasMatch(value.trim())) {
                                    return 'Correo no válido';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 18),
                              _campoEtiqueta('CONTRASEÑA'),
                              TextFormField(
                                controller: _passwordCtrl,
                                obscureText: !_mostrarPassword,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _iniciarSesion(),
                                decoration: InputDecoration(
                                  hintText: '••••••••',
                                  suffixIcon: IconButton(
                                    onPressed: () => setState(() => _mostrarPassword = !_mostrarPassword),
                                    icon: Icon(
                                      _mostrarPassword ? Icons.visibility_off : Icons.visibility,
                                      color: AppColors.textTertiary,
                                      size: 20,
                                    ),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Ingresa tu contraseña';
                                  }
                                  if (value.length < 6) {
                                    return 'Debe tener al menos 6 caracteres';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 10),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () => _proximamente('restablecer contraseña'),
                                  child: const Text('¿Olvidaste tu contraseña?'),
                                ),
                              ),
                              const SizedBox(height: 18),
                              _botonPrincipal(),
                              const SizedBox(height: 24),
                              _divisorConTexto('o continúa con'),
                              const SizedBox(height: 18),
                              _botonProveedor(
                                emoji: 'G',
                                texto: 'Continuar con Google',
                                onTap: _cargando ? null : _iniciarConGoogle,
                              ),
                              const SizedBox(height: 24),
                              _textoConAccion(
                                '¿No tienes cuenta? ',
                                'Regístrate gratis',
                                () => Navigator.of(context).pushNamed('/register'),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: _textoConAccion(
                          'Ya estás en el momento correcto. ',
                          'Volver al inicio',
                          () => Navigator.of(context).popUntil((route) => route.isFirst),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.goldChipBg, AppColors.goldBorder.withValues(alpha: 0.7)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(AppRadii.xl2),
      ),
      child: Column(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              gradient: AppColors.goldGradient,
              borderRadius: BorderRadius.circular(AppRadii.xl2),
              boxShadow: AppColors.sombraPremium(AppColors.gold),
            ),
            alignment: Alignment.center,
            child: const Text(
              'M',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'MYD',
            style: AppTypography.heroTitle,
          ),
          const SizedBox(height: 4),
          Text(
            'MANEJA TU DÍA',
            style: AppTypography.sectionLabel.copyWith(
              color: AppColors.goldDeep,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _campoEtiqueta(String texto) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        texto,
        style: AppTypography.sectionLabel.copyWith(fontSize: 11),
      ),
    );
  }

  Widget _botonPrincipal() {
    return SizedBox(
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: AppColors.goldGradient,
          borderRadius: BorderRadius.circular(AppRadii.xl2),
          boxShadow: AppColors.sombraPremium(AppColors.gold),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadii.xl2),
            onTap: _cargando ? null : _iniciarSesion,
            child: Center(
              child: _cargando
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Ingresar a MYD  →',
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
    );
  }

  Widget _divisorConTexto(String texto) {
    return Row(
      children: [
        Expanded(child: Divider(color: AppColors.borderSoft)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            texto,
            style: AppTypography.secondary.copyWith(color: AppColors.textTertiary),
          ),
        ),
        Expanded(child: Divider(color: AppColors.borderSoft)),
      ],
    );
  }

  Widget _botonProveedor({
    required String emoji,
    required String texto,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadii.xl2),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadii.xl2),
          border: Border.all(color: AppColors.borderSoft, width: AppRadii.borderWidth),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Text(
              texto,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _textoConAccion(String texto, String accion, VoidCallback onTap) {
    return Center(
      child: RichText(
        text: TextSpan(
          style: AppTypography.secondary.copyWith(color: AppColors.textSecondary),
          children: [
            TextSpan(text: texto),
            TextSpan(
              text: accion,
              style: TextStyle(
                color: AppColors.goldDeep,
                fontWeight: FontWeight.w700,
              ),
              recognizer: TapGestureRecognizer()..onTap = onTap,
            ),
          ],
        ),
      ),
    );
  }
}
