import 'package:dose_wise/src/features/medications/models/schedule.dart';
import 'package:dose_wise/src/features/profiles/models/profile.dart';

enum MedicationForm {
  tablet('Tablet'),
  capsule('Capsule'),
  liquid('Liquid'),
  injection('Injection'),
  topical('Topical'),
  other('Other');

  const MedicationForm(this.label);

  final String label;
}

/// A medication with its dosing schedule, active date range, and optional
/// supply (refill) tracking.
final class Medication {
  const Medication({
    required this.id,
    required this.name,
    required this.dosage,
    required this.form,
    required this.colorValue,
    required this.startDate,
    required this.schedule,
    this.endDate,
    this.notes = '',
    this.currentStock,
    this.lowStockThreshold = defaultLowStockThreshold,
    this.remindersEnabled = true,
    this.archived = false,
    this.updatedAt,
    this.profileId = Profile.defaultId,
  });

  factory Medication.fromJson(Map<String, dynamic> json) => Medication(
        id: json['id'] as String,
        name: json['name'] as String,
        dosage: json['dosage'] as String,
        form: MedicationForm.values.byName(json['form'] as String),
        colorValue: json['colorValue'] as int,
        notes: json['notes'] as String? ?? '',
        startDate: DateTime.parse(json['startDate'] as String),
        endDate: json['endDate'] == null
            ? null
            : DateTime.parse(json['endDate'] as String),
        schedule: Schedule.fromJson(json['schedule'] as Map<String, dynamic>),
        currentStock: json['currentStock'] as int?,
        lowStockThreshold:
            json['lowStockThreshold'] as int? ?? defaultLowStockThreshold,
        remindersEnabled: json['remindersEnabled'] as bool? ?? true,
        archived: json['archived'] as bool? ?? false,
        updatedAt: json['updatedAt'] == null
            ? null
            : DateTime.parse(json['updatedAt'] as String),
        profileId: json['profileId'] as String? ?? Profile.defaultId,
      );

  static const int defaultLowStockThreshold = 5;

  final String id;
  final String name;

  /// Free-form dosage text, e.g. "500 mg".
  final String dosage;
  final MedicationForm form;

  /// ARGB color tag value (kept as an int so the model stays pure Dart).
  final int colorValue;
  final String notes;

  /// First day the medication is taken (date component only is significant).
  final DateTime startDate;

  /// Last day the medication is taken, inclusive. Null means open-ended.
  final DateTime? endDate;
  final Schedule schedule;

  /// Units on hand. Null means supply tracking is off for this medication.
  final int? currentStock;

  /// When [currentStock] falls to this value or below, supply is "low".
  final int lowStockThreshold;

  /// Per-medication reminder opt-out (global toggle still wins).
  final bool remindersEnabled;

  /// Archived medications keep their history but stop producing doses.
  final bool archived;

  /// Last modification time, stamped on every save. Null on data written
  /// before backups existed — treated as "oldest" when merging backups.
  final DateTime? updatedAt;

  /// The profile this medication belongs to.
  final String profileId;

  /// Whether supply tracking is enabled for this medication.
  bool get tracksStock => currentStock != null;

  /// Whether the remaining supply is at or below the low-stock threshold.
  bool get isLowStock => tracksStock && currentStock! <= lowStockThreshold;

  /// Whether [day] falls within the active date range (date granularity).
  bool isActiveOn(DateTime day) {
    final d = _dateOnly(day);
    if (d.isBefore(_dateOnly(startDate))) return false;
    final end = endDate;
    if (end != null && d.isAfter(_dateOnly(end))) return false;
    return true;
  }

  Medication copyWith({
    String? name,
    String? dosage,
    MedicationForm? form,
    int? colorValue,
    String? notes,
    DateTime? startDate,
    DateTime? endDate,
    bool clearEndDate = false,
    Schedule? schedule,
    int? currentStock,
    bool clearCurrentStock = false,
    int? lowStockThreshold,
    bool? remindersEnabled,
    bool? archived,
    DateTime? updatedAt,
  }) =>
      Medication(
        id: id,
        name: name ?? this.name,
        dosage: dosage ?? this.dosage,
        form: form ?? this.form,
        colorValue: colorValue ?? this.colorValue,
        notes: notes ?? this.notes,
        startDate: startDate ?? this.startDate,
        endDate: clearEndDate ? null : (endDate ?? this.endDate),
        schedule: schedule ?? this.schedule,
        currentStock:
            clearCurrentStock ? null : (currentStock ?? this.currentStock),
        lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
        remindersEnabled: remindersEnabled ?? this.remindersEnabled,
        archived: archived ?? this.archived,
        updatedAt: updatedAt ?? this.updatedAt,
        profileId: profileId,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'dosage': dosage,
        'form': form.name,
        'colorValue': colorValue,
        'notes': notes,
        'startDate': _dateOnly(startDate).toIso8601String(),
        if (endDate != null) 'endDate': _dateOnly(endDate!).toIso8601String(),
        'schedule': schedule.toJson(),
        if (currentStock != null) 'currentStock': currentStock,
        'lowStockThreshold': lowStockThreshold,
        'remindersEnabled': remindersEnabled,
        'archived': archived,
        if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
        'profileId': profileId,
      };

  static DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);
}
