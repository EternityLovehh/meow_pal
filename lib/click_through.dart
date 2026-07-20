import 'dart:async';
import 'dart:ui';

import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

/// Makes a transparent pet window "click-through" everywhere except over the
/// interactive areas the app cares about.
///
/// `setIgnoreMouseEvents` is window-wide (all or nothing), so we poll the
/// global cursor and flip it based on [hitTest]:
///   - cursor over an interactive area -> ignore = false (clickable)
///   - anywhere else                   -> ignore = true  (clicks pass through)
///
/// [hitTest] takes the cursor in window-local coordinates and returns whether
/// it is over something interactive (the cat, a button, or — when a panel is
/// open — the whole window).
class ClickThroughController {
  ClickThroughController({required this.hitTest});

  final bool Function(Offset local) hitTest;

  Timer? _timer;
  bool? _ignoring; // last applied state; null = not set yet

  void start() {
    _timer = Timer.periodic(const Duration(milliseconds: 80), (_) => _tick());
  }

  Future<void> _tick() async {
    final Offset cursor;
    final Offset windowPos;
    try {
      cursor = await screenRetriever.getCursorScreenPoint();
      windowPos = await windowManager.getPosition();
    } catch (_) {
      return; // window not ready / transient failure — skip this tick
    }

    final local = cursor - windowPos;
    final shouldIgnore = !hitTest(local);

    if (_ignoring != shouldIgnore) {
      _ignoring = shouldIgnore;
      await windowManager.setIgnoreMouseEvents(shouldIgnore);
    }
  }

  void dispose() {
    _timer?.cancel();
  }
}
