import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_text_field.dart';
import 'vendor_registration_scaffold.dart';
import 'vendor_registration_state.dart';

/// Registration step 2 — Manager Code Entry (spec §5.2 / the platform's
/// "golden rule": every Vendor/Driver registers against a Manager's code).
/// Not wired to a real backend yet — there's no Firestore lookup to
/// validate a Manager Code against (a real Vendor account is currently only
/// ever created by a Manager directly, via `manager_vendor_create_screen.dart`),
/// so every code is rejected here rather than a fixed demo one silently
/// succeeding.
class VendorManagerCodeScreen extends ConsumerStatefulWidget {
  const VendorManagerCodeScreen({super.key});

  @override
  ConsumerState<VendorManagerCodeScreen> createState() => _VendorManagerCodeScreenState();
}

class _VendorManagerCodeScreenState extends ConsumerState<VendorManagerCodeScreen> {
  late final _controller = TextEditingController(text: ref.read(vendorRegistrationProvider).managerCode);
  bool _verified = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _verified = ref.read(vendorRegistrationProvider).managerCodeVerified;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _verify() {
    // No real backend to validate this against yet — see this screen's doc
    // comment.
    setState(() {
      _verified = false;
      _error = "Vendor self-registration isn't available yet. Ask your Territory Manager to add you directly.";
    });
  }

  void _continue() {
    if (!_verified) {
      setState(() => _error = 'Please verify a valid Manager Code before continuing.');
      return;
    }
    ref.read(vendorRegistrationProvider.notifier).update((d) => d.copyWith(
      managerCode: _controller.text.trim().toUpperCase(),
      managerCodeVerified: true,
    ));
    context.push('/vendor/register/documents');
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return VendorRegistrationScaffold(
      step: 2,
      totalSteps: 5,
      title: 'Enter your Manager Code',
      subtitle: 'Every vendor onboards under a City Manager. Ask them for your Manager Code.',
      onContinue: _continue,
      children: [
        AppTextField(
          label: 'Manager Code',
          controller: _controller,
          hint: 'e.g. MG-HYD-014',
          onChanged: (_) {
            if (_verified) setState(() => _verified = false);
          },
        ),
        const SizedBox(height: 14),
        OutlinedButton(onPressed: _verify, child: const Text('Verify Code')),
        const SizedBox(height: 14),
        if (_verified)
          Row(
            children: [
              Icon(Icons.check_circle_rounded, color: palette.success, size: 20),
              const SizedBox(width: 8),
              Text('Code verified', style: TextStyle(color: palette.success, fontWeight: FontWeight.w700)),
            ],
          ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: TextStyle(color: palette.error, fontWeight: FontWeight.w600, fontSize: 12.5)),
        ],
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: palette.surfaceMuted, borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded, color: palette.textSecondary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Vendor self-registration isn't available yet — ask your Territory Manager to add you directly.",
                  style: TextStyle(fontSize: 12.5, color: palette.textSecondary, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
