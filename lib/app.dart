import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/branding/branding_controller.dart';
import 'core/notifications/fcm_topics.dart';
import 'core/notifications/foreground_notification_handler.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
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
      routerConfig: router,
    );
  }
}
