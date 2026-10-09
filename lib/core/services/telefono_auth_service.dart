import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase/supabase_config.dart';

class CuentaDisponible {
  final String idEspecial;
  final String nombre;

  CuentaDisponible({
    required this.idEspecial,
    required this.nombre,
  });
}

/// Resultado general de la verificación.
sealed class ResultadoVerificacion {}

/// El teléfono no tiene cuenta y debe completar el registro.
class RequiereRegistro extends ResultadoVerificacion {
  final String otpId;

  RequiereRegistro(this.otpId);
}

/// El teléfono tiene varias cuentas y debe elegir una.
class RequiereIdEspecial extends ResultadoVerificacion {
  final String otpId;
  final List<CuentaDisponible> cuentas;

  RequiereIdEspecial({
    required this.otpId,
    required this.cuentas,
  });
}

/// El backend ya preparó una sesión para Supabase Auth.
class SesionLista extends ResultadoVerificacion {
  final String correo;
  final String emailOtp;

  SesionLista({
    required this.correo,
    required this.emailOtp,
  });
}

class TelefonoAuthService {
  /// Solicita un nuevo código de verificación.
  static Future<void> pedirCodigo(
    String telefono, {
    String canal = 'whatsapp',
  }) async {
    final resp = await supabase.functions.invoke(
      'send-verification-code',
      body: {
        'telefono': telefono,
        'canal': canal,
      },
    );

    final datos = resp.data;

    if (datos is! Map) {
      throw Exception('Respuesta inválida del servidor.');
    }

    if (datos['ok'] != true) {
      throw Exception(
        datos['error'] ?? 'No se pudo enviar el código.',
      );
    }
  }

  /// Verifica el código recibido por WhatsApp.
  static Future<ResultadoVerificacion> verificarCodigo(
    String telefono,
    String codigo,
  ) async {
    final resp = await supabase.functions.invoke(
      'verify-code',
      body: {
        'telefono': telefono,
        'codigo': codigo,
      },
    );

    final datos = resp.data;

    if (datos is! Map) {
      throw Exception('Respuesta inválida del servidor.');
    }

    if (datos['ok'] != true) {
      throw Exception(
        datos['error'] ?? 'Código incorrecto.',
      );
    }

    // No existe cuenta para este teléfono.
    if (datos['requiere_registro'] == true) {
      final otpId = datos['otp_id'];

      if (otpId is! String || otpId.isEmpty) {
        throw Exception('El servidor no devolvió el identificador OTP.');
      }

      return RequiereRegistro(otpId);
    }

    // Existen 2 o 3 cuentas asociadas al teléfono.
    if (datos['requiere_id_especial'] == true) {
      final otpId = datos['otp_id'];

      if (otpId is! String || otpId.isEmpty) {
        throw Exception('El servidor no devolvió el identificador OTP.');
      }

      final cuentasRaw = datos['cuentas'];

      if (cuentasRaw is! List) {
        throw Exception('El servidor no devolvió las cuentas.');
      }

      final cuentas = cuentasRaw.map<CuentaDisponible>((cuenta) {
        final mapa = Map<String, dynamic>.from(cuenta);

        return CuentaDisponible(
          idEspecial: mapa['id_especial']?.toString() ?? '',
          nombre: mapa['nombre']?.toString() ?? 'Cuenta',
        );
      }).where((cuenta) {
        return cuenta.idEspecial.isNotEmpty;
      }).toList();

      if (cuentas.isEmpty) {
        throw Exception('No se encontraron cuentas disponibles.');
      }

      return RequiereIdEspecial(
        otpId: otpId,
        cuentas: cuentas,
      );
    }

    // Una sola cuenta: el backend ya preparó la sesión.
    final sesion = datos['sesion'];

    if (sesion is! Map) {
      throw Exception('El servidor no devolvió la sesión.');
    }

    final correo = sesion['correo']?.toString();
    final emailOtp = sesion['email_otp']?.toString();

    if (correo == null ||
        correo.isEmpty ||
        emailOtp == null ||
        emailOtp.isEmpty) {
      throw Exception('La sesión devuelta por el servidor es inválida.');
    }

    return SesionLista(
      correo: correo,
      emailOtp: emailOtp,
    );
  }

  /// Selecciona una de las cuentas después de haber verificado el OTP.
  ///
  /// IMPORTANTE:
  /// aquí NO se vuelve a mandar el código.
  /// Se utiliza el otpId que el servidor entregó después
  /// de verificar correctamente el OTP.
  static Future<SesionLista> elegirCuenta(
    String telefono,
    String otpId,
    String idEspecial,
  ) async {
    final resp = await supabase.functions.invoke(
      'verify-code',
      body: {
        'telefono': telefono,
        'otp_id': otpId,
        'id_especial': idEspecial,
      },
    );

    final datos = resp.data;

    if (datos is! Map) {
      throw Exception('Respuesta inválida del servidor.');
    }

    if (datos['ok'] != true) {
      throw Exception(
        datos['error'] ?? 'No se pudo seleccionar la cuenta.',
      );
    }

    final sesion = datos['sesion'];

    if (sesion is! Map) {
      throw Exception('El servidor no devolvió la sesión.');
    }

    final correo = sesion['correo']?.toString();
    final emailOtp = sesion['email_otp']?.toString();

    if (correo == null ||
        correo.isEmpty ||
        emailOtp == null ||
        emailOtp.isEmpty) {
      throw Exception('La sesión devuelta por el servidor es inválida.');
    }

    return SesionLista(
      correo: correo,
      emailOtp: emailOtp,
    );
  }

  /// Completa el registro después de verificar el teléfono.
  static Future<SesionLista> completarRegistro(
    String telefono,
    String otpId,
    String nombre, {
    String? apellido,
    String? correo,
  }) async {
    final resp = await supabase.functions.invoke(
      'verify-code',
      body: {
        'telefono': telefono,
        'otp_id': otpId,
        'nombre': nombre,
        'apellido': apellido,
        'correo': correo,
      },
    );

    final datos = resp.data;

    if (datos is! Map) {
      throw Exception('Respuesta inválida del servidor.');
    }

    if (datos['ok'] != true) {
      throw Exception(
        datos['error'] ?? 'No se pudo crear la cuenta.',
      );
    }

    final sesion = datos['sesion'];

    if (sesion is! Map) {
      throw Exception('El servidor no devolvió la sesión.');
    }

    final correoSesion = sesion['correo']?.toString();
    final emailOtp = sesion['email_otp']?.toString();

    if (correoSesion == null ||
        correoSesion.isEmpty ||
        emailOtp == null ||
        emailOtp.isEmpty) {
      throw Exception('La sesión devuelta por el servidor es inválida.');
    }

    return SesionLista(
      correo: correoSesion,
      emailOtp: emailOtp,
    );
  }

  /// Convierte la sesión temporal preparada por el backend
  /// en una sesión real de Supabase Auth.
  static Future<void> establecerSesion(
    SesionLista sesion,
  ) async {
    final resultado = await supabase.auth.verifyOTP(
      email: sesion.correo,
      token: sesion.emailOtp,
      type: OtpType.magiclink,
    );

    if (resultado.session == null) {
      throw Exception(
        'Supabase no pudo establecer la sesión.',
      );
    }
  }
}