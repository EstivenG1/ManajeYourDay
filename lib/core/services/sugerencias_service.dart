import '../supabase/supabase_config.dart';

/// Maneja las sugerencias de autocompletado (tabla `sugerencias_texto`).
/// Se usa tanto para títulos de tareas como, más adelante, para
/// descripciones y categorías de gastos — por eso recibe `contexto`
/// como parámetro en vez de estar hardcodeado a tareas.
class SugerenciasService {
  /// Trae las sugerencias del usuario para un contexto dado, ordenadas
  /// por las más usadas primero.
  static Future<List<String>> obtener(String contexto, {int limite = 20}) async {
    final userId = supabase.auth.currentUser!.id;
    final data = await supabase
        .from('sugerencias_texto')
        .select('valor')
        .eq('usuario_id', userId)
        .eq('contexto', contexto)
        .order('veces_usado', ascending: false)
        .limit(limite);

    return (data as List).map((e) => e['valor'] as String).toList();
  }

  /// Registra que el usuario usó este valor: si ya existía, le suma 1 a
  /// veces_usado; si no, lo crea. Así el autocompletado va aprendiendo.
  static Future<void> registrarUso(String contexto, String valor) async {
    final texto = valor.trim();
    if (texto.isEmpty) return;

    final userId = supabase.auth.currentUser!.id;

    final existente = await supabase
        .from('sugerencias_texto')
        .select('id, veces_usado')
        .eq('usuario_id', userId)
        .eq('contexto', contexto)
        .eq('valor', texto)
        .maybeSingle();

    if (existente == null) {
      await supabase.from('sugerencias_texto').insert({
        'usuario_id': userId,
        'contexto': contexto,
        'valor': texto,
        'veces_usado': 1,
      });
    } else {
      await supabase
          .from('sugerencias_texto')
          .update({
            'veces_usado': (existente['veces_usado'] as int) + 1,
            'ultima_vez': DateTime.now().toIso8601String(),
          })
          .eq('id', existente['id']);
    }
  }
}
