import 'package:flutter_riverpod/flutter_riverpod.dart';

enum DriverVehicleType { bike, cycle, eCart }

extension DriverVehicleTypeX on DriverVehicleType {
  String get label => switch (this) {
    DriverVehicleType.bike => 'Bike',
    DriverVehicleType.cycle => 'Cycle',
    DriverVehicleType.eCart => 'E-Cart',
  };
}

/// In-memory draft collected across the multi-step Driver registration flow
/// (personal details -> Manager Code -> vehicle -> documents), before the
/// shared phone/OTP/terms screens take over as the final step (see
/// driver_routes.dart). Not wired to a real backend yet — the Manager Code
/// step (`driver_manager_code_screen.dart`) rejects every code, so this
/// draft is never actually turned into an account; a real Driver account is
/// currently only ever created by a Manager directly
/// (`manager_driver_create_screen.dart`).
class DriverRegistrationDraft {
  const DriverRegistrationDraft({
    this.name = '',
    this.phone = '',
    this.dob = '',
    this.address = '',
    this.managerCode = '',
    this.vehicleType = DriverVehicleType.bike,
    this.vehicleRegNumber = '',
    this.rcFileName,
    this.licenseFileName,
    this.idProofFileName,
    this.bankOrUpi = '',
    this.selfieFileName,
  });

  final String name;
  final String phone;
  final String dob;
  final String address;
  final String managerCode;
  final DriverVehicleType vehicleType;
  final String vehicleRegNumber;
  final String? rcFileName;
  final String? licenseFileName;
  final String? idProofFileName;
  final String bankOrUpi;
  final String? selfieFileName;

  DriverRegistrationDraft copyWith({
    String? name,
    String? phone,
    String? dob,
    String? address,
    String? managerCode,
    DriverVehicleType? vehicleType,
    String? vehicleRegNumber,
    String? rcFileName,
    String? licenseFileName,
    String? idProofFileName,
    String? bankOrUpi,
    String? selfieFileName,
  }) => DriverRegistrationDraft(
    name: name ?? this.name,
    phone: phone ?? this.phone,
    dob: dob ?? this.dob,
    address: address ?? this.address,
    managerCode: managerCode ?? this.managerCode,
    vehicleType: vehicleType ?? this.vehicleType,
    vehicleRegNumber: vehicleRegNumber ?? this.vehicleRegNumber,
    rcFileName: rcFileName ?? this.rcFileName,
    licenseFileName: licenseFileName ?? this.licenseFileName,
    idProofFileName: idProofFileName ?? this.idProofFileName,
    bankOrUpi: bankOrUpi ?? this.bankOrUpi,
    selfieFileName: selfieFileName ?? this.selfieFileName,
  );
}

class DriverRegistrationController extends StateNotifier<DriverRegistrationDraft> {
  DriverRegistrationController() : super(const DriverRegistrationDraft());

  void updatePersonal({required String name, required String phone, required String dob, required String address}) {
    state = state.copyWith(name: name, phone: phone, dob: dob, address: address);
  }

  void updateManagerCode(String code) => state = state.copyWith(managerCode: code);

  void updateVehicle({required DriverVehicleType type, required String regNumber, String? rcFileName}) {
    state = state.copyWith(vehicleType: type, vehicleRegNumber: regNumber, rcFileName: rcFileName);
  }

  void updateDocuments({String? licenseFileName, String? idProofFileName, String? bankOrUpi, String? selfieFileName}) {
    state = state.copyWith(
      licenseFileName: licenseFileName,
      idProofFileName: idProofFileName,
      bankOrUpi: bankOrUpi,
      selfieFileName: selfieFileName,
    );
  }
}

final driverRegistrationProvider =
    StateNotifierProvider<DriverRegistrationController, DriverRegistrationDraft>((ref) => DriverRegistrationController());
