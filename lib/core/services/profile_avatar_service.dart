import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase/supabase_config.dart';

class ProfileAvatarService {
  static Future<String?> resolve(String? storedValue) async {
    if (storedValue == null || storedValue.trim().isEmpty) return null;

    final value = storedValue.trim();
    final uri = Uri.tryParse(value);
    if (uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty) {
      return value;
    }

    try {
      return await supabase.storage
          .from('avatars')
          .createSignedUrl(value, 3600);
    } on StorageException catch (error) {
      if (error.statusCode == '404') return null;
      rethrow;
    }
  }
}
