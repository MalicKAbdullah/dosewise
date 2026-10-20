/// Color tag palette for medications (ARGB values, model-safe ints).
abstract final class MedicationColors {
  static const List<int> palette = [
    0xFF6366F1, // indigo
    0xFF3B82F6, // blue
    0xFF14B8A6, // teal
    0xFF22C55E, // green
    0xFFF59E0B, // amber
    0xFF06B6D4, // cyan
    0xFFEF4444, // red
    0xFFEC4899, // pink
    0xFF8B5CF6, // violet
    0xFF64748B, // slate
  ];

  static int get defaultColor => palette.first;
}
