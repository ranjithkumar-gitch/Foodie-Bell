import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/branding/branding_controller.dart';
import 'core/dev/firebase_emulators.dart';
import 'core/notifications/chat_notifications.dart';
import 'core/notifications/fcm_topics.dart';
import 'core/notifications/foreground_notification_handler.dart';
import 'core/release/app_version_gate.dart';
import 'core/router/app_router.dart';
import 'core/router/exit_confirm_back_button_dispatcher.dart';
import 'core/session/claim_sync.dart';
import 'core/theme/app_theme.dart';
import 'core/notifications/live_order_card.dart';
import 'core/notifications/notification_taps.dart';
import 'features/driver/driver_location_tracker.dart';
import 'features/driver/new_offer_alert.dart';
import 'features/user/home/selected_territory_provider.dart';
import 'features/user/user_locale.dart';
import 'l10n/generated/app_localizations.dart';

class QuickyApp extends ConsumerWidget {
  const QuickyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final locale = ref.watch(userLocaleProvider);
    final brand = ref.watch(activeBrandThemeProvider);
    listenForBrandThemeChanges(context, ref);
    hydrateSelectedTerritoryFromCache(ref);
    listenForTopicSync(ref);
    listenForDeviceTokenSync(ref);
    listenForDriverTerritoryTopicSync(ref);
    listenForDriverLocationTracking(ref);
    listenForChatNotifications(ref);
    listenForNewDriverOffers(ref);
    listenForClaimChanges(ref);
    // Customers and drivers: the live order card in the notification bar.
    listenForLiveOrderCards(ref);
    listenForNotificationTaps(ref);
    return MaterialApp.router(
      title: 'Quicky',
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(brand),
      darkTheme: AppTheme.dark(brand),
      themeMode: ThemeMode.system,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerDelegate: router.routerDelegate,
      routeInformationParser: router.routeInformationParser,
      routeInformationProvider: router.routeInformationProvider,
      backButtonDispatcher: ref.watch(exitConfirmBackButtonDispatcherProvider),
      // Always claim the device back button. Left to the default, Android
      // closes the app by itself whenever there's nothing to pop, and the
      // exit confirmation would never get the chance to show.
      onNavigationNotification: (notification) {
        SystemNavigator.setFrameworkHandlesBack(true);
        return true;
      },
      // Builds below the server's minimum see a blocking update screen.
      // Emulator builds (Phase I.8) carry a corner ribbon on every screen, so
      // a local test APK can never be mistaken for a real one.
      builder: (context, child) {
        final gated = AppVersionGate(child: child ?? const SizedBox.shrink());
        return usingFirebaseEmulators
            ? Banner(message: 'EMULATOR', location: BannerLocation.topStart, color: const Color(0xFFB00020), child: gated)
            : gated;
      },
    );
  }
}
