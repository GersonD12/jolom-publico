import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Acción para abrir la bandeja de notificaciones.
class NotificationsIconButtonWidget extends StatelessWidget {
  const NotificationsIconButtonWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Notificaciones',
      onPressed: () => context.push('/notifications'),
      icon: const Icon(Icons.notifications_outlined),
    );
  }
}
