import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

import '../../core/theme/app_colors.dart';

/// 6-digit OTP entry + 30s resend timer (spec's "OTP Verification" screen).
/// Purely a text-entry widget — it reports what was typed via [onCompleted]
/// and lets the caller verify it (against Firebase Auth's real SMS code).
/// [onResend] fires when the user taps "Resend code", in addition to this
/// widget restarting its own countdown — the caller is responsible for
/// actually re-triggering delivery of a new code.
class OtpInputField extends StatefulWidget {
  const OtpInputField({
    super.key,
    required this.onCompleted,
    this.onResend,
    this.length = 6,
  });

  final ValueChanged<String> onCompleted;
  final VoidCallback? onResend;
  final int length;

  @override
  State<OtpInputField> createState() => _OtpInputFieldState();
}

class _OtpInputFieldState extends State<OtpInputField> {
  final _controller = TextEditingController();
  Timer? _timer;
  int _secondsLeft = 30;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _secondsLeft = 30;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        t.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Column(
      children: [
        PinCodeTextField(
          appContext: context,
          length: widget.length,
          controller: _controller,
          // Explicit, not relying on the package's own (nominally
          // transparent) default — this is the strip behind the boxes:
          // pin_code_fields paints its whole outer row, gaps included, in
          // this color.
          backgroundColor: Colors.transparent,
          // _controller is owned and disposed by this State (see dispose()
          // below) — pin_code_fields defaults to disposing it too, which
          // double-disposes and throws "used after being disposed" during
          // teardown (e.g. right after OTP completes and the screen navigates
          // away).
          autoDisposeControllers: false,
          // Default true — hints the hidden text field underneath the
          // boxes as a one-time-code field, which is what was actually
          // behind the "white strip": Android's own SMS/OTP autofill
          // suggestion bar, drawn by the OS over the field, not by
          // anything in pinTheme below. Long-press-to-paste (built into
          // the package) still covers pasting a code manually.
          enablePinAutofill: false,
          keyboardType: TextInputType.number,
          animationType: AnimationType.fade,
          onChanged: (_) {},
          // Deferred a frame: `onCompleted` fires synchronously from inside
          // `pin_code_fields`' own controller-listener callback, and our
          // caller's completion handler navigates away (login succeeds)
          // almost immediately — disposing this field's `_controller` while
          // the package is still mid-notification on it throws "A
          // TextEditingController was used after being disposed." Running
          // the callback after the current frame lets that notification
          // finish first.
          onCompleted: (value) => WidgetsBinding.instance.addPostFrameCallback(
            (_) => widget.onCompleted(value),
          ),
          pinTheme: PinTheme(
            shape: PinCodeFieldShape.box,
            borderRadius: BorderRadius.circular(8),
            fieldHeight: 48,
            fieldWidth: 42,
            activeColor: palette.primary,
            selectedColor: palette.primary,
            inactiveColor: palette.border,
            // Transparent, not palette.surfaceMuted — these only apply if
            // enableActiveFill is ever turned on (off below, and by
            // default); harmless either way, but transparent matches the
            // sign-in/OTP screens' translucent glass card
            // (auth_otp_screen.dart) rather than pasting an opaque box over
            // it, if a future box style does turn fill on.
            activeFillColor: Colors.transparent,
            selectedFillColor: Colors.transparent,
            inactiveFillColor: Colors.transparent,
          ),
        ),
        const SizedBox(height: 18),
        _secondsLeft > 0
            ? Text(
                'Resend code in 00:${_secondsLeft.toString().padLeft(2, '0')}',
                style: TextStyle(
                  color: palette.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              )
            : TextButton(
                onPressed: () {
                  _startTimer();
                  widget.onResend?.call();
                },
                child: const Text('Resend code'),
              ),
      ],
    );
  }
}
