import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase/supabase_config.dart';

/// Inicia sesión con la cuenta de Google nativa y crea la sesión en Supabase.
class GoogleAuthService {
  static const String _webClientId =
      '599046597329-itedf1mce8lkjisc02i1i63kqklm81pm.apps.googleusercontent.com';

  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: _webClientId,
  );

  /// Retorna false si el usuario cancela el selector de cuentas.
  static Future<bool> iniciarSesion() async {
    final cuentaGoogle = await _googleSignIn.signIn();
    if (cuentaGoogle == null) return false;

    final authGoogle = await cuentaGoogle.authentication;
    final idToken = authGoogle.idToken;
    if (idToken == null) {
      throw const AuthException('No se pudo obtener el token de Google.');
    }

    final response = await supabase.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: authGoogle.accessToken,
    );

    final user = response.user;
    final metadata = user?.userMetadata ?? const <String, dynamic>{};
    final createdAt = DateTime.tryParse(user?.createdAt ?? '');
    final lastSignInAt = DateTime.tryParse(user?.lastSignInAt ?? '');
    if (user != null &&
        metadata['myd_welcome_pending'] == null &&
        createdAt != null &&
        lastSignInAt != null &&
        lastSignInAt.difference(createdAt).abs() < const Duration(minutes: 5)) {
      await supabase.auth.updateUser(
        UserAttributes(data: {'myd_welcome_pending': true}),
      );
    }

    return true;
  }
}
