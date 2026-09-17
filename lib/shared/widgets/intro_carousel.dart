import 'dart:async';

import 'package:flutter/material.dart';

import 'glossy_surface.dart';

class _IntroSlide {
  const _IntroSlide({required this.title, required this.description});

  final String title;
  final String description;
}

const _slides = [
  _IntroSlide(
    title: 'Order from local vendors',
    description:
        'Food, pharmacy, grocery, and fresh produce from shops in your own neighbourhood.',
  ),
  _IntroSlide(
    title: 'No aggregator tax',
    description:
        'A flat, transparent delivery fee — more of every order stays with the vendor.',
  ),
  _IntroSlide(
    title: 'Support your neighbourhood',
    description:
        'Every order helps a local business and a local delivery partner.',
  ),
];

/// What used to be three separate Onboarding pages, now three
/// auto-advancing slides embedded directly in the sign-in screen
/// (`auth_login_screen.dart`) — the app explains itself while you sign in
/// rather than making that a mandatory step beforehand. Text-only glossy
/// green cards (`GlossyGreenSurface` — no icon/logo; the standalone
/// `BrandedLogo` above the "Sign in to continue" heading already carries
/// the branding), floating on top of the screen's own green background.
class IntroCarousel extends StatefulWidget {
  const IntroCarousel({super.key});

  @override
  State<IntroCarousel> createState() => _IntroCarouselState();
}

class _IntroCarouselState extends State<IntroCarousel> {
  final _controller = PageController();
  Timer? _timer;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_controller.hasClients) return;
      _controller.animateToPage(
        (_page + 1) % _slides.length,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Expanded(
          child: PageView.builder(
            controller: _controller,
            itemCount: _slides.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, i) {
              final slide = _slides[i];
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: GlossySurface(
                  borderRadius: 22,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          slide.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          slide.description,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.88),
                            fontSize: 12.5,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            _slides.length,
            (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == _page ? 20 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: i == _page ? 0.95 : 0.4),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
