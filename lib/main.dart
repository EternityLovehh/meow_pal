import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'click_through.dart';

Future<void> main() async {
  // Engine + window_manager must init before touching the window.
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
    // macos/Runner/MainFlutterWindow.swift. Do NOT call setTitleBarStyle() or
    // setAsFrameless() here: they poke titled-window buttons and will crash or
    // re-break transparency on a borderless window.
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

class _PetHomeState extends State<PetHome> {
  // Must live on the State object (not inside build) so it survives rebuilds.
  Color _color = Colors.deepPurple;

  late final ClickThroughController _clickThrough;

  @override
  void initState() {
    super.initState();
    // Pet body = the 140x140 circle centered in the 260x260 window.
    _clickThrough = ClickThroughController(
      petBounds: () => const Rect.fromLTWH(60, 60, 140, 140),
    )..start();
  }

  @override
  void dispose() {
    _clickThrough.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Scaffold must be transparent too, or it repaints a solid background.
      backgroundColor: Colors.transparent,
      body: Center(
        child: GestureDetector(
          // Tap toggles color (proves clicks land); drag moves the window.
          onTap: () => setState(() {
            _color = _color == Colors.deepPurple ? Colors.teal : Colors.deepPurple;
          }),
          onPanStart: (_) => windowManager.startDragging(),
          child: Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
          ),
        ),
      ),
    );
  }
}
