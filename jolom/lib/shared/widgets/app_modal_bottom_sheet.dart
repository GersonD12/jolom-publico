import 'package:flutter/material.dart';

/// Abre un modal por encima del shell y de su navegación inferior.
///
/// Usar este helper para que los nuevos bottom sheets no queden detrás del
/// menú compartido y respeten siempre el área segura física del dispositivo.
Future<T?> showAppModalBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool? showDragHandle,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: isScrollControlled,
    showDragHandle: showDragHandle,
    builder: (sheetContext) =>
        SafeArea(top: false, child: builder(sheetContext)),
  );
}
