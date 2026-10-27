import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/branding/branding_controller.dart';
import 'core/notifications/fcm_topics.dart';
import 'core/notifications/foreground_notification_handler.dart';
import 'core/router/app_router.dart';
import 'core/router/exit_confirm_back_button_dispatcher.dart';
import 'core/session/claim_sync.dart';
import 'core/theme/app_theme.dart';
import 'features/driver/driver_location_tracker.dart';
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
    listenForAccountTopicSync(ref);
    listenForDriverTerritoryTopicSync(ref);
    listenForDriverLocationTracking(ref);
    listenForClaimChanges(ref);
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
    );
  }
}
