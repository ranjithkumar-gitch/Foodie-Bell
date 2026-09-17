import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers/cart_provider.dart';
import '../../shared/widgets/bottom_nav_shell.dart';
import 'addresses/addresses_screen.dart';
import 'cart/cart_screen.dart';
import 'checkout/checkout_address_screen.dart';
import 'checkout/checkout_payment_screen.dart';
import 'checkout/order_success_screen.dart';
import 'help/help_screen.dart';
import 'help/user_ticket_chat_screen.dart';
import 'home/home_screen.dart';
import 'list_order/list_order_capture_screen.dart';
import 'list_order/list_order_status_screen.dart';
import 'notifications/notifications_screen.dart';
import 'orders/order_detail_screen.dart';
import 'orders/order_history_screen.dart';
import 'orders/user_order_chat_screen.dart';
import 'profile/profile_screen.dart';
import 'profile/user_profile_edit_screen.dart';
import 'referral/referral_screen.dart';
import 'reviews/rate_review_screen.dart';
import 'reviews/vendor_public_reviews_screen.dart';
import 'search/search_screen.dart';
import 'storefront/vendor_detail_screen.dart';
import 'wallet/wallet_screen.dart';

/// CANONICAL EXAMPLE — User is the reference [StatefulShellRoute.indexedStack]
/// implementation. Vendor/Driver copy this bottom-nav pattern; Manager/Admin
/// use [RailDrawerShell] instead (see admin_routes.dart).
List<RouteBase> get userRoutes => [
  GoRoute(path: '/user', redirect: (context, state) => '/user/home'),
  StatefulShellRoute.indexedStack(
    builder: (context, state, navigationShell) => Consumer(
      builder: (context, ref, _) {
        final cartCount = ref.watch(
          cartProvider.select((c) => c.totalQuantity),
        );
        return BottomNavShell(
          navigationShell: navigationShell,
          items: [
            const BottomNavItemData(icon: Icons.home_rounded, label: 'Home'),
            const BottomNavItemData(
              icon: Icons.receipt_long_rounded,
              label: 'Orders',
            ),
            BottomNavItemData(
              icon: Icons.shopping_bag_rounded,
              label: 'Cart',
              badgeCount: cartCount,
            ),
            const BottomNavItemData(
              icon: Icons.person_rounded,
              label: 'Profile',
            ),
          ],
        );
      },
    ),
    branches: [
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: '/user/home',
            name: 'userHome',
            builder: (context, state) => const HomeScreen(),
          ),
        ],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: '/user/orders',
            name: 'userOrders',
            builder: (context, state) => const OrderHistoryScreen(),
          ),
        ],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: '/user/cart',
            name: 'userCart',
            builder: (context, state) => const CartScreen(),
          ),
        ],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: '/user/profile',
            name: 'userProfile',
            builder: (context, state) => const ProfileScreen(),
          ),
        ],
      ),
    ],
  ),
  GoRoute(
    path: '/user/vendor/:id',
    name: 'userVendorDetail',
    builder: (context, state) =>
        VendorDetailScreen(vendorId: state.pathParameters['id']!),
  ),
  GoRoute(
    path: '/user/vendor/:id/reviews',
    name: 'userVendorReviews',
    builder: (context, state) =>
        VendorPublicReviewsScreen(vendorId: state.pathParameters['id']!),
  ),
  GoRoute(
    path: '/user/vendor/:id/list-order',
    name: 'userListOrder',
    // `extra` carries the vendor's display name so this screen doesn't need
    // its own vendor lookup just to show "Send list to {name}" copy — the
    // caller (`vendor_detail_screen.dart`) already has the loaded Account.
    builder: (context, state) => ListOrderCaptureScreen(
      vendorId: state.pathParameters['id']!,
      vendorName: state.extra as String? ?? 'the vendor',
    ),
  ),
  GoRoute(
    path: '/user/list-order/:requestId',
    name: 'userListOrderStatus',
    builder: (context, state) =>
        ListOrderStatusScreen(requestId: state.pathParameters['requestId']!),
  ),
  GoRoute(
    path: '/user/checkout/address',
    name: 'userCheckoutAddress',
    builder: (context, state) => const CheckoutAddressScreen(),
  ),
  GoRoute(
    path: '/user/checkout/payment',
    name: 'userCheckoutPayment',
    builder: (context, state) => const CheckoutPaymentScreen(),
  ),
  GoRoute(
    path: '/user/order-success/:orderId',
    name: 'userOrderSuccess',
    builder: (context, state) =>
        OrderSuccessScreen(orderId: state.pathParameters['orderId']!),
  ),
  GoRoute(
    path: '/user/order/:id',
    name: 'userOrderDetail',
    builder: (context, state) =>
        OrderDetailScreen(orderId: state.pathParameters['id']!),
  ),
  GoRoute(
    path: '/user/order/:id/chat',
    name: 'userOrderChat',
    builder: (context, state) =>
        UserOrderChatScreen(orderId: state.pathParameters['id']!),
  ),
  GoRoute(
    path: '/user/search',
    name: 'userSearch',
    builder: (context, state) => const SearchScreen(),
  ),
  GoRoute(
    path: '/user/notifications',
    name: 'userNotifications',
    builder: (context, state) => const NotificationsScreen(),
  ),
  GoRoute(
    path: '/user/wallet',
    name: 'userWallet',
    builder: (context, state) => const WalletScreen(),
  ),
  GoRoute(
    path: '/user/addresses',
    name: 'userAddresses',
    builder: (context, state) => const AddressesScreen(),
  ),
  GoRoute(
    path: '/user/profile/edit',
    name: 'userProfileEdit',
    builder: (context, state) => const UserProfileEditScreen(),
  ),
  GoRoute(
    path: '/user/help',
    name: 'userHelp',
    builder: (context, state) => const HelpScreen(),
  ),
  GoRoute(
    path: '/user/ticket/:id/chat',
    name: 'userTicketChat',
    builder: (context, state) =>
        UserTicketChatScreen(ticketId: state.pathParameters['id']!),
  ),
  GoRoute(
    path: '/user/referral',
    name: 'userReferral',
    builder: (context, state) => const ReferralScreen(),
  ),
  GoRoute(
    path: '/user/rate/:orderId',
    name: 'userRateOrder',
    builder: (context, state) =>
        RateReviewScreen(orderId: state.pathParameters['orderId']!),
  ),
];
