import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/vendor.dart';
import 'vendor_registration_scaffold.dart';
import 'vendor_registration_state.dart';

/// Registration step 3 — Documents (spec §5.3): FSSAI (required for Food),
/// GST (optional), PAN, and Bank/UPI details. Uses `image_picker` purely as
/// a believable camera/gallery affordance — nothing is ever actually
/// uploaded, we just remember & show the picked filename.
class VendorDocumentsScreen extends ConsumerStatefulWidget {
  const VendorDocumentsScreen({super.key});

  @override
  ConsumerState<VendorDocumentsScreen> createState() => _VendorDocumentsScreenState();
}

class _VendorDocumentsScreenState extends ConsumerState<VendorDocumentsScreen> {
  String? _fssai;
  String? _gst;
  String? _pan;
  String? _bankUpi;
  String? _error;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(vendorRegistrationProvider);
    _fssai = draft.fssaiFileName;
    _gst = draft.gstFileName;
    _pan = draft.panFileName;
    _bankUpi = draft.bankUpiFileName;
  }

  Future<void> _pick(ValueChanged<String> onPicked) async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (file != null) onPicked(file.name);
    } catch (_) {
      // No camera/gallery available in this environment (e.g. simulator
      // without photos) — fall back to a believable placeholder filename
      // so the demo flow never gets stuck.
      onPicked('document_${DateTime.now().millisecondsSinceEpoch}.jpg');
    }
  }

  void _continue() {
    final requiresFssai = ref.read(vendorRegistrationProvider).category == VendorCategory.food;
    if ((requiresFssai && _fssai == null) || _pan == null || _bankUpi == null) {
      setState(() => _error = 'Please upload all required documents to continue.');
      return;
    }
    setState(() => _error = null);
    ref.read(vendorRegistrationProvider.notifier).update((d) => d.copyWith(
      fssaiFileName: _fssai,
      gstFileName: _gst,
      panFileName: _pan,
      bankUpiFileName: _bankUpi,
    ));
    context.push('/vendor/register/location-hours');
  }

  @override
  Widget build(BuildContext context) {
    final category = ref.watch(vendorRegistrationProvider).category;
    final palette = context.colors;
    return VendorRegistrationScaffold(
      step: 3,
      totalSteps: 5,
      title: 'Upload your documents',
      subtitle: 'These are reviewed by your Manager before your store goes live.',
      onContinue: _continue,
      children: [
        if (category == VendorCategory.food)
          _DocumentUploadTile(
            label: 'FSSAI License',
            required: true,
            fileName: _fssai,
            onTap: () => _pick((name) => setState(() => _fssai = name)),
          ),
        _DocumentUploadTile(
          label: 'GST Certificate',
          required: false,
          fileName: _gst,
          onTap: () => _pick((name) => setState(() => _gst = name)),
        ),
        _DocumentUploadTile(
          label: 'PAN Card',
          required: true,
          fileName: _pan,
          onTap: () => _pick((name) => setState(() => _pan = name)),
        ),
        _DocumentUploadTile(
          label: 'Bank Account / UPI Details',
          required: true,
          fileName: _bankUpi,
          onTap: () => _pick((name) => setState(() => _bankUpi = name)),
        ),
        if (_error != null) ...[
          const SizedBox(height: 6),
          Text(_error!, style: TextStyle(color: palette.error, fontWeight: FontWeight.w600, fontSize: 12.5)),
        ],
      ],
    );
  }
}

class _DocumentUploadTile extends StatelessWidget {
  const _DocumentUploadTile({required this.label, required this.required, required this.fileName, required this.onTap});

  final String label;
  final bool required;
  final String? fileName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final uploaded = fileName != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: uploaded ? palette.primary : palette.border),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: palette.surfaceMuted, borderRadius: BorderRadius.circular(10)),
                child: Icon(
                  uploaded ? Icons.description_rounded : Icons.upload_file_rounded,
                  color: uploaded ? palette.primary : palette.textSecondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: palette.textPrimary)),
                        if (required) ...[
                          const SizedBox(width: 6),
                          Text('*', style: TextStyle(color: palette.error, fontWeight: FontWeight.w800)),
                        ] else ...[
                          const SizedBox(width: 6),
                          Text('(optional)', style: TextStyle(fontSize: 11, color: palette.textMuted)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      uploaded ? fileName! : 'Tap to upload from camera or gallery',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, color: uploaded ? palette.success : palette.textMuted),
                    ),
                  ],
                ),
              ),
              Icon(uploaded ? Icons.check_circle_rounded : Icons.chevron_right_rounded, color: uploaded ? palette.success : palette.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
