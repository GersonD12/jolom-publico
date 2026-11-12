/// Plataforma móvil cuya política de actualización se está evaluando.
enum AppUpdatePlatform { ios, android }

/// Versión instalada de la aplicación.
class InstalledAppVersion {
  const InstalledAppVersion({required this.version});

  final String version;
}

/// Configuración remota de actualización obligatoria para una plataforma.
class AppUpdatePolicy {
  const AppUpdatePolicy({
    required this.enabled,
    required this.requiredVersion,
    required this.storeUrl,
    required this.releaseNotes,
  });

  const AppUpdatePolicy.disabled()
    : enabled = false,
      requiredVersion = '',
      storeUrl = '',
      releaseNotes = '';

  final bool enabled;
  final String requiredVersion;
  final String storeUrl;
  final String releaseNotes;

  /// Devuelve `true` cuando la versión instalada es anterior a la requerida.
  ///
  /// Una versión remota inválida no bloquea la app para evitar un bloqueo
  /// accidental causado por una configuración manual mal formada.
  bool requiresUpdate(InstalledAppVersion installed) {
    if (!enabled) return false;

    final installedParts = _parseVersion(installed.version);
    final requiredParts = _parseVersion(requiredVersion);
    if (installedParts == null || requiredParts == null) return false;

    final length = installedParts.length > requiredParts.length
        ? installedParts.length
        : requiredParts.length;
    for (var index = 0; index < length; index++) {
      final installedPart = index < installedParts.length
          ? installedParts[index]
          : 0;
      final requiredPart = index < requiredParts.length
          ? requiredParts[index]
          : 0;
      if (installedPart < requiredPart) return true;
      if (installedPart > requiredPart) return false;
    }

    return false;
  }

  static List<int>? _parseVersion(String value) {
    final normalized = value.trim().split(RegExp(r'[-+]')).first;
    if (normalized.isEmpty) return null;
    final rawParts = normalized.split('.');
    final parts = <int>[];
    for (final rawPart in rawParts) {
      final part = int.tryParse(rawPart);
      if (part == null || part < 0) return null;
      parts.add(part);
    }
    return parts;
  }
}

/// Resultado listo para presentación de la evaluación de versión.
class AppUpdateStatus {
  const AppUpdateStatus({
    required this.policy,
    required this.installed,
    required this.updateRequired,
  });

  final AppUpdatePolicy policy;
  final InstalledAppVersion installed;
  final bool updateRequired;
}
