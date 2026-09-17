import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/session/session_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/address.dart';
import '../../../data/models/list_order_request.dart';
import '../../../data/providers/firestore_addresses_provider.dart';
import '../../../data/providers/firestore_list_order_requests_provider.dart';
import '../../../data/providers/list_order_image_storage_provider.dart';
import '../../../shared/widgets/document_source_sheet.dart';
import '../address_label_text.dart';
import '../addresses/add_address_sheet.dart';

/// "Order via Photo" (Pharmacy/Kirana/Vegetables vendors, per
/// `vendor_detail_screen.dart`'s entry banner): User photographs whatever
/// they want ordered — no typed item list, no OCR — picks a delivery
/// address, and submits both to the vendor as a [ListOrderRequest]. The
/// vendor prices it themselves after looking at the photos
/// (`vendor_order_queue_screen.dart`); once quoted, paid, and confirmed
/// the request becomes a real tracked `Order` (see
/// `firestore_list_order_requests_provider.dart`).
class ListOrderCaptureScreen extends ConsumerStatefulWidget {
  const ListOrderCaptureScreen({
    super.key,
    required this.vendorId,
    required this.vendorName,
  });

  final String vendorId;
  final String vendorName;

  @override
  ConsumerState<ListOrderCaptureScreen> createState() =>
      _ListOrderCaptureScreenState();
}

class _ListOrderCaptureScreenState
    extends ConsumerState<ListOrderCaptureScreen> {
  final List<File> _photos = [];
  Address? _selectedAddress;
  bool _submitting = false;

  Future<void> _addPhoto() async {
    final source = await DocumentSourceSheet.show(
      context,
      title: 'Add a photo',
      subtitle: 'Take a clear photo of what you\'d like to order.',
    );
    if (source == null || !mounted) return;

    XFile? picked;
    try {
      picked = await ImagePicker().pickImage(source: source, imageQuality: 90);
    } catch (_) {
      // No camera/gallery available in this environment.
    }
    if (picked == null || !mounted) return;

    setState(() => _photos.add(File(picked!.path)));
  }

  void _removePhoto(int index) => setState(() => _photos.removeAt(index));

  void _viewPhoto(File file) {
    showDialog(
      context: context,
      builder: (context) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 5,
                child: Image.file(file, fit: BoxFit.contain),
              ),
            ),
            SafeArea(
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAddress(List<Address> addresses) async {
    if (addresses.isEmpty) {
      final saved = await showModalBottomSheet<Address>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => AddAddressSheet(onSaved: (a) => Navigator.of(context).pop(a)),
      );
      if (saved != null && mounted) setState(() => _selectedAddress = saved);
      return;
    }
    final picked = await showModalBottomSheet<Address>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddressPickerSheet(addresses: addresses),
    );
    if (picked != null) setState(() => _selectedAddress = picked);
  }

  Future<void> _submit() async {
    final account = ref.read(sessionControllerProvider).account;
    final address = _selectedAddress;
    if (account == null || _photos.isEmpty || address == null) return;

    setState(() => _submitting = true);
    try {
      final imageUrls = await uploadListOrderImages(widget.vendorId, _photos);
      final id = listOrderRequestsCollection.doc().id;
      await submitListOrderRequest(
        ListOrderRequest(
          id: id,
          vendorId: widget.vendorId,
          vendorName: widget.vendorName,
          userId: account.id,
          userName: account.name,
          userPhone: account.phone,
          imageUrls: imageUrls,
          deliveryAddressLabel: address.shortLabel,
          status: ListOrderStatus.pending,
          createdAt: DateTime.now(),
        ),
      );
      if (!mounted) return;
      context.pushReplacement('/user/list-order/$id');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not submit your order. Please try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final userId = ref.watch(sessionControllerProvider).account?.id;
    final addresses = userId == null
        ? const <Address>[]
        : ref.watch(firestoreAddressesProvider(userId)).valueOrNull ?? const [];
    final canSubmit = _photos.isNotEmpty && _selectedAddress != null && !_submitting;

    return Scaffold(
      appBar: AppBar(title: const Text('Order via Photo')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Text(
              'Snap photo(s) of what you\'d like to order — ${widget.vendorName} will look them over and send you a price.',
              style: TextStyle(color: palette.textSecondary, fontSize: 13.5),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (var i = 0; i < _photos.length; i++)
                  _PhotoThumbnail(
                    file: _photos[i],
                    onTap: () => _viewPhoto(_photos[i]),
                    onRemove: () => _removePhoto(i),
                  ),
                _AddPhotoTile(onTap: _submitting ? null : _addPhoto),
              ],
            ),
            const SizedBox(height: 24),
            Text('Deliver to', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 10),
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: _submitting ? null : () => _pickAddress(addresses),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: palette.border),
                ),
                child: Row(
                  children: [
                    Icon(Icons.place_rounded, color: palette.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _selectedAddress == null
                          ? Text(
                              'Choose a delivery address',
                              style: TextStyle(color: palette.textMuted),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  addressLabelText(context, _selectedAddress!.label),
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                                Text(
                                  _selectedAddress!.line1,
                                  style: TextStyle(color: palette.textSecondary, fontSize: 12.5),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                    ),
                    Icon(Icons.keyboard_arrow_down_rounded, color: palette.textMuted),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: canSubmit ? _submit : null,
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Send to vendor'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoThumbnail extends StatelessWidget {
  const _PhotoThumbnail({required this.file, required this.onTap, required this.onRemove});

  final File file;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.file(file, width: 100, height: 100, fit: BoxFit.cover),
          ),
          Positioned(
            right: 2,
            top: 2,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddPhotoTile extends StatelessWidget {
  const _AddPhotoTile({required this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: palette.surfaceMuted,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: palette.border),
        ),
        child: Icon(Icons.add_a_photo_outlined, color: palette.primary),
      ),
    );
  }
}

class _AddressPickerSheet extends StatelessWidget {
  const _AddressPickerSheet({required this.addresses});
  final List<Address> addresses;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Deliver to', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            for (final address in addresses)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: palette.surfaceMuted,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => Navigator.pop(context, address),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Icon(Icons.place_outlined, color: palette.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  addressLabelText(context, address.label),
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                                Text(
                                  address.line1,
                                  style: TextStyle(color: palette.textSecondary, fontSize: 12.5),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
