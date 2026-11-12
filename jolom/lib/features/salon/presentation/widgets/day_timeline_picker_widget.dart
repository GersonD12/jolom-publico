import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:jolom/core/theme/theme.dart';
import 'package:jolom/features/appointment/domain/entities/busy_interval_entity.dart';

/// Lienzo vertical con ocupación y indicador de inicio arrastrable.
///
/// [dayOpen] / [dayClose] definen la ventana laboral del día.
/// Si [day] es hoy, el lienzo empieza en ahora+1h (snap 5 min): el pasado
/// no se muestra.
class DayTimelinePickerWidget extends StatefulWidget {
  const DayTimelinePickerWidget({
    required this.day,
    required this.dayOpen,
    required this.dayClose,
    required this.durationMinutes,
    required this.busyIntervals,
    required this.selectedStart,
    required this.onStartChanged,
    required this.onValidityChanged,
    this.availableStarts,
    this.minutesPerPixel = 1.2,
    super.key,
  });

  final DateTime day;
  final DateTime dayOpen;
  final DateTime dayClose;
  final int durationMinutes;
  final List<BusyInterval> busyIntervals;
  final DateTime? selectedStart;
  final ValueChanged<DateTime?> onStartChanged;

  /// true si el inicio actual no solapa y cabe en el día / no es pasado.
  final ValueChanged<bool> onValidityChanged;

  /// Inicios permitidos por el backend para la opción "Cualquiera".
  final Set<DateTime>? availableStarts;

  final double minutesPerPixel;

  static const int snapMinutes = 5;

  /// Carril derecho sin gestos para scrollear el ListView padre.
  static const double scrollGutterWidth = 36;

  /// Zona de borde (px) donde el drag dispara auto-scroll del padre.
  static const double edgeScrollZone = 56;

  /// Velocidad máxima de auto-scroll (px por frame ~60fps).
  static const double edgeScrollMaxDelta = 10;

  @override
  State<DayTimelinePickerWidget> createState() =>
      _DayTimelinePickerWidgetState();
}

