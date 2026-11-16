import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manage_your_day/core/auth/auth_errors.dart';

void main() {
  test('explains Android Google OAuth configuration errors', () {
    final error = PlatformException(
      code: 'sign_in_failed',
      message: 'com.google.android.gms.common.api.ApiException: 10: ',
    );

    expect(
      mensajeErrorAuth(error),
      contains('huella SHA-1 del cliente OAuth'),
    );
  });

  test('gives a retryable message for Google network errors', () {
    final error = PlatformException(code: 'network_error');

    expect(mensajeErrorAuth(error), contains('Revisa tu conexión'));
  });

  test('suggests checking both OAuth clients for Google sign-in failures', () {
    final error = PlatformException(code: 'sign_in_failed');

    expect(mensajeErrorAuth(error), contains('Supabase use el mismo cliente web'));
  });
}
