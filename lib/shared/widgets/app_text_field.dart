import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show TextInputFormatter;

import '../../core/theme/app_colors.dart';
import 'glossy_surface.dart';

/// A labeled form field — label above input, consistent across the many
/// registration/form screens (Vendor docs, Driver vehicle details, Manager
/// application, Admin config, ...). Wraps [TextFormField]; styling itself
/// comes from [InputDecorationTheme].
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.keyboardType,
    this.obscureText = false,
    this.maxLines = 1,
    this.prefixIcon,
    this.suffixIcon,
    this.validator,
    this.enabled = true,
    this.onChanged,
    this.labelColor,
    this.textColor,
    this.glossy = false,
    this.maxLength,
    this.inputFormatters,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final TextInputType? keyboardType;
  final bool obscureText;
  final int maxLines;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final bool enabled;
  final ValueChanged<String>? onChanged;

  /// Hard input-level cap (e.g. 10 for phone number fields) — suppresses
  /// the default "x/y" counter row underneath, since none of this app's
  /// forms show one. Pair with [inputFormatters] (`FilteringTextInputFormatter
  /// .digitsOnly`, typically) for fields that also need to reject non-digit
  /// characters, not just stop at a length.
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;

  /// Overrides the label's color — the field itself always keeps its own
  /// light [InputDecorationTheme] fill regardless of what it's sitting on,
  /// but the label sits directly on the page background, so a screen with
  /// a dark/colored background (the sign-in/OTP/registration screens' green
  /// gradient) needs this to stay readable.
  final Color? labelColor;

  /// Overrides the color of what's actually typed into the field — normally
  /// [AppColors.textPrimary], which flips light in dark theme (unlike the
  /// field's own always-light fill), so a screen that wants the entered
  /// text to stay black regardless of theme (the glossy sign-in/register
  /// cards) sets this explicitly rather than relying on the theme default.
  final Color? textColor;

  /// Swaps the field's usual flat [InputDecorationTheme] fill for a white
  /// [GlossySurface] (sign-in screen) — still a light, dark-on-white field
  /// (unlike the green glossy carousel/CTA button, green-on-green input
  /// text would be unreadable), just with the same sheen/shadow/22px-radius
  /// card treatment instead of the theme's flat grey box.
  final bool glossy;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final field = TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      maxLines: maxLines,
      maxLength: maxLength,
      inputFormatters: inputFormatters,
      enabled: enabled,
      validator: validator,
      onChanged: onChanged,
      style: TextStyle(
        color: textColor ?? palette.textPrimary,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: hint,
        counterText: maxLength == null ? null : '',
        prefixIcon: prefixIcon == null
            ? null
            : Icon(prefixIcon, color: palette.textMuted),
        suffixIcon: suffixIcon,
        filled: glossy ? true : null,
        fillColor: glossy ? Colors.transparent : null,
        border: glossy
            ? const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(22)),
                borderSide: BorderSide.none,
              )
            : null,
        enabledBorder: glossy
            ? const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(22)),
                borderSide: BorderSide.none,
              )
            : null,
        focusedBorder: glossy
            ? OutlineInputBorder(
                borderRadius: const BorderRadius.all(Radius.circular(22)),
                borderSide: BorderSide(color: palette.primary, width: 1.6),
              )
            : null,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: labelColor ?? palette.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        glossy
            ? GlossySurface(borderRadius: 22, light: true, child: field)
            : field,
      ],
    );
  }
}