class _DayTimelinePickerWidgetState extends State<DayTimelinePickerWidget>
    with SingleTickerProviderStateMixin {
  DateTime? _dragStart;
  final GlobalKey _canvasKey = GlobalKey();

  bool _dragging = false;
  Offset? _pointerGlobal;
  Ticker? _edgeScrollTicker;

  bool get _isToday {
    final now = DateTime.now();
    return widget.day.year == now.year &&
        widget.day.month == now.month &&
        widget.day.day == now.day;
  }

  DateTime _snapCeil(DateTime value) {
    var mins = value.hour * 60 + value.minute;
    if (value.second > 0 || value.millisecond > 0) {
      mins += 1;
    }
    final snap = DayTimelinePickerWidget.snapMinutes;
    final ceiled = ((mins + snap - 1) ~/ snap) * snap;
    return DateTime(
      value.year,
      value.month,
      value.day,
    ).add(Duration(minutes: ceiled));
  }

  /// Inicio visible del lienzo (hoy: max(dayOpen, snapCeil(now+1h))).
  DateTime get _effectiveOpen {
    if (!_isToday) return widget.dayOpen;
    final minBookable = _snapCeil(DateTime.now().add(const Duration(hours: 1)));
    return minBookable.isAfter(widget.dayOpen) ? minBookable : widget.dayOpen;
  }

  int get _totalMinutes =>
      widget.dayClose.difference(_effectiveOpen).inMinutes.clamp(0, 24 * 60);

  double get _canvasHeight => _totalMinutes * widget.minutesPerPixel;

  @override
  void initState() {
    super.initState();
    _dragStart = widget.selectedStart;
    WidgetsBinding.instance.addPostFrameCallback((_) => _emitValidity());
  }

  @override
  void dispose() {
    _edgeScrollTicker?.dispose();
    _edgeScrollTicker = null;
    super.dispose();
  }

  @override
  void didUpdateWidget(DayTimelinePickerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedStart != oldWidget.selectedStart) {
      _dragStart = widget.selectedStart;
    }
    if (widget.day != oldWidget.day ||
        widget.dayOpen != oldWidget.dayOpen ||
        widget.dayClose != oldWidget.dayClose ||
        widget.durationMinutes != oldWidget.durationMinutes ||
        widget.busyIntervals != oldWidget.busyIntervals ||
        widget.availableStarts != oldWidget.availableStarts ||
        widget.selectedStart != oldWidget.selectedStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _emitValidity());
    }
  }

  void _startEdgeScrollTicker() {
    _edgeScrollTicker ??= createTicker((_) => _tickEdgeScroll());
    if (!_edgeScrollTicker!.isActive) {
      _edgeScrollTicker!.start();
    }
  }

  void _pauseEdgeScrollTicker() {
    _edgeScrollTicker?.stop();
  }

  void _endDrag() {
    _dragging = false;
    _pointerGlobal = null;
    _pauseEdgeScrollTicker();
  }

  /// Actualiza la hora según la posición global del dedo en el canvas.
  void _updateStartFromGlobal() {
    final global = _pointerGlobal;
    if (global == null) return;
    final box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final local = box.globalToLocal(global);
    _updateStart(_offsetToStart(local.dy));
  }

  void _tickEdgeScroll() {
    if (!_dragging || _pointerGlobal == null || !mounted) return;

    final scrollable = Scrollable.maybeOf(context);
    if (scrollable == null) return;

    final renderObject = context.findRenderObject();
    if (renderObject == null) return;
    final viewport = RenderAbstractViewport.maybeOf(renderObject);
    if (viewport is! RenderBox) return;
    final viewportBox = viewport as RenderBox;
    if (!viewportBox.hasSize) return;

    final localInScroll = viewportBox.globalToLocal(_pointerGlobal!);
    final height = viewportBox.size.height;
    final zone = DayTimelinePickerWidget.edgeScrollZone;
    final maxDelta = DayTimelinePickerWidget.edgeScrollMaxDelta;

    double delta = 0;
    if (localInScroll.dy > height - zone) {
      final depth = ((localInScroll.dy - (height - zone)) / zone).clamp(
        0.0,
        1.0,
      );
      delta = maxDelta * depth;
    } else if (localInScroll.dy < zone) {
      final depth = ((zone - localInScroll.dy) / zone).clamp(0.0, 1.0);
      delta = -maxDelta * depth;
    }

    if (delta == 0) return;

    final position = scrollable.position;
    final next = (position.pixels + delta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (next != position.pixels) {
      position.jumpTo(next);
    }
    // Estabilizar hora con coords globales (también en el tope de scroll).
    _updateStartFromGlobal();
  }

  DateTime _snap(DateTime value) {
    final open = _effectiveOpen;
    final openMinutes = open.hour * 60 + open.minute;
    final minutes = value.hour * 60 + value.minute;
    final relative = minutes - openMinutes;
    final snapped =
        (relative / DayTimelinePickerWidget.snapMinutes).round() *
        DayTimelinePickerWidget.snapMinutes;
    final clamped = snapped.clamp(0, _totalMinutes);
    return open.add(Duration(minutes: clamped));
  }

  DateTime _offsetToStart(double dy) {
    final minutes = (dy / widget.minutesPerPixel).round().clamp(
      0,
      _totalMinutes,
    );
    return _snap(_effectiveOpen.add(Duration(minutes: minutes)));
  }

  double _startToOffset(DateTime start) {
    final minutes = start.difference(_effectiveOpen).inMinutes;
    return minutes * widget.minutesPerPixel;
  }

  bool _isValid(DateTime? start) {
    if (start == null) return false;
    final availableStarts = widget.availableStarts;
    if (availableStarts != null && !availableStarts.contains(start)) {
      return false;
    }
    final end = start.add(Duration(minutes: widget.durationMinutes));
    if (start.isBefore(_effectiveOpen) || end.isAfter(widget.dayClose)) {
      return false;
    }
    for (final busy in widget.busyIntervals) {
      if (busy.overlaps(start, end)) return false;
    }
    return true;
  }

  void _emitValidity() {
    widget.onValidityChanged(_isValid(_dragStart));
  }

  void _updateStart(DateTime start) {
    final open = _effectiveOpen;
    final maxStart = widget.dayClose.subtract(
      Duration(minutes: widget.durationMinutes),
    );
    if (maxStart.isBefore(open)) {
      setState(() => _dragStart = null);
      widget.onStartChanged(null);
      widget.onValidityChanged(false);
      return;
    }
    var next = start;
    if (next.isBefore(open)) next = open;
    if (next.isAfter(maxStart)) next = _snap(maxStart);

    setState(() => _dragStart = next);
    widget.onStartChanged(next);
    widget.onValidityChanged(_isValid(next));
  }

  String _fmt(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  List<int> get _hourMarks {
    final open = _effectiveOpen;
    final openHour = open.minute == 0 ? open.hour : open.hour + 1;
    final closeHour = widget.dayClose.hour;
    final marks = <int>[];
    for (var h = openHour; h <= closeHour; h++) {
      final at = DateTime(widget.day.year, widget.day.month, widget.day.day, h);
      if (!at.isBefore(open) && !at.isAfter(widget.dayClose)) {
        marks.add(h);
      }
    }
    return marks;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final start = _dragStart;
    final valid = _isValid(start);
    final blockHeight = widget.durationMinutes * widget.minutesPerPixel;
    final open = _effectiveOpen;

    if (_totalMinutes <= 0) {
      return Text(
        'Horario no disponible',
        style: textTheme.bodyMedium?.copyWith(color: scheme.error),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Ocupado',
              style: textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              width: 14,
              height: 10,
              decoration: BoxDecoration(
                color: scheme.onSurface.withValues(alpha: 0.22),
                borderRadius: AppRadius.chip,
              ),
            ),
            const Spacer(),
            Text(
              'Desde ${_fmt(open)}',
              style: textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            if (start != null) ...[
              const SizedBox(width: 12),
              Text(
                valid
                    ? 'Inicio ${_fmt(start)} · ${widget.durationMinutes} min'
                    : 'Horario no disponible',
                style: textTheme.labelMedium?.copyWith(
                  color: valid ? scheme.primary : scheme.error,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: _canvasHeight,
          width: double.infinity,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: GestureDetector(
                  key: _canvasKey,
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) {
                    _updateStart(_offsetToStart(details.localPosition.dy));
                  },
                  onVerticalDragStart: (details) {
                    _dragging = true;
                    _pointerGlobal = details.globalPosition;
                    _updateStartFromGlobal();
                    _startEdgeScrollTicker();
                  },
                  onVerticalDragUpdate: (details) {
                    _pointerGlobal = details.globalPosition;
                    _updateStartFromGlobal();
                  },
                  onVerticalDragEnd: (_) => _endDrag(),
                  onVerticalDragCancel: _endDrag,
                  child: Stack(
                    clipBehavior: Clip.hardEdge,
                    children: [
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerLow,
                            borderRadius: AppRadius.cardCompact,
                            border: Border.all(
                              color: scheme.outlineVariant.withValues(
                                alpha: 0.7,
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Etiqueta del inicio efectivo si no cae en hora en punto.
                      if (open.minute != 0)
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: Row(
                            children: [
                              SizedBox(
                                width: 44,
                                child: Text(
                                  _fmt(open),
                                  style: textTheme.labelSmall?.copyWith(
                                    color: scheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Divider(
                                  height: 1,
                                  color: scheme.primary.withValues(alpha: 0.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ..._hourMarks.map((hour) {
                        final at = DateTime(
                          widget.day.year,
                          widget.day.month,
                          widget.day.day,
                          hour,
                        );
                        final top = _startToOffset(at);
                        return Positioned(
                          top: top,
                          left: 0,
                          right: 0,
                          child: Row(
                            children: [
                              SizedBox(
                                width: 44,
                                child: Text(
                                  '${hour.toString().padLeft(2, '0')}:00',
                                  style: textTheme.labelSmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Divider(
                                  height: 1,
                                  color: scheme.outlineVariant.withValues(
                                    alpha: 0.55,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      ...widget.busyIntervals.map((busy) {
                        final clippedStart = busy.start.isBefore(open)
                            ? open
                            : busy.start;
                        final clippedEnd = busy.end.isAfter(widget.dayClose)
                            ? widget.dayClose
                            : busy.end;
                        if (!clippedEnd.isAfter(clippedStart)) {
                          return const SizedBox.shrink();
                        }
                        final top = _startToOffset(clippedStart);
                        final height =
                            clippedEnd.difference(clippedStart).inMinutes *
                            widget.minutesPerPixel;
                        final blockH = height
                            .clamp(4.0, _canvasHeight)
                            .toDouble();
                        return Positioned(
                          top: top,
                          left: 48,
                          right: 8,
                          height: blockH,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: scheme.onSurface.withValues(alpha: 0.22),
                              borderRadius: AppRadius.chip,
                            ),
                            child: blockH >= 18
                                ? Align(
                                    alignment: Alignment.topCenter,
                                    child: Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        'Ocupado',
                                        style: textTheme.labelSmall?.copyWith(
                                          color: scheme.onSurfaceVariant
                                              .withValues(alpha: 0.7),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                        );
                      }),
                      if (start != null)
                        Positioned(
                          top: _startToOffset(start),
                          left: 48,
                          right: 8,
                          height: blockHeight
                              .clamp(12.0, _canvasHeight)
                              .toDouble(),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: (valid ? scheme.primary : scheme.error)
                                  .withValues(alpha: 0.35),
                              borderRadius: AppRadius.chip,
                              border: Border.all(
                                color: valid ? scheme.primary : scheme.error,
                                width: 2,
                              ),
                            ),
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  _fmt(start),
                                  style: textTheme.labelMedium?.copyWith(
                                    color: valid
                                        ? scheme.onPrimaryContainer
                                        : scheme.onErrorContainer,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: DayTimelinePickerWidget.scrollGutterWidth),
            ],
          ),
        ),
      ],
    );
  }
}
