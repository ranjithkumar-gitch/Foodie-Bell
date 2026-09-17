import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/bottom_nav_shell.dart';
import 'catalogue/vendor_add_edit_product_screen.dart';
import 'catalogue/vendor_bulk_upload_screen.dart';
import 'catalogue/vendor_catalogue_screen.dart';
import 'catalogue/vendor_category_manager_screen.dart';
import 'catalogue/vendor_global_catalogue_screen.dart';
import 'dashboard/vendor_dashboard_screen.dart';
import 'earnings/vendor_earnings_screen.dart';
import 'notifications/vendor_notifications_screen.dart';
import 'orders/vendor_handover_screen.dart';
import 'orders/vendor_order_detail_screen.dart';
import 'orders/vendor_order_queue_screen.dart';
import 'profile/vendor_documents_status_screen.dart';
import 'profile/vendor_profile_edit_screen.dart';
import 'profile/vendor_profile_screen.dart';
import 'profile/vendor_store_hours_screen.dart';
import 'promotions/vendor_promotions_screen.dart';
import 'registration/vendor_business_details_screen.dart';
import 'registration/vendor_documents_screen.dart';
import 'registration/vendor_location_hours_screen.dart';
import 'registration/vendor_manager_code_screen.dart';
import 'registration/vendor_rebate_terms_screen.dart';
import 'reviews/vendor_reviews_screen.dart';
import 'support/vendor_help_screen.dart';
import 'support/vendor_ticket_chat_screen.dart';

/// Vendor's full route set (spec §5). Registration (items 1-5) lives under
/// `/vendor/register/...` and is reachable pre-auth, per `sessionRedirect`'s
/// `/<role>/register` exception — its last step hands off to the shared
/// `/auth/phone` + `/auth/otp` + `/auth/terms` screens (see
/// vendor_rebate_terms_screen.dart). Everything else requires an active
/// Vendor session. The bottom-nav shell mirrors user_routes.dart's
/// [StatefulShellRoute.indexedStack] pattern.
List<RouteBase> get vendorRoutes => [
  GoRoute(path: '/vendor', redirect: (context, state) => '/vendor/dashboard'),

  // --- Registration (pre-auth) ---
  GoRoute(
    path: '/vendor/register',
    redirect: (context, state) => '/vendor/register/business',
  ),
  GoRoute(
    path: '/vendor/register/business',
    name: 'vendorRegisterBusiness',
    builder: (context, state) => const VendorBusinessDetailsScreen(),
  ),
  GoRoute(
    path: '/vendor/register/manager-code',
    name: 'vendorRegisterManagerCode',
    builder: (context, state) => const VendorManagerCodeScreen(),
  ),
  GoRoute(
    path: '/vendor/register/documents',
    name: 'vendorRegisterDocuments',
    builder: (context, state) => const VendorDocumentsScreen(),
  ),
  GoRoute(
    path: '/vendor/register/location-hours',
    name: 'vendorRegisterLocationHours',
    builder: (context, state) => const VendorLocationHoursScreen(),
  ),
  GoRoute(
    path: '/vendor/register/rebate-terms',
    name: 'vendorRegisterRebateTerms',
    builder: (context, state) => const VendorRebateTermsScreen(),
  ),

  // --- Bottom-nav tabs (active session) ---
  StatefulShellRoute.indexedStack(
    builder: (context, state, navigationShell) => BottomNavShell(
      navigationShell: navigationShell,
      items: const [
        BottomNavItemData(
          icon: Icons.space_dashboard_rounded,
          label: 'Dashboard',
        ),
        BottomNavItemData(icon: Icons.receipt_long_rounded, label: 'Orders'),
        BottomNavItemData(icon: Icons.storefront_rounded, label: 'Catalogue'),
        BottomNavItemData(icon: Icons.person_rounded, label: 'Profile'),
      ],
    ),
    branches: [
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: '/vendor/dashboard',
            name: 'vendorDashboard',
            builder: (context, state) => const VendorDashboardScreen(),
          ),
        ],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: '/vendor/orders',
            name: 'vendorOrders',
            builder: (context, state) => const VendorOrderQueueScreen(),
          ),
        ],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: '/vendor/catalogue',
            name: 'vendorCatalogue',
            builder: (context, state) => const VendorCatalogueScreen(),
          ),
        ],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: '/vendor/profile',
            name: 'vendorProfile',
            builder: (context, state) => const VendorProfileScreen(),
          ),
        ],
      ),
    ],
  ),

  // --- Pushed siblings (active session) ---
  GoRoute(
    path: '/vendor/order/:id',
    name: 'vendorOrderDetail',
    builder: (context, state) =>
        VendorOrderDetailScreen(orderId: state.pathParameters['id']!),
  ),
  GoRoute(
    path: '/vendor/order/:id/handover',
    name: 'vendorOrderHandover',
    builder: (context, state) =>
        VendorHandoverScreen(orderId: state.pathParameters['id']!),
  ),
  GoRoute(
    path: '/vendor/catalogue/product/add',
    name: 'vendorAddProduct',
    builder: (context, state) => const VendorAddEditProductScreen(),
  ),
  GoRoute(
    path: '/vendor/catalogue/product/:id/edit',
    name: 'vendorEditProduct',
    builder: (context, state) =>
        VendorAddEditProductScreen(productId: state.pathParameters['id']!),
  ),
  GoRoute(
    path: '/vendor/catalogue/bulk-upload',
    name: 'vendorBulkUpload',
    builder: (context, state) => const VendorBulkUploadScreen(),
  ),
  GoRoute(
    path: '/vendor/catalogue/categories',
    name: 'vendorCategoryManager',
    builder: (context, state) => const VendorCategoryManagerScreen(),
  ),
  GoRoute(
    path: '/vendor/catalogue/global',
    name: 'vendorGlobalCatalogue',
    builder: (context, state) => const VendorGlobalCatalogueScreen(),
  ),
  GoRoute(
    path: '/vendor/earnings',
    name: 'vendorEarnings',
    builder: (context, state) => const VendorEarningsScreen(),
  ),
  GoRoute(
    path: '/vendor/promotions',
    name: 'vendorPromotions',
    builder: (context, state) => const VendorPromotionsScreen(),
  ),
  GoRoute(
    path: '/vendor/profile/hours',
    name: 'vendorStoreHours',
    builder: (context, state) => const VendorStoreHoursScreen(),
  ),
  GoRoute(
    path: '/vendor/profile/documents',
    name: 'vendorDocumentsStatus',
    builder: (context, state) => const VendorDocumentsStatusScreen(),
  ),
  GoRoute(
    path: '/vendor/profile/edit',
    name: 'vendorProfileEdit',
    builder: (context, state) => const VendorProfileEditScreen(),
  ),
  GoRoute(
    path: '/vendor/reviews',
    name: 'vendorReviews',
    builder: (context, state) => const VendorReviewsScreen(),
  ),
  GoRoute(
    path: '/vendor/notifications',
    name: 'vendorNotifications',
    builder: (context, state) => const VendorNotificationsScreen(),
  ),
  GoRoute(
    path: '/vendor/help',
    name: 'vendorHelp',
    builder: (context, state) => const VendorHelpScreen(),
  ),
  GoRoute(
    path: '/vendor/ticket/:id/chat',
    name: 'vendorTicketChat',
    builder: (context, state) =>
        VendorTicketChatScreen(ticketId: state.pathParameters['id']!),
  ),
];
