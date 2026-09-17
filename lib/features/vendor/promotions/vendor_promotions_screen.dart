import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/session/session_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/account.dart';
import '../../../data/models/coupon.dart';
import '../../../data/models/product.dart';
import '../../../data/models/promotion.dart';
import '../../../data/models/vendor_document.dart';
import '../../../data/promotion_plans.dart';
import '../../../data/providers/firestore_coupons_provider.dart';
import '../../../data/providers/firestore_products_provider.dart';
import '../../../data/providers/firestore_promotions_provider.dart';
import '../../../data/providers/firestore_vendors_provider.dart';
import '../../../data/providers/promotion_image_storage_provider.dart';
import '../../../shared/error_reporting.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../../shared/widgets/currency_text.dart';
import '../../../shared/widgets/document_source_sheet.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/promotion_card_visual.dart';
import '../../../shared/widgets/status_chip.dart';

typedef _CouponRequestResult = ({
  CouponDiscountType discountType,
  double discountValue,
  bool appliesToAllItems,
  List<String> productIds,
  DateTime startAt,
  DateTime endAt,
});

final _dateTimeFormat = DateFormat('d MMM yyyy, h:mm a');

typedef _PromotionRequestResult = ({
  String tagline,
  String discountLabel,
  String? promoImageUrl,
  DateTime startDate,
  int durationDays,
  double price,
});

final _dateFormat = DateFormat('d MMM yyyy');

/// Promotions (spec §5.16) and Coupons, as two tabs on one screen — a
/// Vendor's "get featured on Home" placement requests and their discount
/// codes both live here since they're the two ways a Vendor drives traffic
/// from the User app, just published in different spots (Promotions on
/// Home's carousel; Coupons in the section right below it, see
/// `home_screen.dart`).
class VendorPromotionsScreen extends ConsumerWidget {
  const VendorPromotionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.colors;
    final sessionAccount = ref.watch(
      sessionControllerProvider.select((s) => s.account),
    );
    final account = sessionAccount == null
        ? null
        : ref.watch(liveVendorAccountProvider(sessionAccount.id)) ??
              sessionAccount;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Promotions'),
          bottom: TabBar(
            labelColor: palette.primary,
            unselectedLabelColor: palette.textSecondary,
            indicatorColor: palette.primary,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
            tabs: const [
              Tab(text: 'Promotions'),
              Tab(text: 'Coupons'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _PromotionsTab(account: account),
            _CouponsTab(account: account),
          ],
        ),
      ),
    );
  }
}

/// Promotions (spec §5.16): a Vendor requests to have their business
/// promoted; the request goes to their Territory Manager's approval queue
/// (`manager_promotion_approvals_screen.dart`). Once the Manager confirms
/// payment and approves, it goes live on the User Home page for that
/// territory (`home_screen.dart`) — real Firestore-backed, not a local mock
/// list of discount campaigns. A Vendor can hold any number of requests at
/// once (past, scheduled, or currently live) — each is its own scheduled
/// run ([Promotion.startDate]/[Promotion.durationDays]), not a single slot.
class _PromotionsTab extends ConsumerWidget {
  const _PromotionsTab({required this.account});
  final Account? account;

  StatusTone _tone(PromotionStatus status) => switch (status) {
    PromotionStatus.active => StatusTone.success,
    PromotionStatus.rejected => StatusTone.error,
    PromotionStatus.pending => StatusTone.warning,
    PromotionStatus.ended => StatusTone.neutral,
  };

  Future<void> _requestPromotion(
    BuildContext context,
    WidgetRef ref, {
    required String vendorId,
    required String vendorName,
    required String territory,
    String? vendorPhotoUrl,
    String? category,
  }) async {
    final result = await showModalBottomSheet<_PromotionRequestResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _RequestPromotionSheet(
        vendorId: vendorId,
        vendorName: vendorName,
        vendorPhotoUrl: vendorPhotoUrl,
      ),
    );
    if (result == null || !context.mounted) return;
    try {
      await requestPromotion(
        vendorId: vendorId,
        vendorName: vendorName,
        territory: territory,
        startDate: result.startDate,
        durationDays: result.durationDays,
        price: result.price,
        vendorPhotoUrl: vendorPhotoUrl,
        promoImageUrl: result.promoImageUrl,
        category: category,
        tagline: result.tagline.isEmpty ? null : result.tagline,
        discountLabel: result.discountLabel.isEmpty
            ? null
            : result.discountLabel,
      );
    } catch (e, st) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            friendlyError(e, action: 'Requesting promotion', stackTrace: st),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.colors;
    final account = this.account;
    final promotionsAsync = ref.watch(firestorePromotionsProvider);

