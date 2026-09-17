import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
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
import '../../../shared/widgets/app_network_image.dart';
import '../../../shared/widgets/currency_text.dart';
import '../../../shared/widgets/document_source_sheet.dart';
import '../../../shared/widgets/document_viewer_screen.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/order_status_timestamp.dart';
import '../../../shared/widgets/status_chip.dart';
import '../vendor_session.dart';

/// Orders (spec §5.8 + §5.14, combined): Live Order Queue and Order
/// History as two tabs of the same page, rather than a separate screen you
/// have to navigate to for history — a Vendor deciding on a queued order
/// often wants to check history in the same glance. Vendor owns exactly one
/// status transition from the Queue tab — `placed -> vendorAccepted` —
/// everything after that (assignment, pickup, delivery) belongs to the
/// Driver's app; History is read-only.
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
    final vendorId = ref.watch(currentVendorIdProvider);
    final ordersAsync = ref.watch(firestoreOrdersProvider);
    final queueCount = (ordersAsync.valueOrNull ?? const [])
        .where((o) => o.vendorId == vendorId && o.status == OrderStatus.placed)
        .length;
    final listRequestsAsync = ref.watch(firestoreListOrderRequestsProvider);
    final listRequestPendingCount = (listRequestsAsync.valueOrNull ?? const [])
        .where(
          (r) => r.vendorId == vendorId && r.status == ListOrderStatus.pending,
        )
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Orders'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(text: queueCount > 0 ? 'Queue ($queueCount)' : 'Queue'),
            const Tab(text: 'History'),
            Tab(
              text: listRequestPendingCount > 0
                  ? 'Photo Orders ($listRequestPendingCount)'
                  : 'Photo Orders',
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
                      title: 'No orders in progress',
                      subtitle:
                          'New orders will show up here the moment customers place them.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(20),
                      itemCount: queue.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 14),
                      itemBuilder: (context, i) =>
                          _QueueOrderCard(order: queue[i]),
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
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                      itemCount: history.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, i) => _HistoryOrderCard(
                        order: history[i],
                        tone: orderStatusTone(history[i].status),
                      ),
                    );
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
                          "Customers who photograph what they want instead of browsing will show up here.",
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(20),
                      itemCount: mine.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 14),
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

StatusTone orderStatusTone(OrderStatus status) => switch (status) {
  OrderStatus.delivered => StatusTone.success,
  OrderStatus.cancelled || OrderStatus.rejected => StatusTone.error,
  OrderStatus.placed => StatusTone.info,
  _ => StatusTone.warning,
};

