import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:jolom/core/theme/theme.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

/// QR del negocio con acciones para compartir imagen o URL.
class SalonShareSheet extends StatefulWidget {
  const SalonShareSheet({required this.salonId, super.key});

  final String salonId;

  @override
  State<SalonShareSheet> createState() => _SalonShareSheetState();
}

class _SalonShareSheetState extends State<SalonShareSheet> {
  final GlobalKey _qrKey = GlobalKey();
  bool _sharing = false;

  static const _siteUrl = String.fromEnvironment(
    'JOLOM_SITE_URL',
    defaultValue: 'https://jolom.example',
  );

  String get _url => '$_siteUrl/s/${widget.salonId}';

  Future<void> _shareUrl() async {
    await SharePlus.instance.share(ShareParams(text: _url));
  }

  Future<void> _shareImage() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final boundary =
          _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw StateError('QR no disponible para capturar');
      }

      final image = await boundary.toImage(pixelRatio: 3);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw StateError('No se pudo generar la imagen del QR');
      }

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/salon_qr_${widget.salonId}.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());

      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], text: _url),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo compartir la imagen.')),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        safeBottom + AppSpacing.md,
      ),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Compartir local',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            Center(
              child: RepaintBoundary(
                key: _qrKey,
                child: ColoredBox(
                  color: Colors.white,
                  child: QrImageView(
                    data: _url,
                    size: 220,
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SelectableText(_url, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: _sharing ? null : _shareImage,
              icon: _sharing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.image_outlined),
              label: const Text('Compartir imagen'),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: _sharing ? null : _shareUrl,
              icon: const Icon(Icons.link),
              label: const Text('Compartir URL'),
            ),
          ],
        ),
      ),
    );
  }
}
