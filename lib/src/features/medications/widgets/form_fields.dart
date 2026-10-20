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
          Text(label, style: AppTextStyles.labelStrong),
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
    final c = SuiteColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.labelStrong),
        const SizedBox(height: AppSpacing.sm),
        Material(
          color: c.surfaceAlt,
          borderRadius: BorderRadius.circular(AppSpacing.borderRadius),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppSpacing.borderRadius),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        value,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.body.copyWith(
                          color: c.textPrimary,
                        ),
                      ),
                    ),
                    if (onClear != null)
                      GestureDetector(
                        onTap: onClear,
                        child:
                            Icon(Icons.close, size: 18, color: c.textSecondary),
                      )
                    else
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 18,
                        color: c.textSecondary,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
