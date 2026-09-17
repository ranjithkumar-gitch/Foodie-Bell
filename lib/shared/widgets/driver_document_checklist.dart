import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/account.dart';
import '../../data/models/driver_document.dart';
import '../../data/models/vendor_document.dart';
import '../../data/providers/driver_document_storage_provider.dart';
import '../../data/providers/firestore_drivers_provider.dart';
import '../../data/providers/mock_accounts_provider.dart';
import 'app_network_image.dart';
import 'document_source_sheet.dart';
import 'document_viewer_screen.dart';

/// The Required/Not Required/Submitted document checklist a Driver manages
/// from their own login, plus the mandatory risk-consent acknowledgment.
///
/// Unlike `vendor_document_checklist.dart` (which uploads the instant a
/// photo is cropped), picking/cropping a document or checking consent here
/// only stages it locally — nothing is written to Storage/Firestore until
/// the Driver taps the single "Upload" button at the bottom, which submits
/// every staged document plus consent together in one call
/// (`submitDriverDocuments`/`AccountsNotifier.submitDriverDocuments`). This
/// lets the Driver preview, replace, or remove a pick before committing to
/// it, rather than an API call firing on every tap. A document already
/// submitted in a previous session can still be replaced (tap it again to
/// stage a new photo — "resubmit") or deleted outright (immediate, behind
/// its own confirmation dialog, same as Vendor's).
///
/// Shared by two places a Driver sees it: the post-activation "My
/// Documents" screen (`driver/profile/driver_documents_status_screen.dart`),
/// and the "Account under review" screen a still-`pendingReview` driver
/// lands on (`shared/auth/auth_under_review_screen.dart`).
class DriverDocumentChecklist extends ConsumerStatefulWidget {
  const DriverDocumentChecklist({super.key, required this.account, required this.isFirestoreBacked});

  final Account account;
  final bool isFirestoreBacked;

  @override
  ConsumerState<DriverDocumentChecklist> createState() => _DriverDocumentChecklistState();
}

class _DriverDocumentChecklistState extends ConsumerState<DriverDocumentChecklist> {
  final Map<DriverDocumentType, File> _stagedFiles = {};
  final _deleting = <DriverDocumentType>{};
  bool _consentStaged = false;
  bool _uploading = false;

  bool get _hasPendingChanges => _stagedFiles.isNotEmpty || (_consentStaged && !widget.account.riskConsentAccepted);

  Future<void> _pick(DriverDocumentType type) async {
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

    setState(() => _stagedFiles[type] = File(cropped.path));
  }

  void _unstage(DriverDocumentType type) => setState(() => _stagedFiles.remove(type));

  void _toggleConsent() {
    if (widget.account.riskConsentAccepted) return;
    setState(() => _consentStaged = !_consentStaged);
  }

  Future<void> _deletePersisted(DriverDocumentType type) async {
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

    setState(() => _deleting.add(type));
    try {
      await deleteDriverDocumentFile(widget.account.id, type);
      if (widget.isFirestoreBacked) {
        await clearDriverDocumentUrl(widget.account.id, type);
        await updateDriverDocumentStatus(widget.account.id, type, VendorDocumentStatus.required);
      } else {
        ref.read(mockAccountsProvider.notifier).clearDriverDocumentUrl(widget.account.id, type);
        ref.read(mockAccountsProvider.notifier).updateDriverDocumentStatus(widget.account.id, type, VendorDocumentStatus.required);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not delete. Please try again.')));
      }
    } finally {
      if (mounted) setState(() => _deleting.remove(type));
    }
  }

  void _viewStaged(File file, String title) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            InteractiveViewer(child: Image.file(file)),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(icon: const Icon(Icons.close_rounded, color: Colors.white), onPressed: () => Navigator.of(context).pop()),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _upload() async {
    if (!_hasPendingChanges || _uploading) return;
    setState(() => _uploading = true);
    try {
      final urls = <DriverDocumentType, String>{};
      await Future.wait(
        _stagedFiles.entries.map((entry) async {
          urls[entry.key] = await uploadDriverDocument(widget.account.id, entry.key, entry.value);
        }),
      );
      final consent = _consentStaged && !widget.account.riskConsentAccepted ? true : null;
      if (widget.isFirestoreBacked) {
        await submitDriverDocuments(widget.account.id, urls, riskConsentAccepted: consent);
      } else {
        ref.read(mockAccountsProvider.notifier).submitDriverDocuments(widget.account.id, urls, riskConsentAccepted: consent);
      }
      if (!mounted) return;
      setState(() {
        _stagedFiles.clear();
        _consentStaged = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Submitted for review.')));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not submit. Please try again.')));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ConsentCard(
          accepted: widget.account.riskConsentAccepted,
          staged: _consentStaged,
          onToggle: _uploading ? null : _toggleConsent,
        ),
        const SizedBox(height: 20),
        for (final type in DriverDocumentType.values)
          _DocumentTile(
            type: type,
            status: widget.account.driverDocumentStatus(type),
            persistedUrl: widget.account.driverDocumentUrl(type),
            stagedFile: _stagedFiles[type],
            deleting: _deleting.contains(type),
            busy: _uploading,
            onTap: widget.account.driverDocumentStatus(type) == VendorDocumentStatus.notRequired ? null : () => _pick(type),
            onUnstage: () => _unstage(type),
            onViewPersisted: (url) => DocumentViewerScreen.show(context, imageUrl: url, title: type.label),
            onViewStaged: (file) => _viewStaged(file, type.label),
            onDeletePersisted: () => _deletePersisted(type),
          ),
        if (_hasPendingChanges) ...[
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _uploading ? null : _upload,
              icon: _uploading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2))
                  : const Icon(Icons.cloud_upload_rounded),
              label: Text(_uploading ? 'Submitting…' : 'Upload'),
            ),
          ),
        ],
      ],
    );
  }
}

