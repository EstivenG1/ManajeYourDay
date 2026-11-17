import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Convierte los errores de Supabase Auth en mensajes claros en español
/// para mostrárselos al usuario.
String mensajeErrorAuth(Object error) {
  if (error is PlatformException) {
    final detalle = error.message?.toLowerCase() ?? '';
    if (detalle.contains('apiexception: 10')) {
      return 'Google rechazó la configuración de esta app. Verifica el paquete '
          'Android y la huella SHA-1 del cliente OAuth en Google Cloud.';
    }

    switch (error.code) {
      case 'network_error':
        return 'No se pudo conectar con Google. Revisa tu conexión e intenta '
            'de nuevo.';
      case 'sign_in_failed':
        return 'No se pudo autenticar con Google. Verifica el cliente OAuth '
            'Android (paquete y SHA-1) y que Supabase use el mismo cliente web.';
      case 'sign_in_canceled':
        return 'Se canceló el inicio de sesión con Google.';
    }
  }

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
      return 'Tu correo aún no está confirmado. Confírmalo desde el enlace '
          'recibido y luego vuelve a iniciar sesión.';
    }
    return 'Ocurrió un problema: ${error.message}';
  }
  return 'Ocurrió un problema inesperado. Intenta de nuevo.';
}
