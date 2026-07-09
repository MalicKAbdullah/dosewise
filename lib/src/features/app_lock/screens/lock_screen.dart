import 'package:core_theme/core_theme.dart';
import 'package:dose_wise/src/features/app_lock/providers/app_lock_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Full-screen cover shown while the app is locked.
///
/// The persisted app-lock flag is the single source of truth: whenever this
/// screen is on show the unlock button is present immediately and the
/// biometric/credential prompt auto-fires exactly once — driven by a single
/// post-frame callback and the controller's [LockController.autoPromptArmed]
/// latch, so it behaves identically on cold start, resume re-lock, and
/// inactivity re-lock. The button never waits on the async availability
/// probe (that only decides whether to show the "no biometrics" note), which
/// is why it can never flicker away.
final class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

final class _LockScreenState extends ConsumerState<LockScreen> {
  bool _failed = false;
  bool _busy = false;

  /// null while the availability probe is in flight; the button shows
  /// regardless. false means the device has no biometrics/credential set up,
  /// so we offer a graceful "enter anyway" path instead of a dead screen.
  bool? _canAuthenticate;

  @override
  void initState() {
    super.initState();
    // One post-frame callback keyed on entering the locked state (this
    // screen mounts fresh on every lock). The latch inside autoUnlock makes
    // it fire the prompt exactly once and never double.
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoPrompt());
    _probeAvailability();
  }

  Future<void> _probeAvailability() async {
    final can = await ref.read(lockControllerProvider).canAuthenticate();
    if (mounted) setState(() => _canAuthenticate = can);
  }

  Future<void> _autoPrompt() async {
    // Only a real, armed attempt should be able to flip us into the "failed"
    // state — a spent latch is not a failure.
    if (!ref.read(lockControllerProvider).autoPromptArmed) return;
    await _attempt(auto: true);
  }

  Future<void> _attempt({bool auto = false}) async {
    if (_busy) return;
    setState(() => _busy = true);
    final controller = ref.read(lockControllerProvider);
    final unlocked = auto ? await controller.autoUnlock() : await controller.unlock();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _failed = !unlocked;
    });
  }

  Future<void> _enterWithoutAuth() async {
    if (_busy) return;
    setState(() => _busy = true);
    await ref.read(lockControllerProvider).unlockWithoutAuth();
    // On success the gate removes this screen; if not, drop the busy flag.
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unavailable = _canAuthenticate == false;

    final message = unavailable
        ? 'No fingerprint, face, or screen lock is set up on this device. '
            'Your data stays encrypted — you can still enter DoseWise.'
        : _failed
            ? "Unlocking didn't finish. Try again when you're ready."
            : 'Locked to keep your health data private.';

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.primaryContainer
                        .withValues(alpha: 0.6),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Icon(
                    unavailable ? Icons.lock_outline : Icons.fingerprint,
                    size: 44,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('DoseWise', style: theme.textTheme.headlineSmall),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                if (unavailable)
                  FilledButton.icon(
                    onPressed: _busy ? null : _enterWithoutAuth,
                    icon: const Icon(Icons.lock_open_outlined),
                    label: const Text('Enter DoseWise'),
                  )
                else
                  FilledButton.icon(
                    onPressed: _busy ? null : () => _attempt(),
                    icon: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.fingerprint),
                    label: const Text('Unlock DoseWise'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
