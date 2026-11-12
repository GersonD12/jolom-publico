import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jolom/core/providers/user_directory_provider.dart';
import 'package:jolom/services/user_directory/domain/user_directory_result.dart';

/// Nombre de otro usuario resuelto por [userId] vía directorio.
class UserName extends ConsumerWidget {
  const UserName({
    required this.userId,
    super.key,
    this.style,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
  });

  final String userId;
  final TextStyle? style;
  final int maxLines;
  final TextOverflow overflow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(userDirectoryProvider(userId));
    final text = async.when(
      loading: () => '…',
      error: (_, _) => 'Usuario',
      data: (result) => switch (result) {
        VisibleUser(:final displayName) =>
          (displayName != null && displayName.isNotEmpty)
              ? displayName
              : 'Usuario',
        HiddenUser() => 'Usuario no disponible',
        MissingUser() => 'Usuario',
      },
    );
    return Text(text, style: style, maxLines: maxLines, overflow: overflow);
  }
}

/// Avatar de otro usuario resuelto por [userId] vía directorio.
class UserAvatar extends ConsumerWidget {
  const UserAvatar({
    required this.userId,
    super.key,
    this.radius = 20,
  });

  final String userId;
  final double radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(userDirectoryProvider(userId));
    return async.when(
      loading: () => CircleAvatar(radius: radius),
      error: (_, _) => CircleAvatar(
        radius: radius,
        child: const Icon(Icons.person),
      ),
      data: (result) {
        if (result is HiddenUser || result is MissingUser) {
          return CircleAvatar(
            radius: radius,
            child: const Icon(Icons.person_off),
          );
        }
        final visible = result as VisibleUser;
        final url = visible.photoUrl;
        if (url == null || url.isEmpty) {
          return CircleAvatar(
            radius: radius,
            child: Text(
              _initials(visible.displayName),
              style: TextStyle(fontSize: radius * 0.7),
            ),
          );
        }
        return CircleAvatar(
          radius: radius,
          backgroundImage: CachedNetworkImageProvider(url),
        );
      },
    );
  }

  String _initials(String? name) {
    if (name == null || name.isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }
}
