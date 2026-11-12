import 'dart:async';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Crea marcadores de Jolom con la foto del negocio o un ícono propio.
abstract final class SalonMapMarkerController {
  static const double _canvasWidth = 144;
  static const double _canvasHeight = 168;
  static const double _displayWidth = 54;
  static const double _displayHeight = 63;

  static final Map<String, Future<BitmapDescriptor>> _cache = {};

  static Future<BitmapDescriptor> create({
    required Color accentColor,
    String? imageUrl,
    double displayScale = 1,
  }) {
    final normalizedUrl = imageUrl?.trim() ?? '';
    final cacheKey =
        '${accentColor.toARGB32()}:$normalizedUrl:${displayScale.toStringAsFixed(2)}';
    return _cache.putIfAbsent(
      cacheKey,
      () => _render(
        accentColor: accentColor,
        imageUrl: normalizedUrl.isEmpty ? null : normalizedUrl,
        displayScale: displayScale,
      ),
    );
  }

  static Future<BitmapDescriptor> _render({
    required Color accentColor,
    required String? imageUrl,
    required double displayScale,
  }) async {
    final businessImage = imageUrl == null
        ? null
        : await _loadNetworkImage(imageUrl);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const center = Offset(72, 66);

    final markerShape = Path()
      ..addOval(Rect.fromCircle(center: center, radius: 62))
      ..moveTo(43, 108)
      ..lineTo(72, 164)
      ..lineTo(101, 108)
      ..close();

    canvas.drawShadow(
      markerShape,
      Colors.black.withValues(alpha: 0.38),
      9,
      true,
    );
    canvas.drawPath(markerShape, Paint()..color = accentColor);

    final portraitRect = Rect.fromCircle(center: center, radius: 52);
    canvas.drawOval(portraitRect, Paint()..color = Colors.white);

    if (businessImage != null) {
      _drawCoverImage(canvas, businessImage, portraitRect.deflate(4));
    } else {
      canvas.drawOval(
        portraitRect.deflate(4),
        Paint()..color = accentColor.withValues(alpha: 0.14),
      );
      _drawFallbackIcon(canvas, center, accentColor);
    }

    final picture = recorder.endRecording();
    final rendered = await picture.toImage(
      _canvasWidth.toInt(),
      _canvasHeight.toInt(),
    );
    final data = await rendered.toByteData(format: ui.ImageByteFormat.png);
    rendered.dispose();
    if (data == null) {
      throw StateError('No se pudo crear el marcador del negocio.');
    }

    return BitmapDescriptor.bytes(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      width: _displayWidth * displayScale,
      height: _displayHeight * displayScale,
    );
  }

  static Future<ui.Image?> _loadNetworkImage(String url) async {
    final completer = Completer<ui.Image?>();
    final stream = CachedNetworkImageProvider(
      url,
      maxWidth: 256,
      maxHeight: 256,
    ).resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        if (!completer.isCompleted) completer.complete(info.image);
        stream.removeListener(listener);
      },
      onError: (_, _) {
        if (!completer.isCompleted) completer.complete(null);
        stream.removeListener(listener);
      },
    );
    stream.addListener(listener);

    try {
      return await completer.future.timeout(const Duration(seconds: 8));
    } on TimeoutException {
      stream.removeListener(listener);
      return null;
    }
  }

  static void _drawCoverImage(Canvas canvas, ui.Image image, Rect destination) {
    final imageAspect = image.width / image.height;
    final targetAspect = destination.width / destination.height;
    late final Rect source;
    if (imageAspect > targetAspect) {
      final sourceWidth = image.height * targetAspect;
      source = Rect.fromLTWH(
        (image.width - sourceWidth) / 2,
        0,
        sourceWidth,
        image.height.toDouble(),
      );
    } else {
      final sourceHeight = image.width / targetAspect;
      source = Rect.fromLTWH(
        0,
        (image.height - sourceHeight) / 2,
        image.width.toDouble(),
        sourceHeight,
      );
    }

    canvas
      ..save()
      ..clipPath(Path()..addOval(destination))
      ..drawImageRect(image, source, destination, Paint()..isAntiAlias = true)
      ..restore();
  }

  static void _drawFallbackIcon(
    Canvas canvas,
    Offset center,
    Color accentColor,
  ) {
    final icon = Icons.content_cut;
    final painter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          color: accentColor,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          fontSize: 58,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset(center.dx - painter.width / 2, center.dy - painter.height / 2),
    );
  }
}
