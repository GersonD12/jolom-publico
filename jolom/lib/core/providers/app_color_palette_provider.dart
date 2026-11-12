import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jolom/core/providers/shared_preferences_provider.dart';
import 'package:jolom/core/theme/app_color_palette.dart';

const _appColorPaletteKey = 'app_color_palette';

/// Paleta seleccionada y persistida únicamente en este dispositivo.
class AppColorPaletteNotifier extends Notifier<AppColorPalette> {
  @override
  AppColorPalette build() {
    final preferences = ref.watch(sharedPreferencesProvider);
    return AppColorPalette.fromStorage(
      preferences.getString(_appColorPaletteKey),
    );
  }

  Future<void> setPalette(AppColorPalette palette) async {
    if (palette == state) return;
    state = palette;
    final preferences = ref.read(sharedPreferencesProvider);
    await preferences.setString(_appColorPaletteKey, palette.storageValue);
  }
}

final appColorPaletteProvider =
    NotifierProvider<AppColorPaletteNotifier, AppColorPalette>(
      AppColorPaletteNotifier.new,
    );