class _ConsentCard extends StatelessWidget {
  const _ConsentCard({required this.accepted, required this.staged, required this.onToggle});
  final bool accepted;
  final bool staged;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final checked = accepted || staged;
    final color = accepted ? palette.success : (staged ? palette.primary : palette.primary);
    return Container(
      decoration: BoxDecoration(
        color: accepted ? palette.success.withValues(alpha: 0.08) : (staged ? palette.primary.withValues(alpha: 0.06) : palette.surface),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color),
      ),
      child: Column(
        children: [
          CheckboxListTile(
            value: checked,
            onChanged: accepted ? null : (v) => onToggle?.call(),
            controlAffinity: ListTileControlAffinity.leading,
            title: Text('Risk acknowledgment', style: TextStyle(fontWeight: FontWeight.w700, color: palette.textPrimary)),
            subtitle: Text(
              'I understand that driving involves inherent risks (road, traffic, weather) and I am taking up this work willingly, of my own free will and without any pressure.',
              style: TextStyle(fontSize: 12.5, color: palette.textSecondary),
            ),
          ),
          if (staged && !accepted)
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 10),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 14, color: palette.primary),
                  const SizedBox(width: 6),
                  Text('Added — tap Upload below to confirm', style: TextStyle(fontSize: 11.5, color: palette.primary, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DocumentTile extends StatelessWidget {
  const _DocumentTile({
    required this.type,
    required this.status,
    required this.persistedUrl,
    required this.stagedFile,
    required this.deleting,
    required this.busy,
    required this.onTap,
    required this.onUnstage,
    required this.onViewPersisted,
    required this.onViewStaged,
    required this.onDeletePersisted,
  });
  final DriverDocumentType type;
  final VendorDocumentStatus status;
  final String? persistedUrl;
  final File? stagedFile;
  final bool deleting;
  final bool busy;
  final VoidCallback? onTap;
  final VoidCallback onUnstage;
  final ValueChanged<String> onViewPersisted;
  final ValueChanged<File> onViewStaged;
  final VoidCallback onDeletePersisted;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final staged = stagedFile != null;
    final submitted = status == VendorDocumentStatus.submitted;
    final notRequired = status == VendorDocumentStatus.notRequired;
    final tickShown = staged || submitted;
    final color = staged ? palette.primary : (submitted ? palette.success : (notRequired ? palette.textMuted : palette.primary));
    final subtitle = deleting
        ? 'Deleting…'
        : staged
        ? 'Added — tap Upload below to submit'
        : switch (status) {
            VendorDocumentStatus.notRequired => 'Not required',
            VendorDocumentStatus.required => 'Tap to add from camera or gallery',
            VendorDocumentStatus.submitted => 'Submitted — awaiting Manager review',
          };

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: busy || deleting ? null : onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: notRequired ? palette.surfaceMuted : palette.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: staged ? palette.primary : (submitted ? palette.success : (notRequired ? palette.border : palette.primary))),
          ),
          child: Row(
            children: [
              if (stagedFile != null)
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => onViewStaged(stagedFile!),
                  child: ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.file(stagedFile!, width: 42, height: 42, fit: BoxFit.cover)),
                )
              else if (submitted && persistedUrl != null)
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => onViewPersisted(persistedUrl!),
                  child: AppNetworkImage(url: persistedUrl!, width: 42, height: 42, borderRadius: BorderRadius.circular(10)),
                )
              else
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(color: palette.surfaceMuted, borderRadius: BorderRadius.circular(10)),
                  child: deleting
                      ? Padding(padding: const EdgeInsets.all(11), child: CircularProgressIndicator(strokeWidth: 2, color: palette.primary))
                      : Icon(type.icon, color: color),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (tickShown) Icon(Icons.check_circle_rounded, size: 15, color: color),
                        if (tickShown) const SizedBox(width: 5),
                        Flexible(child: Text(type.label, style: TextStyle(fontWeight: FontWeight.w700, color: palette.textPrimary))),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(subtitle, style: TextStyle(fontSize: 12.5, color: color)),
                  ],
                ),
              ),
              if (deleting)
                const SizedBox.shrink()
              else if (staged)
                IconButton(
                  tooltip: 'Remove',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.close_rounded, size: 20, color: palette.error),
                  onPressed: busy ? null : onUnstage,
                )
              else if (submitted)
                IconButton(
                  tooltip: 'Delete',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.delete_outline_rounded, size: 20, color: palette.error),
                  onPressed: busy ? null : onDeletePersisted,
                )
              else if (!notRequired)
                Icon(Icons.chevron_right_rounded, color: color),
            ],
          ),
        ),
      ),
    );
  }
}
