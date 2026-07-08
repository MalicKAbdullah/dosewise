import 'package:flutter/material.dart';

/// How an imported backup is applied.
enum ImportMode { merge, replace }

/// Passphrase prompt used when opening a backup file.
Future<String?> promptBackupPassphrase(BuildContext context) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Backup passphrase'),
      content: TextField(
        controller: controller,
        autofocus: true,
        obscureText: true,
        textInputAction: TextInputAction.done,
        decoration: const InputDecoration(hintText: 'Passphrase for this file'),
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(controller.text),
          child: const Text('Open'),
        ),
      ],
    ),
  ).whenComplete(controller.dispose);
}

/// Shows what the backup contains and asks how to apply it.
Future<ImportMode?> showImportPreviewDialog(
  BuildContext context, {
  required int medicationCount,
  required int recordCount,
}) {
  return showDialog<ImportMode>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Restore backup'),
      content: Text(
        'This backup contains $medicationCount '
        '${medicationCount == 1 ? 'medication' : 'medications'} and '
        '$recordCount dose log '
        '${recordCount == 1 ? 'entry' : 'entries'}.\n\n'
        'Merge keeps what is on this device and adds the backup (the '
        'newer version of anything wins). Replace overwrites everything '
        'with the backup.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(ImportMode.replace),
          child: const Text('Replace'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(ImportMode.merge),
          child: const Text('Merge'),
        ),
      ],
    ),
  );
}
