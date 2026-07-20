import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:rive/rive.dart';

/// Wraps the Rive state machine so the rest of the app never touches Rive
/// directly. This .riv provides the good-looking idle/gaze art; richer
/// reactions (bounce, wiggle, etc.) are layered on top at the Flutter level.
class RiveCatController {
  void onRiveInit(Artboard artboard) {
    final sm = StateMachineController.fromArtboard(artboard, 'State Machine 1');
    if (sm == null) {
      if (kDebugMode) {
        debugPrint('meow_pal: state machine "State Machine 1" not found in '
            'artboard "${artboard.name}"');
      }
      return;
    }
    // The artboard retains the controller, so we do not keep a reference.
    artboard.addController(sm);
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
