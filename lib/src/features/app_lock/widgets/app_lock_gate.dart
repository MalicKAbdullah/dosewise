import 'package:dose_wise/src/features/app_lock/providers/app_lock_providers.dart';
import 'package:dose_wise/src/features/app_lock/screens/lock_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Sits above the router (via MaterialApp.builder) and covers the whole app
/// with [LockScreen] while locked. The navigator stays mounted underneath so
/// unlocking restores exactly where the user was. Also forwards lifecycle
/// changes to the controller for the background re-lock timer.
final class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

final class _AppLockGateState extends ConsumerState<AppLockGate>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    ref.read(lockControllerProvider).onLifecycleChanged(state);
  }

  @override
  Widget build(BuildContext context) {
    final locked = ref.watch(lockControllerProvider.select((c) => c.isLocked));
    return Stack(
      children: [
        // Offstage (not removed): navigation state survives the lock, and
        // nothing private is painted underneath while locked.
        Offstage(offstage: locked, child: widget.child),
        if (locked) const LockScreen(),
      ],
    );
  }
}
