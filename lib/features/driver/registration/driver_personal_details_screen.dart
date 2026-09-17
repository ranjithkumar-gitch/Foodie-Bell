import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_text_field.dart';
import 'driver_registration_controller.dart';

/// Step 1/4 of Driver registration (spec §6). Phone is collected here for
/// display only — actual verification happens at the very end of this flow
/// via the shared phone/OTP screens (see DriverDocumentsScreen).
class DriverPersonalDetailsScreen extends ConsumerStatefulWidget {
  const DriverPersonalDetailsScreen({super.key});

  @override
  ConsumerState<DriverPersonalDetailsScreen> createState() =>
      _DriverPersonalDetailsScreenState();
}

class _DriverPersonalDetailsScreenState
    extends ConsumerState<DriverPersonalDetailsScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _dobController = TextEditingController();
  final _addressController = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(driverRegistrationProvider);
    _nameController.text = draft.name;
    _phoneController.text = draft.phone;
    _dobController.text = draft.dob;
    _addressController.text = draft.address;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _dobController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _continue() {
    if (_nameController.text.trim().isEmpty ||
        _phoneController.text.trim().length != 10 ||
        _dobController.text.trim().isEmpty ||
        _addressController.text.trim().isEmpty) {
      setState(
        () => _error =
            'Fill in every field, and use a valid 10-digit mobile number.',
      );
      return;
    }
    setState(() => _error = null);
    ref
        .read(driverRegistrationProvider.notifier)
        .updatePersonal(
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          dob: _dobController.text.trim(),
          address: _addressController.text.trim(),
        );
    context.go('/driver/register/manager-code');
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Scaffold(
      appBar: AppBar(title: const Text('Become a Driver · 1 of 4')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        children: [
          Text(
            'Personal details',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            'Tell us a bit about yourself.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          AppTextField(
            label: 'Full name',
            controller: _nameController,
            hint: 'Your name',
            prefixIcon: Icons.person_outline_rounded,
          ),
          const SizedBox(height: 16),
          AppTextField(
            label: 'Mobile number',
            controller: _phoneController,
            hint: '10-digit mobile number',
            keyboardType: TextInputType.phone,
            prefixIcon: Icons.call_outlined,
            maxLength: 10,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          const SizedBox(height: 16),
          AppTextField(
            label: 'Date of birth',
            controller: _dobController,
            hint: 'DD/MM/YYYY',
            keyboardType: TextInputType.datetime,
            prefixIcon: Icons.cake_outlined,
          ),
          const SizedBox(height: 16),
          AppTextField(
            label: 'Home address',
            controller: _addressController,
            hint: 'House no., street, area, city',
            maxLines: 3,
            prefixIcon: Icons.home_outlined,
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            Text(
              _error!,
              style: TextStyle(
                color: palette.error,
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: ElevatedButton(
            onPressed: _continue,
            child: const Text('Continue'),
          ),
        ),
      ),
    );
  }
}
