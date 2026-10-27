import 'package:core_theme/core_theme.dart';
import 'package:dose_wise/src/core/data/app_data.dart';
import 'package:dose_wise/src/core/providers/app_data_provider.dart';
import 'package:dose_wise/src/features/medications/models/medication_colors.dart';
import 'package:dose_wise/src/features/profiles/models/profile.dart';
import 'package:dose_wise/src/features/profiles/providers/profile_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Compact avatar chip for the Today app bar: shows the active profile
/// and opens the switcher sheet.
final class ProfileChip extends ConsumerWidget {
  const ProfileChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(activeProfileProvider);
    return Center(
      child: Tooltip(
        message: 'Switch profile',
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => showProfileSwitcherSheet(context),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: ProfileAvatar(profile: profile, radius: 16),
          ),
        ),
      ),
    );
  }
}

/// Colored circle with the profile's initial.
final class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({required this.profile, this.radius = 18, super.key});

  final Profile profile;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: Color(profile.colorValue),
      child: Text(
        profile.initial,
        style: TextStyle(
          color: MedicationColors.inkOn(profile.colorValue),
          fontWeight: FontWeight.w700,
          fontSize: radius * 0.9,
        ),
      ),
    );
  }
}

/// Bottom sheet: switch between profiles, add, rename, or delete one.
Future<void> showProfileSwitcherSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => const _ProfileSwitcherSheet(),
  );
}

final class _ProfileSwitcherSheet extends ConsumerWidget {
  const _ProfileSwitcherSheet();

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final name = await _promptName(context, title: 'Add profile');
    if (name == null || name.trim().isEmpty) return;
    await ref.read(appDataProvider.notifier).addProfile(name);
    if (context.mounted) Navigator.of(context).pop();
  }

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    Profile profile,
  ) async {
    final name = await _promptName(
      context,
      title: 'Rename profile',
      initial: profile.name,
    );
    if (name == null || name.trim().isEmpty) return;
    await ref.read(appDataProvider.notifier).renameProfile(profile.id, name);
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    Profile profile,
  ) async {
    final data = ref.read(appDataProvider).valueOrNull ?? const AppData();
    final medicationCount = data.medicationsFor(profile.id).length;
    final recordCount = data.recordsFor(profile.id).length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _TypedDeleteDialog(
        profile: profile,
        medicationCount: medicationCount,
        recordCount: recordCount,
      ),
    );
    if (confirmed != true) return;
    await ref.read(appDataProvider.notifier).deleteProfile(profile.id);
  }

  Future<String?> _promptName(
    BuildContext context, {
    required String title,
    String initial = '',
  }) {
    return showDialog<String>(
      context: context,
      builder: (context) => _NamePromptDialog(title: title, initial: initial),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = ref.watch(profilesProvider);
    final active = ref.watch(activeProfileProvider);

    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Text(
              'Profiles',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final profile in profiles)
            ListTile(
              leading: ProfileAvatar(profile: profile),
              title: Text(profile.name),
              subtitle: profile.id == active.id ? const Text('Active') : null,
              onTap: () async {
                await ref
                    .read(appDataProvider.notifier)
                    .switchProfile(profile.id);
                if (context.mounted) Navigator.of(context).pop();
              },
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (profile.id == active.id)
                    Icon(
                      Icons.check_circle,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  PopupMenuButton<String>(
                    tooltip: 'Profile options for ${profile.name}',
                    onSelected: (choice) => switch (choice) {
                      'rename' => _rename(context, ref, profile),
                      _ => _delete(context, ref, profile),
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'rename',
                        child: Text('Rename'),
                      ),
                      if (profiles.length > 1)
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete…'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.add)),
            title: const Text('Add profile'),
            onTap: () => _add(context, ref),
          ),
        ],
      ),
    );
  }
}

/// Name entry dialog for add/rename (owns its controller so disposal
/// happens after the route animation finishes).
final class _NamePromptDialog extends StatefulWidget {
  const _NamePromptDialog({required this.title, required this.initial});

  final String title;
  final String initial;

  @override
  State<_NamePromptDialog> createState() => _NamePromptDialogState();
}

final class _NamePromptDialogState extends State<_NamePromptDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(hintText: 'Name'),
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// Delete confirmation that requires typing the profile name, because it
/// cascades to everything that profile owns.
final class _TypedDeleteDialog extends StatefulWidget {
  const _TypedDeleteDialog({
    required this.profile,
    required this.medicationCount,
    required this.recordCount,
  });

  final Profile profile;
  final int medicationCount;
  final int recordCount;

  @override
  State<_TypedDeleteDialog> createState() => _TypedDeleteDialogState();
}

final class _TypedDeleteDialogState extends State<_TypedDeleteDialog> {
  final _controller = TextEditingController();
  bool _matches = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    return AlertDialog(
      title: Text('Delete ${profile.name}?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This permanently deletes ${profile.name}\'s '
            '${widget.medicationCount} medication'
            '${widget.medicationCount == 1 ? '' : 's'} and '
            '${widget.recordCount} dose log '
            '${widget.recordCount == 1 ? 'entry' : 'entries'}. '
            'It cannot be undone.\n\n'
            'Type the profile name to confirm.',
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: InputDecoration(hintText: profile.name),
            onChanged: (value) =>
                setState(() => _matches = value.trim() == profile.name),
          ),
        ],
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
          onPressed: _matches ? () => Navigator.of(context).pop(true) : null,
          child: const Text('Delete profile'),
        ),
      ],
    );
  }
}
