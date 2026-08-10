import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../home/home_shell.dart';

class _OnboardPage {
  const _OnboardPage({required this.icon, required this.title, required this.description});
  final IconData icon;
  final String title;
  final String description;
}

const _pages = [
  _OnboardPage(
    icon: Icons.restaurant_menu_rounded,
    title: 'Discover great food',
    description: 'Browse thousands of dishes from the best restaurants near you.',
  ),
  _OnboardPage(
    icon: Icons.delivery_dining_rounded,
    title: 'Fast, live delivery',
    description: 'Track your order in real time from the kitchen to your door.',
  ),
  _OnboardPage(
    icon: Icons.favorite_rounded,
    title: 'Made just for you',
    description: 'Save your favorites and get personalized recommendations.',
  ),
];

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  void _finish() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeShell()),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _pages.length - 1;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: TextButton(
                  onPressed: _finish,
                  child: const Text('Skip', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) {
                  final page = _pages[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 36),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 220,
                          height: 220,
                          decoration: const BoxDecoration(color: AppColors.primaryLight, shape: BoxShape.circle),
                          child: Icon(page.icon, size: 96, color: AppColors.primary),
                        ),
                        const SizedBox(height: 44),
                        Text(
                          page.title,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.displaySmall,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          page.description,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: i == _page ? 22 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == _page ? AppColors.primary : AppColors.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
              child: ElevatedButton(
                onPressed: isLast
                    ? _finish
                    : () => _controller.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut),
                child: Text(isLast ? 'Get Started' : 'Next'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
