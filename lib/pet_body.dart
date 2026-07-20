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

  final Random _rng = Random();
  double _tiltDir = 1; // randomize the head-tilt direction each reaction
  int _bounceSeq = 0; // guards against overlapping bounce triggers

  Future<void> _playBounce() async {
    final seq = ++_bounceSeq;
    _bounce.stop();
    _tiltDir = _rng.nextBool() ? 1.0 : -1.0;
    // #2 Anticipation: a small, quick squash before the perk.
    await _bounce.animateTo(
      -0.35,
      duration: const Duration(milliseconds: 70),
      curve: Curves.easeOut,
    );
    // Bail if a newer bounce superseded this one (rapid taps/reminders).
    if (!mounted || seq != _bounceSeq) return;
    // #3 Spring: a gentle perk + head-tilt that settles naturally.
    _bounce.animateWith(SpringSimulation(_spring, _bounce.value, 0, 9));
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
        final b = _bounce.value; // spring displacement around 0
        // Subtle "notice": a small perk + head-tilt, not a big jump.
        final scaleY = 1 + b * 0.12;
        final scaleX = 1 - b * 0.07;
        final bob = _walkBob.isAnimating ? sin(_walkBob.value * 2 * pi) * 4 : 0.0;
        final hop = b * -10 + bob;
        final tilt = _wiggleAngle.value + b * 0.09 * _tiltDir;
        return Transform.translate(
          offset: Offset(0, hop),
          child: Transform.rotate(
            angle: tilt,
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
