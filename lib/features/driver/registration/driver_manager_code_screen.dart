import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_text_field.dart';
import 'driver_registration_controller.dart';

/// Step 2/4: the platform's "golden rule" Manager Code gate (spec §3/§6) —
/// every Driver registers against a specific Manager's territory code. Not
/// wired to a real backend yet — there's no Firestore lookup to validate a
/// Manager Code against (a real Driver account is currently only ever
/// created by a Manager directly, via `manager_driver_create_screen.dart`),
/// so every code is rejected here rather than a fixed demo one silently
/// succeeding.
class DriverManagerCodeScreen extends ConsumerStatefulWidget {
  const DriverManagerCodeScreen({super.key});

  @override
  ConsumerState<DriverManagerCodeScreen> createState() => _DriverManagerCodeScreenState();
}

class _DriverManagerCodeScreenState extends ConsumerState<DriverManagerCodeScreen> {
  final _codeController = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    _codeController.text = ref.read(driverRegistrationProvider).managerCode;
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _continue() {
    // No real backend to validate a Manager Code against yet — see this
    // screen's doc comment.
    setState(() => _error = "Driver self-registration isn't available yet. Ask your Territory Manager to add you directly.");
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Scaffold(
      appBar: AppBar(title: const Text('Become a Driver · 2 of 4')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        children: [
          Icon(Icons.qr_code_2_rounded, size: 40, color: palette.primary),
          const SizedBox(height: 16),
          Text('Enter your Manager Code', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            'Your local Quicky Manager gave you this code when they signed you up — it links your account to their territory for review.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          AppTextField(label: 'Manager code', controller: _codeController, hint: 'e.g. MG-HYD-014', prefixIcon: Icons.pin_outlined),
          if (_error != null) ...[
            const SizedBox(height: 14),
            Text(_error!, style: TextStyle(color: palette.error, fontWeight: FontWeight.w600, fontSize: 12.5)),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: ElevatedButton(onPressed: _continue, child: const Text('Verify & continue')),
        ),
      ),
    );
  }
}
