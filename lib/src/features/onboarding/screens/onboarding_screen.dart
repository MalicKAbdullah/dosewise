import 'package:core_theme/core_theme.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dose_wise/src/core/providers/app_providers.dart';
import 'package:dose_wise/src/core/router/app_router.dart';
import 'package:dose_wise/src/features/onboarding/onboarding_flag.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final class _Page {
  const _Page({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;
}

const List<_Page> _pages = [
  _Page(
    icon: Icons.medication_liquid_outlined,
    title: 'Never miss a dose',
    body: 'Set up each medication once — DoseWise builds your daily '
        'schedule, tracks what you took, and shows your adherence at a '
        'glance.',
  ),
  _Page(
    icon: Icons.lock_outline,
    title: 'Private by design',
    body: 'Your health data stays on this device, encrypted. No account, '
        'no cloud, no tracking — and an encrypted backup file whenever '
        'you want one.',
  ),
  _Page(
    icon: Icons.notifications_active_outlined,
    title: 'Reminders that do the work',
    body: 'Dose reminders arrive right on time — and you can mark a dose '
        'taken or skipped straight from the notification.',
  ),
];

/// Three-page intro shown once on first launch. Skippable; both paths
/// persist the seen flag and land on Today.
final class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

final class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await OnboardingFlag.markSeen(ref.read(secureStorageProvider));
    if (!mounted) return;
    ref.read(onboardingCompleteProvider.notifier).state = true;
    context.go(AppRoutes.today);
  }

  void _next() {
    if (_page == _pages.length - 1) {
      _finish();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = SuiteColors.of(context);
    final isLast = _page == _pages.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: TextButton(
                  onPressed: _finish,
                  child: const Text('Skip'),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (index) => setState(() => _page = index),
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconBadge(
                          icon: page.icon,
                          size: 88,
                          color: c.accent,
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        Text(page.title, style: AppTextStyles.h1),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          page.body,
                          style: AppTextStyles.body.copyWith(
                            color: c.textSecondary,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _pages.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _page ? 20 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _page ? c.accent : c.border,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: VaultButton(
                label: isLast ? 'Get started' : 'Next',
                onPressed: _next,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
