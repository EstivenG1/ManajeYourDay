import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Configuración de conexión a Supabase.
class SupabaseConfig {
  SupabaseConfig._();

  static const String supabaseUrl = 'https://lciwjsrheewewgtasrmt.supabase.co';

  static const String supabasePublishableKey =
      'sb_publishable_qCKguGUejGoZfwpDYOvo9w_y03nJYb0';

  static const String mercadoPagoPublicKey =
      'APP_USR-472b9ada-02ad-4c71-b45d-8d3595d7e780';

  static const String passwordRecoveryRedirect = 'https://manageyourday.app/';

  static const String authCallbackRedirect = 'io.supabase.myd://auth-callback';
  static const String emailConfirmationRedirect = 'https://manageyourday.app/';

  static String passwordRecoveryRedirectFor({
    required bool isWeb,
    required Uri currentUri,
  }) {
    if (!isWeb) return passwordRecoveryRedirect;
    return '${currentUri.origin}${currentUri.path}';
  }

  static String authCallbackRedirectFor({
    required bool isWeb,
    required Uri currentUri,
  }) {
    if (!isWeb) return authCallbackRedirect;
    return '${currentUri.origin}${currentUri.path}';
  }

  static String get currentPasswordRecoveryRedirect =>
      passwordRecoveryRedirectFor(isWeb: kIsWeb, currentUri: Uri.base);

  static String get currentAuthCallbackRedirect =>
      authCallbackRedirectFor(isWeb: kIsWeb, currentUri: Uri.base);

  static String emailConfirmationRedirectFor({
    required bool isWeb,
    required Uri currentUri,
  }) {
    if (!isWeb) return emailConfirmationRedirect;
    return '${currentUri.origin}${currentUri.path}';
  }

  static String get currentEmailConfirmationRedirect =>
      emailConfirmationRedirectFor(isWeb: kIsWeb, currentUri: Uri.base);

  static bool _passwordRecoveryRedirectReceived = false;

  static bool isPasswordRecoveryRedirect(Uri uri) =>
      uri.scheme == 'io.supabase.myd' && uri.host == 'reset-password';

  static bool detectAuthRedirect(Uri uri) {
    final isPasswordRecovery = isPasswordRecoveryRedirect(uri);
    if (isPasswordRecovery) {
      _passwordRecoveryRedirectReceived = true;
    }
    return _hasAuthParameters(uri) || isPasswordRecovery;
  }

  static bool consumePasswordRecoveryRedirect() {
    final received = _passwordRecoveryRedirectReceived;
    _passwordRecoveryRedirectReceived = false;
    return received;
  }

  static Future<void> init() async {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabasePublishableKey,
      authOptions: FlutterAuthClientOptions(
        detectSessionInUriPredicate: detectAuthRedirect,
      ),
    );
  }

  static bool _hasAuthParameters(Uri uri) {
    final fragmentParameters = Uri.splitQueryString(uri.fragment);
    return uri.queryParameters.containsKey('access_token') ||
        uri.queryParameters.containsKey('code') ||
        uri.queryParameters.containsKey('error') ||
        uri.queryParameters.containsKey('error_code') ||
        uri.queryParameters.containsKey('error_description') ||
        fragmentParameters.containsKey('access_token') ||
        fragmentParameters.containsKey('code') ||
        fragmentParameters.containsKey('error') ||
        fragmentParameters.containsKey('error_code') ||
        fragmentParameters.containsKey('error_description');
  }
}

/// Acceso al cliente de Supabase desde cualquier parte de la app.
final SupabaseClient supabase = Supabase.instance.client;
