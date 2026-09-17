import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_text_field.dart';
import 'driver_registration_controller.dart';
import 'driver_upload_tile.dart';

/// Step 3/4: vehicle type, registration number, and RC upload.
class DriverVehicleDetailsScreen extends ConsumerStatefulWidget {
  const DriverVehicleDetailsScreen({super.key});

  @override
  ConsumerState<DriverVehicleDetailsScreen> createState() => _DriverVehicleDetailsScreenState();
}

class _DriverVehicleDetailsScreenState extends ConsumerState<DriverVehicleDetailsScreen> {
  final _regController = TextEditingController();
  late DriverVehicleType _type;
  String? _rcFileName;
  String? _error;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(driverRegistrationProvider);
    _regController.text = draft.vehicleRegNumber;
    _type = draft.vehicleType;
    _rcFileName = draft.rcFileName;
  }

  @override
  void dispose() {
    _regController.dispose();
    super.dispose();
  }

  void _continue() {
    if (_regController.text.trim().isEmpty || _rcFileName == null) {
      setState(() => _error = 'Enter your registration number and upload the RC document.');
      return;
    }
    setState(() => _error = null);
    ref
        .read(driverRegistrationProvider.notifier)
        .updateVehicle(type: _type, regNumber: _regController.text.trim(), rcFileName: _rcFileName);
    context.go('/driver/register/documents');
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Scaffold(
      appBar: AppBar(title: const Text('Become a Driver · 3 of 4')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        children: [
          Text('Vehicle details', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text('What will you deliver on?', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            children: [
              for (final type in DriverVehicleType.values)
                ChoiceChip(
                  label: Text(type.label),
                  selected: _type == type,
                  onSelected: (_) => setState(() => _type = type),
                  selectedColor: palette.primaryLight.withValues(alpha: 0.3),
                  labelStyle: TextStyle(color: _type == type ? palette.primary : palette.textSecondary, fontWeight: FontWeight.w700),
                ),
            ],
          ),
          const SizedBox(height: 20),
          AppTextField(
            label: 'Vehicle registration number',
            controller: _regController,
            hint: 'e.g. TS 09 AB 1234',
            prefixIcon: Icons.confirmation_number_outlined,
          ),
          const SizedBox(height: 20),
          DriverUploadTile(
            label: 'Upload RC (Registration Certificate)',
            fileName: _rcFileName,
            onPicked: (name) => setState(() => _rcFileName = name),
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            Text(_error!, style: TextStyle(color: palette.error, fontWeight: FontWeight.w600, fontSize: 12.5)),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: ElevatedButton(onPressed: _continue, child: const Text('Continue')),
        ),
      ),
    );
  }
}
