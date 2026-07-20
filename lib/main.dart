import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

import 'click_through.dart';
import 'particles.dart';
import 'pet_body.dart';
import 'pet_view.dart';
import 'reactions.dart';
import 'reminders.dart';
import 'settings.dart';
import 'settings_panel.dart';
import 'settings_store.dart';
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

/// Orchestrator: wires input + scheduling to reactions. Body animation lives in
/// PetBody; particles in ParticleField; the bubble animates itself.
class _PetHomeState extends State<PetHome> with SingleTickerProviderStateMixin {
  final RiveCatController _cat = RiveCatController();
  final PetBodyController _body = PetBodyController();
  final ParticleController _particles = ParticleController();
  late final ClickThroughController _clickThrough;

  // Interactive region (window-local): the cat body.
  static const Rect _petRect = Rect.fromLTWH(60, 60, 140, 140);

  final SettingsStore _store = SettingsStore();
  Settings _settings = const Settings();
  bool _settingsOpen = false;

  // Wandering: moves the whole window; the walk-bob visual lives in PetBody.
  late final AnimationController _walk;
  Offset _walkFrom = Offset.zero;
  Offset _walkTo = Offset.zero;
  Rect? _workArea;
  Timer? _wanderTimer;

  final Random _random = Random();
  late final ReminderScheduler _reminders;
  Timer? _idleTimer;

  String? _bubble;
  Timer? _bubbleTimer;

  @override
  void initState() {
    super.initState();
    _clickThrough = ClickThroughController(
      hitTest: (local) => _settingsOpen || _petRect.contains(local),
    )..start();

    _walk = AnimationController(vsync: this);
    _walk.addListener(() {
      final pos = Offset.lerp(
        _walkFrom,
        _walkTo,
        Curves.easeInOut.transform(_walk.value),
      )!;
      windowManager.setPosition(pos);
    });
    _walk.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _body.setWalking(false);
        _scheduleWander();
      }
    });
    _initWorkArea();

    _reminders = ReminderScheduler(
      onWater: () => _play(Reactions.water),
      onStand: () => _play(Reactions.stand),
    );
    _loadSettings();

    _scheduleIdle();
  }

  Future<void> _loadSettings() async {
    final s = await _store.load();
    if (!mounted) return;
    setState(() => _settings = s);
    _applyReminderSchedule();
  }

  void _applySettings(Settings s) {
    setState(() => _settings = s);
    _applyReminderSchedule();
    _store.save(s);
  }

  void _applyReminderSchedule() {
    _reminders.configure(
      waterEnabled: _settings.waterEnabled,
      water: Duration(minutes: _settings.waterMinutes),
      standEnabled: _settings.standEnabled,
      stand: Duration(minutes: _settings.standMinutes),
    );
  }

  Future<void> _openSettings() async {
    // Pause wandering and nudge the window fully on-screen so the panel is not
    // clipped by a screen edge.
    _walk.stop();
    _body.setWalking(false);
    _wanderTimer?.cancel();
    final wa = _workArea;
    if (wa != null) {
      final pos = await windowManager.getPosition();
      final safe = Offset(
        pos.dx.clamp(wa.left, wa.right - 260),
        pos.dy.clamp(wa.top, wa.bottom - 260),
      );
      if (safe != pos) await windowManager.setPosition(safe);
    }
    if (mounted) setState(() => _settingsOpen = true);
  }

  void _closeSettings() {
    setState(() => _settingsOpen = false);
    _scheduleWander();
  }

  /// One entry point: play a reaction's animation, line and particles.
  void _play(Reaction r) {
    switch (r.anim) {
      case ReactionAnim.bounce:
        _body.bounce();
      case ReactionAnim.wiggle:
        _body.wiggle();
      case null:
        break;
    }
    if (r.lines.isNotEmpty) {
      _say(r.lines[_random.nextInt(r.lines.length)]);
    }
    final emoji = r.emoji;
    if (emoji != null) _particles.emit(emoji, count: r.particleCount);
  }

  void _say(String text) {
    setState(() => _bubble = text);
    _bubbleTimer?.cancel();
    _bubbleTimer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted) setState(() => _bubble = null);
    });
  }

  // Self-initiated micro-actions so the cat feels alive when left alone.
  void _scheduleIdle() {
    final ms = 6000 + _random.nextInt(9000); // fire every 6-15s
    _idleTimer = Timer(Duration(milliseconds: ms), () {
      _doIdleAction();
      _scheduleIdle();
    });
  }

  void _doIdleAction() {
    final r = _random.nextDouble();
    if (r < 0.45) {
      _play(Reactions.idleBounce);
    } else if (r < 0.75) {
      _play(Reactions.idleWiggle);
    } else {
      _play(Reactions.idleQuip);
    }
  }

  Future<void> _initWorkArea() async {
    final d = await screenRetriever.getPrimaryDisplay();
    final pos = d.visiblePosition ?? Offset.zero;
    final size = d.visibleSize ?? d.size;
    _workArea = Rect.fromLTWH(pos.dx, pos.dy, size.width, size.height);
    _scheduleWander();
  }

  void _scheduleWander() {
    _wanderTimer?.cancel();
    // Wander only a few times a day: next stroll in ~1.5-4 hours.
    final minutes = 90 + _random.nextInt(151); // 90-240 min
    _wanderTimer = Timer(Duration(minutes: minutes), _startWander);
  }

  Future<void> _startWander() async {
    final wa = _workArea;
    if (wa == null) return;
    const win = 260.0;
    final from = await windowManager.getPosition();
    final maxX = (wa.width - win).clamp(0.0, double.infinity);
    final maxY = (wa.height - win).clamp(0.0, double.infinity);
    final to = Offset(
      wa.left + _random.nextDouble() * maxX,
      wa.top + _random.nextDouble() * maxY,
    );
    final dist = (to - from).distance;
    if (dist < 8) {
      _scheduleWander();
      return;
    }
    _walkFrom = from;
    _walkTo = to;
    _walk.duration = Duration(
      milliseconds: (dist / 90 * 1000).clamp(700, 4500).round(),
    );
    _body.setWalking(true);
    _walk.forward(from: 0);
  }

  @override
  void dispose() {
    _bubbleTimer?.cancel();
    _idleTimer?.cancel();
    _wanderTimer?.cancel();
    _reminders.dispose();
    _walk.dispose();
    _clickThrough.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Center(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _play(Reactions.tap),
              onSecondaryTap: _openSettings, // right-click opens settings
              onLongPress: _openSettings, // long-press too (trackpad-friendly)
              onPanStart: (_) {
                _walk.stop();
                _body.setWalking(false);
                _play(Reactions.drag);
                windowManager.startDragging();
                _scheduleWander(); // resume roaming after a perch
              },
              child: PetBody(controller: _body, riveController: _cat),
            ),
          ),
          Positioned.fill(child: ParticleField(controller: _particles)),
          // Always mounted so it can animate its own exit when text clears.
          Positioned(
            top: 4,
            left: 0,
            right: 0,
            child: Center(child: SpeechBubble(text: _bubble)),
          ),
          if (_settingsOpen)
            Positioned.fill(
              child: SettingsPanel(
                settings: _settings,
                onChanged: _applySettings,
                onClose: _closeSettings,
                onQuit: () => windowManager.destroy(),
              ),
            ),
        ],
      ),
    );
  }
}
