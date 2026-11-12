import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jolom/core/di/injection.dart';
import 'package:jolom/core/errors/user_facing_error.dart';
import 'package:jolom/core/providers/feature_providers.dart';
import 'package:jolom/core/providers/session_provider.dart';
import 'package:jolom/core/providers/user_directory_provider.dart';
import 'package:jolom/features/salon/domain/entities/salon_invitation_entity.dart';
import 'package:jolom/features/salon/domain/repositories/salon_repository.dart';

/// Invitaciones pendientes del usuario.
class InvitationsScreen extends ConsumerStatefulWidget {
  const InvitationsScreen({super.key});

  @override
  ConsumerState<InvitationsScreen> createState() => _InvitationsScreenState();
}

class _InvitationsScreenState extends ConsumerState<InvitationsScreen> {
  List<SalonInvitation> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = ref.read(sessionProvider).value?.id;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }
    final items = await getIt<SalonRepository>().listPendingInvitationsForUser(
      uid,
    );
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _respond(String id, bool accept) async {
    try {
      await getIt<SalonRepository>().respondToInvitation(
        invitationId: id,
        accept: accept,
      );
      ref.invalidate(membershipProvider);
      ref.invalidate(pendingInvitationsProvider);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(accept ? 'Invitación aceptada' : 'Rechazada')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFacingError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Invitaciones')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
          ? const Center(child: Text('No tienes invitaciones pendientes.'))
          : ListView.builder(
              itemCount: _items.length,
              itemBuilder: (context, i) {
                final inv = _items[i];
                final salonAsync = ref.watch(salonByIdProvider(inv.salonId));
                final salonTitle = salonAsync.when(
                  loading: () => '…',
                  error: (_, _) => 'Peluquería',
                  data: (salon) => salon?.name ?? 'Peluquería',
                );
                return Card(
                  margin: const EdgeInsets.all(12),
                  child: ListTile(
                    title: Text(salonTitle),
                    subtitle: Text('Vence: ${inv.expiresAt.toLocal()}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.check),
                          onPressed: () => _respond(inv.id, true),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => _respond(inv.id, false),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
