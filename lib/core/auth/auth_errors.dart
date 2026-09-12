import 'package:supabase_flutter/supabase_flutter.dart';

/// Convierte los errores de Supabase Auth en mensajes claros en español
/// para mostrárselos al usuario.
String mensajeErrorAuth(Object error) {
  if (error is AuthException) {
    final mensaje = error.message.toLowerCase();

    if (mensaje.contains('user already registered') ||
        mensaje.contains('already registered')) {
      return 'Ya existe una cuenta con este correo. Intenta iniciar sesión.';
    }
    if (mensaje.contains('invalid login credentials') ||
        mensaje.contains('invalid_credentials')) {
      return 'Correo o contraseña incorrectos.';
    }
    if (mensaje.contains('password should be at least')) {
      return 'La contraseña debe tener al menos 6 caracteres.';
    }
    if (mensaje.contains('unable to validate email') ||
        mensaje.contains('invalid email')) {
      return 'El correo ingresado no es válido.';
    }
    if (mensaje.contains('email not confirmed')) {
      return 'Tu correo aún no está confirmado. Puedes seguir usando la app; '
          'la confirmación es opcional.';
    }
    return 'Ocurrió un problema: ${error.message}';
  }
  return 'Ocurrió un problema inesperado. Intenta de nuevo.';
}