    return promotionsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(
        child: Text(
          friendlyError(e, action: 'Loading promotions', stackTrace: st),
        ),
      ),
      data: (allPromotions) {
        final mine =
            allPromotions.where((p) => p.vendorId == account?.id).toList()
              ..sort((a, b) => b.requestedAt.compareTo(a.requestedAt));

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: palette.surfaceMuted,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.campaign_rounded, color: palette.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Get featured on Home',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: palette.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Pick a start date and a duration plan, and your Territory Manager will review it. Once payment is confirmed and the Manager approves, your business appears above the category list on every User\'s Home page in your territory for the dates you picked. You can request as many promotions as you like.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: palette.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: account == null
                    ? null
                    : () => _requestPromotion(
                        context,
                        ref,
                        vendorId: account.id,
                        vendorName: account.name,
                        territory: account.territory ?? '',
                        vendorPhotoUrl: account.documentUrl(
                          VendorDocumentType.shopFrontPhoto,
                        ),
                        category: account.category,
                      ),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Request Promotion'),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Your requests',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            if (mine.isEmpty)
              const EmptyState(
                icon: Icons.local_offer_outlined,
                title: 'No promotion requests yet',
                subtitle: 'Request one above to get featured on the Home page.',
              )
            else
              for (final promo in mine)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: palette.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: palette.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (promo.promoImageUrl != null ||
                            promo.vendorPhotoUrl != null) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: AppNetworkImage(
                              url:
                                  (promo.promoImageUrl ??
                                  promo.vendorPhotoUrl)!,
                              width: double.infinity,
                              height: 110,
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                promo.tagline ?? 'Promote my business',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: palette.textPrimary,
                                ),
                              ),
                            ),
                            StatusChip(
                              label: promo.status.label,
                              tone: _tone(promo.status),
                            ),
                          ],
                        ),
                        if (promo.discountLabel != null &&
                            promo.discountLabel!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: palette.secondary.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              promo.discountLabel!,
                              style: TextStyle(
                                color: palette.secondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Text(
                          promo.isOpenEnded
                              ? 'Started ${_dateFormat.format(promo.startDate)} · No end date'
                              : '${_dateFormat.format(promo.startDate)} — ${_dateFormat.format(promo.endDate!)} · ${promo.durationDays} days',
                          style: TextStyle(
                            color: palette.textSecondary,
                            fontSize: 11.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              'Requested ${_dateFormat.format(promo.requestedAt)}',
                              style: TextStyle(
                                color: palette.textMuted,
                                fontSize: 11.5,
                              ),
                            ),
                            const Spacer(),
                            CurrencyText(
                              promo.price,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12.5,
                                color: palette.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        if (promo.status == PromotionStatus.active) ...[
                          const SizedBox(height: 8),
                          StatusChip(
                            label: promo.isLiveNow
                                ? 'Live now'
                                : (promo.hasExpired ? 'Expired' : 'Scheduled'),
                            tone: promo.isLiveNow
                                ? StatusTone.success
                                : StatusTone.neutral,
                          ),
                        ],
                        if (promo.status == PromotionStatus.pending) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                promo.paymentReceived
                                    ? Icons.check_circle_rounded
                                    : Icons.pending_rounded,
                                size: 14,
                                color: promo.paymentReceived
                                    ? palette.success
                                    : palette.warning,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                promo.paymentReceived
                                    ? 'Payment received — awaiting approval'
                                    : 'Awaiting payment confirmation',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: promo.paymentReceived
                                      ? palette.success
                                      : palette.warning,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (promo.status == PromotionStatus.rejected &&
                            promo.rejectionReason != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            promo.rejectionReason!,
                            style: TextStyle(
                              color: palette.error,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
          ],
        );
      },
    );
  }
}

/// Coupons: a Vendor-created discount code (`coupon.dart`) — either a
/// percentage or a flat ₹ amount off, on their whole catalogue or a
/// hand-picked subset of it, valid for a date/time window they pick.
/// Published to Users on Home (`home_screen.dart`, below the Promotions
/// carousel) once live, and redeemable once per User (enforced at order
/// placement, `firestore_orders_provider.dart`'s `createOrderWithCoupon`).
class _CouponsTab extends ConsumerWidget {
  const _CouponsTab({required this.account});
  final Account? account;

  StatusTone _couponTone(Coupon coupon) {
    if (coupon.hasExpired) return StatusTone.neutral;
    if (coupon.isLiveNow) return StatusTone.success;
    return StatusTone.warning;
  }

  String _couponStatusLabel(Coupon coupon) {
    if (coupon.hasExpired) return 'Expired';
    if (coupon.isLiveNow) return 'Live now';
    return 'Scheduled';
  }

