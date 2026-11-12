import 'package:flutter/material.dart';
import 'package:jolom/core/theme/theme.dart';

import '../widgets/salon_explore_list_widget.dart';
import '../widgets/salon_explore_map_widget.dart';

enum _ExploreView { list, map }

/// Coordina las vistas de lista y mapa para explorar peluquerías.
class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  _ExploreView _view = _ExploreView.map;
  bool _mapWasOpened = true;

  void _selectView(_ExploreView next) {
    if (_view == next) return;
    setState(() {
      _view = next;
      if (next == _ExploreView.map) _mapWasOpened = true;
    });
  }

  Widget _buildViewSelector({bool floatingOnMap = false}) {
    final selector = SegmentedButton<_ExploreView>(
      segments: const [
        ButtonSegment(
          value: _ExploreView.map,
          icon: Icon(Icons.map_outlined),
          label: Text('Mapa'),
        ),
        ButtonSegment(
          value: _ExploreView.list,
          icon: Icon(Icons.view_agenda_outlined),
          label: Text('Lista'),
        ),
      ],
      selected: {_view},
      showSelectedIcon: false,
      onSelectionChanged: (selection) => _selectView(selection.first),
    );

    if (!floatingOnMap) return selector;
    return Material(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.94),
      borderRadius: AppRadius.pill,
      clipBehavior: Clip.antiAlias,
      child: selector,
    );
  }

  @override
  Widget build(BuildContext context) {
    final mapControlsTopInset =
        MediaQuery.paddingOf(context).top +
        AppSpacing.minTapTarget +
        AppSpacing.md;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Offstage(
            offstage: _view != _ExploreView.list,
            child: Column(
              children: [
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xs,
                    ),
                    child: _buildViewSelector(),
                  ),
                ),
                const Expanded(child: SalonExploreListWidget()),
              ],
            ),
          ),
          if (_mapWasOpened)
            Offstage(
              offstage: _view != _ExploreView.map,
              child: SalonExploreMapWidget(
                controlsTopInset: mapControlsTopInset,
              ),
            ),
          if (_view == _ExploreView.map)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Center(child: _buildViewSelector(floatingOnMap: true)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
