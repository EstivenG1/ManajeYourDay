import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../../core/theme/app_theme.dart';
import '../../core/supabase/supabase_config.dart';
import '../../core/auth/auth_errors.dart';

enum AuthTab { login, register }

/// Pantalla única de acceso: una franja superior con el logo, y abajo
/// un formulario que cambia entre "Iniciar sesión" y "Registrarse"
/// mediante pestañas, tal como en el boceto.
class AuthScreen extends StatefulWidget {
  final AuthTab initialTab;
  const AuthScreen({super.key, this.initialTab = AuthTab.login});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  late AuthTab _tab = widget.initialTab;
  final _formKey = GlobalKey<FormState>();

  final _nombreCtrl = TextEditingController();
  final _apellidoCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _correoCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmarCtrl = TextEditingController();

  bool _verPassword = false;
  bool _cargando = false;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _apellidoCtrl.dispose();
    _telefonoCtrl.dispose();
    _correoCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmarCtrl.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _cargando = true);

    try {
      final respuesta = _tab == AuthTab.login
          ? await supabase.auth.signInWithPassword(
              email: _correoCtrl.text.trim(),
              password: _passwordCtrl.text,
            )
          : await supabase.auth.signUp(
              email: _correoCtrl.text.trim(),
              password: _passwordCtrl.text,
              data: {
                'nombre': _nombreCtrl.text.trim(),
                'apellido': _apellidoCtrl.text.trim().isEmpty
                    ? null
                    : _apellidoCtrl.text.trim(),
                'telefono': _telefonoCtrl.text.trim(),
              },
            );

      if (!mounted) return;

      if (respuesta.session != null) {
        // Ya hay sesión activa: AuthGate (debajo de esta pantalla en la
        // pila de navegación) ya cambió a HomeShell — solo hace falta
        // cerrar esta pantalla para que se vea. Sin este paso, la app
        // se queda "detrás" del login hasta que el usuario presiona
        // atrás (el bug reportado).
        Navigator.of(context).popUntil((route) => route.isFirst);
      } else if (_tab == AuthTab.register) {
        // Caso borde: si la confirmación de correo estuviera activada
        // en Supabase, signUp no crea sesión de inmediato.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cuenta creada. Ahora inicia sesión.')),
        );
        setState(() => _tab = AuthTab.login);
      }
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
        child: SingleChildScrollView(
          child: Column(
            children: [
              _encabezado(),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _segmentado(),
                      const SizedBox(height: 22),
                      if (_tab == AuthTab.register) ..._camposRegistro(),
                      _campoEtiqueta('CORREO ELECTRÓNICO'),
                      TextFormField(
                        controller: _correoCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration:
                            const InputDecoration(hintText: 'tu@email.com'),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Ingresa tu correo';
                          final regex = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');
                          if (!regex.hasMatch(v.trim())) return 'Correo no válido';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      _campoEtiqueta('CONTRASEÑA'),
                      TextFormField(
                        controller: _passwordCtrl,
                        obscureText: !_verPassword,
                        decoration: InputDecoration(
                          hintText: '••••••••',
                          suffixIcon: IconButton(
                            icon: Icon(
                              _verPassword ? Icons.visibility_off : Icons.visibility,
                              color: AppColors.textTertiary,
                              size: 20,
                            ),
                            onPressed: () =>
                                setState(() => _verPassword = !_verPassword),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Ingresa tu contraseña';
                          if (_tab == AuthTab.register && v.length < 6) {
                            return 'Mínimo 6 caracteres';
                          }
                          return null;
                        },
                      ),

                      if (_tab == AuthTab.register) ...[
                        const SizedBox(height: 16),
                        _campoEtiqueta('CONFIRMAR CONTRASEÑA'),
                        TextFormField(
                          controller: _confirmarCtrl,
                          obscureText: !_verPassword,
                          decoration: const InputDecoration(hintText: '••••••••'),
                          validator: (v) => v != _passwordCtrl.text
                              ? 'Las contraseñas no coinciden'
                              : null,
                        ),
                      ],

                      if (_tab == AuthTab.login) ...[
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {},
                            child: const Text('¿Olvidaste tu contraseña?'),
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),

                      _botonPrincipal(),
                      const SizedBox(height: 24),

                      _divisorConTexto('o continúa con'),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: _botonProveedor(
                              emoji: '🌐',
                              texto: 'Google',
                              onTap: () => _proximamente('Google'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _botonProveedor(
                              emoji: '🍎',
                              texto: 'Apple',
                              onTap: () => _proximamente('Apple'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),

                      Center(child: _enlaceInferior()),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _camposRegistro() {
    return [
      Row(
        children: [
          Expanded(
            child: _campoConEtiqueta(
              etiqueta: 'NOMBRE',
              controller: _nombreCtrl,
              hint: 'Nombre',
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Requerido' : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _campoConEtiqueta(
              etiqueta: 'APELLIDO (opcional)',
              controller: _apellidoCtrl,
              hint: 'Apellido',
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      _campoEtiqueta('NÚMERO TELEFÓNICO'),
      TextFormField(
        controller: _telefonoCtrl,
        keyboardType: TextInputType.phone,
        decoration: const InputDecoration(hintText: '300 123 4567'),
        validator: (v) {
          if (v == null || v.trim().isEmpty) return 'Ingresa tu teléfono';
          final soloDigitos = v.replaceAll(RegExp(r'\D'), '');
          if (soloDigitos.length < 7) return 'Teléfono no válido';
          return null;
        },
      ),
      const SizedBox(height: 16),
    ];
  }

  Widget _campoConEtiqueta({
    required String etiqueta,
    required TextEditingController controller,
    required String hint,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _campoEtiqueta(etiqueta),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(hintText: hint),
          validator: validator,
        ),
      ],
    );
  }

  Widget _campoEtiqueta(String texto) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(texto, style: AppTypography.sectionLabel.copyWith(fontSize: 11)),
    );
  }

  Widget _encabezado() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.goldChipBg, AppColors.goldBorder.withValues(alpha: 0.6)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.gold,
              borderRadius: BorderRadius.circular(AppRadii.xl2),
            ),
            alignment: Alignment.center,
            child: const Text(
              'M',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 10),
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

  Widget _segmentado() {
    Widget segmento(String texto, AuthTab tab) {
      final activo = _tab == tab;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _tab = tab),
          child: AnimatedContainer(
            duration: AppMotion.fast,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: activo ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadii.xl2 - 2),
              boxShadow: activo
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: Text(
              texto,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: activo ? AppColors.textPrimary : AppColors.textTertiary,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.borderSoft,
        borderRadius: BorderRadius.circular(AppRadii.xl2),
      ),
      child: Row(
        children: [
          segmento('Iniciar sesión', AuthTab.login),
          segmento('Registrarse', AuthTab.register),
        ],
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
            onTap: _cargando ? null : _enviar,
            child: Center(
              child: _cargando
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                    )
                  : Text(
                      _tab == AuthTab.login ? 'Ingresar a MYD  →' : 'Crear cuenta  →',
                      style: const TextStyle(
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
          child: Text(texto,
              style: AppTypography.secondary.copyWith(color: AppColors.textTertiary)),
        ),
        Expanded(child: Divider(color: AppColors.borderSoft)),
      ],
    );
  }

  Widget _botonProveedor({
    required String emoji,
    required String texto,
    required VoidCallback onTap,
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
            Text(texto,
                style: const TextStyle(
                    color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _enlaceInferior() {
    if (_tab == AuthTab.login) {
      return _textoConAccion('¿No tienes cuenta? ', 'Regístrate gratis',
          () => setState(() => _tab = AuthTab.register));
    }
    return _textoConAccion('¿Ya tienes cuenta? ', 'Inicia sesión',
        () => setState(() => _tab = AuthTab.login));
  }

  Widget _textoConAccion(String texto, String accion, VoidCallback onTap) {
    return RichText(
      text: TextSpan(
        style: AppTypography.secondary.copyWith(color: AppColors.textSecondary),
        children: [
          TextSpan(text: texto),
          TextSpan(
            text: accion,
            style: const TextStyle(color: AppColors.goldDeep, fontWeight: FontWeight.w700),
            recognizer: TapGestureRecognizer()..onTap = onTap,
          ),
        ],
      ),
    );
  }
}
