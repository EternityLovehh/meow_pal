import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Handle the pet code uses to spray particles: `controller.emit('❤️')`.
class ParticleController {
  void Function(String emoji, int count)? _bind;

  void emit(String emoji, {int count = 6}) => _bind?.call(emoji, count);
}

class _Particle {
  _Particle({
    required this.emoji,
    required this.x,
    required this.vx,
    required this.vy,
    required this.lifetime,
  });

  final String emoji;
  final double x; // start x offset from horizontal center
  final double vx; // horizontal drift, px/s
  final double vy; // vertical speed, px/s (negative = up)
  final double lifetime; // seconds
  double age = 0;
}

/// A transparent overlay that floats emoji particles upward and fades them out.
/// Driven by a single Ticker that only runs while particles are alive.
class ParticleField extends StatefulWidget {
  const ParticleField({super.key, required this.controller});

  final ParticleController controller;

  @override
  State<ParticleField> createState() => _ParticleFieldState();
}

class _ParticleFieldState extends State<ParticleField>
    with SingleTickerProviderStateMixin {
  final List<_Particle> _particles = [];
  final Random _rng = Random();
  late final Ticker _ticker;
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    widget.controller._bind = _emit;
    _ticker = createTicker(_onTick);
  }

  void _emit(String emoji, int count) {
    for (var i = 0; i < count; i++) {
      _particles.add(_Particle(
        emoji: emoji,
        x: (_rng.nextDouble() - 0.5) * 60,
        vx: (_rng.nextDouble() - 0.5) * 30,
        vy: -(45 + _rng.nextDouble() * 45),
        lifetime: 1.2 + _rng.nextDouble() * 0.8,
      ));
    }
    if (!_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    }
    setState(() {});
  }

  void _onTick(Duration elapsed) {
    final dt =
        _last == Duration.zero ? 0.0 : (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    for (final p in _particles) {
      p.age += dt;
    }
    _particles.removeWhere((p) => p.age >= p.lifetime);
    if (_particles.isEmpty) _ticker.stop();
    setState(() {});
  }

  @override
  void dispose() {
    widget.controller._bind = null;
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cx = constraints.maxWidth / 2;
          final baseY = constraints.maxHeight * 0.42; // emit around the head
          return Stack(
            children: [
              for (final p in _particles)
                Positioned(
                  left: cx + p.x + p.vx * p.age - 11,
                  top: baseY + p.vy * p.age,
                  child: Opacity(
                    opacity: (1 - p.age / p.lifetime).clamp(0.0, 1.0),
                    child: Text(p.emoji, style: const TextStyle(fontSize: 22)),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
