/// Toggles whether phone login/registration (`auth_phone_screen.dart`,
/// `auth_otp_screen.dart`) verifies against real Firebase SMS delivery
/// (`verifyPhoneNumber`/`signInWithCredential`) or accepts a fixed demo
/// code instead.
///
/// Real SMS needs Firebase's phone-auth infra fully wired up — Console
/// test numbers or actual delivery, Play Integrity on Android, an APNs key
/// on iOS — none of which is set up yet. Until it is, every phone number
/// accepts [kDemoOtp] instead, so login/registration testing isn't blocked
/// on that setup. Flip this to `true` once real notifications are in place;
/// no other code needs to change.
const kUseDynamicOtp = false;

/// The fixed code every phone number accepts while [kUseDynamicOtp] is off.
const kDemoOtp = '123456';
