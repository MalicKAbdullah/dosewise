import 'package:dose_wise/src/features/app_lock/controllers/lock_controller.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fakes.dart';

void main() {
  var now = DateTime(2026, 7, 7, 9, 0);

  LockController controller({
    required FakeDeviceAuth auth,
    InMemorySecureStorage? storage,
    bool enabled = false,
  }) =>
      LockController(
        deviceAuth: auth,
        storage: storage ?? InMemorySecureStorage(),
        clock: () => now,
        enabled: enabled,
      );

  setUp(() => now = DateTime(2026, 7, 7, 9, 0));

  group('cold start', () {
    test('disabled -> starts unlocked', () {
      final c = controller(auth: FakeDeviceAuth());
      expect(c.isEnabled, isFalse);
      expect(c.isLocked, isFalse);
    });

    test('enabled -> starts locked', () {
      final c = controller(auth: FakeDeviceAuth(), enabled: true);
      expect(c.isEnabled, isTrue);
      expect(c.isLocked, isTrue);
    });

    test('readEnabled round-trips the persisted flag', () async {
      final storage = InMemorySecureStorage();
      expect(await LockController.readEnabled(storage), isFalse);

      final c = controller(auth: FakeDeviceAuth(), storage: storage);
      await c.setEnabled(true);
      expect(await LockController.readEnabled(storage), isTrue);

      await c.setEnabled(false);
      expect(await LockController.readEnabled(storage), isFalse);
    });
  });

  group('setEnabled', () {
    test('enabling requires one successful authentication', () async {
      final auth = FakeDeviceAuth();
      final storage = InMemorySecureStorage();
      final c = controller(auth: auth, storage: storage);

      expect(await c.setEnabled(true), isTrue);
      expect(auth.authCalls, 1);
      expect(c.isEnabled, isTrue);
      expect(c.isLocked, isFalse, reason: 'already in the app, stays open');
      expect(storage.values[LockController.storageKey], 'true');
    });

    test('failed authentication leaves the lock off and persists nothing',
        () async {
      final auth = FakeDeviceAuth(authResult: false);
      final storage = InMemorySecureStorage();
      final c = controller(auth: auth, storage: storage);

      expect(await c.setEnabled(true), isFalse);
      expect(c.isEnabled, isFalse);
      expect(storage.values, isEmpty);
    });

    test('cannot enable when the device has no auth method', () async {
      final auth = FakeDeviceAuth(available: false);
      final c = controller(auth: auth);

      expect(await c.setEnabled(true), isFalse);
      expect(auth.authCalls, 0, reason: 'no prompt when unavailable');
      expect(c.isEnabled, isFalse);
    });

    test('disabling clears the flag and unlocks without a prompt', () async {
      final auth = FakeDeviceAuth();
      final storage = InMemorySecureStorage();
      final c = controller(auth: auth, storage: storage, enabled: true);

      expect(await c.setEnabled(false), isTrue);
      expect(auth.authCalls, 0);
      expect(c.isEnabled, isFalse);
      expect(c.isLocked, isFalse);
      expect(storage.values, isEmpty);
    });
  });

  group('auto-prompt latch', () {
    test('enabled cold start arms the auto-prompt', () {
      final c = controller(auth: FakeDeviceAuth(), enabled: true);
      expect(c.autoPromptArmed, isTrue);
    });

    test('disabled cold start does not arm the auto-prompt', () {
      final c = controller(auth: FakeDeviceAuth());
      expect(c.autoPromptArmed, isFalse);
    });

    test('autoUnlock fires the prompt once, then the latch is spent',
        () async {
      final auth = FakeDeviceAuth();
      final c = controller(auth: auth, enabled: true);

      expect(await c.autoUnlock(), isTrue);
      expect(auth.authCalls, 1);
      expect(c.isLocked, isFalse);
      expect(c.autoPromptArmed, isFalse);

      // A second call (e.g. a spurious rebuild) is a no-op — no double prompt.
      expect(await c.autoUnlock(), isFalse);
      expect(auth.authCalls, 1);
    });

    test('autoUnlock does nothing when not armed', () async {
      final auth = FakeDeviceAuth();
      final c = controller(auth: auth); // disabled -> unarmed
      expect(await c.autoUnlock(), isFalse);
      expect(auth.authCalls, 0);
    });

    test('a failed auto-prompt still spends the latch; manual unlock retries',
        () async {
      final auth = FakeDeviceAuth(authResult: false);
      final c = controller(auth: auth, enabled: true);

      expect(await c.autoUnlock(), isFalse);
      expect(c.isLocked, isTrue);
      expect(c.autoPromptArmed, isFalse, reason: 'attempt spends the latch');

      auth.authResult = true;
      expect(await c.unlock(), isTrue, reason: 'button retry still works');
      expect(c.isLocked, isFalse);
    });

    test('a background re-lock re-arms the auto-prompt every time', () async {
      final auth = FakeDeviceAuth();
      final c = controller(auth: auth, enabled: true);
      await c.autoUnlock();
      expect(c.autoPromptArmed, isFalse);

      c.onLifecycleChanged(AppLifecycleState.paused);
      now = now.add(const Duration(seconds: 31));
      c.onLifecycleChanged(AppLifecycleState.resumed);

      expect(c.isLocked, isTrue);
      expect(c.autoPromptArmed, isTrue, reason: 're-armed on re-lock');
      expect(await c.autoUnlock(), isTrue);
      expect(auth.authCalls, 2);
    });

    test('disabling the lock clears the arm flag', () async {
      final c = controller(auth: FakeDeviceAuth(), enabled: true);
      expect(c.autoPromptArmed, isTrue);
      await c.setEnabled(false);
      expect(c.autoPromptArmed, isFalse);
    });
  });

  group('unlockWithoutAuth (no lock-out escape hatch)', () {
    test('unlocks without a prompt when the device cannot authenticate',
        () async {
      final auth = FakeDeviceAuth(available: false);
      final c = controller(auth: auth, enabled: true);

      expect(await c.unlockWithoutAuth(), isTrue);
      expect(auth.authCalls, 0, reason: 'no prompt on the escape hatch');
      expect(c.isLocked, isFalse);
      expect(c.autoPromptArmed, isFalse);
    });

    test('refuses to unlock when authentication IS available', () async {
      final auth = FakeDeviceAuth();
      final c = controller(auth: auth, enabled: true);

      expect(await c.unlockWithoutAuth(), isFalse);
      expect(c.isLocked, isTrue, reason: 'must use a real prompt instead');
      expect(auth.authCalls, 0);
    });
  });

  group('unlock', () {
    test('successful authentication unlocks', () async {
      final auth = FakeDeviceAuth();
      final c = controller(auth: auth, enabled: true);

      expect(await c.unlock(), isTrue);
      expect(auth.reasons, ['Unlock DoseWise']);
      expect(c.isLocked, isFalse);
    });

    test('failed authentication stays locked and can retry', () async {
      final auth = FakeDeviceAuth(authResult: false);
      final c = controller(auth: auth, enabled: true);

      expect(await c.unlock(), isFalse);
      expect(c.isLocked, isTrue);

      auth.authResult = true;
      expect(await c.unlock(), isTrue);
      expect(c.isLocked, isFalse);
    });

    test('unlock when already unlocked is a no-op success', () async {
      final auth = FakeDeviceAuth();
      final c = controller(auth: auth);

      expect(await c.unlock(), isTrue);
      expect(auth.authCalls, 0);
    });
  });

  group('background re-lock', () {
    Future<LockController> unlockedEnabled(FakeDeviceAuth auth) async {
      final c = controller(auth: auth, enabled: true);
      await c.unlock();
      expect(c.isLocked, isFalse);
      return c;
    }

    test('re-locks after more than 30 seconds in the background', () async {
      final c = await unlockedEnabled(FakeDeviceAuth());

      c.onLifecycleChanged(AppLifecycleState.paused);
      now = now.add(const Duration(seconds: 31));
      c.onLifecycleChanged(AppLifecycleState.resumed);

      expect(c.isLocked, isTrue);
    });

    test('stays unlocked within the 30 second grace period', () async {
      final c = await unlockedEnabled(FakeDeviceAuth());

      c.onLifecycleChanged(AppLifecycleState.paused);
      now = now.add(const Duration(seconds: 30));
      c.onLifecycleChanged(AppLifecycleState.resumed);

      expect(c.isLocked, isFalse);
    });

    test('grace period counts from the first backgrounded state', () async {
      final c = await unlockedEnabled(FakeDeviceAuth());

      c.onLifecycleChanged(AppLifecycleState.paused);
      now = now.add(const Duration(seconds: 20));
      c.onLifecycleChanged(AppLifecycleState.hidden);
      now = now.add(const Duration(seconds: 20));
      c.onLifecycleChanged(AppLifecycleState.resumed);

      expect(c.isLocked, isTrue, reason: '40s total in the background');
    });

    test('inactive alone (transient overlay) never locks', () async {
      final c = await unlockedEnabled(FakeDeviceAuth());

      c.onLifecycleChanged(AppLifecycleState.inactive);
      now = now.add(const Duration(minutes: 5));
      c.onLifecycleChanged(AppLifecycleState.resumed);

      expect(c.isLocked, isFalse);
    });

    test('disabled -> never re-locks however long backgrounded', () {
      final c = controller(auth: FakeDeviceAuth());

      c.onLifecycleChanged(AppLifecycleState.paused);
      now = now.add(const Duration(hours: 2));
      c.onLifecycleChanged(AppLifecycleState.resumed);

      expect(c.isLocked, isFalse);
    });

    test('time spent inside the auth prompt does not count as background',
        () async {
      final auth = FakeDeviceAuth();
      final c = controller(auth: auth, enabled: true);

      // The OS prompt backgrounds the app while authenticating; simulate a
      // slow prompt by advancing the clock inside the auth call.
      auth.authResult = true;
      final unlocking = c.unlock();
      c.onLifecycleChanged(AppLifecycleState.paused);
      now = now.add(const Duration(minutes: 1));
      expect(await unlocking, isTrue);
      c.onLifecycleChanged(AppLifecycleState.resumed);

      expect(c.isLocked, isFalse);
    });
  });
}
