import 'package:flutter/material.dart';

import 'settings.dart';

/// Settings overlay: reminder toggles + interval sliders, a CC-BY attribution
/// line, and a quit button. The header and footer stay pinned; only the
/// reminder list scrolls if it doesn't fit the small pet window. Tapping the
/// empty area closes it.
class SettingsPanel extends StatelessWidget {
  const SettingsPanel({
    super.key,
    required this.settings,
    required this.onChanged,
    required this.onClose,
    required this.onQuit,
  });

  final Settings settings;
  final ValueChanged<Settings> onChanged;
  final VoidCallback onClose;
  final VoidCallback onQuit;

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF8A7CFF),
      brightness: Brightness.dark,
    );
    return Theme(
      data: ThemeData(useMaterial3: true, colorScheme: scheme),
      child: Stack(
        children: [
          // Invisible tap-catcher: tap outside the card to close (no dark scrim
          // — in this tiny window a scrim just looks like a black box).
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onClose,
              child: const SizedBox.expand(),
            ),
          ),
          Center(
            child: GestureDetector(
              onTap: () {}, // absorb taps so they don't reach the tap-catcher
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutBack,
                builder: (context, t, child) => Opacity(
                  opacity: t.clamp(0.0, 1.0),
                  child: Transform.scale(scale: 0.9 + 0.1 * t, child: child),
                ),
                child: _card(scheme),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(ColorScheme scheme) {
    return Container(
      width: 236,
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF26262F),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 248),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header (pinned)
            Row(
              children: [
                Icon(Icons.pets, size: 16, color: scheme.primary),
                const SizedBox(width: 6),
                const Text('设置',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                const Spacer(),
                IconButton(
                  iconSize: 18,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: onClose,
                  icon: const Icon(Icons.close),
                  color: Colors.white54,
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Reminder list (scrolls if it doesn't fit)
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _reminderCard(
                      label: '喝水提醒',
                      icon: Icons.water_drop_outlined,
                      enabled: settings.waterEnabled,
                      minutes: settings.waterMinutes,
                      min: 15,
                      max: 120,
                      onToggle: (v) =>
                          onChanged(settings.copyWith(waterEnabled: v)),
                      onMinutes: (v) =>
                          onChanged(settings.copyWith(waterMinutes: v)),
                    ),
                    const SizedBox(height: 8),
                    _reminderCard(
                      label: '站立提醒',
                      icon: Icons.directions_walk,
                      enabled: settings.standEnabled,
                      minutes: settings.standMinutes,
                      min: 10,
                      max: 120,
                      onToggle: (v) =>
                          onChanged(settings.copyWith(standEnabled: v)),
                      onMinutes: (v) =>
                          onChanged(settings.copyWith(standMinutes: v)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Footer (pinned — always visible)
            Row(
              children: [
                const Expanded(
                  child: Text('素材 rive.app · CC BY',
                      style: TextStyle(fontSize: 10, color: Colors.white38)),
                ),
                TextButton.icon(
                  onPressed: onQuit,
                  icon: const Icon(Icons.power_settings_new, size: 15),
                  label: const Text('退出'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _reminderCard({
    required String label,
    required IconData icon,
    required bool enabled,
    required int minutes,
    required int min,
    required int max,
    required ValueChanged<bool> onToggle,
    required ValueChanged<int> onMinutes,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 8, 6),
      decoration: BoxDecoration(
        color: const Color(0xFF33333E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: Colors.white60),
              const SizedBox(width: 6),
              Expanded(
                  child: Text(label, style: const TextStyle(fontSize: 13))),
              Transform.scale(
                scale: 0.8,
                child: Switch(value: enabled, onChanged: onToggle),
              ),
            ],
          ),
          if (enabled)
            Row(
              children: [
                Expanded(
                  child: SliderTheme(
                    data: const SliderThemeData(trackHeight: 3),
                    child: Slider(
                      value: minutes
                          .toDouble()
                          .clamp(min.toDouble(), max.toDouble()),
                      min: min.toDouble(),
                      max: max.toDouble(),
                      divisions: max - min,
                      label: '$minutes 分钟',
                      onChanged: (v) => onMinutes(v.round()),
                    ),
                  ),
                ),
                SizedBox(
                  width: 44,
                  child: Text('$minutes 分',
                      style:
                          const TextStyle(fontSize: 11, color: Colors.white70)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
