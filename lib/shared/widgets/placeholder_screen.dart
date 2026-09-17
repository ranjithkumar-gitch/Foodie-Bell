import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Temporary stand-in for a not-yet-built screen. Every real usage of this
/// widget is meant to be replaced — it exists so the router always resolves
/// to *something* while screens land incrementally.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.construction_rounded, size: 40, color: palette.textMuted),
              const SizedBox(height: 12),
              Text('$title — coming soon', style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
