import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';

/// A caption above an arbitrary form control, matching VaultTextField's
/// label styling.
final class LabeledField extends StatelessWidget {
  const LabeledField({required this.label, required this.child, super.key});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.label),
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    );
  }
}

/// Labeled date-picker button with an optional clear affordance.
final class DateButton extends StatelessWidget {
  const DateButton({
    required this.label,
    required this.value,
    required this.onTap,
    this.onClear,
    super.key,
  });

  final String label;
  final String value;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.label),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton(
          onPressed: onTap,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(value, overflow: TextOverflow.ellipsis),
              ),
              if (onClear != null)
                GestureDetector(
                  onTap: onClear,
                  child: const Icon(Icons.close, size: 18),
                )
              else
                const Icon(Icons.calendar_today_outlined, size: 18),
            ],
          ),
        ),
      ],
    );
  }
}
