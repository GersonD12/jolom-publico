import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jolom/app/routes/routes.dart';
import 'package:jolom/core/navigation/work_appointment_nav.dart';
import 'package:jolom/core/providers/app_color_palette_provider.dart';
import 'package:jolom/core/providers/theme_mode_provider.dart';
import 'package:jolom/core/theme/theme.dart';
import 'package:jolom/features/app_update/presentation/widgets/app_update_gate_widget.dart';
import 'package:jolom/services/fcm_service.dart';

/// Widget raíz de la aplicación (MaterialApp + GoRouter).
class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    final themeMode = ref.watch(themeModeProvider);
    final colorPalette = ref.watch(appColorPaletteProvider);

    return _FcmNavigationBinder(
      child: MaterialApp.router(
        title: 'Jolom',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightFor(colorPalette),
        darkTheme: AppTheme.darkFor(colorPalette),
        themeMode: themeMode,
        routerConfig: router,
        builder: (context, child) =>
            AppUpdateGate(child: child ?? const SizedBox.shrink()),
      ),
    );
  }
}

/// Enlaza taps de push FCM → destino explícito de la cita.
class _FcmNavigationBinder extends ConsumerStatefulWidget {
  const _FcmNavigationBinder({required this.child});

  final Widget child;

  @override
  ConsumerState<_FcmNavigationBinder> createState() =>
      _FcmNavigationBinderState();
}

class _FcmNavigationBinderState extends ConsumerState<_FcmNavigationBinder> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FcmService.attachAppointmentOpenHandler((appointmentId, openMode) {
        openAppointmentFromNotification(ref, appointmentId, openMode);
      });
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
