import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/session/session_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/address.dart';
import '../../../data/providers/firestore_addresses_provider.dart';
import '../../../l10n/app_localizations_context.dart';
import '../../../shared/error_reporting.dart';
import '../address_label_text.dart';

/// Shared "Add Address" bottom sheet — used by both the Saved Addresses
/// screen and the Checkout address-selection screen (which needs the same
/// add-new-address capability without leaving the checkout flow). Writes a
/// real `addresses` doc (`firestore_addresses_provider.dart`) for the
/// signed-in User; pass [onSaved] to react to the newly created address
/// (e.g. auto-selecting it for checkout).
class AddAddressSheet extends ConsumerStatefulWidget {
  const AddAddressSheet({super.key, this.onSaved});

  final ValueChanged<Address>? onSaved;

  @override
  ConsumerState<AddAddressSheet> createState() => _AddAddressSheetState();
}

class _AddAddressSheetState extends ConsumerState<AddAddressSheet> {
  final _formKey = GlobalKey<FormState>();
  AddressLabel _label = AddressLabel.home;
  late final _nameController = TextEditingController(
    text: ref.read(sessionControllerProvider).account?.name ?? '',
  );
  late final _phoneController = TextEditingController(
    text: ref.read(sessionControllerProvider).account?.phone ?? '',
  );
  final _line1Controller = TextEditingController();
  final _landmarkController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _cityController = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _line1Controller.dispose();
    _landmarkController.dispose();
    _pincodeController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final userId = ref.read(sessionControllerProvider).account?.id;
    if (userId == null) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final saved = await addAddress(
        userId,
        Address(
          id: '',
          label: _label,
          recipientName: _nameController.text.trim(),
          recipientPhone: _phoneController.text.trim(),
          line1: _line1Controller.text.trim(),
          landmark: _landmarkController.text.trim().isEmpty
              ? null
              : _landmarkController.text.trim(),
          pincode: _pincodeController.text.trim(),
          city: _cityController.text.trim(),
        ),
      );
      if (!mounted) return;
      Navigator.pop(context);
      widget.onSaved?.call(saved);
    } catch (e, st) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = friendlyError(e, action: 'Saving address', stackTrace: st);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: palette.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                context.l10n.addAddressTitle,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              Text(
                context.l10n.addAddressLabelHeading,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: palette.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final label in AddressLabel.values) ...[
                    Expanded(
                      child: _LabelChoice(
                        label: label,
                        selected: _label == label,
                        onTap: _saving
                            ? () {}
                            : () => setState(() => _label = label),
                      ),
                    ),
                    if (label != AddressLabel.values.last)
                      const SizedBox(width: 10),
                  ],
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _nameController,
                      enabled: !_saving,
                      decoration: InputDecoration(
                        labelText: context.l10n.addAddressRecipientName,
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? context.l10n.fieldRequired
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _phoneController,
                      enabled: !_saving,
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: context.l10n.addAddressPhoneNumber,
                        counterText: '',
                      ),
                      validator: (v) => (v == null || v.trim().length != 10)
                          ? context.l10n.addAddressPhoneDigitsError
                          : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _line1Controller,
                enabled: !_saving,
                decoration: InputDecoration(
                  labelText: context.l10n.addAddressHouseStreet,
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? context.l10n.fieldRequired
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _landmarkController,
                enabled: !_saving,
                decoration: InputDecoration(
                  labelText: context.l10n.addAddressLandmarkOptional,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _pincodeController,
                      enabled: !_saving,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: context.l10n.addAddressPincode,
                      ),
                      validator: (v) => (v == null || v.trim().length != 6)
                          ? context.l10n.addAddressPincodeDigitsError
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _cityController,
                      enabled: !_saving,
                      decoration: InputDecoration(
                        labelText: context.l10n.addAddressCity,
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? context.l10n.fieldRequired
                          : null,
                    ),
                  ),
                ],
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
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.4,
                          ),
                        )
                      : Text(context.l10n.addAddressSaveButton),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LabelChoice extends StatelessWidget {
  const _LabelChoice({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final AddressLabel label;
  final bool selected;
  final VoidCallback onTap;

  IconData get _icon => switch (label) {
    AddressLabel.home => Icons.home_rounded,
    AddressLabel.work => Icons.work_rounded,
    AddressLabel.other => Icons.place_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? palette.primaryLight.withValues(alpha: 0.18)
              : palette.surfaceMuted,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? palette.primary : Colors.transparent,
            width: 1.4,
          ),
        ),
        child: Column(
          children: [
            Icon(
              _icon,
              size: 18,
              color: selected ? palette.primary : palette.textSecondary,
            ),
            const SizedBox(height: 4),
            Text(
              addressLabelText(context, label),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? palette.primary : palette.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
