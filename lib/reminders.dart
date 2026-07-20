import 'dart:async';

/// Fires water / stand reminders on fixed intervals. Reconfigurable at runtime
/// (from Settings): [configure] cancels and re-arms the timers, skipping any
/// reminder that is disabled.
class ReminderScheduler {
  ReminderScheduler({required this.onWater, required this.onStand});

  final void Function() onWater;
  final void Function() onStand;

  Timer? _waterTimer;
  Timer? _standTimer;

  void configure({
    required bool waterEnabled,
    required Duration water,
    required bool standEnabled,
    required Duration stand,
  }) {
    _waterTimer?.cancel();
    _standTimer?.cancel();
    if (waterEnabled) {
      _waterTimer = Timer.periodic(water, (_) => onWater());
    }
    if (standEnabled) {
      _standTimer = Timer.periodic(stand, (_) => onStand());
    }
  }

  void dispose() {
    _waterTimer?.cancel();
    _standTimer?.cancel();
  }
}
