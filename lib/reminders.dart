import 'dart:async';

/// Fires water / stand reminders on fixed intervals.
///
/// Single responsibility: it only knows "it's time" and calls back. It does
/// not know how the pet reacts — that keeps scheduling testable and lets the
/// UI decide the animation/line.
class ReminderScheduler {
  ReminderScheduler({
    required this.water,
    required this.stand,
    required this.onWater,
    required this.onStand,
  });

  final Duration water;
  final Duration stand;
  final void Function() onWater;
  final void Function() onStand;

  Timer? _waterTimer;
  Timer? _standTimer;

  void start() {
    _waterTimer = Timer.periodic(water, (_) => onWater());
    _standTimer = Timer.periodic(stand, (_) => onStand());
  }

  void dispose() {
    _waterTimer?.cancel();
    _standTimer?.cancel();
  }
}