  Future<void> _createCoupon(
    BuildContext context,
    WidgetRef ref, {
    required String vendorId,
    required String vendorName,
  }) async {
    final products =
        ref.read(vendorProductsProvider(vendorId)).valueOrNull ?? const [];
    final result = await showModalBottomSheet<_CouponRequestResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CreateCouponSheet(products: products),
    );
    if (result == null || !context.mounted) return;
    try {
      final coupon = await createCoupon(
        vendorId: vendorId,
        vendorName: vendorName,
        discountType: result.discountType,
        discountValue: result.discountValue,
        appliesToAllItems: result.appliesToAllItems,
        productIds: result.productIds,
        startAt: result.startAt,
        endAt: result.endAt,
      );
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Coupon created'),
          content: Text(
            'Your coupon code is ${coupon.code}. Share it with customers or let them find it on their Home page.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } catch (e, st) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            friendlyError(e, action: 'Creating coupon', stackTrace: st),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.colors;
    final account = this.account;
    final couponsAsync = ref.watch(firestoreCouponsProvider);

    return couponsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(
        child: Text(
          friendlyError(e, action: 'Loading coupons', stackTrace: st),
        ),
      ),
      data: (allCoupons) {
        final mine = allCoupons.where((c) => c.vendorId == account?.id).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: palette.surfaceMuted,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.confirmation_number_outlined,
                        color: palette.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Offer a discount code',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: palette.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Discount codes on specific items or your whole catalogue, valid for a date/time window you pick. Once live, it\'s published to customers on their Home page below Promotions. Each customer can redeem a given coupon once.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: palette.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: account == null
                    ? null
                    : () => _createCoupon(
                        context,
                        ref,
                        vendorId: account.id,
                        vendorName: account.name,
                      ),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Create Coupon'),
              ),
            ),
            const SizedBox(height: 24),
            Text('Your coupons', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            if (mine.isEmpty)
              const EmptyState(
                icon: Icons.confirmation_number_outlined,
                title: 'No coupons yet',
                subtitle: 'Create one above to offer customers a discount.',
              )
            else
              for (final coupon in mine)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: palette.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: palette.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () async {
                                  await Clipboard.setData(
                                    ClipboardData(text: coupon.code),
                                  );
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Code copied'),
                                    ),
                                  );
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      coupon.code,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                        letterSpacing: 0.5,
                                        color: palette.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Icon(
                                      Icons.copy_rounded,
                                      size: 14,
                                      color: palette.textMuted,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            StatusChip(
                              label: _couponStatusLabel(coupon),
                              tone: _couponTone(coupon),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: palette.secondary.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            coupon.discountLabel,
                            style: TextStyle(
                              color: palette.secondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          coupon.appliesToAllItems
                              ? 'All items'
                              : '${coupon.productIds.length} item${coupon.productIds.length == 1 ? '' : 's'}',
                          style: TextStyle(
                            color: palette.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_dateTimeFormat.format(coupon.startAt)} — ${_dateTimeFormat.format(coupon.endAt)}',
                          style: TextStyle(
                            color: palette.textMuted,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        );
      },
    );
  }
}

class _RequestPromotionSheet extends StatefulWidget {
  const _RequestPromotionSheet({
    required this.vendorId,
    required this.vendorName,
    this.vendorPhotoUrl,
  });
  final String vendorId;
  final String vendorName;
  final String? vendorPhotoUrl;

