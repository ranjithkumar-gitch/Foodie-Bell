import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Generic icon + title + subtitle (+ optional CTA) empty state, reused for
/// empty carts, empty order history, no search results, no tickets, etc.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.ctaLabel,
    this.onCta,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? ctaLabel;
  final VoidCallback? onCta;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(color: palette.primaryLight.withValues(alpha: 0.25), shape: BoxShape.circle),
              child: Icon(icon, size: 52, color: palette.primary),
            ),
            const SizedBox(height: 22),
            Text(title, style: Theme.of(context).textTheme.headlineMedium, textAlign: TextAlign.center),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(subtitle!, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
            ],
            if (ctaLabel != null && onCta != null) ...[
              const SizedBox(height: 24),
              ElevatedButton(onPressed: onCta, child: Text(ctaLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
