import 'dart:async';

import 'package:flutter/material.dart';
import 'package:jolom/core/theme/theme.dart';

import '../../domain/entities/nearby_salon_entity.dart';
import 'salon_map_business_card_widget.dart';

/// Carrusel horizontal de negocios ya cargados dentro del radio del mapa.
class SalonMapBusinessCarouselWidget extends StatefulWidget {
  const SalonMapBusinessCarouselWidget({
    required this.items,
    required this.onHighlight,
    required this.onOpen,
    super.key,
  });

  final List<NearbySalon> items;
  final ValueChanged<NearbySalon> onHighlight;
  final ValueChanged<NearbySalon> onOpen;

  @override
  State<SalonMapBusinessCarouselWidget> createState() =>
      _SalonMapBusinessCarouselWidgetState();
}

class _SalonMapBusinessCarouselWidgetState
    extends State<SalonMapBusinessCarouselWidget> {
  static const _autoAdvanceDelay = Duration(seconds: 2);
  static const _autoAdvanceDuration = Duration(milliseconds: 560);

  late final PageController _controller;
  Timer? _autoAdvanceTimer;
  var _currentPage = 1;
  String? _currentSalonId;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.items.length > 1 ? 1 : 0;
    _controller = PageController(initialPage: _currentPage);
    if (widget.items.isNotEmpty) {
      _currentSalonId = widget.items.first.salon.id;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleAutoAdvance();
  }

  @override
  void didUpdateWidget(SalonMapBusinessCarouselWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.items.isEmpty) {
      _autoAdvanceTimer?.cancel();
      return;
    }
    final retainedIndex = _currentSalonId == null
        ? -1
        : widget.items.indexWhere((item) => item.salon.id == _currentSalonId);
    final logicalIndex = retainedIndex >= 0
        ? retainedIndex
        : (_currentPage - 1).clamp(0, widget.items.length - 1);
    final targetPage = widget.items.length > 1 ? logicalIndex + 1 : 0;
    _currentPage = targetPage;
    _currentSalonId = widget.items[logicalIndex].salon.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          _controller.hasClients &&
          _controller.page?.round() != targetPage) {
        _controller.jumpToPage(_currentPage);
      }
    });
    _scheduleAutoAdvance();
  }

  @override
  void dispose() {
    _autoAdvanceTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  int get _pageCount =>
      widget.items.length <= 1 ? widget.items.length : widget.items.length + 2;

  NearbySalon _itemForPage(int page) {
    if (widget.items.length == 1) return widget.items.first;
    if (page == 0) return widget.items.last;
    if (page == widget.items.length + 1) return widget.items.first;
    return widget.items[page - 1];
  }

  void _scheduleAutoAdvance() {
    _autoAdvanceTimer?.cancel();
    if (!mounted ||
        widget.items.length <= 1 ||
        AppMotion.reduceMotion(context)) {
      return;
    }
    _autoAdvanceTimer = Timer(_autoAdvanceDelay, _advanceAutomatically);
  }

  Future<void> _advanceAutomatically() async {
    if (!mounted || !_controller.hasClients) {
      _scheduleAutoAdvance();
      return;
    }
    if (_controller.position.isScrollingNotifier.value) {
      _scheduleAutoAdvance();
      return;
    }
    final lastPage = widget.items.length + 1;
    final nextPage = (_currentPage + 1).clamp(1, lastPage);
    await _controller.animateToPage(
      nextPage,
      duration: _autoAdvanceDuration,
      curve: AppMotion.standard,
    );
  }

  void _handlePageChanged(int page) {
    _currentPage = page;
    _currentSalonId = _itemForPage(page).salon.id;

    if (widget.items.length > 1 &&
        (page == 0 || page == widget.items.length + 1)) {
      final loopPage = page == 0 ? widget.items.length : 1;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_controller.hasClients) return;
        _currentPage = loopPage;
        _controller.jumpToPage(loopPage);
      });
    }
    _scheduleAutoAdvance();
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification is ScrollStartNotification) {
      _autoAdvanceTimer?.cancel();
    } else if (notification is ScrollEndNotification) {
      _scheduleAutoAdvance();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 104,
    child: NotificationListener<ScrollNotification>(
      onNotification: _handleScrollNotification,
      child: PageView.builder(
        key: const ValueKey('nearby-salons-carousel'),
        controller: _controller,
        clipBehavior: Clip.hardEdge,
        itemCount: _pageCount,
        onPageChanged: _handlePageChanged,
        itemBuilder: (context, page) {
          final item = _itemForPage(page);
          final isLoopPage =
              widget.items.length > 1 &&
              (page == 0 || page == widget.items.length + 1);
          return Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xxs,
              vertical: AppSpacing.xs,
            ),
            child: SalonMapBusinessCardWidget(
              key: ValueKey(
                isLoopPage
                    ? 'nearby-salon-${item.salon.id}-loop-$page'
                    : 'nearby-salon-${item.salon.id}',
              ),
              item: item,
              onCardTap: () {
                _scheduleAutoAdvance();
                widget.onHighlight(item);
              },
              onOpen: () => widget.onOpen(item),
            ),
          );
        },
      ),
    ),
  );
}
