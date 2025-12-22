import 'package:flutter/material.dart';

import 'data/data.dart';
import 'ui/ui.dart';

void main() {
  runApp(const VioletPatchApp());
}

class VioletPatchApp extends StatefulWidget {
  const VioletPatchApp({super.key});

  @override
  State<VioletPatchApp> createState() => _VioletPatchAppState();
}

class _VioletPatchAppState extends State<VioletPatchApp> {
  late final AudioService _audioService;
  late final DashboardViewModel _dashboardViewModel;

  @override
  void initState() {
    super.initState();
    _audioService = AudioService();
    _dashboardViewModel = DashboardViewModel(_audioService);
  }

  @override
  void dispose() {
    _dashboardViewModel.dispose();
    _audioService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VioletPatch',
      theme: AppTheme.dark,
      home: DashboardPage(viewModel: _dashboardViewModel),
    );
  }
}
