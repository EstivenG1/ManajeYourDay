import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase/supabase_config.dart';

class ProfileBootstrapService {
  static Future<void> ensureExists(User user) async {
    final existing = await supabase
        .from('perfiles')
        .select('id')
        .eq('id', user.id)
        .maybeSingle();
    if (existing != null) return;

    final metadata = user.userMetadata ?? const <String, dynamic>{};
    final email = user.email;
    if (email == null || email.isEmpty) {
      throw StateError('The signed-in user has no email for profile creation.');
    }

    await supabase
        .from('perfiles')
        .upsert(
          {
            'id': user.id,
            'nombre':
                _metadataText(metadata, const [
                  'nombre',
                  'full_name',
                  'name',
                ]) ??
                'Usuario',
            'apellido': _metadataText(metadata, const [
              'apellido',
              'family_name',
            ]),
            'telefono': _metadataText(metadata, const ['telefono', 'phone']),
            'correo': email,
            'avatar_url': _metadataText(metadata, const [
              'avatar_url',
              'picture',
            ]),
          },
          onConflict: 'id',
          ignoreDuplicates: true,
        );

    final created = await supabase
        .from('perfiles')
        .select('id')
        .eq('id', user.id)
        .maybeSingle();
    if (created == null) {
      throw StateError('The profile was not created for the signed-in user.');
    }
  }

  static String? _metadataText(
    Map<String, dynamic> metadata,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = metadata[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }
}
