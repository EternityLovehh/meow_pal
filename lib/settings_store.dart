import 'package:shared_preferences/shared_preferences.dart';

import 'settings.dart';

/// Loads/saves [Settings] to local storage (shared_preferences).
class SettingsStore {
  static const String _p = 'meow_pal.';

  Future<Settings> load() async {
    final sp = await SharedPreferences.getInstance();
    const d = Settings();
    return Settings(
      waterEnabled: sp.getBool('${_p}waterEnabled') ?? d.waterEnabled,
      waterMinutes: sp.getInt('${_p}waterMinutes') ?? d.waterMinutes,
      standEnabled: sp.getBool('${_p}standEnabled') ?? d.standEnabled,
      standMinutes: sp.getInt('${_p}standMinutes') ?? d.standMinutes,
    );
  }

  Future<void> save(Settings s) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool('${_p}waterEnabled', s.waterEnabled);
    await sp.setInt('${_p}waterMinutes', s.waterMinutes);
    await sp.setBool('${_p}standEnabled', s.standEnabled);
    await sp.setInt('${_p}standMinutes', s.standMinutes);
  }
}
