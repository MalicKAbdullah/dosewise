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
    // Narrowed to settings only: medication/record/dose mutations elsewhere
    // no longer rebuild this screen (settings keeps its identity across
    // unrelated copyWith calls).
    final settings =
        ref.watch(appDataProvider.select((d) => d.valueOrNull?.settings)) ??
            const AppSettings();
    final c = SuiteColors.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.xl,
        ),
        children: [
          RowGroup(
            children: [
              SettingsTile(
                icon: Icons.notifications_none_rounded,
                title: 'Dose reminders',
                subtitle: 'Notify me when a dose is due',
                showChevron: false,
                trailing: Switch(
                  value: settings.remindersEnabled,
                  onChanged: (enabled) => ref
                      .read(appDataProvider.notifier)
                      .setRemindersEnabled(enabled),
                ),
                onTap: () => ref
                    .read(appDataProvider.notifier)
                    .setRemindersEnabled(!settings.remindersEnabled),
              ),
            ],
          ),
          const _Gap(),
          const SectionHeader(title: 'Backup'),
          RowGroup(
            children: [
              SettingsTile(
                icon: Icons.shield_outlined,
                title: 'Encrypted backup',
                subtitle: 'Export or restore a protected file',
                onTap: () => context.push(AppRoutes.backup),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.smd),
          VaultCard(
            padding: EdgeInsets.zero,
            child: AutoBackupSection(
              service: ref.watch(autoBackupServiceProvider),
              producer: ref.watch(doseBackupProducerProvider),
              onRevealGate: () => confirmAppLockIdentity(
                context,
                ref.read(lockControllerProvider),
                reason: 'Show your backup passphrase',
              ),
            ),
          ),
          const _Gap(),
          const SectionHeader(title: 'Security'),
          AppLockSettings(controller: ref.watch(lockControllerProvider)),
          const _Gap(),
          const SectionHeader(title: 'Updates'),
          const _UpdateCheckTile(),
          const _Gap(),
          const SectionHeader(title: 'About'),
          VaultCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const SuiteAppIcon(app: SuiteApp.dosewise, size: 44),
                    const SizedBox(width: AppSpacing.smd),
                    const Expanded(
                      child: Text('DoseWise', style: AppTextStyles.h3),
                    ),
                    Text(
                      'v${ref.watch(appVersionProvider).valueOrNull ?? ''}',
                      style: AppTextStyles.numberSmall.copyWith(
                        color: c.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Your health data stays on this device and is encrypted. '
                  'The only network use is the optional update check.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: c.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                const SuiteEndorsement(),
              ],
            ),
          ),
          const _Gap(),
          const SectionHeader(title: 'Danger zone'),
          VaultButton(
            label: 'Erase all data',
            variant: VaultButtonVariant.destructive,
            onPressed: () => _confirmErase(context, ref),
          ),
        ],
      ),
    );
  }
}

/// Space before a section header: 24 px in all.
final class _Gap extends StatelessWidget {
  const _Gap();

  @override
  Widget build(BuildContext context) => const SizedBox(height: AppSpacing.md);
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
    return RowGroup(
      children: [
        SettingsTile(
          icon: Icons.system_update_alt,
          title: 'Check for updates on open',
          subtitle: 'Looks for a new release on GitHub',
          showChevron: false,
          trailing: Switch(
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
        ),
        SettingsTile(
          icon: Icons.refresh,
          title: 'Check now',
          trailing: _checking
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : null,
          onTap: _checking ? null : _checkNow,
        ),
      ],
    );
  }
}
