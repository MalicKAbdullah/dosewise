import 'package:core_backup/core_backup.dart';
import 'package:core_lock/core_lock.dart';
import 'package:core_theme/core_theme.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dose_wise/src/core/app_info.dart';
import 'package:dose_wise/src/core/data/app_data.dart';
import 'package:dose_wise/src/core/providers/app_data_provider.dart';
import 'package:dose_wise/src/core/providers/app_providers.dart';
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    // Narrowed to settings only: medication/record/dose mutations elsewhere
    // no longer rebuild this screen (settings keeps its identity across
    // unrelated copyWith calls).
    final settings =
        ref.watch(appDataProvider.select((d) => d.valueOrNull?.settings)) ??
            const AppSettings();
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
          const SizedBox(height: AppSpacing.sm),
          Text('Automatic backup', style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          VaultCard(
            padding: EdgeInsets.zero,
            child: AutoBackupSection(
              service: ref.watch(autoBackupServiceProvider),
              producer: ref.watch(doseBackupProducerProvider),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Security', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          AppLockSettings(controller: ref.watch(lockControllerProvider)),
          const SizedBox(height: AppSpacing.lg),
          Text('Updates', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          const _UpdateCheckTile(),
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
                  'The only network use is the optional update check.',
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

/// "Check for updates on open" toggle + a manual "Check now", backed by
/// core_update. On by default; the only network call the app makes.
class _UpdateCheckTile extends ConsumerStatefulWidget {
  const _UpdateCheckTile();

  @override
  ConsumerState<_UpdateCheckTile> createState() => _UpdateCheckTileState();
}

class _UpdateCheckTileState extends ConsumerState<_UpdateCheckTile> {
  bool _checking = false;

  Future<void> _checkNow() async {
    setState(() => _checking = true);
    final info = await ref.read(updateServiceProvider).check();
    if (!mounted) return;
    setState(() => _checking = false);
    final messenger = ScaffoldMessenger.of(context);
    if (info == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text("You're on the latest version.")),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Update available · v${info.version}'),
          action: SnackBarAction(
            label: 'Update',
            onPressed: () => ref.read(updateServiceProvider).openDownload(info),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final autoCheck = ref.watch(updateAutoCheckProvider).valueOrNull ?? true;
    return VaultCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.system_update_alt),
            title: const Text('Check for updates on open'),
            subtitle: const Text(
              'Looks for a new release on GitHub. Nothing is uploaded.',
            ),
            value: autoCheck,
            onChanged: (v) async {
              await ref.read(secureStorageProvider).write(
                    key: updateAutoCheckKey,
                    value: v ? 'true' : 'false',
                  );
              ref.invalidate(updateAutoCheckProvider);
              ref.invalidate(updateCheckProvider);
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.refresh),
            title: const Text('Check now'),
            trailing: _checking
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.chevron_right),
            onTap: _checking ? null : _checkNow,
          ),
        ],
      ),
    );
  }
}
