import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import 'pet_view.dart';

/// Imperative handle the orchestrator uses to trigger body reactions.
/// (The widget below binds these callbacks in initState.)
class PetBodyController {
  VoidCallback? _bounce;
  VoidCallback? _wiggle;
  void Function(bool walking)? _setWalking;

  void bounce() => _bounce?.call();
  void wiggle() => _wiggle?.call();
  void setWalking(bool walking) => _setWalking?.call(walking);
}

/// Owns every "body" animation for the cat (bounce, wiggle, walk-bob) and
/// renders the Rive art. Keeps all animation guts out of the orchestrator.
class PetBody extends StatefulWidget {
  const PetBody({
    super.key,
    required this.controller,
    required this.riveController,
    this.size = 140,
  });

  final PetBodyController controller;
  final RiveCatController riveController;
  final double size;

  @override
  State<PetBody> createState() => _PetBodyState();
}

class _PetBodyState extends State<PetBody> with TickerProviderStateMixin {
  // Unbounded: holds a spring "displacement" oscillating around 0.
  late final AnimationController _bounce;
  late final AnimationController _wiggle;
  late final Animation<double> _wiggleAngle;
  late final AnimationController _walkBob;

  static final SpringDescription _spring =
      SpringDescription(mass: 1, stiffness: 380, damping: 17);

  @override
  void initState() {
    super.initState();
    widget.controller
      .._bounce = _playBounce
      .._wiggle = _playWiggle
      .._setWalking = _setWalking;

    _bounce = AnimationController.unbounded(vsync: this);

    _wiggle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _wiggleAngle = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: -0.18)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween(begin: -0.18, end: 0.18)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.18, end: 0.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 35,
      ),
    ]).animate(_wiggle);

    _walkBob = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
  }

  Future<void> _playBounce() async {
    _bounce.stop();
    // #2 Anticipation: quick squash down before launching.
    await _bounce.animateTo(
      -0.6,
      duration: const Duration(milliseconds: 80),
      curve: Curves.easeOut,
    );
    if (!mounted) return;
    // #3 Spring: pop up and settle naturally (interruptible).
    _bounce.animateWith(SpringSimulation(_spring, _bounce.value, 0, 12));
  }

  void _playWiggle() => _wiggle.forward(from: 0);

  void _setWalking(bool walking) {
    if (walking) {
      if (!_walkBob.isAnimating) _walkBob.repeat();
    } else {
      _walkBob
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    widget.controller
      .._bounce = null
      .._wiggle = null
      .._setWalking = null;
    _bounce.dispose();
    _wiggle.dispose();
    _walkBob.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_bounce, _wiggle, _walkBob]),
      builder: (context, child) {
        final b = _bounce.value; // ~ -0.6 (squash) .. +overshoot .. 0
        final scaleY = 1 + b * 0.5;
        final scaleX = 1 - b * 0.35; // inverse coupling = squash & stretch
        final bob = _walkBob.isAnimating ? sin(_walkBob.value * 2 * pi) * 4 : 0.0;
        final hop = b * -55 + bob; // stretch up = lift; squash = settle down
        return Transform.translate(
          offset: Offset(0, hop),
          child: Transform.rotate(
            angle: _wiggleAngle.value,
            child: Transform.scale(
              scaleX: scaleX,
              scaleY: scaleY,
              alignment: Alignment.bottomCenter,
              child: child,
            ),
          ),
        );
      },
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        // Rive registers its own pointer recognizers; combined with
        // windowManager.startDragging() that crashes. We own gestures upstream.
        child: IgnorePointer(child: PetView(controller: widget.riveController)),
      ),
    );
  }
}
