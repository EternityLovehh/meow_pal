import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'click_through.dart';
import 'pet_view.dart';
import 'reminders.dart';
import 'speech_bubble.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  const windowOptions = WindowOptions(
    size: Size(260, 260),
    backgroundColor: Colors.transparent,
    skipTaskbar: true,
    alwaysOnTop: true,
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    // Window chrome (borderless + transparency) is configured natively in
    // macos/Runner/MainFlutterWindow.swift.
    await windowManager.setBackgroundColor(Colors.transparent);
    await windowManager.setAlwaysOnTop(true);
    await windowManager.setSkipTaskbar(true);
    await windowManager.show();
  });

  runApp(const MeowPalApp());
}

class MeowPalApp extends StatelessWidget {
  const MeowPalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: PetHome(),
    );
  }
}

class PetHome extends StatefulWidget {
  const PetHome({super.key});

  @override
  State<PetHome> createState() => _PetHomeState();
}

// SingleTickerProviderStateMixin provides the `vsync` the AnimationController needs.
class _PetHomeState extends State<PetHome> with SingleTickerProviderStateMixin {
  final RiveCatController _cat = RiveCatController();
  late final ClickThroughController _clickThrough;

  // Pet body = the 140x140 area centered in the 260x260 window.
  static const Rect _petRect = Rect.fromLTWH(60, 60, 140, 140);

  // A squash/stretch "bounce" reaction, driven explicitly.
  late final AnimationController _bounce;
  late final Animation<double> _bounceScale;
  late final Animation<double> _hopOffset;

  String? _bubble;
  Timer? _bubbleTimer;

  static const List<String> _tapLines = <String>[
    '嗯哼~',
    '在的在的!',
    '摸鱼被我抓到啦😼',
    '喵?',
  ];
  static const List<String> _waterLines = <String>[
    '该喝水啦!',
    '补个水,冲鸭💧',
    '干了这杯白开水!',
    '喉咙渴不渴呀~',
  ];
  static const List<String> _standLines = <String>[
    '站起来动动~',
    '久坐会变石雕哦!',
    '伸个懒腰,一起!',
    '起来走两步鸭!',
  ];
  final Random _random = Random();

  late final ReminderScheduler _reminders;

  @override
  void initState() {
    super.initState();
    _clickThrough = ClickThroughController(petBounds: () => _petRect)..start();

    _bounce = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    // Big scale pop, then settle back with an elastic wobble.
    _bounceScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.32)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.32, end: 1.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 70,
      ),
    ]).animate(_bounce);
    // Hop up, then drop back down with a bouncy landing.
    _hopOffset = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: -34.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween(begin: -34.0, end: 0.0)
            .chain(CurveTween(curve: Curves.bounceOut)),
        weight: 65,
      ),
    ]).animate(_bounce);

    // NOTE: spec defaults are water 45 min / stand 30 min. Using short test
    // intervals now so reminders are easy to observe; moves to Settings later.
    _reminders = ReminderScheduler(
      water: const Duration(seconds: 10),
      stand: const Duration(seconds: 16),
      onWater: () => _react(_waterLines),
      onStand: () => _react(_standLines),
    )..start();
  }

  void _react(List<String> lines) {
    _bounce.forward(from: 0); // replay the bounce from the start
    _say(lines[_random.nextInt(lines.length)]);
  }

  void _say(String text) {
    setState(() => _bubble = text);
    _bubbleTimer?.cancel();
    _bubbleTimer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted) setState(() => _bubble = null);
    });
  }

  @override
  void dispose() {
    _bubbleTimer?.cancel();
    _reminders.dispose();
    _bounce.dispose();
    _clickThrough.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Cat, centered so it lines up with _petRect (used by click-through).
          Center(
            child: GestureDetector(
              onTap: () => _react(_tapLines),
              onPanStart: (_) => windowManager.startDragging(),
              child: AnimatedBuilder(
                animation: _bounce,
                builder: (context, child) => Transform.translate(
                  offset: Offset(0, _hopOffset.value),
                  child:
                      Transform.scale(scale: _bounceScale.value, child: child),
                ),
                child: SizedBox(
                  width: 140,
                  height: 140,
                  child: PetView(controller: _cat),
                ),
              ),
            ),
          ),
          // Speech bubble, floating in the transparent area above the cat.
          if (_bubble != null)
            Positioned(
              top: 4,
              left: 0,
              right: 0,
              child: Center(child: SpeechBubble(text: _bubble)),
            ),
        ],
      ),
    );
  }
}
