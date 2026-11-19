import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';

/// Home's promotions carousel (2026-11-18 refresh — "more exciting"):
///  - a continuous loop: a centred hero card with its neighbours cut at
///    both screen edges; after the last card comes the first again,
///    sliding on in the same direction (either way when swiping);
///  - cover-flow: side cards tilt away in 3D, shrink, sink a little and
///    fade toward the page colour;
///  - the centre card glows in the brand colour, gently breathing, and a
///    shine sweeps across it each time it settles;
///  - cards spring up into place when Home first shows them;
///  - story-style dots: the active one fills over the auto-advance time, and
///    tapping a dot jumps to that card;
///  - auto-advance pauses while the User is swiping; a light haptic tick on
///    each swipe.
/// The phone's "reduce motion" setting turns the glow, shine and entrance off.
///
/// No `Opacity` anywhere: Impeller logs a validation error for Opacity over
/// these transformed cards, so fading is a veil in the page colour.
class PromoCarousel extends StatefulWidget {
  const PromoCarousel({
    super.key,
    required this.count,
    required this.itemBuilder,
  });

  final int count;

  /// Builds card [index], [height] tall (a 3:2 frame of the card's width).
  final Widget Function(BuildContext context, int index, double height)
  itemBuilder;

  @override
  State<PromoCarousel> createState() => _PromoCarouselState();
}

