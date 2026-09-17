import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/session/session_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/review.dart';
import '../../../data/providers/firestore_orders_provider.dart';
import '../../../data/providers/firestore_reviews_provider.dart';
import '../../../l10n/app_localizations_context.dart';
import '../../../shared/error_reporting.dart';

/// Rate & Review (spec §4.15): star rating for vendor + driver (driver only
/// shown when the order has one), a comment box, and photo upload via
/// `image_picker` (tracks picked filenames only — no real storage backend,
/// matching the pattern in `driver_upload_tile.dart`). Reached from
/// `order_detail_screen.dart` for delivered orders that haven't been
/// reviewed yet. Submits to `firestoreReviewsProvider` — real and visible to
/// the Vendor and every other User browsing that vendor's storefront, not
/// just this session.
class RateReviewScreen extends ConsumerStatefulWidget {
  const RateReviewScreen({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<RateReviewScreen> createState() => _RateReviewScreenState();
}

class _RateReviewScreenState extends ConsumerState<RateReviewScreen> {
  int _vendorRating = 5;
  int _driverRating = 5;
  final _commentController = TextEditingController();
  final List<XFile> _photos = [];
  bool _submitting = false;
  String? _error;

  Future<void> _addPhoto() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked != null) setState(() => _photos.add(picked));
  }

  Future<void> _submit(String vendorId, String? driverId, bool hasDriver) async {
    final account = ref.read(sessionControllerProvider).account;
    if (account == null) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final review = Review(
      id: 'rev-${DateTime.now().millisecondsSinceEpoch}',
      orderId: widget.orderId,
      userId: account.id,
      userName: account.name,
      vendorId: vendorId,
      vendorRating: _vendorRating,
      driverId: hasDriver ? driverId : null,
      driverRating: hasDriver ? _driverRating : null,
      comment: _commentController.text.trim().isEmpty ? null : _commentController.text.trim(),
      photoUrls: _photos.map((p) => p.name).toList(),
      createdAt: DateTime.now(),
    );
    try {
      await submitReview(review);
    } catch (e, st) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = friendlyError(e, action: 'Submitting review', stackTrace: st);
      });
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.rateReviewSubmittedSnack)));
    context.pop();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final order = ref.watch(orderByIdProvider(widget.orderId)).valueOrNull;
    if (order == null) {
      return Scaffold(appBar: AppBar(title: Text(context.l10n.rateReviewTitle)), body: const Center(child: CircularProgressIndicator()));
    }
    final hasDriver = order.driverName != null;

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.rateReviewTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: palette.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: palette.border)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.l10n.rateReviewRateEntity(order.vendorName), style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),
                _StarRow(rating: _vendorRating, onChanged: (r) => setState(() => _vendorRating = r)),
              ],
            ),
          ),
          if (hasDriver) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: palette.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: palette.border)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.l10n.rateReviewRateEntity(order.driverName!), style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 10),
                  _StarRow(rating: _driverRating, onChanged: (r) => setState(() => _driverRating = r)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: palette.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: palette.border)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.l10n.rateReviewAddComment, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),
                TextField(
                  controller: _commentController,
                  minLines: 3,
                  maxLines: 5,
                  decoration: InputDecoration(hintText: context.l10n.rateReviewCommentHint),
                ),
                const SizedBox(height: 14),
                Text(context.l10n.rateReviewAddPhotos, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: palette.textPrimary)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final photo in _photos) _PhotoChip(photo: photo, onRemove: () => setState(() => _photos.remove(photo))),
                    _AddPhotoTile(onTap: _addPhoto),
                  ],
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            Text(_error!, style: TextStyle(color: palette.error, fontWeight: FontWeight.w600, fontSize: 12.5)),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitting ? null : () => _submit(order.vendorId, order.driverId, hasDriver),
              child: _submitting
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4))
                  : Text(context.l10n.rateReviewSubmitButton),
            ),
          ),
        ],
      ),
    );
  }
}

class _StarRow extends StatelessWidget {
  const _StarRow({required this.rating, required this.onChanged});
  final int rating;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Row(
      children: [
        for (var i = 1; i <= 5; i++)
          InkWell(
            onTap: () => onChanged(i),
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                i <= rating ? Icons.star_rounded : Icons.star_border_rounded,
                color: i <= rating ? palette.secondary : palette.textMuted,
                size: 32,
              ),
            ),
          ),
      ],
    );
  }
}

class _PhotoChip extends StatelessWidget {
  const _PhotoChip({required this.photo, required this.onRemove});
  final XFile photo;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(color: palette.surfaceMuted, borderRadius: BorderRadius.circular(12), border: Border.all(color: palette.border)),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.file(File(photo.path), fit: BoxFit.cover),
          Positioned(
            top: 2,
            right: 2,
            child: InkWell(
              onTap: onRemove,
              borderRadius: BorderRadius.circular(10),
              child: CircleAvatar(radius: 10, backgroundColor: palette.error, child: const Icon(Icons.close_rounded, size: 12, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddPhotoTile extends StatelessWidget {
  const _AddPhotoTile({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: palette.border, style: BorderStyle.solid),
        ),
        child: Icon(Icons.add_a_photo_outlined, color: palette.textSecondary),
      ),
    );
  }
}
