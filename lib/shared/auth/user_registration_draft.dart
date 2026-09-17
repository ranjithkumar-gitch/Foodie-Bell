import 'package:flutter_riverpod/flutter_riverpod.dart';

/// In-memory draft bridging User's registration steps.
/// `auth_register_screen.dart` stages name/phone/email here so
/// `auth_phone_screen.dart` can pre-fill the number instead of asking the
/// user to type it twice; `AuthPhoneScreen._sendOtp()` then re-stages
/// [phone] as the raw digits actually sent for verification (in case it
/// was edited), which is also the format Vendor/Driver/the phone-lookup
/// functions store/query (`firestore_vendors_provider.dart`,
/// `firestore_users_provider.dart`) — never the `+91`-prefixed
/// `FirebaseAuth` form. `auth_terms_screen.dart` reads the whole draft once
/// at the final submit to build the real Firestore `users` doc — mirrors
/// `DriverRegistrationDraft`'s shape (`driver_registration_controller.dart`),
/// but lives in `shared/auth/` since every screen that touches it already
/// does too.
class UserRegistrationDraft {
  const UserRegistrationDraft({this.name = '', this.phone = '', this.email});

  final String name;
  final String phone;
  final String? email;

  UserRegistrationDraft copyWith({String? name, String? phone, String? email}) => UserRegistrationDraft(
    name: name ?? this.name,
    phone: phone ?? this.phone,
    email: email ?? this.email,
  );
}

class UserRegistrationDraftController extends StateNotifier<UserRegistrationDraft> {
  UserRegistrationDraftController() : super(const UserRegistrationDraft());

  void updateDetails({required String name, required String phone, String? email}) {
    state = state.copyWith(name: name, phone: phone, email: email);
  }

  void setPhone(String phone) => state = state.copyWith(phone: phone);

  void reset() => state = const UserRegistrationDraft();
}

final userRegistrationDraftProvider =
    StateNotifierProvider<UserRegistrationDraftController, UserRegistrationDraft>((ref) => UserRegistrationDraftController());
