import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Shared chrome for the 5-step Vendor registration wizard — a step
/// progress bar, title/subtitle, scrollable body, and a bottom "Continue"
/// button. Keeps every step screen visually consistent without duplicating
/// layout code.
class VendorRegistrationScaffold extends StatelessWidget {
  const VendorRegistrationScaffold({
    super.key,
    required this.step,
    required this.totalSteps,
    required this.title,
    required this.subtitle,
    required this.children,
    required this.onContinue,
    this.continueLabel = 'Continue',
  });

  final int step;
  final int totalSteps;
  final String title;
  final String subtitle;
  final List<Widget> children;
  final VoidCallback? onContinue;
  final String continueLabel;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Scaffold(
      appBar: AppBar(title: Text('Vendor Registration · Step $step of $totalSteps')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Row(
                children: [
                  for (var i = 0; i < totalSteps; i++)
                    Expanded(
                      child: Container(
                        margin: EdgeInsets.only(right: i == totalSteps - 1 ? 0 : 6),
                        height: 5,
                        decoration: BoxDecoration(
                          color: i < step ? palette.primary : palette.border,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                children: [
                  Text(title, style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 6),
                  Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 24),
                  ...children,
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: ElevatedButton(onPressed: onContinue, child: Text(continueLabel)),
        ),
      ),
    );
  }
}
