import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jolom/core/di/injection.dart';
import 'package:jolom/core/domain/entities/user_data_status.dart';
import 'package:jolom/core/domain/entities/user_entity.dart';
import 'package:jolom/core/errors/user_facing_error.dart';
import 'package:jolom/core/providers/feature_providers.dart';
import 'package:jolom/core/providers/session_provider.dart';
import 'package:jolom/core/utils/app_scroll_padding.dart';
import 'package:jolom/features/auth/domain/repositories/auth_repository.dart';
import 'package:jolom/shared/widgets/app_modal_bottom_sheet.dart';
import 'package:jolom/shared/widgets/notifications_icon_button_widget.dart';
import 'package:jolom/shared/widgets/pill_button_widget.dart';
import 'package:jolom/shared/widgets/soft_card_widget.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Versión de la app desde `pubspec.yaml` (vía package_info_plus).
final _appVersionProvider = FutureProvider<String>((ref) async {
  ref.keepAlive();
  final info = await PackageInfo.fromPlatform();
  return info.version;
});

/// Perfil cliente + conversión a peluquero / invitaciones.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  Future<void> _requestDeletion() async {
    final membership = ref.read(membershipProvider).value;
    final isOwner = membership?.isOwner == true;
    final isBarber = membership != null && !isOwner;
    final message = isOwner
        ? 'Tu cuenta y tu negocio se ocultarán de inmediato. Se eliminarán '
              'servicios, imágenes, horarios, equipo y citas. Los registros '
              'necesarios para estadísticas quedarán sin datos personales ni '
              'referencias que permitan identificarte.'
        : isBarber
        ? 'Saldrás automáticamente del equipo. Tus citas futuras como '
              'profesional se cancelarán y el historial se conservará solo '
              'de forma anonimizada para el negocio.'
        : 'Tus citas futuras se cancelarán. El historial que deba '
              'conservar el negocio quedará anonimizado, sin nombre, correo, '
              'teléfono, foto ni referencias a tu cuenta.';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar cuenta permanentemente'),
        content: Text(
          '$message\n\nLa eliminación no puede deshacerse. Si vuelves a '
          'registrarte después, será una cuenta nueva.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            child: const Text('Eliminar definitivamente'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await FirebaseFunctions.instance
          .httpsCallable('requestAccountDeletion')
          .call(<String, dynamic>{});
      if (!mounted) return;
      ref.read(pendingBookingProvider.notifier).set(null);
      ref.read(highlightedAppointmentIdProvider.notifier).clear();
      ref.read(highlightedClientAppointmentIdProvider.notifier).clear();
      ref.read(appModeProvider.notifier).setMode(AppMode.client);
      context.go('/account-deletion');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFacingError(e))));
    }
  }

  void _openEditNameSheet(String? currentName) {
    showAppModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) =>
          _EditDisplayNameBottomSheet(initialName: currentName?.trim() ?? ''),
    );
  }

  Future<void> _rehydrateProfile() async {
    ref.invalidate(hydratedSessionProvider);
    await ref.read(hydratedSessionProvider.future);
  }

  UserDataStatus _statusOf(AsyncValue<UserEntity?> async) {
    return async.when(
      data: (_) => UserDataStatus.loaded,
      loading: () => UserDataStatus.loading,
      error: (_, _) => UserDataStatus.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    final authSession = ref.watch(sessionProvider).value;
    if (authSession == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Perfil')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.person_outline,
                  size: 56,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Únete para gestionar tu perfil',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Inicia sesión o crea una cuenta para ver tu perfil, notificaciones y más.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  // go (no push): evita Duplicate GlobalKey al volver a /profile
                  // con el shell aún debajo del login.
                  onPressed: () => context.go('/login?from=/profile'),
                  child: const Text('Iniciar sesión'),
                ),
                const SizedBox(height: 32),
                const _AppVersionLabel(),
              ],
            ),
          ),
        ),
      );
    }

    final hydratedAsync = ref.watch(hydratedSessionProvider);
    final status = _statusOf(hydratedAsync);
    // Auth como fallback mientras hidrata o si falla la lectura.
    final profile = hydratedAsync.value ?? authSession;
    final membership = ref.watch(membershipProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil'),
        actions: [
          const NotificationsIconButtonWidget(),
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: () => getIt<AuthRepository>().signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _rehydrateProfile,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: appScrollPadding(context, horizontal: 16, vertical: 16),
          children: [
            if (status == UserDataStatus.error) ...[
              SoftCardWidget(
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'No se pudo actualizar el perfil. Desliza para reintentar.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            SoftCardWidget(
              child: Row(
                children: [
                  _SessionAvatar(
                    displayName: profile.displayName,
                    photoUrl: profile.photoUrl,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                (profile.displayName != null &&
                                        profile.displayName!.trim().isNotEmpty)
                                    ? profile.displayName!.trim()
                                    : 'Sin nombre',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Editar nombre',
                              onPressed: () =>
                                  _openEditNameSheet(profile.displayName),
                              icon: const Icon(Icons.edit_outlined, size: 20),
                              visualDensity: VisualDensity.compact,
                              constraints: const BoxConstraints(
                                minWidth: 40,
                                minHeight: 40,
                              ),
                            ),
                          ],
                        ),
                        if (profile.email != null &&
                            profile.email!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            profile.email!,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                        if (profile.phone != null &&
                            profile.phone!.trim().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            profile.phone!.trim(),
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          membership != null && membership.isActive
                              ? 'También eres ${membership.isOwner ? 'propietario' : 'peluquero'}'
                              : 'Cuenta cliente',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SoftCardWidget(
              onTap: () => context.push('/profile/appearance'),
              child: Row(
                children: [
                  Icon(
                    Icons.palette_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Apariencia',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tema y formato de hora',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SoftCardWidget(
              onTap: () => context.push('/profile/business'),
              child: Row(
                children: [
                  Icon(
                    Icons.storefront_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mi negocio',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          membership != null && membership.isActive
                              ? 'Accede al modo trabajo'
                              : 'Crea y administra tu peluquería',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Fase 1: reportes deshabilitados; reactivar al implementar moderación.
            // TextButton(
            //   onPressed: () => context.push('/report'),
            //   child: const Text('Reportar un problema'),
            // ),
            TextButton(
              onPressed: _requestDeletion,
              child: const Text('Solicitar eliminación de cuenta'),
            ),
            const SizedBox(height: 24),
            const _AppVersionLabel(),
          ],
        ),
      ),
    );
  }
}

/// Etiqueta de versión al pie del perfil.
class _AppVersionLabel extends ConsumerWidget {
  const _AppVersionLabel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final versionAsync = ref.watch(_appVersionProvider);
    final version = versionAsync.asData?.value;
    if (version == null || version.isEmpty) {
      return const SizedBox.shrink();
    }

    return Center(
      child: Text(
        'Versión $version',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Formulario para editar el nombre visible del usuario.
class _EditDisplayNameBottomSheet extends ConsumerStatefulWidget {
  const _EditDisplayNameBottomSheet({required this.initialName});

  final String initialName;

  @override
  ConsumerState<_EditDisplayNameBottomSheet> createState() =>
      _EditDisplayNameBottomSheetState();
}

class _EditDisplayNameBottomSheetState
    extends ConsumerState<_EditDisplayNameBottomSheet> {
  late final TextEditingController _nameCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    try {
      await getIt<AuthRepository>().updateDisplayName(name);
      ref.invalidate(hydratedSessionProvider);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Nombre actualizado.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFacingError(e))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(left: 16, right: 16, bottom: bottomInset + 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Editar nombre',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nameCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _save(),
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
            const SizedBox(height: 20),
            PillButtonWidget(
              label: 'Guardar',
              loading: _saving,
              onPressed: _save,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// Avatar del usuario de sesión (no usa directorio: es el autenticado).
class _SessionAvatar extends StatelessWidget {
  const _SessionAvatar({required this.displayName, required this.photoUrl});

  final String? displayName;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    const radius = 32.0;
    final url = photoUrl?.trim();
    if (url != null && url.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: CachedNetworkImageProvider(url),
      );
    }
    return CircleAvatar(
      radius: radius,
      child: Text(_initials(displayName), style: const TextStyle(fontSize: 22)),
    );
  }

  String _initials(String? name) {
    if (name == null || name.trim().isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }
}
