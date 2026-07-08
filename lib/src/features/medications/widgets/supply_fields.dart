import 'package:core_theme/core_theme.dart';
import 'package:dose_wise/src/features/medications/widgets/form_fields.dart';
import 'package:flutter/material.dart';

/// Supply-tracking and per-medication reminder controls for the
/// medication form. The parent form owns the state.
final class SupplyAndReminderFields extends StatelessWidget {
  const SupplyAndReminderFields({
    required this.trackSupply,
    required this.onTrackSupplyChanged,
    required this.stockController,
    required this.thresholdController,
    required this.remindersEnabled,
    required this.onRemindersChanged,
    super.key,
  });

  final bool trackSupply;
  final ValueChanged<bool> onTrackSupplyChanged;
  final TextEditingController stockController;
  final TextEditingController thresholdController;
  final bool remindersEnabled;
  final ValueChanged<bool> onRemindersChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Track supply'),
          subtitle: const Text(
            'Count down doses on hand and warn before you run out',
          ),
          value: trackSupply,
          onChanged: onTrackSupplyChanged,
        ),
        if (trackSupply) ...[
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: LabeledField(
                  label: 'Doses on hand',
                  child: TextFormField(
                    controller: stockController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(hintText: 'e.g. 30'),
                    validator: (value) =>
                        int.tryParse(value?.trim() ?? '') == null
                            ? 'Enter a number'
                            : null,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: LabeledField(
                  label: 'Warn at',
                  child: TextFormField(
                    controller: thresholdController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(hintText: 'e.g. 5'),
                  ),
                ),
              ),
            ],
          ),
        ],
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Reminders'),
          subtitle: const Text('Notify you when doses are due'),
          value: remindersEnabled,
          onChanged: onRemindersChanged,
        ),
      ],
    );
  }
}
