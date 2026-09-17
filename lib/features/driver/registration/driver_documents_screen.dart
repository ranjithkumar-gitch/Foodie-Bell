import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_text_field.dart';
import 'driver_registration_controller.dart';
import 'driver_upload_tile.dart';

/// Step 4/4: driving licence, ID proof, bank/UPI payout details, and a
/// selfie/liveness capture affordance — then hands off to the shared
/// phone+OTP+terms screens as the very last step. AuthOtpScreen (register
/// mode) routes to `/auth/terms`, which is the screen that actually fires
/// `completeRegistration()` and lands the Driver on `/auth/under-review`
/// (Driver requires approval — see AppRoleX.requiresApproval).
class DriverDocumentsScreen extends ConsumerStatefulWidget {
  const DriverDocumentsScreen({super.key});

  @override
  ConsumerState<DriverDocumentsScreen> createState() => _DriverDocumentsScreenState();
}

class _DriverDocumentsScreenState extends ConsumerState<DriverDocumentsScreen> {
  final _bankController = TextEditingController();
  String? _licenseFileName;
  String? _idProofFileName;
  String? _selfieFileName;
  String? _error;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(driverRegistrationProvider);
    _bankController.text = draft.bankOrUpi;
    _licenseFileName = draft.licenseFileName;
    _idProofFileName = draft.idProofFileName;
    _selfieFileName = draft.selfieFileName;
  }

  @override
  void dispose() {
    _bankController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_licenseFileName == null || _idProofFileName == null || _selfieFileName == null || _bankController.text.trim().isEmpty) {
      setState(() => _error = 'Upload every document and add your bank/UPI details to continue.');
      return;
    }
    setState(() => _error = null);
    ref
        .read(driverRegistrationProvider.notifier)
        .updateDocuments(
          licenseFileName: _licenseFileName,
          idProofFileName: _idProofFileName,
          bankOrUpi: _bankController.text.trim(),
          selfieFileName: _selfieFileName,
        );
    context.go('/auth/phone?mode=register');
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Scaffold(
      appBar: AppBar(title: const Text('Become a Driver · 4 of 4')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        children: [
          Text('Documents & payout', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text('Last step — our team reviews these before you go live.', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 20),
          DriverUploadTile(
            label: 'Driving licence',
            fileName: _licenseFileName,
            icon: Icons.badge_outlined,
            onPicked: (name) => setState(() => _licenseFileName = name),
          ),
          const SizedBox(height: 14),
          DriverUploadTile(
            label: 'Aadhaar / ID proof',
            fileName: _idProofFileName,
            icon: Icons.credit_card_outlined,
            onPicked: (name) => setState(() => _idProofFileName = name),
          ),
          const SizedBox(height: 14),
          DriverUploadTile(
            label: 'Selfie (liveness check)',
            fileName: _selfieFileName,
            icon: Icons.camera_alt_outlined,
            source: ImageSource.camera,
            onPicked: (name) => setState(() => _selfieFileName = name),
          ),
          const SizedBox(height: 20),
          AppTextField(
            label: 'Bank account / UPI ID for payouts',
            controller: _bankController,
            hint: 'e.g. yourname@upi',
            prefixIcon: Icons.account_balance_outlined,
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            Text(_error!, style: TextStyle(color: palette.error, fontWeight: FontWeight.w600, fontSize: 12.5)),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: ElevatedButton(onPressed: _submit, child: const Text('Submit for review')),
        ),
      ),
    );
  }
}
