import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:rive/rive.dart';

/// Wraps the Rive state machine so the rest of the app never touches Rive
/// directly. This .riv provides the good-looking idle/gaze art; richer
/// reactions (bounce, wiggle, etc.) are layered on top at the Flutter level.
class RiveCatController {
  StateMachineController? _sm;

  void onRiveInit(Artboard artboard) {
    final sm = StateMachineController.fromArtboard(artboard, 'State Machine 1');
    if (sm == null) {
      if (kDebugMode) {
        debugPrint('meow_pal: state machine "State Machine 1" not found in '
            'artboard "${artboard.name}"');
      }
      return;
    }
    artboard.addController(sm);
    _sm = sm;
  }

  /// Fire a trigger input by name (no-op if absent / wrong type).
  void fireTrigger(String name) {
    final input = _sm?.findInput<bool>(name);
    if (input is SMITrigger) input.fire();
  }

  /// Set a boolean input by name.
  void setBool(String name, {required bool value}) {
    final input = _sm?.findInput<bool>(name);
    if (input is SMIBool) input.value = value;
  }

  /// Set a number input by name.
  void setNumber(String name, double value) {
    final input = _sm?.findInput<double>(name);
    if (input is SMINumber) input.value = value;
  }
}

/// Renders the Rive cat. Nothing else — layout/sizing is the caller's job.
class PetView extends StatelessWidget {
  const PetView({super.key, required this.controller});

  final RiveCatController controller;

  @override
  Widget build(BuildContext context) {
    return RiveAnimation.asset(
      'assets/rive/cat.riv',
      fit: BoxFit.contain,
      stateMachines: const ['State Machine 1'],
      onInit: controller.onRiveInit,
    );
  }
}
