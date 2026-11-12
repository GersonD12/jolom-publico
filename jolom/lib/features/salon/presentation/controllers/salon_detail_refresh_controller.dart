/// Evita recargas simultáneas o demasiado frecuentes de la ficha pública.
class SalonDetailRefreshController {
  SalonDetailRefreshController({
    this.minimumInterval = const Duration(seconds: 5),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final Duration minimumInterval;
  final DateTime Function() _clock;

  Future<void>? _inFlight;
  DateTime? _lastAcceptedAt;

  /// Ejecuta [refresh] una sola vez y comparte su resultado entre llamadas.
  ///
  /// Durante el intervalo mínimo devuelve inmediatamente, permitiendo que el
  /// gesto visual termine sin generar una nueva consulta al servidor.
  Future<void> run(Future<void> Function() refresh) async {
    final active = _inFlight;
    if (active != null) {
      await active;
      return;
    }

    final now = _clock();
    final lastAcceptedAt = _lastAcceptedAt;
    if (lastAcceptedAt != null &&
        now.difference(lastAcceptedAt) < minimumInterval) {
      return;
    }

    _lastAcceptedAt = now;
    final operation = Future<void>.sync(refresh);
    _inFlight = operation;
    try {
      await operation;
    } finally {
      if (identical(_inFlight, operation)) _inFlight = null;
    }
  }
}
