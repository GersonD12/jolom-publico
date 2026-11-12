import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jolom/core/di/injection.dart';
import 'package:jolom/core/errors/user_facing_error.dart';
import 'package:jolom/features/report/application/use_cases/submit_report_use_case.dart';
import 'package:jolom/shared/widgets/pill_button_widget.dart';
import 'package:jolom/shared/widgets/user_identity.dart';

/// Formulario de reporte privado.
class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({
    required this.targetType,
    required this.targetId,
    this.targetLabel,
    this.sourceAppointmentId,
    super.key,
  });

  final String targetType;
  final String targetId;
  final String? targetLabel;
  final String? sourceAppointmentId;

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  final _descCtrl = TextEditingController();
  late String _category;
  bool _submitting = false;

  List<({String value, String label})> get _reasons =>
      widget.targetType == 'salon'
      ? const [
          (value: 'servicio', label: 'Mala experiencia de servicio'),
          (value: 'informacion', label: 'Información engañosa o incorrecta'),
          (value: 'conducta', label: 'Conducta inapropiada'),
          (value: 'fraude', label: 'Posible fraude'),
          (value: 'otro', label: 'Otro motivo'),
        ]
      : const [
          (value: 'conducta', label: 'Conducta inapropiada'),
          (value: 'inasistencia', label: 'Inasistencia reiterada'),
          (value: 'fraude', label: 'Posible fraude'),
          (value: 'spam', label: 'Spam o abuso'),
          (value: 'otro', label: 'Otro motivo'),
        ];

  @override
  void initState() {
    super.initState();
    _category = _reasons.first.value;
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      await getIt<SubmitReportUseCase>()(
        targetType: widget.targetType,
        targetId: widget.targetId,
        category: _category,
        description: _descCtrl.text.trim(),
        sourceAppointmentId: widget.sourceAppointmentId,
        idempotencyKey:
            'report_${widget.targetType}_${widget.targetId}_${DateTime.now().microsecondsSinceEpoch}',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.targetType == 'user'
                ? 'Cliente bloqueado para esta peluquería y reporte enviado.'
                : 'Reporte enviado. Estado: Recibido.',
          ),
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFacingError(e))));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.targetType == 'user'
              ? 'Reportar y bloquear'
              : 'Reportar peluquería',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: Icon(
                widget.targetType == 'salon'
                    ? Icons.storefront_outlined
                    : Icons.person_outline,
              ),
              title: Text(
                widget.targetType == 'salon'
                    ? 'Reportar peluquería'
                    : 'Reportar y bloquear cliente',
              ),
              subtitle: widget.targetType == 'user'
                  ? UserName(userId: widget.targetId)
                  : Text(widget.targetLabel ?? 'Peluquería'),
            ),
          ),
          if (widget.targetType == 'user') ...[
            const SizedBox(height: 12),
            const Text(
              'Al enviar el reporte, el cliente quedará bloqueado para nuevas '
              'reservas en esta peluquería hasta que el negocio lo desbloquee. '
              'El administrador de Jolom revisará el reporte y decidirá si '
              'corresponde una sanción global.',
            ),
          ],
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _category,
            items: _reasons
                .map(
                  (reason) => DropdownMenuItem(
                    value: reason.value,
                    child: Text(reason.label),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => _category = v ?? _category),
            decoration: const InputDecoration(labelText: 'Motivo'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descCtrl,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Detalles adicionales (opcional)',
              hintText: 'Cuéntanos brevemente qué ocurrió.',
            ),
          ),
          const SizedBox(height: 16),
          PillButtonWidget(
            label: widget.targetType == 'user'
                ? 'Reportar y bloquear'
                : 'Enviar reporte',
            loading: _submitting,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
