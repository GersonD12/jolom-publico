import 'package:flutter/material.dart';

/// Diálogo para confirmar abandono de cambios sin guardar.
Future<bool> showDiscardUnsavedChangesDialog(BuildContext context) async {
  final discard = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Cambios sin guardar'),
      content: const Text(
        'Tienes cambios sin guardar. ¿Seguro que quieres abandonarlos?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Continuar editando'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Abandonar'),
        ),
      ],
    ),
  );
  return discard == true;
}
