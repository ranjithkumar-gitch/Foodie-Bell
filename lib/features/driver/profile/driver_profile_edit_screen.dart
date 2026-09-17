import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../registration/driver_registration_controller.dart';
import 'driver_profile_controller.dart';

/// Profile & Vehicle Details Editor (spec §6 item 15) — lets the driver
/// update their vehicle type, registration number, and payout account after
/// approval, writing straight back into [driverProfileProvider].
class DriverProfileEditScreen extends ConsumerStatefulWidget {
  const DriverProfileEditScreen({super.key});

  @override
  ConsumerState<DriverProfileEditScreen> createState() =>
      _DriverProfileEditScreenState();
}

class _DriverProfileEditScreenState
    extends ConsumerState<DriverProfileEditScreen> {
  late final TextEditingController _regController;
  late final TextEditingController _bankController;
  late DriverVehicleType _type;

  @override
  void initState() {
    super.initState();
    final vehicle = ref.read(driverProfileProvider);
    _regController = TextEditingController(text: vehicle.vehicleRegNumber);
    _bankController = TextEditingController(text: vehicle.bankOrUpi);
    _type = vehicle.vehicleType;
  }

  @override
  void dispose() {
    _regController.dispose();
    _bankController.dispose();
    super.dispose();
  }

  void _save() {
    ref
        .read(driverProfileProvider.notifier)
        .update(
          vehicleType: _type,
          vehicleRegNumber: _regController.text.trim(),
          bankOrUpi: _bankController.text.trim(),
        );
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Vehicle details updated')));
    // `/driver/profile/edit` is a top-level route, not nested inside the
    // shell's Profile branch (see driver_routes.dart), so context.pop() —
    // wrong tool for coming back to a shell tab regardless — is skipped
    // here in favor of going straight to the Profile page explicitly.
    context.go('/driver/profile');
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Scaffold(
      appBar: AppBar(title: const Text('Edit vehicle details')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        children: [
          Text(
            'Vehicle type',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            children: [
              for (final type in DriverVehicleType.values)
                ChoiceChip(
                  label: Text(type.label),
                  selected: _type == type,
                  onSelected: (_) => setState(() => _type = type),
                  selectedColor: palette.primaryLight.withValues(alpha: 0.3),
                  labelStyle: TextStyle(
                    color: _type == type
                        ? palette.primary
                        : palette.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          AppTextField(
            label: 'Vehicle registration number',
            controller: _regController,
            prefixIcon: Icons.confirmation_number_outlined,
          ),
          const SizedBox(height: 16),
          AppTextField(
            label: 'Bank account / UPI ID for payouts',
            controller: _bankController,
            prefixIcon: Icons.account_balance_outlined,
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: ElevatedButton(
            onPressed: _save,
            child: const Text('Save changes'),
          ),
        ),
      ),
    );
  }
}