  @override
  State<_RequestPromotionSheet> createState() => _RequestPromotionSheetState();
}

class _RequestPromotionSheetState extends State<_RequestPromotionSheet> {
  final _controller = TextEditingController();
  final _discountLabelController = TextEditingController();
  XFile? _pickedImage;
  DateTime? _startDate;
  PromotionPlan? _selectedPlan;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    _discountLabelController.dispose();
    super.dispose();
  }

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 90)),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _pickImage() async {
    final source = await DocumentSourceSheet.show(
      context,
      title: 'Add promotion image',
      subtitle: 'A 3:2 banner customers will see on your promoted card.',
    );
    if (source == null || !mounted) return;

    XFile? picked;
    try {
      picked = await ImagePicker().pickImage(source: source, imageQuality: 90);
    } catch (_) {
      // No camera/gallery available in this environment — fall through.
    }
    if (picked == null || !mounted) return;

    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      compressQuality: 85,
      aspectRatio: const CropAspectRatio(ratioX: 3, ratioY: 2),
      uiSettings: [
        AndroidUiSettings(toolbarTitle: 'Crop image', lockAspectRatio: true),
        IOSUiSettings(title: 'Crop image', aspectRatioLockEnabled: true),
      ],
    );
    if (cropped == null || !mounted) return;

    setState(() => _pickedImage = XFile(cropped.path));
  }

  Future<void> _submit() async {
    final startDate = _startDate;
    final plan = _selectedPlan;
    if (startDate == null || plan == null) return;

    setState(() {
      _submitting = true;
      _error = null;
    });
    String? promoImageUrl;
    try {
      if (_pickedImage != null) {
        promoImageUrl = await uploadPromotionImage(
          widget.vendorId,
          File(_pickedImage!.path),
        );
      }
    } catch (e, st) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = friendlyError(
          e,
          action: 'Uploading promotion image',
          stackTrace: st,
        );
      });
      return;
    }
    if (!mounted) return;
    Navigator.pop(context, (
      tagline: _controller.text.trim(),
      discountLabel: _discountLabelController.text.trim(),
      promoImageUrl: promoImageUrl,
      startDate: startDate,
      durationDays: plan.days,
      price: plan.price,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final canSubmit = _startDate != null && _selectedPlan != null;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: palette.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Request Promotion',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'This is exactly how your card will look on the User Home page — update it live below.',
                style: TextStyle(color: palette.textSecondary, fontSize: 12.5),
              ),
              const SizedBox(height: 14),
              AspectRatio(
                aspectRatio: 3 / 2,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    AnimatedBuilder(
                      animation: Listenable.merge([
                        _controller,
                        _discountLabelController,
                      ]),
                      builder: (context, _) => PromotionCardVisual(
                        imageFile: _pickedImage == null
                            ? null
                            : File(_pickedImage!.path),
                        imageUrl: _pickedImage == null
                            ? widget.vendorPhotoUrl
                            : null,
                        vendorName: widget.vendorName,
                        tagline: _controller.text,
                        discountLabel: _discountLabelController.text,
                      ),
                    ),
                    Positioned(
                      right: 10,
                      bottom: 10,
                      child: Material(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: _submitting ? null : _pickImage,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.photo_camera_outlined,
                                  color: Colors.white,
                                  size: 15,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  _pickedImage == null
                                      ? 'Add photo'
                                      : 'Change photo',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
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
              const SizedBox(height: 4),
              Text(
                'Falls back to your storefront photo if you skip adding one.',
                style: TextStyle(color: palette.textMuted, fontSize: 11),
              ),
              const SizedBox(height: 18),
              Text(
                'Start date',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: palette.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: _submitting ? null : _pickStartDate,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: palette.surfaceMuted,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: palette.border),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 18,
                        color: palette.textSecondary,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _startDate == null
                            ? 'Select start date'
                            : _dateFormat.format(_startDate!),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _startDate == null
                              ? palette.textSecondary
                              : palette.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Duration & price',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: palette.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              for (final plan in promotionPlans)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: _submitting
                        ? null
                        : () => setState(() => _selectedPlan = plan),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: _selectedPlan == plan
                            ? palette.primary.withValues(alpha: 0.08)
                            : palette.surfaceMuted,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _selectedPlan == plan
                              ? palette.primary
                              : palette.border,
                          width: _selectedPlan == plan ? 1.4 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _selectedPlan == plan
                                ? Icons.radio_button_checked_rounded
                                : Icons.radio_button_off_rounded,
                            color: _selectedPlan == plan
                                ? palette.primary
                                : palette.textMuted,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '${plan.days} days',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: palette.textPrimary,
                              ),
                            ),
                          ),
                          CurrencyText(
                            plan.price,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: palette.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 6),
              TextField(
                controller: _discountLabelController,
                maxLength: 12,
                enabled: !_submitting,
                decoration: const InputDecoration(
                  labelText: 'Discount label (optional)',
                  hintText: 'e.g. 50% OFF or ₹100 OFF',
                ),
              ),
              TextField(
                controller: _controller,
                maxLength: 60,
                enabled: !_submitting,
                decoration: const InputDecoration(
                  labelText: 'Message (optional)',
                  hintText: 'e.g. Flat 20% off this weekend',
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 4),
                Text(
                  _error!,
                  style: TextStyle(
                    color: palette.error,
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitting || !canSubmit ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.4,
                          ),
                        )
                      : const Text('Submit Request'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateCouponSheet extends StatefulWidget {
  const _CreateCouponSheet({required this.products});
  final List<Product> products;

  @override
  State<_CreateCouponSheet> createState() => _CreateCouponSheetState();
}

class _CreateCouponSheetState extends State<_CreateCouponSheet> {
  final _valueController = TextEditingController();
  CouponDiscountType _discountType = CouponDiscountType.percentage;
  bool _appliesToAllItems = true;
  final Set<String> _selectedProductIds = {};
  DateTime? _startAt;
  DateTime? _endAt;

  @override
  void dispose() {
    _valueController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final now = DateTime.now();
    final current = isStart ? _startAt : _endAt;
    final date = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: current == null
          ? TimeOfDay.now()
          : TimeOfDay(hour: current.hour, minute: current.minute),
    );
    if (time == null) return;
    final combined = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() {
      if (isStart) {
        _startAt = combined;
      } else {
        _endAt = combined;
      }
    });
  }

  bool get _canSubmit {
    final value = double.tryParse(_valueController.text);
    if (value == null || value <= 0) return false;
    if (_discountType == CouponDiscountType.percentage && value > 100) {
      return false;
    }
    if (!_appliesToAllItems && _selectedProductIds.isEmpty) return false;
    if (_startAt == null || _endAt == null) return false;
    if (!_endAt!.isAfter(_startAt!)) return false;
    return true;
  }

  void _submit() {
    final value = double.tryParse(_valueController.text);
    if (value == null || _startAt == null || _endAt == null) return;
    Navigator.pop(context, (
      discountType: _discountType,
      discountValue: value,
      appliesToAllItems: _appliesToAllItems,
      productIds: _selectedProductIds.toList(),
      startAt: _startAt!,
      endAt: _endAt!,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: palette.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Create Coupon',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 14),
              Text(
                'Discount',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: palette.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _ToggleTile(
                      label: 'Percentage',
                      selected: _discountType == CouponDiscountType.percentage,
                      onTap: () => setState(
                        () => _discountType = CouponDiscountType.percentage,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ToggleTile(
                      label: 'Flat Amount',
                      selected: _discountType == CouponDiscountType.flatAmount,
                      onTap: () => setState(
                        () => _discountType = CouponDiscountType.flatAmount,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _valueController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: _discountType == CouponDiscountType.percentage
                      ? 'Percentage off'
                      : 'Amount off (₹)',
                  hintText: _discountType == CouponDiscountType.percentage
                      ? 'e.g. 20'
                      : 'e.g. 100',
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Applies to',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: palette.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _ToggleTile(
                      label: 'All items',
                      selected: _appliesToAllItems,
                      onTap: () => setState(() => _appliesToAllItems = true),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ToggleTile(
                      label: 'Specific items',
                      selected: !_appliesToAllItems,
                      onTap: () => setState(() => _appliesToAllItems = false),
                    ),
                  ),
                ],
              ),
              if (!_appliesToAllItems) ...[
                const SizedBox(height: 10),
                if (widget.products.isEmpty)
                  Text(
                    'Add products to your catalogue first.',
                    style: TextStyle(color: palette.textMuted, fontSize: 12.5),
                  )
                else
                  Container(
                    constraints: const BoxConstraints(maxHeight: 220),
                    decoration: BoxDecoration(
                      color: palette.surfaceMuted,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: palette.border),
                    ),
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final product in widget.products)
                          CheckboxListTile(
                            dense: true,
                            value: _selectedProductIds.contains(product.id),
                            title: Text(
                              product.name,
                              style: const TextStyle(fontSize: 13.5),
                            ),
                            onChanged: (checked) => setState(() {
                              if (checked ?? false) {
                                _selectedProductIds.add(product.id);
                              } else {
                                _selectedProductIds.remove(product.id);
                              }
                            }),
                          ),
                      ],
                    ),
                  ),
              ],
              const SizedBox(height: 18),
              Text(
                'Valid from',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: palette.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              _DateTimeField(
                value: _startAt,
                onTap: () => _pickDateTime(isStart: true),
              ),
              const SizedBox(height: 14),
              Text(
                'Valid until',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: palette.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              _DateTimeField(
                value: _endAt,
                onTap: () => _pickDateTime(isStart: false),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: !_canSubmit ? null : _submit,
                  child: const Text('Create Coupon'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  const _ToggleTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? palette.primary.withValues(alpha: 0.08)
              : palette.surfaceMuted,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? palette.primary : palette.border,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: selected ? palette.primary : palette.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _DateTimeField extends StatelessWidget {
  const _DateTimeField({required this.value, required this.onTap});
  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: palette.surfaceMuted,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: palette.border),
        ),
        child: Row(
          children: [
            Icon(Icons.event_rounded, size: 18, color: palette.textSecondary),
            const SizedBox(width: 10),
            Text(
              value == null
                  ? 'Select date & time'
                  : _dateTimeFormat.format(value!),
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: value == null
                    ? palette.textSecondary
                    : palette.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
