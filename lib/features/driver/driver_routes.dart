import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/bottom_nav_shell.dart';
import 'earnings/driver_earnings_screen.dart';
import 'history/driver_history_screen.dart';
import 'home/driver_home_screen.dart';
import 'notifications/driver_notifications_screen.dart';
import 'orders/driver_cash_collection_screen.dart';
import 'orders/driver_delivery_confirm_screen.dart';
import 'orders/driver_incoming_offer_screen.dart';
import 'orders/driver_navigate_customer_screen.dart';
import 'orders/driver_navigate_vendor_screen.dart';
import 'orders/driver_order_chat_screen.dart';
import 'orders/driver_pickup_confirm_screen.dart';
import 'profile/driver_availability_screen.dart';
import 'profile/driver_documents_status_screen.dart';
import 'profile/driver_profile_edit_screen.dart';
import 'profile/driver_profile_screen.dart';
import 'reviews/driver_reviews_screen.dart';
import 'registration/driver_documents_screen.dart';
import 'registration/driver_manager_code_screen.dart';
import 'registration/driver_personal_details_screen.dart';
import 'registration/driver_vehicle_details_screen.dart';
import 'support/driver_support_screen.dart';
import 'support/driver_ticket_chat_screen.dart';

/// Driver's full route set (spec §6). Registration lives under
/// `/driver/register/...` and is reachable pre-auth as soon as Driver is
/// picked on the Role Selector (see sessionRedirect's carve-out for
/// `/<role>/register`); its last step hands off to the shared
/// `/auth/phone?mode=register` -> OTP -> Terms flow rather than completing
/// registration itself (AuthTermsScreen fires `completeRegistration()`,
/// which lands Driver — an approval-required role — on `/auth/under-review`,
/// the shared "pending approval" screen with its own demo approve/reject
/// buttons). Every other `/driver/...` route requires an active Driver
/// session.
///
/// Order-status ownership: this role performs `vendorAccepted ->
/// driverAssigned` (accepting an offer), `driverAssigned -> pickedUp`
/// (Pickup Confirmation), and `pickedUp -> delivered` (Delivery
/// Confirmation) — see the individual screens for where each transition
/// fires.
List<RouteBase> get driverRoutes => [
  GoRoute(path: '/driver', redirect: (context, state) => '/driver/home'),

  // Registration (pre-auth) — a 4-step wizard using context.go() throughout
  // so each step replaces the last, matching the shared auth screens' style.
  GoRoute(path: '/driver/register', name: 'driverRegisterPersonal', builder: (context, state) => const DriverPersonalDetailsScreen()),
  GoRoute(path: '/driver/register/manager-code', name: 'driverRegisterManagerCode', builder: (context, state) => const DriverManagerCodeScreen()),
  GoRoute(path: '/driver/register/vehicle', name: 'driverRegisterVehicle', builder: (context, state) => const DriverVehicleDetailsScreen()),
  GoRoute(path: '/driver/register/documents', name: 'driverRegisterDocuments', builder: (context, state) => const DriverDocumentsScreen()),

  StatefulShellRoute.indexedStack(
    builder: (context, state, navigationShell) => BottomNavShell(
      navigationShell: navigationShell,
      items: const [
        BottomNavItemData(icon: Icons.two_wheeler_rounded, label: 'Home'),
        BottomNavItemData(icon: Icons.payments_rounded, label: 'Earnings'),
        BottomNavItemData(icon: Icons.history_rounded, label: 'History'),
        BottomNavItemData(icon: Icons.person_rounded, label: 'Profile'),
      ],
    ),
    branches: [
      StatefulShellBranch(routes: [GoRoute(path: '/driver/home', name: 'driverHome', builder: (context, state) => const DriverHomeScreen())]),
      StatefulShellBranch(routes: [GoRoute(path: '/driver/earnings', name: 'driverEarnings', builder: (context, state) => const DriverEarningsScreen())]),
      StatefulShellBranch(routes: [GoRoute(path: '/driver/history', name: 'driverHistory', builder: (context, state) => const DriverHistoryScreen())]),
      StatefulShellBranch(routes: [GoRoute(path: '/driver/profile', name: 'driverProfile', builder: (context, state) => const DriverProfileScreen())]),
    ],
  ),

  // Incoming order offer — full-screen accept/decline, reached by pushing
  // from Home so decline can simply pop back.
  GoRoute(
    path: '/driver/offer/:orderId',
    name: 'driverIncomingOffer',
    builder: (context, state) => DriverIncomingOfferScreen(orderId: state.pathParameters['orderId']!),
  ),

  // Active delivery funnel: navigate-to-vendor -> pickup-confirm ->
  // navigate-to-customer -> (cash-collection if COD) -> delivery-confirm.
  GoRoute(
    path: '/driver/delivery/:orderId/navigate-vendor',
    name: 'driverNavigateVendor',
    builder: (context, state) => DriverNavigateVendorScreen(orderId: state.pathParameters['orderId']!),
  ),
  GoRoute(
    path: '/driver/delivery/:orderId/pickup-confirm',
    name: 'driverPickupConfirm',
    builder: (context, state) => DriverPickupConfirmScreen(orderId: state.pathParameters['orderId']!),
  ),
  GoRoute(
    path: '/driver/delivery/:orderId/navigate-customer',
    name: 'driverNavigateCustomer',
    builder: (context, state) => DriverNavigateCustomerScreen(orderId: state.pathParameters['orderId']!),
  ),
  GoRoute(
    path: '/driver/delivery/:orderId/chat',
    name: 'driverOrderChat',
    builder: (context, state) => DriverOrderChatScreen(orderId: state.pathParameters['orderId']!),
  ),
  GoRoute(
    path: '/driver/delivery/:orderId/cash-collection',
    name: 'driverCashCollection',
    builder: (context, state) => DriverCashCollectionScreen(orderId: state.pathParameters['orderId']!),
  ),
  GoRoute(
    path: '/driver/delivery/:orderId/delivery-confirm',
    name: 'driverDeliveryConfirm',
    builder: (context, state) => DriverDeliveryConfirmScreen(orderId: state.pathParameters['orderId']!),
  ),

  GoRoute(path: '/driver/profile/edit', name: 'driverProfileEdit', builder: (context, state) => const DriverProfileEditScreen()),
  GoRoute(path: '/driver/profile/documents', name: 'driverDocumentsStatus', builder: (context, state) => const DriverDocumentsStatusScreen()),
  GoRoute(path: '/driver/reviews', name: 'driverReviews', builder: (context, state) => const DriverReviewsScreen()),
  GoRoute(path: '/driver/availability', name: 'driverAvailability', builder: (context, state) => const DriverAvailabilityScreen()),
  GoRoute(path: '/driver/notifications', name: 'driverNotifications', builder: (context, state) => const DriverNotificationsScreen()),
  GoRoute(path: '/driver/help', name: 'driverHelp', builder: (context, state) => const DriverSupportScreen()),
  GoRoute(
    path: '/driver/ticket/:id/chat',
    name: 'driverTicketChat',
    builder: (context, state) =>
        DriverTicketChatScreen(ticketId: state.pathParameters['id']!),
  ),
];
