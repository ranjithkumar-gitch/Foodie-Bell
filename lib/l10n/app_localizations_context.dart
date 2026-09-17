import 'package:flutter/widgets.dart';

import 'generated/app_localizations.dart';

/// Shorthand for `AppLocalizations.of(context)!`, mirroring `context.colors`
/// (`app_colors.dart`) — every User-module screen reads translated strings
/// via `context.l10n.someKey` rather than the longer call.
extension AppLocalizationsContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}
