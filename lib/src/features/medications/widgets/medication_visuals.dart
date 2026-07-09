import 'package:core_theme/core_theme.dart';
import 'package:dose_wise/src/features/medications/models/medication.dart';
import 'package:flutter/material.dart';

/// Icon for each medication form.
IconData medicationFormIcon(MedicationForm form) => switch (form) {
      MedicationForm.tablet => Icons.medication_outlined,
      MedicationForm.capsule => Icons.medication_liquid_outlined,
      MedicationForm.liquid => Icons.water_drop_outlined,
      MedicationForm.injection => Icons.vaccines_outlined,
      MedicationForm.topical => Icons.healing_outlined,
      MedicationForm.other => Icons.medical_services_outlined,
    };

/// Cached [Color] for a medication's ARGB tag. The same handful of palette
/// values recur across every list row, so memoizing avoids re-allocating
/// identical Color objects on each rebuild and keeps identity stable for
/// const/equality short-circuits.
final Map<int, Color> _medicationColorCache = {};

Color medicationColor(int argb) =>
    _medicationColorCache.putIfAbsent(argb, () => Color(argb));

/// Rounded square avatar: the medication's form icon on a soft tint of
/// its color tag. The shared visual anchor for tiles and headers.
final class MedicationAvatar extends StatelessWidget {
  const MedicationAvatar({
    required this.medication,
    this.size = 44,
    super.key,
  });

  final Medication medication;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = medicationColor(medication.colorValue);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(
        medicationFormIcon(medication.form),
        size: size * 0.55,
        color: color,
      ),
    );
  }
}

/// Small pill-shaped status chip (e.g. "Low supply", "Archived").
final class StatusChip extends StatelessWidget {
  const StatusChip({
    required this.label,
    required this.color,
    this.icon,
    super.key,
  });

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(
            label,
            style: AppTextStyles.caption
                .copyWith(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
