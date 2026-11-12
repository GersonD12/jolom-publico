import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jolom/core/di/injection.dart';
import 'package:jolom/core/errors/user_facing_error.dart';
import 'package:jolom/core/providers/feature_providers.dart';
import 'package:jolom/core/utils/app_scroll_padding.dart';
import 'package:jolom/features/salon/domain/entities/salon_membership_entity.dart';
import 'package:jolom/features/salon/domain/repositories/salon_repository.dart';
import 'package:jolom/shared/widgets/pill_button_widget.dart';

/// Equipo e invitaciones (propietario).
class TeamScreen extends ConsumerStatefulWidget {
  const TeamScreen({super.key});

  @override
  ConsumerState<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends ConsumerState<TeamScreen> {
  List<SalonMembership> _members = [];
  final _emailCtrl = TextEditingController();
  bool _loading = true;
  bool _inviting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final membership = ref.read(membershipProvider).value;
    if (membership == null) {
      setState(() => _loading = false);
      return;
    }
    final members = await getIt<SalonRepository>().listSalonMembers(
      membership.salonId,
      includePendingExit: true,
    );
    if (!mounted) return;
    setState(() {
      _members = members;
      _loading = false;
    });
  }

  Future<void> _invite() async {
    final membership = ref.read(membershipProvider).value;
    final email = _emailCtrl.text.trim();
    if (membership == null || email.isEmpty) return;
    setState(() => _inviting = true);
    try {
      await getIt<SalonRepository>().inviteBarber(
        salonId: membership.salonId,
        inviteeEmail: email,
      );
      _emailCtrl.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invitación enviada.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFacingError(e))));
    } finally {
      if (mounted) setState(() => _inviting = false);
    }
  }

  Future<void> _beginExit(String userId) async {
    try {
      final result = await getIt<SalonRepository>().beginMembershipExit(
        targetUserId: userId,
      );
      final future = (result['futureAppointments'] as List?)?.length ?? 0;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Salida pendiente. Citas futuras por resolver: $future',
          ),
        ),
      );
      await _load();
      ref.invalidate(membershipProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFacingError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final membership = ref.watch(membershipProvider).value;
    if (membership == null || !membership.isOwner) {
      return const Scaffold(
        body: Center(child: Text('Solo el propietario gestiona el equipo.')),
      );
    }
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Equipo')),
      body: ListView(
        padding: appScrollPadding(context, horizontal: 16, vertical: 16),
        children: [
          ..._members.map(
            (m) => ListTile(
              title: Text(m.userId),
              subtitle: Text('${m.role.labelEs} · ${m.status.labelEs}'),
              trailing: m.isOwner
                  ? null
                  : IconButton(
                      tooltip: 'Retirar',
                      icon: const Icon(Icons.person_remove_outlined),
                      onPressed: () => _beginExit(m.userId),
                    ),
            ),
          ),
          const Divider(height: 32),
          Text(
            'Invitar peluquero',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          TextField(
            controller: _emailCtrl,
            decoration: const InputDecoration(
              labelText: 'Email del usuario registrado',
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 12),
          PillButtonWidget(
            label: 'Enviar invitación',
            loading: _inviting,
            onPressed: _invite,
          ),
        ],
      ),
    );
  }
}
