import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jolom/core/di/injection.dart';
import 'package:jolom/core/providers/feature_providers.dart';
import 'package:jolom/core/providers/session_provider.dart';
import 'package:jolom/core/utils/app_scroll_padding.dart';
import 'package:jolom/features/appointment/domain/repositories/appointment_repository.dart';

/// Estadísticas personales o globales (propietario).
class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  Map<String, dynamic>? _barberStats;
  Map<String, dynamic>? _salonStats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = ref.read(sessionProvider).value?.id;
    final membership = ref.read(membershipProvider).value;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final repo = getIt<AppointmentRepository>();
      final barber = await repo.getStats('barber_$uid');
      Map<String, dynamic>? salon;
      if (membership?.isOwner == true) {
        salon = await repo.getStats('salon_${membership!.salonId}');
      }
      if (!mounted) return;
      setState(() {
        _barberStats = barber;
        _salonStats = salon;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _barberStats = null;
        _salonStats = null;
        _loading = false;
      });
    }
  }

  Widget _statCard(String title, Map<String, dynamic>? data) {
    final requests = data?['requests'] ?? 0;
    final confirmed = data?['confirmed'] ?? 0;
    final completed = data?['completed'] ?? 0;
    final cancellations = data?['cancellations'] ?? 0;
    final noShow = data?['noShow'] ?? 0;
    final revenue = data?['estimatedRevenue'] ?? 0;
    final qr = data?['qrOpens'] ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Solicitudes: $requests'),
            Text('Confirmadas: $confirmed'),
            Text('Finalizadas: $completed'),
            Text('Cancelaciones: $cancellations'),
            Text('Ausencias: $noShow'),
            Text('Ingreso estimado: $revenue GTQ'),
            if (qr != 0) Text('Aperturas QR: $qr'),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final membership = ref.watch(membershipProvider).value;
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Estadísticas')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: appScrollPadding(context, horizontal: 16, vertical: 16),
          children: [
            const Text(
              'Periodos agregados de forma incremental (hoy / 7d / 30d se refinan en reconciliación).',
            ),
            const SizedBox(height: 12),
            _statCard('Mis indicadores', _barberStats),
            if (membership?.isOwner == true) ...[
              const SizedBox(height: 12),
              _statCard('Consolidados del negocio', _salonStats),
            ],
          ],
        ),
      ),
    );
  }
}
