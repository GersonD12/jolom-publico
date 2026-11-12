import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jolom/core/providers/feature_providers.dart';
import 'package:jolom/core/utils/app_scroll_padding.dart';

import '../widgets/salon_share_sheet.dart';

/// QR estable de la peluquería con compartir imagen o URL.
class SalonQrScreen extends ConsumerWidget {
  const SalonQrScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membership = ref.watch(membershipProvider).value;
    if (membership == null) {
      return const Scaffold(
        body: Center(child: Text('Sin peluquería activa.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('QR del negocio')),
      body: Center(
        child: SingleChildScrollView(
          padding: appScrollPadding(context, horizontal: 0, vertical: 16),
          child: SalonShareSheet(salonId: membership.salonId),
        ),
      ),
    );
  }
}
