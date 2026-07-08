/// A person whose medications DoseWise tracks (family / caregiver mode).
/// Medications and dose records carry a `profileId` pointing here.
final class Profile {
  const Profile({
    required this.id,
    required this.name,
    required this.colorValue,
  });

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        id: json['id'] as String,
        name: json['name'] as String,
        colorValue: json['colorValue'] as int? ?? defaultColorValue,
      );

  /// The profile a pre-profiles vault is migrated into, and the one a
  /// fresh install starts with.
  factory Profile.defaults() => const Profile(
        id: defaultId,
        name: defaultName,
        colorValue: defaultColorValue,
      );

  static const String defaultId = 'default';
  static const String defaultName = 'Me';
  static const int defaultColorValue = 0xFF14B8A6; // teal

  final String id;
  final String name;

  /// ARGB color tag (kept as an int so the model stays pure Dart).
  final int colorValue;

  /// Uppercased first character, for the avatar chip.
  String get initial => name.trim().isEmpty
      ? '?'
      : String.fromCharCode(name.trim().runes.first).toUpperCase();

  Profile copyWith({String? name, int? colorValue}) => Profile(
        id: id,
        name: name ?? this.name,
        colorValue: colorValue ?? this.colorValue,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'colorValue': colorValue,
      };

  @override
  bool operator ==(Object other) =>
      other is Profile &&
      other.id == id &&
      other.name == name &&
      other.colorValue == colorValue;

  @override
  int get hashCode => Object.hash(id, name, colorValue);
}