class _PromoCarouselState extends State<PromoCarousel>
    with TickerProviderStateMixin {
  // < 1 so the neighbours on both sides peek in, cut by the screen edges.
  static const _baseViewport = 0.8;

  /// Extra width of each neighbour that shows, on top of the base 10% of
  /// the screen less the 8px gap (2026-11-18: owner asked for 10px more).
  static const _extraPeek = 10.0;

  /// The page's share of the carousel's [width]: narrower by twice the
  /// extra peek, so each side card shows [_extraPeek] more.
  static double _viewportFor(double width) => width <= 0
      ? _baseViewport
      : (_baseViewport - 2 * _extraPeek / width).clamp(0.6, 0.95);
  static const _cardRadius = 22.0;
  static const _advanceEvery = Duration(seconds: 5);

  /// Continuous loop (2026-11-18): the list is [_loopPages] long and starts
  /// in its middle, so it can be swiped (or auto-advance) either way;
  /// page `p` shows card `p % count`. Kept short (2026-11-20): at 100000
  /// pages the list's length lost floating-point precision and tripped
  /// Flutter's fixed-extent layout check. Instead, once a scroll settles in
  /// the outer quarters, it jumps back to the same card in the middle
  /// ([_recenter]) — invisible, so the loop still never ends.
  static const _loopPages = 240;
  // Made for the carousel's width on first layout ([_controllerFor]).
  late PageController _controller = PageController(
    viewportFraction: _baseViewport,
    initialPage: _startPage,
  );

  /// The controller for [fraction] — remade (keeping the card in focus)
  /// only when the width changes, e.g. on rotation.
  PageController _controllerFor(double fraction) {
    if ((_controller.viewportFraction - fraction).abs() < 0.0001) {
      return _controller;
    }
    final previous = _controller;
    _controller = PageController(
      viewportFraction: fraction,
      initialPage: _page,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
    return _controller;
  }

  int get _startPage => widget.count <= 1
      ? 0
      : (_loopPages ~/ 2) - ((_loopPages ~/ 2) % widget.count);
  bool get _loops => widget.count > 1;
  late int _page = _startPage;
  late final _progress =
      AnimationController(vsync: this, duration: _advanceEvery)
        ..addStatusListener((s) {
          if (s == AnimationStatus.completed) _advance();
        });
  late final _shine = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );
  late final _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  int _index = 0;
  bool _dragging = false;
  bool _calm = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _calm = MediaQuery.disableAnimationsOf(context);
      if (_calm) {
        _entrance.value = 1;
      } else {
        _pulse.repeat(reverse: true);
        _entrance.forward().whenComplete(() {
          if (mounted) _shine.forward(from: 0);
        });
      }
      _restartProgress();
    });
  }

  @override
  void didUpdateWidget(PromoCarousel old) {
    super.didUpdateWidget(old);
    if (widget.count != old.count) {
      // A different number of cards: start the loop again at the first.
      final previous = _controller;
      _controller = PageController(
        viewportFraction: previous.viewportFraction,
        initialPage: _startPage,
      );
      _page = _startPage;
      _index = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _progress.dispose();
    _shine.dispose();
    _pulse.dispose();
    _entrance.dispose();
    super.dispose();
  }

  void _restartProgress() {
    if (widget.count <= 1 || _dragging) return;
    _progress.forward(from: 0);
  }

  void _advance() {
    if (!_controller.hasClients || widget.count <= 1 || _dragging) return;
    // Always forward — after the last card comes the first again, sliding
    // on in the same direction instead of rewinding.
    _controller.animateToPage(
      _page + 1,
      duration: const Duration(milliseconds: 750),
      curve: Curves.easeInOutCubic,
    );
  }

  /// Jumps to card [i] the short way round the loop.
  void _goToCard(int i) {
    final n = widget.count;
    var step = (i - _index) % n;
    if (step > n ~/ 2) step -= n;
    _controller.animateToPage(
      _page + step,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
    );
  }

  bool _recentering = false;

  /// Back to the same card near the middle of the list (see [_loopPages]).
  void _recenter() {
    if (!_loops || !_controller.hasClients || _dragging) return;
    if (_page >= _loopPages ~/ 4 && _page <= _loopPages * 3 ~/ 4) return;
    _recentering = true;
    _controller.jumpToPage(_startPage + _index);
    _recentering = false;
  }

  void _onPageChanged(int page) {
    final wasRecentering = _recentering;
    setState(() {
      _page = page;
      _index = page % widget.count;
    });
    // Same card, new position: no haptic, shine or progress restart.
    if (wasRecentering) return;
    if (_dragging) HapticFeedback.selectionClick();
    if (!_calm) _shine.forward(from: 0);
    _restartProgress();
  }

  bool _onScroll(ScrollNotification n) {
    if (n is ScrollStartNotification && n.dragDetails != null) {
      _dragging = true;
      _progress.stop();
    } else if (n is ScrollEndNotification && _dragging) {
      _dragging = false;
      _restartProgress();
    }
    if (n is ScrollEndNotification) WidgetsBinding.instance.addPostFrameCallback((_) => mounted ? _recenter() : null);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return LayoutBuilder(
      builder: (context, constraints) =>
          _build(context, palette, constraints.maxWidth),
    );
  }

  Widget _build(BuildContext context, AppPalette palette, double width) {
    // Exactly 3:2: the page is [_viewportFor] of the carousel's own width,
    // less the 8px gap on each side.
    final fraction = _viewportFor(width);
    _controllerFor(fraction);
    final cardWidth = width * fraction - 16;
    final cardHeight = cardWidth * 2 / 3;
    return Column(
      children: [
        SizedBox(
          // Room above and below for the glow and the springing entrance.
          height: cardHeight + 24,
          child: NotificationListener<ScrollNotification>(
            onNotification: _onScroll,
            child: PageView.builder(
              controller: _controller,
              // The hero card sits centred, its neighbours cut at both edges.
              padEnds: true,
              clipBehavior: Clip.none,
              itemCount: _loops ? _loopPages : widget.count,
              onPageChanged: _onPageChanged,
              itemBuilder: (context, page) => Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 12,
                ),
                child: AnimatedBuilder(
                  animation: Listenable.merge([
                    _controller,
                    _shine,
                    _pulse,
                    _entrance,
                  ]),
                  child: widget.itemBuilder(
                    context,
                    page % widget.count,
                    cardHeight,
                  ),
                  builder: (context, card) =>
                      _transformed(context, page, card!, palette),
                ),
              ),
            ),
          ),
        ),
        if (widget.count > 1) ...[
          const SizedBox(height: 2),
          AnimatedBuilder(
            animation: _progress,
            builder: (context, _) => Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < widget.count; i++)
                  GestureDetector(
                    key: Key('promoDot_$i'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _goToCard(i),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 3,
                        vertical: 6,
                      ),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutBack,
                        width: _index == i ? 26 : 7,
                        height: 7,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: _index == i
                              ? palette.primary.withValues(alpha: 0.25)
                              : palette.border,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        alignment: Alignment.centerLeft,
                        child: _index == i
                            ? FractionallySizedBox(
                                widthFactor: _calm
                                    ? 1
                                    : _progress.value.clamp(0.0, 1.0),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: palette.primary,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// The page in focus, fractional while sliding.
  double _focusPage() =>
      _controller.hasClients && _controller.position.haveDimensions
      ? _controller.page!
      : _page.toDouble();

  Widget _transformed(
    BuildContext context,
    int i,
    Widget card,
    AppPalette palette,
  ) {
    final page = _focusPage();
    // > 0: the card is left of centre; < 0: right of it.
    final delta = (page - i).clamp(-1.0, 1.0);
    final dist = delta.abs();
    final focus = 1 - dist;

    // Springing entrance, staggered left to right.
    // Left neighbour first, then the hero, then the right one.
    final start = ((i - _startPage + 1).clamp(0, 3)) * 0.12;
    final t = Curves.easeOutBack.transform(
      ((_entrance.value - start) / (1 - start)).clamp(0.0, 1.0),
    );

    final matrix = Matrix4.identity()
      ..setEntry(3, 2, 0.0012)
      ..translateByDouble(0, 10 * dist + (1 - t) * 60, 0, 1)
      ..rotateY(delta * 0.35)
      ..scaleByDouble(
        1 - 0.1 * dist - (1 - t) * 0.08,
        1 - 0.1 * dist - (1 - t) * 0.08,
        1,
        1,
      );

    final glow = _calm ? 0.0 : focus * (0.55 + 0.45 * _pulse.value);
    return Transform(
      alignment: Alignment.center,
      transform: matrix,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_cardRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10 + 0.08 * focus),
              blurRadius: 10 + 8 * focus,
              offset: Offset(0, 4 + 4 * focus),
            ),
            if (glow > 0)
              BoxShadow(
                color: palette.primary.withValues(alpha: 0.35 * glow),
                blurRadius: 14 + 12 * glow,
                spreadRadius: 1 + 2 * glow,
              ),
          ],
        ),
        child: DecoratedBox(
          // Side cards fade toward the page colour (see the class comment on Opacity).
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            color: palette.background.withValues(alpha: 0.4 * dist),
            borderRadius: BorderRadius.circular(_cardRadius),
          ),
          child: CustomPaint(
            foregroundPainter: _calm || dist > 0.02
                ? null
                : _ShinePainter(_shine.value, _cardRadius),
            child: card,
          ),
        ),
      ),
    );
  }
}

/// A soft diagonal streak of light crossing the card once as [progress]
/// goes 0 → 1.
class _ShinePainter extends CustomPainter {
  _ShinePainter(this.progress, this.radius);

  final double progress;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final rect = Offset.zero & size;
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    final p = Curves.easeInOut.transform(progress);
    final cx = -size.width * 0.4 + p * size.width * 1.8;
    final center = Offset(cx, size.height / 2);
    // Across the band, perpendicular to a ~30° streak.
    const angle = math.pi / 6;
    final dir = Offset(math.cos(angle), math.sin(angle));
    final half = size.width * 0.16;
    final paint = Paint()
      ..shader = ui.Gradient.linear(
        center - dir * half,
        center + dir * half,
        [
          Colors.white.withValues(alpha: 0),
          Colors.white.withValues(alpha: 0.38),
          Colors.white.withValues(alpha: 0),
        ],
        [0, 0.5, 1],
      )
      ..blendMode = BlendMode.plus;
    canvas.drawRect(rect, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ShinePainter old) => old.progress != progress;
}
