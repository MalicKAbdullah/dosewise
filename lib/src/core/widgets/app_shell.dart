import 'dart:async';

import 'package:dose_wise/src/core/providers/app_data_provider.dart';
import 'package:dose_wise/src/core/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Bottom-navigation scaffold hosting the four tab branches.
final class AppShell extends ConsumerStatefulWidget {
  const AppShell({required this.shell, super.key});

  final StatefulNavigationShell shell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  @override
  void initState() {
    super.initState();
    // Run a scheduled backup once per open, when due (F-4).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        ref
            .read(autoBackupServiceProvider)
            .runIfDue(ref.read(doseBackupProducerProvider)),
      );
      unawaited(_checkRefills());
    });
  }

  static const String _refillAlertedKey = 'dose_wise_refill_alerted';

  /// Once per open: notify when a supply-tracked medication has newly dropped
  /// to its low-stock threshold. Meds that were restocked drop out of the
  /// remembered set, so they can alert again next time they run low.
  Future<void> _checkRefills() async {
    final data = await ref.read(appDataProvider.future);
    final storage = ref.read(secureStorageProvider);
    final reminders = ref.read(reminderServiceProvider);

    final low = data.medications.where((m) => m.isLowStock).toList();
    final lowIds = low.map((m) => m.id).toSet();
    final alerted = (await storage.read(key: _refillAlertedKey) ?? '')
        .split(',')
        .where((s) => s.isNotEmpty)
        .toSet();
    final newlyLow = low.where((m) => !alerted.contains(m.id)).toList();

    if (newlyLow.isNotEmpty) {
      final title = newlyLow.length == 1
          ? '${newlyLow.first.name} is running low'
          : '${newlyLow.length} medications running low';
      final body = newlyLow.length == 1
          ? '${newlyLow.first.currentStock} left — time to refill.'
          : '${newlyLow.map((m) => m.name).join(', ')} — time to refill.';
      await reminders.showRefillAlert(title: title, body: body);
    }
    // Persist the current low set (restocked meds fall out).
    await storage.write(key: _refillAlertedKey, value: lowIds.join(','));
  }

  @override
  Widget build(BuildContext context) {
    final shell = widget.shell;
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (index) => shell.goBranch(
          index,
          initialLocation: index == shell.currentIndex,
        ),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.today_outlined),
            selectedIcon: Icon(Icons.today),
            label: 'Today',
          ),
          NavigationDestination(
            icon: Icon(Icons.medication_outlined),
            selectedIcon: Icon(Icons.medication),
            label: 'Medications',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Stats',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
