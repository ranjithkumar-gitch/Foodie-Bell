import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/account.dart';
import '../../../data/models/list_order_request.dart';
import '../../../data/models/order.dart';
import '../../../data/providers/firestore_list_order_requests_provider.dart';
import '../../../data/providers/firestore_orders_provider.dart';
import '../../../data/providers/firestore_vendors_provider.dart';
import '../../../data/providers/list_order_image_storage_provider.dart';
import '../../../shared/error_reporting.dart';
import '../../../shared/time_ago.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../../shared/widgets/currency_text.dart';
import '../../../shared/widgets/document_source_sheet.dart';
import '../../../shared/widgets/document_viewer_screen.dart';
import '../../../shared/widgets/empty_state.dart';
import '../vendor_session.dart';

/// Orders (spec §5.8 + §5.14, combined): Live Order Queue and Order
/// History as two tabs of the same page, rather than a separate screen you
/// have to navigate to for history — a Vendor deciding on a queued order
/// often wants to check history in the same glance. Vendor owns exactly one
/// status transition from the Queue tab — `placed -> vendorAccepted` —
/// everything after that (assignment, pickup, delivery) belongs to the
/// Driver's app; History is read-only.
///
/// Kept deliberately plain for small-town shop owners: white cards, large
/// text, colour only where it carries meaning (new order, cancelled).
class VendorOrderQueueScreen extends ConsumerStatefulWidget {
  const VendorOrderQueueScreen({super.key});

  @override
  ConsumerState<VendorOrderQueueScreen> createState() =>
      _VendorOrderQueueScreenState();
}

class _VendorOrderQueueScreenState extends ConsumerState<VendorOrderQueueScreen>
    with SingleTickerProviderStateMixin {
  late final _tabController = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final vendorId = ref.watch(currentVendorIdProvider);
    final ordersAsync = ref.watch(firestoreOrdersProvider);
    final activeCount = (ordersAsync.valueOrNull ?? const <Order>[])
        .where((o) => o.vendorId == vendorId && !o.status.isTerminal)
        .length;
    final listRequestsAsync = ref.watch(firestoreListOrderRequestsProvider);
    final listRequestPendingCount = (listRequestsAsync.valueOrNull ?? const [])
        .where(
          (r) => r.vendorId == vendorId && r.status == ListOrderStatus.pending,
        )
        .length;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: const Text('Orders'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelStyle: const TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w500,
          ),
          labelColor: palette.primary,
          unselectedLabelColor: palette.textSecondary,
          indicatorColor: palette.primary,
          indicatorWeight: 3,
          dividerColor: palette.divider,
          tabs: [
            Tab(text: activeCount > 0 ? 'Active ($activeCount)' : 'Active'),
            const Tab(text: 'History'),
            Tab(
              text: listRequestPendingCount > 0
                  ? 'Photo orders ($listRequestPendingCount)'
                  : 'Photo orders',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          ordersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(
              child: Text(
                friendlyError(e, action: 'Loading orders', stackTrace: st),
              ),
            ),
            data: (orders) {
              // Stays in the Queue tab all the way through delivery — not
              // just the `placed` orders still needing an Accept/Reject —
              // so a Vendor can track everything still in flight in one
              // place instead of it disappearing into the full History
              // list the moment they accept it. Orders still needing a
              // decision are sorted to the top.
              final queue =
                  orders
                      .where(
                        (o) => o.vendorId == vendorId && !o.status.isTerminal,
                      )
                      .toList()
                    ..sort((a, b) {
                      final aNew = a.status == OrderStatus.placed;
                      final bNew = b.status == OrderStatus.placed;
                      if (aNew != bNew) return aNew ? -1 : 1;
                      return a.placedAt.compareTo(b.placedAt);
                    });
              return queue.isEmpty
                  ? const EmptyState(
                      icon: Icons.inbox_rounded,
                      title: 'No orders right now',
                      subtitle:
                          'New orders will show up here the moment customers place them.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: queue.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, i) => _QueueOrderCard(
                        key: ValueKey(queue[i].id),
                        order: queue[i],
                      ),
                    );
            },
          ),
          ordersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(
              child: Text(
                friendlyError(e, action: 'Loading orders', stackTrace: st),
              ),
            ),
            data: (orders) {
              final history =
                  orders.where((o) => o.vendorId == vendorId).toList()
                    ..sort((a, b) => b.placedAt.compareTo(a.placedAt));
              return history.isEmpty
                  ? const EmptyState(
                      icon: Icons.receipt_long_rounded,
                      title: 'No orders yet',
                    )
                  : _HistoryList(orders: history);
            },
          ),
          listRequestsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(
              child: Text(
                friendlyError(
                  e,
                  action: 'Loading list requests',
                  stackTrace: st,
                ),
              ),
            ),
            data: (requests) {
              final mine = requests
                  .where((r) => r.vendorId == vendorId)
                  .toList();
              return mine.isEmpty
                  ? const EmptyState(
                      icon: Icons.document_scanner_outlined,
                      title: 'No photo orders yet',
                      subtitle:
                          "Customers who send a photo of their list will show up here.",
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: mine.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, i) =>
                          _ListRequestCard(request: mine[i]),
                    );
            },
          ),
        ],
      ),
    );
  }
}

