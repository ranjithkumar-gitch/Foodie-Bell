import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../registration/driver_registration_controller.dart';

/// This driver's editable vehicle profile (spec §6 item 15). Separate from
/// [DriverRegistrationDraft] — that one only exists to carry data across the
/// pre-auth registration wizard, while this is the post-approval "my
/// vehicle" record the Profile screen reads and its editor writes, seeded
/// with plausible demo data since there's no real backend to fetch it from.
class DriverVehicleProfile {
  const DriverVehicleProfile({
    this.vehicleType = DriverVehicleType.bike,
    this.vehicleRegNumber = 'TS 09 AB 1234',
    this.bankOrUpi = 'ravi.kumar@upi',
  });

  final DriverVehicleType vehicleType;
  final String vehicleRegNumber;
  final String bankOrUpi;

  DriverVehicleProfile copyWith({DriverVehicleType? vehicleType, String? vehicleRegNumber, String? bankOrUpi}) => DriverVehicleProfile(
    vehicleType: vehicleType ?? this.vehicleType,
    vehicleRegNumber: vehicleRegNumber ?? this.vehicleRegNumber,
    bankOrUpi: bankOrUpi ?? this.bankOrUpi,
  );
}

class DriverProfileController extends StateNotifier<DriverVehicleProfile> {
  DriverProfileController() : super(const DriverVehicleProfile());

  void update({required DriverVehicleType vehicleType, required String vehicleRegNumber, required String bankOrUpi}) {
    state = state.copyWith(vehicleType: vehicleType, vehicleRegNumber: vehicleRegNumber, bankOrUpi: bankOrUpi);
  }
}

final driverProfileProvider = StateNotifierProvider<DriverProfileController, DriverVehicleProfile>((ref) => DriverProfileController());
