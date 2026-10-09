import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase/supabase_config.dart';

/// Inicio de sesión con Google, usando el flujo NATIVO (el selector de
/// cuenta de Google del propio sistema, no un navegador con redirección).
class GoogleAuthService {
  // Se pega aquí el ID de cliente WEB (no el de Android) que copiaste
  // de Google Cloud Console — es el mismo que pegaste en Supabase.
  static const String _webClientId = '599046597329-itedf1mce8lkjisc02i1i63kqklm81pm.apps.googleusercontent.com';

  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: _webClientId,
  );

  /// Devuelve true si el usuario completó el login. Devuelve false si
  /// canceló el selector de cuenta (eso no es un error, no hay que
  /// mostrar ningún mensaje en ese caso).
  static Future<bool> iniciarSesion() async {
    final cuentaGoogle = await _googleSignIn.signIn();
    if (cuentaGoogle == null) return false; // el usuario canceló

    final authGoogle = await cuentaGoogle.authentication;
    final idToken = authGoogle.idToken;
    final accessToken = authGoogle.accessToken;

    if (idToken == null) {
      throw const AuthException('No se pudo obtener el token de Google.');
    }

    await supabase.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );

    return true;
  }
}
