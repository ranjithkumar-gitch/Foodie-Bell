import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// How many [runBusy] actions are in flight right now. [BusyOverlayHost]
/// shows the progress overlay while this is above zero.
final ValueNotifier<int> _pending = ValueNotifier<int>(0);

/// Whether a [runBusy] action is running — for a handler that should do
/// nothing at all when tapped twice.
bool get isBusy => _pending.value > 0;

/// Runs [action] behind a full-screen progress overlay (2026-11-18): every
/// button that saves, sends, uploads or calls the server wraps its work in
/// this, so a tap always shows a spinner and a second tap can't fire the
/// same action again while the first is still running.
///
/// Wrap only the waiting part. A confirmation dialog or sheet the action
/// opens must be shown before (outside) [runBusy] — the overlay sits above
/// every route, dialogs included, so it would cover it.
///
/// The overlay lifts after [maxWait] even if [action] hasn't finished (a
/// Firestore write made offline only completes once the phone reconnects),
/// so the app is never locked; [action] itself keeps running.
Future<T> runBusy<T>(Future<T> Function() action, {Duration maxWait = const Duration(seconds: 20)}) async {
  var released = false;
  void release() {
    if (released) return;
    released = true;
    _pending.value--;
  }

  _pending.value++;
  final timer = Timer(maxWait, release);
  try {
    return await action();
  } finally {
    timer.cancel();
    release();
  }
}

/// Sits above the whole app (`app.dart`'s `MaterialApp.router` builder) and
/// covers it while a [runBusy] action runs: taps are blocked straight away,
/// and the spinner fades in after a moment so instant actions don't flash.
class BusyOverlayHost extends StatelessWidget {
  const BusyOverlayHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        ValueListenableBuilder<int>(
          valueListenable: _pending,
          builder: (context, pending, _) => pending > 0 ? const _BusyBarrier() : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _BusyBarrier extends StatelessWidget {
  const _BusyBarrier();

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Positioned.fill(
      child: AbsorbPointer(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 350),
          curve: const Interval(0.4, 1),
          builder: (context, t, child) => Opacity(opacity: t, child: child),
          child: ColoredBox(
            color: Colors.black.withValues(alpha: 0.25),
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 16)],
                ),
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(strokeWidth: 3, color: palette.primary),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
