import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jolom/core/providers/app_color_palette_provider.dart';
import 'package:jolom/core/providers/hour_format_provider.dart';
import 'package:jolom/core/providers/theme_mode_provider.dart';
import 'package:jolom/core/theme/theme.dart';
import 'package:jolom/core/utils/app_scroll_padding.dart';
import 'package:jolom/shared/widgets/soft_card_widget.dart';

/// Preferencias visuales de la aplicación.
class AppearanceScreen extends ConsumerWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final hourFormat = ref.watch(hourFormatProvider);
    final colorPalette = ref.watch(appColorPaletteProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Apariencia')),
      body: ListView(
        padding: appScrollPadding(context, horizontal: 16, vertical: 16),
        children: [
          SoftCardWidget(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tema de la aplicación',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'Elige cómo quieres ver Jolom.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.system,
                      label: Text('Sistema'),
                      icon: Icon(Icons.brightness_auto_outlined),
                    ),
                    ButtonSegment(
                      value: ThemeMode.light,
                      label: Text('Claro'),
                      icon: Icon(Icons.light_mode_outlined),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      label: Text('Oscuro'),
                      icon: Icon(Icons.dark_mode_outlined),
                    ),
                  ],
                  selected: {themeMode},
                  onSelectionChanged: (selected) {
                    ref
                        .read(themeModeProvider.notifier)
                        .setMode(selected.first);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SoftCardWidget(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Color de la app', style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  'Selecciona una paleta incluida en Jolom.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                for (
                  var index = 0;
                  index < AppColorPalette.values.length;
                  index++
                ) ...[
                  _ColorPaletteOption(
                    palette: AppColorPalette.values[index],
                    selected: colorPalette == AppColorPalette.values[index],
                    brightness: theme.brightness,
                    onTap: () {
                      ref
                          .read(appColorPaletteProvider.notifier)
                          .setPalette(AppColorPalette.values[index]);
                    },
                  ),
                  if (index < AppColorPalette.values.length - 1)
                    const SizedBox(height: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          SoftCardWidget(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Formato de hora', style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  'Define cómo se muestran las horas en la app.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                SegmentedButton<HourFormatPreference>(
                  segments: const [
                    ButtonSegment(
                      value: HourFormatPreference.system,
                      label: Text('Sistema'),
                      icon: Icon(Icons.phonelink_setup_outlined),
                    ),
                    ButtonSegment(
                      value: HourFormatPreference.h12,
                      label: Text('12 h'),
                      icon: Icon(Icons.access_time),
                    ),
                    ButtonSegment(
                      value: HourFormatPreference.h24,
                      label: Text('24 h'),
                      icon: Icon(Icons.schedule),
                    ),
                  ],
                  selected: {hourFormat},
                  onSelectionChanged: (selected) {
                    ref
                        .read(hourFormatProvider.notifier)
                        .setPreference(selected.first);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Opción local con muestra de los tres colores principales de la paleta.
class _ColorPaletteOption extends StatelessWidget {
  const _ColorPaletteOption({
    required this.palette,
    required this.selected,
    required this.brightness,
    required this.onTap,
  });

  final AppColorPalette palette;
  final bool selected;
  final Brightness brightness;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preview = palette.colorScheme(brightness);

    return Semantics(
      button: true,
      selected: selected,
      label: '${palette.label}. ${palette.description}',
      excludeSemantics: true,
      child: SoftCardWidget(
        onTap: onTap,
        elevated: selected,
        color: selected
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.72)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSpacing.minTapTarget),
          child: Row(
            children: [
              _PaletteSwatches(colorScheme: preview),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(palette.label, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      palette.description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                color: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaletteSwatches extends StatelessWidget {
  const _PaletteSwatches({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final colors = [
      colorScheme.primary,
      colorScheme.secondary,
      colorScheme.tertiary,
    ];

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < colors.length; index++) ...[
          Container(
            width: 16,
            height: 32,
            decoration: BoxDecoration(
              color: colors[index],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.outline.withValues(alpha: 0.22),
              ),
            ),
          ),
          if (index < colors.length - 1) const SizedBox(width: 3),
        ],
      ],
    );
  }
}
