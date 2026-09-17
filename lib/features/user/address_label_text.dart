import 'package:flutter/widgets.dart';

import '../../data/models/address.dart';
import '../../l10n/app_localizations_context.dart';

/// Localized display text for [AddressLabel] — used everywhere a saved
/// address's Home/Work/Other tag is shown (`checkout_address_screen.dart`,
/// `checkout_payment_screen.dart`, `addresses_screen.dart`,
/// `add_address_sheet.dart`). [AddressLabelX.label] on the model itself
/// stays English (it's shared data-model code, not UI copy) — this is the
/// one place that maps it to the User's chosen language.
String addressLabelText(BuildContext context, AddressLabel label) => switch (label) {
  AddressLabel.home => context.l10n.addressLabelHome,
  AddressLabel.work => context.l10n.addressLabelWork,
  AddressLabel.other => context.l10n.addressLabelOther,
};
