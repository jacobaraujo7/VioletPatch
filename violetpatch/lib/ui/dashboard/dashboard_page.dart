import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/widgets/widgets.dart';
import 'viewmodel/dashboard_viewmodel.dart';
import 'widgets/widgets.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, required this.viewModel});

  final DashboardViewModel viewModel;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  DashboardViewModel get _vm => widget.viewModel;

  @override
  void initState() {
    super.initState();
    _vm.addListener(_onViewModelChanged);
  }

  @override
  void dispose() {
    _vm.removeListener(_onViewModelChanged);
    super.dispose();
  }

  void _onViewModelChanged() {
    if (mounted) setState(() {});
  }

  void _showCreateRouteDialog() {
    final state = _vm.state;
    showDialog(
      context: context,
      builder: (context) => CreateRouteDialog(
        devices: state.devices,
        initialInputUID: state.defaults.defaultInputUID,
        initialOutputUID: state.defaults.defaultOutputUID,
        onRouteCreated: (inputUID, outputUID, inL, inR, outL, outR) {
          return _vm.addRoute(
            inputUID: inputUID,
            outputUID: outputUID,
            inL: inL,
            inR: inR,
            outL: outL,
            outR: outR,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('VioletPatch'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Theme.of(context).colorScheme.onSurface,
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showCreateRouteDialog,
          icon: const Icon(Icons.add),
          label: const Text('New Route'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: _buildRoutesPanel(constraints),
            );
          },
        ),
      ),
    );
  }

  int _calculateColumns(double width) {
    if (width >= 1400) return 4;
    if (width >= 1000) return 3;
    if (width >= 600) return 2;
    return 1;
  }

  Widget _buildRoutesPanel(BoxConstraints constraints) {
    final state = _vm.state;
    final columns = _calculateColumns(constraints.maxWidth);
    const spacing = 16.0;
    const cardHeight = 260.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Active Routes', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        if (state.routes.isEmpty)
          EmptyRoutesCard(width: constraints.maxWidth - 48),
        if (state.routes.isNotEmpty)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: spacing,
              mainAxisSpacing: spacing,
              mainAxisExtent: cardHeight,
            ),
            itemCount: state.routes.length,
            itemBuilder: (context, index) {
              final route = state.routes[index];
              final inputAvailable =
                  _vm.deviceForUID(route.inDeviceUID) != null;
              final outputAvailable =
                  _vm.deviceForUID(route.outDeviceUID) != null;

              return RouteCard(
                route: route,
                inputName: _vm.deviceNameForRoute(route, isInput: true),
                outputName: _vm.deviceNameForRoute(route, isInput: false),
                inputAvailable: inputAvailable,
                outputAvailable: outputAvailable,
                onRemove: () => _vm.removeRoute(route.id),
                onGainChanged: (gain) => _vm.setRouteGain(route.id, gain),
                onEnabledChanged: (enabled) =>
                    _vm.setRouteEnabled(route.id, enabled),
              );
            },
          ),
      ],
    );
  }
}
