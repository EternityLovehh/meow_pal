import 'dart:async';
import 'dart:ui';

import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

/// Makes a transparent pet window "click-through" everywhere except on the pet
/// body.
///
/// The whole window is a rectangle, but we only want the pet itself to catch
/// the mouse — clicks on the transparent area should fall through to whatever
/// is behind. `setIgnoreMouseEvents` is window-wide (all or nothing), so we
/// poll the global cursor position on a timer and flip it:
///   - cursor over the pet  -> ignore = false (pet is clickable / draggable)
///   - cursor anywhere else -> ignore = true  (clicks pass through)
///
/// We poll the *global* cursor (not Flutter hover) on purpose: while the window
/// is ignoring the mouse, Flutter receives no hover events, so global polling is
/// the only way to know when the cursor comes back over the pet.
class ClickThroughController {
  ClickThroughController({required this.petBounds});

  /// Pet body rect in logical window coordinates (origin = window top-left).
  final Rect Function() petBounds;

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

    final local = cursor - windowPos; // cursor in window-local coordinates
    final overPet = petBounds().contains(local);
    final shouldIgnore = !overPet;

    // Only call across the platform channel when the state actually changes.
    if (_ignoring != shouldIgnore) {
      _ignoring = shouldIgnore;
      await windowManager.setIgnoreMouseEvents(shouldIgnore);
    }
  }

  void dispose() {
    _timer?.cancel();
  }
}
