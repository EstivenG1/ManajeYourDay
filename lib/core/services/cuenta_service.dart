
import '../supabase/supabase_config.dart';

class CuentaService {
  /// Llama a la Edge Function 'eliminar-cuenta'. Lanza una excepción
  /// con un mensaje legible si algo falla; si no lanza nada, quiere
  /// decir que la cuenta ya fue eliminada en el servidor.
  static Future<void> eliminarCuentaDefinitivamente() async {
    try {
      // Inicia el proceso de eliminación de la cuenta.
      print('🟡 Iniciando eliminación de cuenta...');

      // Comprobamos que exista una sesión activa antes de intentar
      // eliminar la cuenta.
      final session = supabase.auth.currentSession;

      print('🟡 Sesión existe: ${session != null}');
      print('🟡 Usuario: ${session?.user.id}');

      if (session == null) {
        throw Exception('No hay una sesión activa.');
      }

      // Llamamos a la Edge Function 'eliminar-cuenta'.
      // La función se ejecuta en el servidor de Supabase y es la
      // encargada de eliminar definitivamente al usuario.
      final respuesta = await supabase.functions.invoke(
        'eliminar-cuenta',
      );

      print('🟢 Status: ${respuesta.status}');
      print('🟢 Data: ${respuesta.data}');

      final datos = respuesta.data;

      // Comprobamos si Supabase devolvió un error dentro de la respuesta.
      final huboError = datos is Map && datos['error'] != null;

      if (respuesta.status != 200 || huboError) {
        final mensaje = (datos is Map && datos['error'] != null)
            ? datos['error'].toString()
            : 'No se pudo eliminar la cuenta '
                '(código ${respuesta.status}).';

        throw Exception(mensaje);
      }

      // La cuenta ya fue eliminada correctamente del servidor.
      print('✅ Cuenta eliminada correctamente.');

      // Cerramos la sesión local.
      // Esto elimina la sesión almacenada en Flutter/Supabase.
      await supabase.auth.signOut();

      print('✅ Sesión cerrada correctamente.');
    } catch (e) {
      // Mostramos el error en la consola para facilitar el diagnóstico.
      print('🔴 Error eliminando cuenta: $e');

      // Volvemos a lanzar la excepción para que la pantalla pueda
      // mostrar el mensaje de error al usuario.
      rethrow;
    }
  }
}
