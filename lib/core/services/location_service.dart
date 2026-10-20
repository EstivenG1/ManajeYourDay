import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  LocationService._();

  static Future<Position> currentPosition() async {
    if (kIsWeb ||
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      // Supported platforms.
    } else {
      throw UnsupportedError(
        'La ubicación está disponible en Android, iOS y navegadores seguros.',
      );
    }

    if (!await Geolocator.isLocationServiceEnabled()) {
      throw StateError('Activa la ubicación del dispositivo para continuar.');
    }

    var permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
    }
    if (permiso == LocationPermission.denied ||
        permiso == LocationPermission.deniedForever) {
      throw StateError(
        'Permite el acceso a la ubicación para guardar este lugar.',
      );
    }

    return Geolocator.getCurrentPosition(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      ),
    );
  }
}
