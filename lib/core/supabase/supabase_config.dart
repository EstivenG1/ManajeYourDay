import 'package:supabase_flutter/supabase_flutter.dart';

/// Configuración de conexión a Supabase.
class SupabaseConfig {
  SupabaseConfig._();

  static const String supabaseUrl =
      'https://lciwjsrheewewgtasrmt.supabase.co';

  static const String supabasePublishableKey =
      'sb_publishable_qCKguGUejGoZfwpDYOvo9w_y03nJYb0';

  static Future<void> init() async {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabasePublishableKey,
    );
  }
}

/// Acceso al cliente de Supabase desde cualquier parte de la app.
final SupabaseClient supabase = Supabase.instance.client;