Color _statusColor(AppPalette palette, OrderStatus status) => switch (status) {
  OrderStatus.placed => palette.warning,
  OrderStatus.delivered => palette.success,
  OrderStatus.cancelled || OrderStatus.rejected => palette.error,
  _ => palette.primary,
};

/// A plain white bordered card.
class _Card extends StatelessWidget {
  const _Card({required this.child, this.onTap, this.highlight});
  final Widget child;
  final VoidCallback? onTap;

  /// Border colour for a card that needs attention; plain border otherwise.
  final Color? highlight;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Material(
      color: palette.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: highlight ?? palette.border,
              width: highlight != null ? 1.5 : 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// A coloured dot followed by text — the one way status is shown here.
class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

String _itemsSummary(Order order) =>
    order.items.map((i) => '${i.quantity} × ${i.name}').join(', ');

String _paymentText(PaymentMethod method) =>
    method == PaymentMethod.cod ? 'Cash on delivery' : 'Paid online';

final _dayFormat = DateFormat('EEE, d MMM');
final _timeFormat = DateFormat('h:mm a');

/// Every order, newest first, under a plain date heading per day.
class _HistoryList extends StatelessWidget {
  const _HistoryList({required this.orders});
  final List<Order> orders;

  String _dayLabel(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(DateTime(dt.year, dt.month, dt.day)).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return _dayFormat.format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final grouped = <String, List<Order>>{};
    for (final o in orders) {
      grouped.putIfAbsent(_dayLabel(o.placedAt), () => []).add(o);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        for (final entry in grouped.entries) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
            child: Text(
              entry.key,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: palette.textSecondary,
              ),
            ),
          ),
          for (final order in entry.value) ...[
            _Card(
              onTap: () => context.push('/vendor/order/${order.id}'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          order.userName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: palette.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      CurrencyText(
                        order.total,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: palette.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _itemsSummary(order),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14.5,
                      color: palette.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _StatusLine(
                    text:
                        '${order.status.label} · ${_timeFormat.format(order.placedAt)}',
                    color: _statusColor(palette, order.status),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ],
    );
  }
}

class _QueueOrderCard extends ConsumerStatefulWidget {
  const _QueueOrderCard({super.key, required this.order});
  final Order order;

  @override
  ConsumerState<_QueueOrderCard> createState() => _QueueOrderCardState();
}

class _QueueOrderCardState extends ConsumerState<_QueueOrderCard> {
  bool _updating = false;

  Future<void> _setStatus(OrderStatus status, String failedAction) async {
    setState(() => _updating = true);
    try {
      await updateOrderStatus(widget.order.id, status);
    } catch (e, st) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            friendlyError(e, action: failedAction, stackTrace: st),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  Future<void> _accept() async {
    if (!await ensureVendorReadyToAccept(context, ref)) return;
    await _setStatus(OrderStatus.vendorAccepted, 'Accepting order');
  }

  Future<void> _reject() =>
      _setStatus(OrderStatus.rejected, 'Rejecting order');

  String _progressText(Order order) => switch (order.status) {
    OrderStatus.vendorAccepted => 'Accepted · finding a driver',
    OrderStatus.driverAssigned =>
      '${order.driverName ?? 'Driver'} is coming to pick up',
    OrderStatus.pickedUp =>
      'Picked up by ${order.driverName ?? 'driver'} · on the way',
    _ => order.status.label,
  };

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final order = widget.order;
    final awaitingDecision = order.status == OrderStatus.placed;

    return _Card(
      onTap: () => context.push('/vendor/order/${order.id}'),
      highlight: awaitingDecision ? palette.warning : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatusLine(
            text: awaitingDecision ? 'New order' : _progressText(order),
            color: awaitingDecision ? palette.warning : palette.primary,
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.userName,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: palette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    TimeAgoText(
                      order.placedAt,
                      style: TextStyle(
                        fontSize: 14,
                        color: palette.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  CurrencyText(
                    order.total,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: palette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _paymentText(order.paymentMethod),
                    style: TextStyle(
                      fontSize: 13.5,
                      color: palette.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: palette.divider),
          const SizedBox(height: 12),
          for (final item in order.items)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 40,
                    child: Text(
                      '${item.quantity} ×',
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: palette.textPrimary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      item.name,
                      style: TextStyle(
                        fontSize: 15.5,
                        color: palette.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (awaitingDecision) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: palette.error,
                      minimumSize: const Size.fromHeight(50),
                    ),
                    onPressed: _updating ? null : _reject,
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                    onPressed: _updating ? null : _accept,
                    child: const Text('Accept'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// A single "Order via Photo" request — the vendor looks at the customer's
/// photo(s), sends a price, and (once paid) confirms with a receipt photo,
/// at which point it becomes a real `Order` that the Driver pool can pick
/// up — see [ListOrderRequest]'s doc comment and
/// `acceptListOrderRequestAndCreateOrder`'s doc comment for the handoff.
class _ListRequestCard extends ConsumerStatefulWidget {
  const _ListRequestCard({required this.request});
  final ListOrderRequest request;

  @override
  ConsumerState<_ListRequestCard> createState() => _ListRequestCardState();
}

class _ListRequestCardState extends ConsumerState<_ListRequestCard> {
  bool _updating = false;

  Future<void> _run(Future<void> Function() action, {required String failedAction}) async {
    setState(() => _updating = true);
    try {
      await action();
    } catch (e, st) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e, action: failedAction, stackTrace: st))),
      );
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  Future<void> _decline() => _run(
    () => declineListOrderRequest(widget.request.id),
    failedAction: 'Declining request',
  );

  Future<void> _sendQuote() async {
    final amount = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _QuoteAmountSheet(),
    );
    if (amount == null) return;
    await _run(
      () => quoteListOrderRequest(widget.request.id, amount),
      failedAction: 'Sending quote',
    );
  }

  Future<void> _acceptAndConfirm(double rebatePercent) async {
    if (!await ensureVendorReadyToAccept(context, ref) || !mounted) return;
    final source = await DocumentSourceSheet.show(
      context,
      title: 'Photograph the receipt',
      subtitle: 'Take a photo of the receipt to confirm this order.',
    );
    if (source == null || !mounted) return;

    XFile? picked;
    try {
      picked = await ImagePicker().pickImage(source: source, imageQuality: 90);
    } catch (_) {
      // No camera/gallery available in this environment.
    }
    if (picked == null || !mounted) return;

    final request = widget.request;
    await _run(() async {
      final receiptUrl = await uploadListOrderReceiptImage(request.vendorId, File(picked!.path));
      final placedAt = DateTime.now();
      final order = Order(
        id: generateOrderId(),
        vendorId: request.vendorId,
        vendorName: request.vendorName,
        userId: request.userId,
        userName: request.userName,
        userPhone: request.userPhone,
        items: [
          OrderLineItem(
            productId: 'photo-order',
            name: 'Photo order',
            price: request.quotedAmount ?? 0,
            imageUrl: request.imageUrls.isNotEmpty ? request.imageUrls.first : '',
            quantity: 1,
          ),
        ],
        deliveryAddressLabel: request.deliveryAddressLabel,
        deliveryLatitude: request.deliveryLatitude,
        deliveryLongitude: request.deliveryLongitude,
        paymentMethod: PaymentMethod.upi,
        subtotal: request.quotedAmount ?? 0,
        deliveryFee: 0,
        platformFee: 0,
        gstAmount: 0,
        total: request.quotedAmount ?? 0,
        placedAt: placedAt,
        statusTimestamps: {OrderStatus.placed: placedAt},
        rebatePercent: rebatePercent,
        handoverCode: generateOrderCode(),
        deliveryOtp: generateOrderCode(),
      );
      await acceptListOrderRequestAndCreateOrder(
        requestId: request.id,
        receiptImageUrl: receiptUrl,
        order: order,
      );
    }, failedAction: 'Confirming order');
  }

  Future<void> _call() async {
    final phone = widget.request.userPhone;
    if (phone.isEmpty) return;
    try {
      final launched = await launchUrl(Uri(scheme: 'tel', path: phone));
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't open the phone dialer.")),
        );
      }
    } catch (e, st) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            friendlyError(e, action: 'Calling customer', stackTrace: st),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final request = widget.request;
    final vendors = ref.watch(firestoreVendorsProvider).valueOrNull ?? const <Account>[];
    final rebatePercent = vendors
        .where((v) => v.id == request.vendorId)
        .map((v) => v.rebatePercent)
        .firstOrNull ?? 15;
    final statusColor = switch (request.status) {
      ListOrderStatus.pending || ListOrderStatus.quoted => palette.warning,
      ListOrderStatus.paid => palette.primary,
      ListOrderStatus.accepted => palette.success,
      ListOrderStatus.rejected || ListOrderStatus.cancelled => palette.error,
    };
    final needsAction = request.status == ListOrderStatus.pending ||
        request.status == ListOrderStatus.paid;

    return _Card(
      highlight: needsAction ? statusColor : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatusLine(text: request.status.label, color: statusColor),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.userName,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: palette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      request.deliveryAddressLabel,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.5,
                        color: palette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Call customer',
                onPressed: request.userPhone.isEmpty ? null : _call,
                icon: Icon(Icons.call_outlined, color: palette.primary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Full-width and tap-to-zoom, not small thumbnails — these photos
          // ARE the order, and a vendor needs to actually see what's in
          // them to price and fulfill the request.
          SizedBox(
            height: 150,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: request.imageUrls.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) => GestureDetector(
                onTap: () => DocumentViewerScreen.show(
                  context,
                  imageUrl: request.imageUrls[i],
                  title: '${request.userName}\'s photo ${i + 1}',
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: AppNetworkImage(
                    url: request.imageUrls[i],
                    width: 150,
                    height: 150,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tap a photo to see it bigger',
            style: TextStyle(fontSize: 13.5, color: palette.textMuted),
          ),
          if (request.quotedAmount != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Your price',
                    style: TextStyle(
                      fontSize: 15.5,
                      color: palette.textSecondary,
                    ),
                  ),
                ),
                CurrencyText(
                  request.quotedAmount!,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: palette.textPrimary,
                  ),
                ),
              ],
            ),
          ],
          if (request.status == ListOrderStatus.pending) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: palette.error,
                      minimumSize: const Size.fromHeight(50),
                    ),
                    onPressed: _updating ? null : _decline,
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                    onPressed: _updating ? null : _sendQuote,
                    child: const Text('Send price'),
                  ),
                ),
              ],
            ),
          ] else if (request.status == ListOrderStatus.paid) ...[
            const SizedBox(height: 14),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
              onPressed: _updating ? null : () => _acceptAndConfirm(rebatePercent),
              child: const Text('Confirm order'),
            ),
          ] else if (request.status == ListOrderStatus.quoted) ...[
            const SizedBox(height: 10),
            Text(
              'Waiting for the customer to pay.',
              style: TextStyle(fontSize: 14.5, color: palette.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

class _QuoteAmountSheet extends StatefulWidget {
  const _QuoteAmountSheet();

  @override
  State<_QuoteAmountSheet> createState() => _QuoteAmountSheetState();
}

class _QuoteAmountSheetState extends State<_QuoteAmountSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final amount = double.tryParse(_controller.text.trim());
    if (amount == null || amount <= 0) return;
    Navigator.pop(context, amount);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
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
              Text('Send your price', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                'Enter the total amount for everything in the photos.',
                style: TextStyle(color: palette.textSecondary, fontSize: 15),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                decoration: const InputDecoration(prefixText: '₹ ', hintText: 'Amount'),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(onPressed: _submit, child: const Text('Send price')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
