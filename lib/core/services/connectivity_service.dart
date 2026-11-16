import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Monitorea el estado de conectividad de red del dispositivo.
/// Permite a la UI mostrar indicadores y prevenir operaciones sin conexión.
class ConnectivityService {
  ConnectivityService._();

  static final ConnectivityService instance = ConnectivityService._();

  final Connectivity _connectivity = Connectivity();
  bool _isConnected = true;
  final List<void Function(bool connected)> _listeners = [];

  StreamSubscription<List<ConnectivityResult>>? _subscription;

  bool get isConnected => _isConnected;

  /// Inicializa el monitoreo de conectividad.
  Future<void> init() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _isConnected = _resultsIndicateConnection(results);
    } catch (_) {
      _isConnected = true;
    }

    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      final connected = _resultsIndicateConnection(results);
      if (connected != _isConnected) {
        _isConnected = connected;
        for (final listener in List.from(_listeners)) {
          listener(_isConnected);
        }
      }
    });
  }

  /// Detiene el monitoreo.
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _listeners.clear();
  }

  /// Registra un listener que se invoca cuando cambia la conectividad.
  void onConnectivityChanged(void Function(bool connected) listener) {
    _listeners.add(listener);
  }

  bool _resultsIndicateConnection(List<ConnectivityResult> results) {
    if (results.isEmpty) return true;
    return !results.contains(ConnectivityResult.none);
  }

  /// Ejecuta una acción solo si hay conectividad, con reintento opcional.
  Future<T?> whenConnected<T>(Future<T> Function() action, {int maxRetries = 3}) async {
    if (!_isConnected) {
      return null;
    }
    for (var i = 0; i <= maxRetries; i++) {
      try {
        return await action();
      } catch (e) {
        if (i == maxRetries) rethrow;
        await Future.delayed(const Duration(seconds: 1));
      }
    }
    return null;
  }
}
