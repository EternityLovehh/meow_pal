/// User-adjustable settings. Immutable; change via [copyWith].
class Settings {
  const Settings({
    this.waterEnabled = true,
    this.waterMinutes = 45,
    this.standEnabled = true,
    this.standMinutes = 30,
  });

  final bool waterEnabled;
  final int waterMinutes;
  final bool standEnabled;
  final int standMinutes;

  Settings copyWith({
    bool? waterEnabled,
    int? waterMinutes,
    bool? standEnabled,
    int? standMinutes,
  }) {
    return Settings(
      waterEnabled: waterEnabled ?? this.waterEnabled,
      waterMinutes: waterMinutes ?? this.waterMinutes,
      standEnabled: standEnabled ?? this.standEnabled,
      standMinutes: standMinutes ?? this.standMinutes,
    );
  }
}
