import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/session/session_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/account.dart';
import 'legal_content.dart';
import 'legal_info.dart';

/// Opens the Privacy Policy or Terms & Conditions for [role] (the signed-in
/// role when omitted). `/legal/...` sits outside every role shell, so a
/// push from inside one is safe.
void openLegal(BuildContext context, LegalKind kind, {AppRole? role}) {
  final path = kind == LegalKind.privacy ? '/legal/privacy' : '/legal/terms';
  context.push(role == null ? path : '$path?role=${role.name}');
}

AppRole? legalRoleFromQuery(String? name) => AppRole.values.where((r) => r.name == name).firstOrNull;

/// One role's Privacy Policy or Terms & Conditions, read-only.
class LegalScreen extends ConsumerWidget {
  const LegalScreen({super.key, required this.kind, this.role});

  final LegalKind kind;

  /// Null: the signed-in role, or Customer for a guest.
  final AppRole? role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.colors;
    final resolved = legalRoleFor(role ?? ref.watch(sessionControllerProvider.select((s) => s.role)) ?? AppRole.user);
    final doc = legalDocument(kind, resolved);

    return Scaffold(
      appBar: AppBar(title: Text(doc.title)),
      body: SafeArea(
        top: false,
        child: ListView(
          key: Key('legal_${kind.name}_${resolved.name}'),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Text(
              'For ${roleTitle(resolved)}',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: palette.textPrimary),
            ),
            const SizedBox(height: 4),
            Text('${LegalInfo.app} · ${LegalInfo.company}', style: TextStyle(fontSize: 13, color: palette.textSecondary)),
            const SizedBox(height: 12),
            for (final block in doc.blocks) _Block(block),
          ],
        ),
      ),
    );
  }
}

class _Block extends StatelessWidget {
  const _Block(this.block);

  final LegalBlock block;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final body = TextStyle(fontSize: 14.5, height: 1.55, color: palette.textPrimary);
    return switch (block) {
      LegalHeading(:final text, :final sub) => Padding(
        padding: EdgeInsets.only(top: sub ? 14 : 22, bottom: 6),
        child: Text(
          text,
          style: TextStyle(fontSize: sub ? 15 : 17, fontWeight: FontWeight.w800, color: palette.textPrimary),
        ),
      ),
      LegalPara(:final text) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text.rich(_rich(text, body))),
      LegalBullets(:final items) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 8, right: 10),
                      child: Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(color: palette.primary, shape: BoxShape.circle),
                      ),
                    ),
                    Expanded(child: Text.rich(_rich(item, body))),
                  ],
                ),
              ),
          ],
        ),
      ),
      LegalCallout(:final lines) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
        decoration: BoxDecoration(
          color: palette.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border(left: BorderSide(color: palette.primary, width: 4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [for (final line in lines) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text.rich(_rich(line, body)))],
        ),
      ),
    };
  }
}

/// `**bold**` → bold spans.
TextSpan _rich(String text, TextStyle style) {
  final parts = text.split('**');
  return TextSpan(
    style: style,
    children: [
      for (var i = 0; i < parts.length; i++)
        if (parts[i].isNotEmpty)
          TextSpan(
            text: parts[i],
            style: i.isOdd ? const TextStyle(fontWeight: FontWeight.w800) : null,
          ),
    ],
  );
}
