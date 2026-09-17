import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/account.dart';
import '../../data/models/vendor_document.dart';
import '../../data/providers/firestore_vendors_provider.dart';
import '../../data/providers/mock_accounts_provider.dart';
import '../../data/providers/vendor_document_storage_provider.dart';
import 'app_network_image.dart';
import 'document_source_sheet.dart';
import 'document_viewer_screen.dart';

/// The Required/Not Required/Submitted document checklist a Vendor manages
/// from their own login — the flip side of Manager's Vendor Detail screen
/// (`manager_vendor_detail_screen.dart`), which decides which of the 4
/// fixed documents are required for this vendor; only the signed-in Vendor
/// can move one to Submitted, from here. Once every required document is
/// submitted, Manager's screen surfaces "Ready to Activate" instead of
/// "Pending".
///
/// Shared by two places a Vendor sees it: the post-activation "My
/// Documents" screen (`vendor/profile/vendor_documents_status_screen.dart`),
/// and the "Account under review" screen a still-`pendingReview` vendor
/// lands on (`shared/auth/auth_under_review_screen.dart`) — a pending
/// Vendor can't reach `/vendor/**` routes yet (see `session_redirect.dart`),
/// so this needs to work embedded there too, not just as its own screen.
///
/// Pick → crop → upload to Firebase Storage
/// (`vendor_document_storage_provider.dart`), then persist both the status
/// and the download URL via the same Firestore/mock split every other
/// vendor mutation in this app uses.
class VendorDocumentChecklist extends ConsumerStatefulWidget {
  const VendorDocumentChecklist({super.key, required this.account, required this.isFirestoreBacked});

  final Account account;
  final bool isFirestoreBacked;

  @override
  ConsumerState<VendorDocumentChecklist> createState() => _VendorDocumentChecklistState();
}

class _VendorDocumentChecklistState extends ConsumerState<VendorDocumentChecklist> {
  final _uploading = <VendorDocumentType>{};

  Future<void> _submit(VendorDocumentType type) async {
    final source = await DocumentSourceSheet.show(context);
    if (source == null || !mounted) return;

    XFile? picked;
    try {
      picked = await ImagePicker().pickImage(source: source, imageQuality: 90);
    } catch (_) {
      // No camera/gallery available in this environment (e.g. simulator
      // without photos) — fall through, nothing picked.
    }
    if (picked == null || !mounted) return;

    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      compressQuality: 80,
      uiSettings: [
        AndroidUiSettings(toolbarTitle: 'Crop ${type.label}', lockAspectRatio: false),
        IOSUiSettings(title: 'Crop ${type.label}'),
      ],
    );
    if (cropped == null || !mounted) return;

    setState(() => _uploading.add(type));
    try {
      final url = await uploadVendorDocument(widget.account.id, type, File(cropped.path));
      if (widget.isFirestoreBacked) {
        await updateVendorDocumentUrl(widget.account.id, type, url);
        await updateVendorDocumentStatus(widget.account.id, type, VendorDocumentStatus.submitted);
      } else {
        ref.read(mockAccountsProvider.notifier).updateDocumentUrl(widget.account.id, type, url);
        ref.read(mockAccountsProvider.notifier).updateDocumentStatus(widget.account.id, type, VendorDocumentStatus.submitted);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Upload failed. Please try again.')));
      }
    } finally {
      if (mounted) setState(() => _uploading.remove(type));
    }
  }

  Future<void> _delete(VendorDocumentType type) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${type.label}?'),
        content: const Text('You can upload a new photo afterwards.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _uploading.add(type));
    try {
      await deleteVendorDocumentFile(widget.account.id, type);
      if (widget.isFirestoreBacked) {
        await clearVendorDocumentUrl(widget.account.id, type);
        await updateVendorDocumentStatus(widget.account.id, type, VendorDocumentStatus.required);
      } else {
        ref.read(mockAccountsProvider.notifier).clearDocumentUrl(widget.account.id, type);
        ref.read(mockAccountsProvider.notifier).updateDocumentStatus(widget.account.id, type, VendorDocumentStatus.required);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not delete. Please try again.')));
      }
    } finally {
      if (mounted) setState(() => _uploading.remove(type));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final type in VendorDocumentType.values)
          if (widget.account.documentStatus(type) != VendorDocumentStatus.notRequired)
            _DocumentTile(
              type: type,
              status: widget.account.documentStatus(type),
              imageUrl: widget.account.documentUrl(type),
              uploading: _uploading.contains(type),
              onTap: widget.account.documentStatus(type) == VendorDocumentStatus.required ? () => _submit(type) : null,
              onView: (url) => DocumentViewerScreen.show(context, imageUrl: url, title: type.label),
              onDelete: () => _delete(type),
            ),
      ],
    );
  }
}

class _DocumentTile extends StatelessWidget {
  const _DocumentTile({
    required this.type,
    required this.status,
    required this.imageUrl,
    required this.uploading,
    required this.onTap,
    required this.onView,
    required this.onDelete,
  });
  final VendorDocumentType type;
  final VendorDocumentStatus status;
  final String? imageUrl;
  final bool uploading;
  final VoidCallback? onTap;
  final ValueChanged<String> onView;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final submitted = status == VendorDocumentStatus.submitted;
    final notRequired = status == VendorDocumentStatus.notRequired;
    final color = submitted ? palette.success : (notRequired ? palette.textMuted : palette.primary);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: uploading ? null : onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: notRequired ? palette.surfaceMuted : palette.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: submitted ? palette.success : (notRequired ? palette.border : palette.primary)),
          ),
          child: Row(
            children: [
              if (submitted && imageUrl != null)
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: uploading ? null : () => onView(imageUrl!),
                  child: AppNetworkImage(url: imageUrl!, width: 42, height: 42, borderRadius: BorderRadius.circular(10)),
                )
              else
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(color: palette.surfaceMuted, borderRadius: BorderRadius.circular(10)),
                  child: uploading
                      ? Padding(padding: const EdgeInsets.all(11), child: CircularProgressIndicator(strokeWidth: 2, color: palette.primary))
                      : Icon(submitted ? Icons.check_circle_rounded : type.icon, color: color),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(type.label, style: TextStyle(fontWeight: FontWeight.w700, color: palette.textPrimary)),
                    const SizedBox(height: 3),
                    Text(
                      uploading
                          ? 'Uploading…'
                          : switch (status) {
                              VendorDocumentStatus.notRequired => 'Not required',
                              VendorDocumentStatus.required => 'Tap to submit from camera or gallery',
                              VendorDocumentStatus.submitted => 'Submitted — awaiting Manager review',
                            },
                      style: TextStyle(fontSize: 12.5, color: color),
                    ),
                  ],
                ),
              ),
              if (submitted && !uploading)
                IconButton(
                  tooltip: 'Delete',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.delete_outline_rounded, size: 20, color: palette.error),
                  onPressed: onDelete,
                )
              else if (!notRequired && !uploading)
                Icon(Icons.chevron_right_rounded, color: color),
            ],
          ),
        ),
      ),
    );
  }
}
