enum Units { imperial, metric }

/// Route-suggestion preferences stored on `users/{uid}`.
class UserPreferences {
  const UserPreferences({
    required this.bikeSpeedKph,
    required this.enduranceKm,
    required this.hillTolerance,
    required this.transitEnabled,
    required this.units,
    required this.speedStrainWeight,
  });

  /// Comfortable cruising speed on flat ground.
  final double bikeSpeedKph;

  /// Distance the rider can cover comfortably before fatigue sets in.
  final double enduranceKm;

  /// 0 = avoid hills strongly, 1 = hills barely matter.
  final double hillTolerance;

  final bool transitEnabled;
  final Units units;

  /// 0 = minimize strain only, 1 = minimize time only.
  final double speedStrainWeight;

  static const UserPreferences defaults = UserPreferences(
    bikeSpeedKph: 18,
    enduranceKm: 10,
    hillTolerance: 0.5,
    transitEnabled: true,
    units: Units.imperial,
    speedStrainWeight: 0.5,
  );

  double get bikeSpeedMps => bikeSpeedKph / 3.6;

  factory UserPreferences.fromMap(Map<String, dynamic> map) {
    double num_(String key, double fallback) =>
        (map[key] as num?)?.toDouble() ?? fallback;
    const d = defaults;
    return UserPreferences(
      bikeSpeedKph: num_('bikeSpeedKph', d.bikeSpeedKph),
      enduranceKm: num_('enduranceKm', d.enduranceKm),
      hillTolerance: num_('hillTolerance', d.hillTolerance).clamp(0.0, 1.0),
      transitEnabled: map['transitEnabled'] as bool? ?? d.transitEnabled,
      units: map['units'] == 'metric' ? Units.metric : Units.imperial,
      speedStrainWeight:
          num_('speedStrainWeight', d.speedStrainWeight).clamp(0.0, 1.0),
    );
  }

  Map<String, dynamic> toMap() => {
        'bikeSpeedKph': bikeSpeedKph,
        'enduranceKm': enduranceKm,
        'hillTolerance': hillTolerance,
        'transitEnabled': transitEnabled,
        'units': units.name,
        'speedStrainWeight': speedStrainWeight,
      };

  UserPreferences copyWith({
    double? bikeSpeedKph,
    double? enduranceKm,
    double? hillTolerance,
    bool? transitEnabled,
    Units? units,
    double? speedStrainWeight,
  }) {
    return UserPreferences(
      bikeSpeedKph: bikeSpeedKph ?? this.bikeSpeedKph,
      enduranceKm: enduranceKm ?? this.enduranceKm,
      hillTolerance: hillTolerance ?? this.hillTolerance,
      transitEnabled: transitEnabled ?? this.transitEnabled,
      units: units ?? this.units,
      speedStrainWeight: speedStrainWeight ?? this.speedStrainWeight,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is UserPreferences &&
      other.bikeSpeedKph == bikeSpeedKph &&
      other.enduranceKm == enduranceKm &&
      other.hillTolerance == hillTolerance &&
      other.transitEnabled == transitEnabled &&
      other.units == units &&
      other.speedStrainWeight == speedStrainWeight;

  @override
  int get hashCode => Object.hash(bikeSpeedKph, enduranceKm, hillTolerance,
      transitEnabled, units, speedStrainWeight);
}
