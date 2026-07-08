import 'package:core_theme/core_theme.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dose_wise/src/core/app_info.dart';
import 'package:dose_wise/src/core/data/app_data.dart';
import 'package:dose_wise/src/core/providers/app_data_provider.dart';
import 'package:dose_wise/src/core/router/app_router.dart';
import 'package:dose_wise/src/features/app_lock/providers/app_lock_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _confirmErase(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Erase all data?'),
        content: const Text(
          'This permanently deletes all medications, dose history, and '
          'settings from this device. It cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Erase everything'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(appDataProvider.notifier).eraseAll();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All data erased.')),
      );
    }
  }

  Future<void> _setAppLock(
    BuildContext context,
    WidgetRef ref,
    bool enabled,
  ) async {
    final applied = await ref.read(lockControllerProvider).setEnabled(enabled);
    if (!applied && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Authentication is required to turn on app lock.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings =
        ref.watch(appDataProvider).valueOrNull?.settings ?? const AppSettings();
    final lockEnabled =
        ref.watch(lockControllerProvider.select((c) => c.isEnabled));
    final authAvailable =
        ref.watch(deviceAuthAvailableProvider).valueOrNull ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          VaultCard(
            padding: EdgeInsets.zero,
            child: SwitchListTile(
              title: const Text('Dose reminders'),
              subtitle: const Text(
                'Notify you when scheduled doses are due. You can also turn '
                'reminders off per medication.',
              ),
              value: settings.remindersEnabled,
              onChanged: (enabled) => ref
                  .read(appDataProvider.notifier)
                  .setRemindersEnabled(enabled),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Backup', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          VaultCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.shield_outlined),
              title: const Text('Encrypted backup'),
              subtitle: const Text(
                'Export or restore a passphrase-protected backup file.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(AppRoutes.backup),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Security', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          VaultCard(
            padding: EdgeInsets.zero,
            child: SwitchListTile(
              title: const Text('App lock'),
              subtitle: Text(
                authAvailable
                    ? 'Require fingerprint or face unlock to open DoseWise.'
                    : 'Not available — set up a screen lock or biometrics '
                        'on this device first.',
              ),
              value: lockEnabled,
              onChanged: authAvailable
                  ? (enabled) => _setAppLock(context, ref, enabled)
                  : null,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('About', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          VaultCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer
                            .withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(AppSpacing.sm),
                      ),
                      child: Icon(
                        Icons.medication_outlined,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text('DoseWise', style: theme.textTheme.titleMedium),
                    const Spacer(),
                    Text(
                      'v${AppInfo.version}',
                      style: AppTextStyles.numberSmall.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Your health data stays on this device and is encrypted. '
                  'DoseWise never connects to the internet.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Danger zone', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          VaultButton(
            label: 'Erase all data',
            variant: VaultButtonVariant.destructive,
            onPressed: () => _confirmErase(context, ref),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}
