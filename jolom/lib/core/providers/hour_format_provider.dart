import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preferencia visual de formato de hora (solo UI; no afecta Firestore).
enum HourFormatPreference {
  /// Usa [MediaQuery.alwaysUse24HourFormat] del dispositivo.
  system,

  /// Fuerza reloj de 12 horas (p. ej. 1:30 PM).
  h12,

  /// Fuerza reloj de 24 horas (p. ej. 13:30).
  h24,
}

const _hourFormatKey = 'hour_format';

/// Preferencia de formato de hora persistida en el dispositivo.
class HourFormatNotifier extends Notifier<HourFormatPreference> {
  @override
  HourFormatPreference build() {
    _load();
    return HourFormatPreference.system;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_hourFormatKey);
    if (raw == null) return;
    final mode = _fromStorage(raw);
    if (mode != state) state = mode;
  }

  Future<void> setPreference(HourFormatPreference preference) async {
    state = preference;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_hourFormatKey, _toStorage(preference));
  }

  static String _toStorage(HourFormatPreference preference) =>
      switch (preference) {
        HourFormatPreference.h12 => 'h12',
        HourFormatPreference.h24 => 'h24',
        HourFormatPreference.system => 'system',
      };

  static HourFormatPreference _fromStorage(String raw) => switch (raw) {
        'h12' => HourFormatPreference.h12,
        'h24' => HourFormatPreference.h24,
        _ => HourFormatPreference.system,
      };
}

final hourFormatProvider =
    NotifierProvider<HourFormatNotifier, HourFormatPreference>(
  HourFormatNotifier.new,
);