class _HistoryOrderCard extends StatelessWidget {
  const _HistoryOrderCard({required this.order, required this.tone});
  final Order order;
  final StatusTone tone;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push('/vendor/order/${order.id}'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: palette.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    order.id,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    StatusChip(label: order.status.label, tone: tone),
                    const SizedBox(height: 3),
                    OrderStatusTimestamp(order.statusReachedAt(order.status)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${order.items.length} item${order.items.length == 1 ? '' : 's'} · ${order.userName}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            CurrencyText(
              order.total,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _QueueOrderCard extends ConsumerStatefulWidget {
  const _QueueOrderCard({required this.order});
  final Order order;

  @override
  ConsumerState<_QueueOrderCard> createState() => _QueueOrderCardState();
}

class _QueueOrderCardState extends ConsumerState<_QueueOrderCard> {
  static const _kWindowSeconds = 120;
  late int _secondsLeft = _kWindowSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // The Accept/Reject countdown only makes sense while this order is
    // still actually waiting on that decision — once accepted it stays in
    // this same tab (see the Queue tab's doc comment) all the way through
    // delivery, so there's nothing left to count down.
    if (widget.order.status == OrderStatus.placed) {
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return;
        if (_secondsLeft <= 0) {
          t.cancel();
        } else {
          setState(() => _secondsLeft--);
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _accept() async {
    try {
      await updateOrderStatus(widget.order.id, OrderStatus.vendorAccepted);
    } catch (e, st) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            friendlyError(e, action: 'Accepting order', stackTrace: st),
          ),
        ),
      );
    }
  }

  Future<void> _reject() async {
    try {
      await updateOrderStatus(widget.order.id, OrderStatus.rejected);
    } catch (e, st) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            friendlyError(e, action: 'Rejecting order', stackTrace: st),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final order = widget.order;
    final awaitingDecision = order.status == OrderStatus.placed;
    final minutes = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final seconds = (_secondsLeft % 60).toString().padLeft(2, '0');
    final urgent = _secondsLeft <= 30;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push('/vendor/order/${order.id}'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: palette.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    order.id,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (awaitingDecision)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: (urgent ? palette.error : palette.warning)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.timer_outlined,
                          size: 14,
                          color: urgent ? palette.error : palette.warning,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _secondsLeft > 0 ? '$minutes:$seconds' : 'Expiring',
                          style: TextStyle(
                            color: urgent ? palette.error : palette.warning,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  StatusChip(label: order.status.label, tone: orderStatusTone(order.status)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              order.items.map((i) => '${i.quantity}x ${i.name}').join(', '),
              style: TextStyle(color: palette.textSecondary, fontSize: 12.5),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CurrencyText(
                  order.total,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  order.paymentMethod.label,
                  style: TextStyle(fontSize: 11.5, color: palette.textMuted),
                ),
              ],
            ),
            if (awaitingDecision) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: palette.error,
                        side: BorderSide(color: palette.error),
                      ),
                      onPressed: _reject,
                      child: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _accept,
                      child: const Text('Accept'),
                    ),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 8),
              Text(
                order.driverName != null
                    ? 'With ${order.driverName} · tap to view'
                    : 'Waiting for a driver · tap to view',
                style: TextStyle(color: palette.textMuted, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

StatusTone _listRequestTone(ListOrderStatus status) => switch (status) {
  ListOrderStatus.pending => StatusTone.warning,
  ListOrderStatus.quoted => StatusTone.warning,
  ListOrderStatus.paid => StatusTone.info,
  ListOrderStatus.accepted => StatusTone.success,
  ListOrderStatus.rejected || ListOrderStatus.cancelled => StatusTone.error,
};

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

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Full-width and tap-to-zoom, not small thumbnails — these photos
          // ARE the order, and a vendor needs to actually see what's in
          // them to price and fulfill the request.
          SizedBox(
            height: 140,
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
                  borderRadius: BorderRadius.circular(12),
                  child: AppNetworkImage(
                    url: request.imageUrls[i],
                    width: 140,
                    height: 140,
                  ),
                ),
              ),
            ),
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
                      request.userName,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      request.deliveryAddressLabel,
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 12.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              StatusChip(
                label: request.status.label,
                tone: _listRequestTone(request.status),
              ),
            ],
          ),
          if (request.quotedAmount != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Text('Quoted: ', style: TextStyle(color: palette.textSecondary, fontSize: 12.5)),
                CurrencyText(request.quotedAmount!, style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: request.userPhone.isEmpty ? null : _call,
                  icon: const Icon(Icons.call_outlined, size: 16),
                  label: const Text('Call customer'),
                ),
              ),
              if (request.status == ListOrderStatus.pending) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: palette.error,
                      side: BorderSide(color: palette.error),
                    ),
                    onPressed: _updating ? null : _decline,
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _updating ? null : _sendQuote,
                    child: const Text('Send quote'),
                  ),
                ),
              ] else if (request.status == ListOrderStatus.paid) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _updating ? null : () => _acceptAndConfirm(rebatePercent),
                    child: const Text('Accept & confirm'),
                  ),
                ),
              ],
            ],
          ),
          if (request.status == ListOrderStatus.quoted) ...[
            const SizedBox(height: 8),
            Text(
              'Waiting for the customer to pay.',
              style: TextStyle(color: palette.textMuted, fontSize: 12),
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
              Text('Send a quote', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                'Enter the total amount for this order based on the photos.',
                style: TextStyle(color: palette.textSecondary),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(prefixText: '₹ ', hintText: 'Amount'),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(onPressed: _submit, child: const Text('Send quote')),
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
