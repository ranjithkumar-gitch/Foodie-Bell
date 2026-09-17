import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/rail_drawer_shell.dart';
import 'categories/manager_categories_screen.dart';
import 'code/manager_code_management_screen.dart';
import 'dashboard/manager_dashboard_screen.dart';
import 'drivers/manager_driver_create_screen.dart';
import 'drivers/manager_driver_detail_screen.dart';
import 'drivers/manager_driver_list_screen.dart';
import 'marketing/manager_marketing_tracker_screen.dart';
import 'notifications/manager_notifications_screen.dart';
import 'oversight/manager_order_oversight_screen.dart';
import 'profile/manager_profile_screen.dart';
import 'promotions/manager_promotion_approvals_screen.dart';
import 'reports/manager_territory_earnings_screen.dart';
import 'settlement/manager_daily_settlement_screen.dart';
import 'settlement/manager_settlement_history_screen.dart';
import 'support/manager_support_screen.dart';
import 'support/manager_ticket_chat_screen.dart';
import 'vendors/manager_vendor_create_screen.dart';
import 'vendors/manager_vendor_detail_screen.dart';
import 'vendors/manager_vendor_list_screen.dart';

/// Manager's full screen set (spec §7, as amended). Rail/drawer shell, same
/// reference pattern as admin_routes.dart (spec calls Manager "mobile +
/// responsive web", same shape as Admin).
///
/// Routing shape:
/// - There is no `/manager/register` — Manager accounts are created by
///   Admin (see `admin/managers/manager_create_screen.dart`'s "Add
///   Manager" form) and log in directly via the shared `/auth/login`
///   screen (Role Selector routes Manager straight there, skipping the
///   Login-vs-Register landing screen). `sessionRedirect`'s `/<role>/register`
///   pre-auth carve-out still exists generically for Vendor/Driver; it's
///   simply unused for Manager now.
/// - The 5 tabs mirror the Phase-0 placeholder shell exactly (Dashboard /
///   Vendors / Drivers / Settlement / Profile).
/// - Everything else (post-creation onboarding chain, approval detail
///   screens, settlement history, earnings report, marketing tracker,
///   promotion approvals, order oversight, code management, notifications,
///   support) is a flat sibling `GoRoute` alongside the shell — same
///   pattern user_routes.dart uses for non-tab screens like order detail.
///   These are reachable from the Dashboard's quick-actions grid and the
///   Profile menu (see those screens' doc comments for why they aren't
///   rail/drawer tabs themselves).
List<RouteBase> get managerRoutes => [
  GoRoute(path: '/manager', redirect: (context, state) => '/manager/dashboard'),

  StatefulShellRoute.indexedStack(
    builder: (context, state, navigationShell) => RailDrawerShell(
      navigationShell: navigationShell,
      title: 'Quicky Manager',
      items: const [
        RailItemData(icon: Icons.space_dashboard_outlined, selectedIcon: Icons.space_dashboard_rounded, label: 'Dashboard'),
        RailItemData(icon: Icons.storefront_outlined, selectedIcon: Icons.storefront_rounded, label: 'Vendors'),
        RailItemData(icon: Icons.two_wheeler_outlined, selectedIcon: Icons.two_wheeler_rounded, label: 'Drivers'),
        RailItemData(icon: Icons.receipt_long_outlined, selectedIcon: Icons.receipt_long_rounded, label: 'Settlement'),
        RailItemData(icon: Icons.person_outline_rounded, selectedIcon: Icons.person_rounded, label: 'Profile'),
      ],
      // Day-to-day territory operations first, periodic financial reports
      // after — moved here from Profile's menu so they're reachable from
      // every screen's menu icon, not just one tab.
      extraItems: const [
        DrawerLinkData(icon: Icons.delivery_dining_rounded, label: 'Order Oversight', path: '/manager/orders'),
        DrawerLinkData(icon: Icons.local_offer_outlined, label: 'Vendor Promotion Approvals', path: '/manager/promotions'),
        DrawerLinkData(icon: Icons.category_outlined, label: 'Territory Categories', path: '/manager/categories'),
        DrawerLinkData(icon: Icons.receipt_long_rounded, label: 'Settlement History', path: '/manager/settlement/history'),
        DrawerLinkData(icon: Icons.trending_up_rounded, label: 'Territory Earnings Report', path: '/manager/reports/earnings'),
      ],
    ),
    branches: [
      StatefulShellBranch(routes: [GoRoute(path: '/manager/dashboard', name: 'managerDashboard', builder: (context, state) => const ManagerDashboardScreen())]),
      StatefulShellBranch(routes: [GoRoute(path: '/manager/vendors', name: 'managerVendors', builder: (context, state) => const ManagerVendorListScreen())]),
      StatefulShellBranch(routes: [GoRoute(path: '/manager/drivers', name: 'managerDrivers', builder: (context, state) => const ManagerDriverListScreen())]),
      StatefulShellBranch(routes: [GoRoute(path: '/manager/settlement', name: 'managerSettlement', builder: (context, state) => const ManagerDailySettlementScreen())]),
      StatefulShellBranch(routes: [GoRoute(path: '/manager/profile', name: 'managerProfile', builder: (context, state) => const ManagerProfileScreen())]),
    ],
  ),

  // Direct Vendor/Driver onboarding — see manager_vendor_create_screen.dart
  // and manager_driver_create_screen.dart.
  GoRoute(path: '/manager/vendors/new', name: 'managerCreateVendor', builder: (context, state) => const ManagerVendorCreateScreen()),
  GoRoute(path: '/manager/drivers/new', name: 'managerCreateDriver', builder: (context, state) => const ManagerDriverCreateScreen()),

  // Vendor/Driver approval detail (spec §7.7/§7.8).
  GoRoute(
    path: '/manager/vendors/:id',
    name: 'managerVendorDetail',
    builder: (context, state) => ManagerVendorDetailScreen(accountId: state.pathParameters['id']!),
  ),
  GoRoute(
    path: '/manager/drivers/:id',
    name: 'managerDriverDetail',
    builder: (context, state) => ManagerDriverDetailScreen(accountId: state.pathParameters['id']!),
  ),

  GoRoute(path: '/manager/settlement/history', name: 'managerSettlementHistory', builder: (context, state) => const ManagerSettlementHistoryScreen()),
  GoRoute(path: '/manager/reports/earnings', name: 'managerTerritoryEarnings', builder: (context, state) => const ManagerTerritoryEarningsScreen()),
  GoRoute(path: '/manager/marketing', name: 'managerMarketingTracker', builder: (context, state) => const ManagerMarketingTrackerScreen()),
  GoRoute(path: '/manager/promotions', name: 'managerPromotionApprovals', builder: (context, state) => const ManagerPromotionApprovalsScreen()),
  GoRoute(path: '/manager/orders', name: 'managerOrderOversight', builder: (context, state) => const ManagerOrderOversightScreen()),
  GoRoute(path: '/manager/code', name: 'managerCodeManagement', builder: (context, state) => const ManagerCodeManagementScreen()),
  GoRoute(path: '/manager/categories', name: 'managerCategories', builder: (context, state) => const ManagerCategoriesScreen()),
  GoRoute(path: '/manager/notifications', name: 'managerNotifications', builder: (context, state) => const ManagerNotificationsScreen()),
  GoRoute(path: '/manager/support', name: 'managerSupport', builder: (context, state) => const ManagerSupportScreen()),
  GoRoute(
    path: '/manager/ticket/:id/chat',
    name: 'managerTicketChat',
    builder: (context, state) =>
        ManagerTicketChatScreen(ticketId: state.pathParameters['id']!),
  ),
];
