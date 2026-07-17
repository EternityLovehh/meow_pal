# meow_pal MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a cross-platform Flutter desktop pet — an energetic cat that floats on the desktop, reacts to interaction, and gives non-intrusive water/stand/late-night reminders.

**Architecture:** A transparent, frameless, always-on-top Flutter window renders a Rive cat. Global cursor polling toggles click-through so only the cat body is interactive. A pure-logic behavior layer (scheduler + sensor + dialogue book) emits `PetEvent`s onto a stream; the view layer maps each event to a Rive animation state and a speech bubble. Settings persist locally and reconfigure the schedulers at runtime.

**Tech Stack:** Flutter (desktop), `window_manager` (window + click-through), `screen_retriever` (cursor position), `rive` (art + state machine), `tray_manager` (system tray), `shared_preferences` (settings persistence), platform channels (native idle-time: Swift on macOS, C++ on Windows).

## Global Constraints

- Platforms: macOS + Windows only (no mobile/web/linux targets in MVP).
- No system notifications, no sound — reminders are pure on-screen (bubble + animation).
- No autostart, no cloud/account, no AI chat, no feeding/leveling, no multi-pet.
- Sensing scope: time + local idle duration ONLY. Never read foreground app, screen content, or notifications.
- Dialogue: Chinese, hard-coded in the dialogue book; each event type has 3-5 lines rotated without immediate repeat.
- Default params (all editable in settings): water 45 min, stand 30 min, idle threshold 5 min, late-night threshold 23:30.
- Code comments in English. Conventional-commit messages. Commit after each task.
- Front-load the click-through risk: Task 1 is a standalone spike that must be manually verified on macOS before proceeding.

---

### Task 1: Scaffold project + transparent floating window with click-through (RISK SPIKE)

**Files:**
- Create: whole Flutter project at `~/AndroidStudioProjects/meow_pal` (already has `docs/`, `.git`)
- Create: `lib/main.dart`
- Create: `lib/window/pet_window.dart`
- Modify: `pubspec.yaml`

**Interfaces:**
- Produces: `configurePetWindow()` async fn (sets transparent/frameless/always-on-top/skip-taskbar); `ClickThroughController` class with `void start()` / `void dispose()` and constructor `ClickThroughController({required Rect Function() petBounds})` — polls cursor, toggles `setIgnoreMouseEvents`.

- [ ] **Step 1: Scaffold Flutter project into the existing directory**

Run:
```bash
cd ~/AndroidStudioProjects/meow_pal
flutter create --platforms=macos,windows --project-name meow_pal .
```
Expected: Flutter generates `lib/`, `macos/`, `windows/`, `pubspec.yaml` without deleting `docs/` or `.git`.

- [ ] **Step 2: Add dependencies**

Run:
```bash
flutter pub add window_manager screen_retriever
```
Then confirm `pubspec.yaml` lists `window_manager` and `screen_retriever` under dependencies. (Note: verify the resolved versions' APIs against `~/.pub-cache` READMEs — method names below are for current majors; adjust if `flutter pub get` pulls something different.)

- [ ] **Step 3: Write the window config helper**

Create `lib/window/pet_window.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

/// Configures the app window as a transparent, borderless, always-on-top
/// overlay suitable for a desktop pet. Call after windowManager.ensureInitialized().
Future<void> configurePetWindow() async {
  const options = WindowOptions(
    size: Size(260, 260),
    backgroundColor: Colors.transparent,
    skipTaskbar: true,
    titleBarStyle: TitleBarStyle.hidden,
    alwaysOnTop: true,
  );
  await windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.setAsFrameless();
    await windowManager.setBackgroundColor(Colors.transparent);
    await windowManager.setAlwaysOnTop(true);
    await windowManager.setSkipTaskbar(true);
    await windowManager.setResizable(false);
    await windowManager.show();
  });
}
```

- [ ] **Step 4: Write the click-through controller**

Append to `lib/window/pet_window.dart`:
```dart
import 'dart:async';
import 'dart:ui';
import 'package:screen_retriever/screen_retriever.dart';

/// Polls the global cursor position and enables mouse events only while the
/// cursor is over the pet's body rect; otherwise the whole (transparent)
/// window ignores the mouse so clicks pass through to whatever is behind it.
class ClickThroughController {
  ClickThroughController({required this.petBounds});

  /// Pet body rect in *logical window coordinates* (origin = window top-left).
  final Rect Function() petBounds;

  Timer? _timer;
  bool? _ignoring; // last applied state; null = unset

  void start() {
    _timer = Timer.periodic(const Duration(milliseconds: 80), (_) => _tick());
  }

  Future<void> _tick() async {
    final cursor = await screenRetriever.getCursorScreenPoint();
    final windowPos = await windowManager.getPosition();
    final local = Offset(cursor.dx - windowPos.dx, cursor.dy - windowPos.dy);
    final overPet = petBounds().contains(local);
    final shouldIgnore = !overPet;
    if (_ignoring != shouldIgnore) {
      _ignoring = shouldIgnore;
      await windowManager.setIgnoreMouseEvents(shouldIgnore, forward: true);
    }
  }

  void dispose() {
    _timer?.cancel();
  }
}
```

- [ ] **Step 5: Write a spike main that renders a draggable circle**

Create `lib/main.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'window/pet_window.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  await configurePetWindow();
  runApp(const SpikeApp());
}

class SpikeApp extends StatefulWidget {
  const SpikeApp({super.key});
  @override
  State<SpikeApp> createState() => _SpikeAppState();
}

class _SpikeAppState extends State<SpikeApp> with WindowListener {
  // Circle centered in a 260x260 window, radius 70.
  static const Rect _petRect = Rect.fromLTWH(60, 60, 140, 140);
  late final ClickThroughController _clickThrough;
  Color _color = Colors.deepPurple;

  @override
  void initState() {
    super.initState();
    _clickThrough = ClickThroughController(petBounds: () => _petRect)..start();
  }

  @override
  void dispose() {
    _clickThrough.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: GestureDetector(
            onTap: () => setState(() =>
                _color = _color == Colors.deepPurple ? Colors.teal : Colors.deepPurple),
            onPanStart: (_) => windowManager.startDragging(),
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 6: Run and MANUALLY VERIFY on macOS**

Run:
```bash
flutter run -d macos
```
Verify ALL of the following (this is the risk gate):
1. A circle floats with a fully transparent background (no white window box, no title bar).
2. The window stays above other windows.
3. Clicking the circle toggles its color (mouse events reach the pet).
4. Dragging the circle moves the whole window.
5. Clicking the transparent area around the circle passes through to the app behind (e.g., you can click a Finder icon showing through the corner).

If transparency shows a black/white box instead: check `macos/Runner/MainFlutterWindow.swift` — the window's `backgroundColor` may need `NSColor.clear` and `isOpaque = false`. Add a troubleshooting note and fix before continuing.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat: transparent always-on-top window with click-through spike"
```

---

### Task 2: Render the Rive cat + controllable state machine

**Files:**
- Create: `assets/rive/cat.riv` (placeholder from rive.app community — see step 1)
- Create: `lib/pet/rive_controller.dart`
- Create: `lib/pet/pet_view.dart`
- Modify: `pubspec.yaml` (rive dep + asset)
- Modify: `lib/main.dart` (swap circle for `PetView`)

**Interfaces:**
- Consumes: `configurePetWindow`, `ClickThroughController` from Task 1.
- Produces:
  - `PetVisualState` enum: `idle, happy, dragged, sleepy, remind, care, praise`.
  - `RiveCatController` with `void play(PetVisualState state)`, `RiveWidget get widget` (or exposes an `Artboard`), and knowledge of the state-machine input names.
  - `PetView` widget (constructor `PetView({required RiveCatController controller})`).

- [ ] **Step 1: Obtain a placeholder cat .riv and add it**

Manual: download a free, reusable cat character from rive.app/community with an idle animation. Save as `assets/rive/cat.riv`. Open it in the Rive editor and note the **state machine name** and its **input names** (e.g., a trigger per reaction, or a number input selecting a state). Record them in a comment at the top of `rive_controller.dart`. If no single asset has all 7 states, wire what exists and leave the rest mapping to `idle` for now.

Run:
```bash
flutter pub add rive
```

- [ ] **Step 2: Declare the asset**

In `pubspec.yaml` under `flutter:`, add:
```yaml
  assets:
    - assets/rive/cat.riv
```

- [ ] **Step 3: Write the Rive controller wrapper**

Create `lib/pet/rive_controller.dart`. Adjust the state-machine name and input lookups to match the actual `.riv` from Step 1:
```dart
import 'package:flutter/foundation.dart';
import 'package:rive/rive.dart';

enum PetVisualState { idle, happy, dragged, sleepy, remind, care, praise }

/// Wraps a Rive StateMachineController and exposes a single [play] entry point.
/// The behavior layer never touches Rive directly — it only asks for a state.
class RiveCatController {
  RiveCatController();

  StateMachineController? _sm;
  Artboard? _artboard;
  // Map each visual state to a state-machine trigger input name in cat.riv.
  // Replace these strings with the actual input names from the asset.
  static const Map<PetVisualState, String> _triggerNames = {
    PetVisualState.happy: 'happy',
    PetVisualState.dragged: 'dragged',
    PetVisualState.sleepy: 'sleepy',
    PetVisualState.remind: 'remind',
    PetVisualState.care: 'care',
    PetVisualState.praise: 'praise',
  };

  /// Called from RiveAnimation's onInit.
  void onRiveInit(Artboard artboard) {
    _artboard = artboard;
    final sm = StateMachineController.fromArtboard(artboard, 'State Machine 1');
    if (sm != null) {
      _artboard!.addController(sm);
      _sm = sm;
    }
  }

  void play(PetVisualState state) {
    if (_sm == null) return;
    if (state == PetVisualState.idle) return; // idle is the resting default
    final name = _triggerNames[state];
    if (name == null) return;
    final input = _sm!.findInput<bool>(name);
    if (input is SMITrigger) {
      input.fire();
    } else {
      if (kDebugMode) print('meow_pal: no trigger "$name" in state machine');
    }
  }
}
```

- [ ] **Step 4: Write the PetView widget**

Create `lib/pet/pet_view.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:rive/rive.dart';
import 'rive_controller.dart';

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
```

- [ ] **Step 5: Wire PetView into main, keep tap/drag + click-through**

Modify `lib/main.dart`: replace the `Container` circle with `PetView`, hold a `RiveCatController`, fire `happy` on tap:
```dart
// in _SpikeAppState:
final RiveCatController _cat = RiveCatController();
// ...
child: GestureDetector(
  onTap: () => _cat.play(PetVisualState.happy),
  onPanStart: (_) {
    _cat.play(PetVisualState.dragged);
    windowManager.startDragging();
  },
  child: SizedBox(width: 140, height: 140, child: PetView(controller: _cat)),
),
```
(Add the imports for `pet/pet_view.dart` and `pet/rive_controller.dart`.)

- [ ] **Step 6: Run and MANUALLY VERIFY**

Run: `flutter run -d macos`
Expected: the cat renders with a transparent background, idles by default, and tapping it fires a reaction animation (if the asset has one). Click-through around the cat still works.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat: render Rive cat with controllable state machine"
```

---

### Task 3: Dialogue book (pure logic, TDD)

**Files:**
- Create: `lib/behavior/pet_event.dart`
- Create: `lib/behavior/dialogue_book.dart`
- Test: `test/dialogue_book_test.dart`

**Interfaces:**
- Produces:
  - `enum PetEvent { tap, drag, idle, water, stand, lateNight, praise }`
  - `class DialogueBook { String? lineFor(PetEvent event); }` — returns a Chinese line (or null for events with no line, e.g. `drag` has lines, `idle` mostly silent). Never returns the same line twice in a row for the same event. Uses an injectable index picker for deterministic tests: constructor `DialogueBook({int Function(int max)? pick})`.

- [ ] **Step 1: Write the event enum**

Create `lib/behavior/pet_event.dart`:
```dart
/// Domain events the behavior layer emits. The view maps these to visuals+lines.
enum PetEvent { tap, drag, idle, water, stand, lateNight, praise }
```

- [ ] **Step 2: Write the failing test**

Create `test/dialogue_book_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_pal/behavior/pet_event.dart';
import 'package:meow_pal/behavior/dialogue_book.dart';

void main() {
  test('returns a non-empty line for tap', () {
    final book = DialogueBook();
    expect(book.lineFor(PetEvent.tap), isNotNull);
    expect(book.lineFor(PetEvent.tap)!.isNotEmpty, isTrue);
  });

  test('never repeats the same line twice in a row for one event', () {
    // pick always returns 0, but book must skip the just-used index.
    final book = DialogueBook(pick: (max) => 0);
    final first = book.lineFor(PetEvent.water);
    final second = book.lineFor(PetEvent.water);
    expect(first, isNotNull);
    expect(second, isNot(equals(first)));
  });

  test('water has at least 3 rotation lines', () {
    final book = DialogueBook(pick: (max) => 0);
    final seen = <String>{};
    for (var i = 0; i < 6; i++) {
      final l = book.lineFor(PetEvent.water);
      if (l != null) seen.add(l);
    }
    expect(seen.length, greaterThanOrEqualTo(3));
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/dialogue_book_test.dart`
Expected: FAIL — `DialogueBook` not defined.

- [ ] **Step 4: Implement DialogueBook**

Create `lib/behavior/dialogue_book.dart`:
```dart
import 'dart:math';
import 'pet_event.dart';

/// Maps a PetEvent to a Chinese line, rotating within each event's pool and
/// never repeating the immediately previous line for that event.
class DialogueBook {
  DialogueBook({int Function(int max)? pick})
      : _pick = pick ?? ((max) => Random().nextInt(max));

  final int Function(int max) _pick;
  final Map<PetEvent, int> _lastIndex = {};

  static const Map<PetEvent, List<String>> _pools = {
    PetEvent.tap: ['嗯哼~', '在的在的!', '摸鱼被我抓到啦😼', '喵?'],
    PetEvent.drag: ['喵呜——!', '放我下来啦~', '飞起来咯!'],
    PetEvent.idle: ['…zzz', '还在吗?'],
    PetEvent.water: ['该喝水啦!', '补个水,冲鸭💧', '干了这杯白开水!', '喉咙渴不渴呀~'],
    PetEvent.stand: ['站起来动动~', '久坐会变石雕哦!', '伸个懒腰,一起!', '起来走两步鸭!'],
    PetEvent.lateNight: ['这么晚啦,早点睡呀~🌙', '明天的你会感谢现在休息的你', '别熬啦,我先困了…'],
    PetEvent.praise: ['耶!你最棒!', '就知道你可以😽', '这波很可以!'],
  };

  String? lineFor(PetEvent event) {
    final pool = _pools[event];
    if (pool == null || pool.isEmpty) return null;
    if (pool.length == 1) return pool.first;
    var idx = _pick(pool.length);
    final last = _lastIndex[event];
    if (idx == last) idx = (idx + 1) % pool.length; // avoid immediate repeat
    _lastIndex[event] = idx;
    return pool[idx];
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/dialogue_book_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 6: Commit**

```bash
git add lib/behavior/pet_event.dart lib/behavior/dialogue_book.dart test/dialogue_book_test.dart
git commit -m "feat: dialogue book with no-immediate-repeat rotation"
```

---

### Task 4: Speech bubble UI

**Files:**
- Create: `lib/pet/speech_bubble.dart`
- Modify: `lib/main.dart` (overlay bubble above pet)

**Interfaces:**
- Produces: `SpeechBubble` widget — `SpeechBubble({required String? text})`; renders nothing when `text == null`, otherwise a rounded bubble. Auto-hide is driven by the caller clearing `text` (state held in main for now; PetBrain takes over in Task 8).

- [ ] **Step 1: Write the bubble widget**

Create `lib/pet/speech_bubble.dart`:
```dart
import 'package:flutter/material.dart';

class SpeechBubble extends StatelessWidget {
  const SpeechBubble({super.key, required this.text});
  final String? text;

  @override
  Widget build(BuildContext context) {
    if (text == null) return const SizedBox.shrink();
    return Container(
      constraints: const BoxConstraints(maxWidth: 220),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Text(text!, style: const TextStyle(fontSize: 13, color: Color(0xFF222222), fontWeight: FontWeight.w500)),
    );
  }
}
```
(Note: `withValues(alpha:)` is the current API; if the resolved Flutter version predates it, use `withOpacity`.)

- [ ] **Step 2: Show a bubble on tap in main (temporary wiring)**

Modify `lib/main.dart`: add `String? _bubble;`, a `Column` with `SpeechBubble(text: _bubble)` above the pet, and on tap set `_bubble` from a `DialogueBook` then clear it after 2.5s:
```dart
final DialogueBook _book = DialogueBook();
String? _bubble;
void _say(PetEvent event) {
  setState(() => _bubble = _book.lineFor(event));
  Future.delayed(const Duration(milliseconds: 2500), () {
    if (mounted) setState(() => _bubble = null);
  });
}
```
Wire `onTap` to call `_cat.play(PetVisualState.happy); _say(PetEvent.tap);`. Layout:
```dart
body: Center(
  child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
    SpeechBubble(text: _bubble),
    const SizedBox(height: 6),
    GestureDetector(/* ...pet... */),
  ]),
),
```

- [ ] **Step 3: Run and MANUALLY VERIFY**

Run: `flutter run -d macos`
Expected: tapping the cat shows a bubble that disappears after ~2.5s. Bubble does not block click-through when hidden.

- [ ] **Step 4: Commit**

```bash
git add lib/pet/speech_bubble.dart lib/main.dart
git commit -m "feat: speech bubble above pet"
```

---

### Task 5: Reminder scheduler (TDD with injected timers)

**Files:**
- Create: `lib/behavior/reminder_scheduler.dart`
- Test: `test/reminder_scheduler_test.dart`

**Interfaces:**
- Produces: `ReminderScheduler` — constructor `ReminderScheduler({required Duration water, required Duration stand})`; `Stream<PetEvent> get events`; `void start()`; `void updateIntervals({Duration? water, Duration? stand})`; `void dispose()`. Emits `PetEvent.water` every `water`, `PetEvent.stand` every `stand`. Uses `Stream.periodic` so `fakeAsync` can drive it deterministically.

- [ ] **Step 1: Write the failing test**

Create `test/reminder_scheduler_test.dart`:
```dart
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_pal/behavior/pet_event.dart';
import 'package:meow_pal/behavior/reminder_scheduler.dart';

void main() {
  test('emits water and stand events at their intervals', () {
    fakeAsync((async) {
      final s = ReminderScheduler(
        water: const Duration(minutes: 45),
        stand: const Duration(minutes: 30),
      );
      final got = <PetEvent>[];
      s.events.listen(got.add);
      s.start();

      async.elapse(const Duration(minutes: 30));
      expect(got, [PetEvent.stand]);

      async.elapse(const Duration(minutes: 15)); // t=45
      expect(got, [PetEvent.stand, PetEvent.water]);

      async.elapse(const Duration(minutes: 15)); // t=60
      expect(got, [PetEvent.stand, PetEvent.water, PetEvent.stand]);
      s.dispose();
    });
  });

  test('updateIntervals reschedules', () {
    fakeAsync((async) {
      final s = ReminderScheduler(
        water: const Duration(minutes: 45),
        stand: const Duration(minutes: 30),
      );
      final got = <PetEvent>[];
      s.events.listen(got.add);
      s.start();
      s.updateIntervals(stand: const Duration(minutes: 10));
      async.elapse(const Duration(minutes: 10));
      expect(got, contains(PetEvent.stand));
      s.dispose();
    });
  });
}
```
Add `fake_async` to dev deps: `flutter pub add --dev fake_async`.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/reminder_scheduler_test.dart`
Expected: FAIL — `ReminderScheduler` not defined.

- [ ] **Step 3: Implement the scheduler**

Create `lib/behavior/reminder_scheduler.dart`:
```dart
import 'dart:async';
import 'pet_event.dart';

/// Emits reminder PetEvents on fixed intervals. Intervals can be changed at
/// runtime; changing one resubscribes only that timer.
class ReminderScheduler {
  ReminderScheduler({required Duration water, required Duration stand})
      : _water = water,
        _stand = stand;

  Duration _water;
  Duration _stand;
  final _out = StreamController<PetEvent>.broadcast();
  StreamSubscription? _waterSub;
  StreamSubscription? _standSub;

  Stream<PetEvent> get events => _out.stream;

  void start() {
    _restartWater();
    _restartStand();
  }

  void _restartWater() {
    _waterSub?.cancel();
    _waterSub = Stream.periodic(_water).listen((_) => _out.add(PetEvent.water));
  }

  void _restartStand() {
    _standSub?.cancel();
    _standSub = Stream.periodic(_stand).listen((_) => _out.add(PetEvent.stand));
  }

  void updateIntervals({Duration? water, Duration? stand}) {
    if (water != null) { _water = water; _restartWater(); }
    if (stand != null) { _stand = stand; _restartStand(); }
  }

  void dispose() {
    _waterSub?.cancel();
    _standSub?.cancel();
    _out.close();
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/reminder_scheduler_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/behavior/reminder_scheduler.dart test/reminder_scheduler_test.dart pubspec.yaml
git commit -m "feat: reminder scheduler for water/stand intervals"
```

---

### Task 6: Activity sensor — native idle time + late-night logic

**Files:**
- Create: `lib/platform/idle_time.dart`
- Create: `lib/behavior/activity_sensor.dart`
- Modify: `macos/Runner/MainFlutterWindow.swift` (idle MethodChannel)
- Modify: `windows/runner/flutter_window.cpp` (idle MethodChannel)
- Test: `test/activity_sensor_test.dart`

**Interfaces:**
- Consumes: `PetEvent` from Task 3.
- Produces:
  - `class IdleTime { Future<Duration> sinceLastInput(); }` — MethodChannel `meow_pal/idle`, method `getIdleSeconds` returning a double (seconds).
  - `class ActivitySensor` — constructor `ActivitySensor({required Duration idleThreshold, required int lateNightHour, required int lateNightMinute, required Future<Duration> Function() readIdle, required DateTime Function() now})`; `Stream<PetEvent> get events`; `void start()`; `void dispose()`. Emits `PetEvent.idle` when idle crosses the threshold (once per idle period), `PetEvent.lateNight` at most once per calendar day when local time ≥ threshold. `readIdle`/`now` are injected for tests.

- [ ] **Step 1: Write the failing test (logic only, injected clock + idle reader)**

Create `test/activity_sensor_test.dart`:
```dart
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_pal/behavior/pet_event.dart';
import 'package:meow_pal/behavior/activity_sensor.dart';

void main() {
  test('emits idle once when idle exceeds threshold, again only after activity resets', () {
    fakeAsync((async) {
      var idle = Duration.zero;
      final sensor = ActivitySensor(
        idleThreshold: const Duration(minutes: 5),
        lateNightHour: 23, lateNightMinute: 30,
        readIdle: () async => idle,
        now: () => DateTime(2026, 7, 17, 14, 0),
      );
      final got = <PetEvent>[];
      sensor.events.listen(got.add);
      sensor.start();

      idle = const Duration(minutes: 6);
      async.elapse(const Duration(seconds: 15)); // one poll tick
      async.flushMicrotasks();
      expect(got.where((e) => e == PetEvent.idle).length, 1);

      async.elapse(const Duration(seconds: 30)); // still idle -> no repeat
      async.flushMicrotasks();
      expect(got.where((e) => e == PetEvent.idle).length, 1);

      idle = Duration.zero; // user came back
      async.elapse(const Duration(seconds: 15));
      idle = const Duration(minutes: 6); // idle again
      async.elapse(const Duration(seconds: 15));
      async.flushMicrotasks();
      expect(got.where((e) => e == PetEvent.idle).length, 2);
      sensor.dispose();
    });
  });

  test('emits lateNight at most once per day past threshold', () {
    fakeAsync((async) {
      var clock = DateTime(2026, 7, 17, 23, 45);
      final sensor = ActivitySensor(
        idleThreshold: const Duration(minutes: 5),
        lateNightHour: 23, lateNightMinute: 30,
        readIdle: () async => Duration.zero,
        now: () => clock,
      );
      final got = <PetEvent>[];
      sensor.events.listen(got.add);
      sensor.start();

      async.elapse(const Duration(seconds: 15));
      async.flushMicrotasks();
      expect(got.where((e) => e == PetEvent.lateNight).length, 1);

      async.elapse(const Duration(seconds: 30)); // same night, no repeat
      async.flushMicrotasks();
      expect(got.where((e) => e == PetEvent.lateNight).length, 1);
      sensor.dispose();
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/activity_sensor_test.dart`
Expected: FAIL — `ActivitySensor` not defined.

- [ ] **Step 3: Implement the sensor logic**

Create `lib/behavior/activity_sensor.dart`:
```dart
import 'dart:async';
import 'pet_event.dart';

/// Polls injected idle-reader and clock; emits idle/lateNight PetEvents.
class ActivitySensor {
  ActivitySensor({
    required this.idleThreshold,
    required this.lateNightHour,
    required this.lateNightMinute,
    required this.readIdle,
    required this.now,
    this.pollInterval = const Duration(seconds: 15),
  });

  final Duration idleThreshold;
  final int lateNightHour;
  final int lateNightMinute;
  final Future<Duration> Function() readIdle;
  final DateTime Function() now;
  final Duration pollInterval;

  final _out = StreamController<PetEvent>.broadcast();
  StreamSubscription? _sub;
  bool _idleAnnounced = false;
  int? _lateNightDayOfYear;

  Stream<PetEvent> get events => _out.stream;

  void start() {
    _sub = Stream.periodic(pollInterval).listen((_) => _poll());
  }

  Future<void> _poll() async {
    final idle = await readIdle();
    if (idle >= idleThreshold) {
      if (!_idleAnnounced) {
        _idleAnnounced = true;
        _out.add(PetEvent.idle);
      }
    } else {
      _idleAnnounced = false;
    }

    final t = now();
    final past = t.hour > lateNightHour ||
        (t.hour == lateNightHour && t.minute >= lateNightMinute);
    final doy = _dayOfYear(t);
    if (past && _lateNightDayOfYear != doy) {
      _lateNightDayOfYear = doy;
      _out.add(PetEvent.lateNight);
    }
  }

  int _dayOfYear(DateTime d) =>
      d.difference(DateTime(d.year)).inDays; // stable per calendar day

  void dispose() {
    _sub?.cancel();
    _out.close();
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/activity_sensor_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Write the IdleTime platform channel (Dart side)**

Create `lib/platform/idle_time.dart`:
```dart
import 'package:flutter/services.dart';

/// Reads system-wide seconds since the last user input via a native channel.
class IdleTime {
  static const _channel = MethodChannel('meow_pal/idle');

  Future<Duration> sinceLastInput() async {
    final seconds = await _channel.invokeMethod<double>('getIdleSeconds') ?? 0.0;
    return Duration(milliseconds: (seconds * 1000).round());
  }
}
```

- [ ] **Step 6: Implement the macOS native handler**

In `macos/Runner/MainFlutterWindow.swift`, inside `awakeFromNib()` after `RegisterGeneratedPlugins`, register the channel:
```swift
let controller = flutterViewController
let idleChannel = FlutterMethodChannel(
  name: "meow_pal/idle",
  binaryMessenger: controller.engine.binaryMessenger)
idleChannel.setMethodCallHandler { call, result in
  if call.method == "getIdleSeconds" {
    // Seconds since ANY input event (mouse/keyboard).
    let anyEvent = CGEventType(rawValue: ~0)!
    let seconds = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyEvent)
    result(seconds)
  } else {
    result(FlutterMethodNotImplemented)
  }
}
```
(Add `import CoreGraphics` if not present.)

- [ ] **Step 7: Implement the Windows native handler**

In `windows/runner/flutter_window.cpp`, after the engine registers plugins, add a method channel using the standard codec. Include headers `<windows.h>` and the Flutter method-channel headers, then:
```cpp
auto channel = std::make_unique<flutter::MethodChannel<>>(
    flutter_controller_->engine()->messenger(), "meow_pal/idle",
    &flutter::StandardMethodCodec::GetInstance());
channel->SetMethodCallHandler(
    [](const flutter::MethodCall<>& call,
       std::unique_ptr<flutter::MethodResult<>> result) {
      if (call.method_name() == "getIdleSeconds") {
        LASTINPUTINFO lii; lii.cbSize = sizeof(LASTINPUTINFO);
        GetLastInputInfo(&lii);
        double seconds = (GetTickCount() - lii.dwTime) / 1000.0;
        result->Success(flutter::EncodableValue(seconds));
      } else {
        result->NotImplemented();
      }
    });
// keep `channel` alive for the window's lifetime (store as a member).
```
(Store the channel as a member of `FlutterWindow` so it isn't destroyed. Adjust includes/types to match the generated Windows runner template.)

- [ ] **Step 8: MANUALLY VERIFY idle reading on macOS**

Temporarily print `await IdleTime().sinceLastInput()` on a 2s timer in `main`, run `flutter run -d macos`, stop touching the mouse/keyboard, and confirm the printed duration grows and resets when you move the mouse. Remove the temporary print after verifying.

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "feat: activity sensor with native idle-time channel (macos+windows)"
```

---

### Task 7: Settings model + persistence (TDD)

**Files:**
- Create: `lib/settings/settings.dart`
- Create: `lib/settings/settings_store.dart`
- Test: `test/settings_test.dart`
- Modify: `pubspec.yaml` (shared_preferences)

**Interfaces:**
- Produces:
  - `class Settings` — immutable: `bool waterEnabled, standEnabled, careEnabled; int waterMinutes, standMinutes, idleMinutes; int lateHour, lateMinute;` + `Settings copyWith(...)`, `Map<String,Object> toMap()`, `Settings.fromMap(Map)`, `Settings.defaults()` (water 45, stand 30, idle 5, late 23:30, all enabled).
  - `class SettingsStore { Future<Settings> load(); Future<void> save(Settings s); }` using `shared_preferences`.

- [ ] **Step 1: Add dependency**

Run: `flutter pub add shared_preferences`

- [ ] **Step 2: Write the failing test**

Create `test/settings_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_pal/settings/settings.dart';

void main() {
  test('defaults match the spec', () {
    final s = Settings.defaults();
    expect(s.waterMinutes, 45);
    expect(s.standMinutes, 30);
    expect(s.idleMinutes, 5);
    expect(s.lateHour, 23);
    expect(s.lateMinute, 30);
    expect(s.waterEnabled && s.standEnabled && s.careEnabled, isTrue);
  });

  test('round-trips through map', () {
    final s = Settings.defaults().copyWith(waterMinutes: 60, standEnabled: false);
    final back = Settings.fromMap(s.toMap());
    expect(back.waterMinutes, 60);
    expect(back.standEnabled, isFalse);
    expect(back.lateMinute, 30);
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/settings_test.dart`
Expected: FAIL — `Settings` not defined.

- [ ] **Step 4: Implement Settings**

Create `lib/settings/settings.dart`:
```dart
class Settings {
  const Settings({
    required this.waterEnabled,
    required this.standEnabled,
    required this.careEnabled,
    required this.waterMinutes,
    required this.standMinutes,
    required this.idleMinutes,
    required this.lateHour,
    required this.lateMinute,
  });

  final bool waterEnabled, standEnabled, careEnabled;
  final int waterMinutes, standMinutes, idleMinutes, lateHour, lateMinute;

  factory Settings.defaults() => const Settings(
        waterEnabled: true, standEnabled: true, careEnabled: true,
        waterMinutes: 45, standMinutes: 30, idleMinutes: 5,
        lateHour: 23, lateMinute: 30,
      );

  Settings copyWith({
    bool? waterEnabled, bool? standEnabled, bool? careEnabled,
    int? waterMinutes, int? standMinutes, int? idleMinutes, int? lateHour, int? lateMinute,
  }) => Settings(
        waterEnabled: waterEnabled ?? this.waterEnabled,
        standEnabled: standEnabled ?? this.standEnabled,
        careEnabled: careEnabled ?? this.careEnabled,
        waterMinutes: waterMinutes ?? this.waterMinutes,
        standMinutes: standMinutes ?? this.standMinutes,
        idleMinutes: idleMinutes ?? this.idleMinutes,
        lateHour: lateHour ?? this.lateHour,
        lateMinute: lateMinute ?? this.lateMinute,
      );

  Map<String, Object> toMap() => {
        'waterEnabled': waterEnabled, 'standEnabled': standEnabled, 'careEnabled': careEnabled,
        'waterMinutes': waterMinutes, 'standMinutes': standMinutes, 'idleMinutes': idleMinutes,
        'lateHour': lateHour, 'lateMinute': lateMinute,
      };

  factory Settings.fromMap(Map<String, Object?> m) {
    final d = Settings.defaults();
    return Settings(
      waterEnabled: m['waterEnabled'] as bool? ?? d.waterEnabled,
      standEnabled: m['standEnabled'] as bool? ?? d.standEnabled,
      careEnabled: m['careEnabled'] as bool? ?? d.careEnabled,
      waterMinutes: m['waterMinutes'] as int? ?? d.waterMinutes,
      standMinutes: m['standMinutes'] as int? ?? d.standMinutes,
      idleMinutes: m['idleMinutes'] as int? ?? d.idleMinutes,
      lateHour: m['lateHour'] as int? ?? d.lateHour,
      lateMinute: m['lateMinute'] as int? ?? d.lateMinute,
    );
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/settings_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 6: Implement SettingsStore**

Create `lib/settings/settings_store.dart`:
```dart
import 'package:shared_preferences/shared_preferences.dart';
import 'settings.dart';

/// Persists Settings to shared_preferences as individual keys.
class SettingsStore {
  static const _prefix = 'meow_pal.';

  Future<Settings> load() async {
    final p = await SharedPreferences.getInstance();
    final map = <String, Object?>{};
    for (final key in Settings.defaults().toMap().keys) {
      final v = p.get('$_prefix$key');
      if (v != null) map[key] = v;
    }
    return Settings.fromMap(map);
  }

  Future<void> save(Settings s) async {
    final p = await SharedPreferences.getInstance();
    s.toMap().forEach((k, v) {
      if (v is bool) p.setBool('$_prefix$k', v);
      if (v is int) p.setInt('$_prefix$k', v);
    });
  }
}
```

- [ ] **Step 7: Commit**

```bash
git add lib/settings/settings.dart lib/settings/settings_store.dart test/settings_test.dart pubspec.yaml
git commit -m "feat: settings model + shared_preferences persistence"
```

---

### Task 8: PetBrain — wire events to visuals + bubble

**Files:**
- Create: `lib/behavior/pet_brain.dart`
- Rewrite: `lib/main.dart` (production wiring; remove spike temporaries)

**Interfaces:**
- Consumes: `ReminderScheduler`, `ActivitySensor`, `IdleTime`, `DialogueBook`, `RiveCatController`, `PetVisualState`, `PetEvent`, `Settings`, `SettingsStore`.
- Produces: `class PetBrain extends ChangeNotifier` — holds current `String? bubbleText`; method `void handle(PetEvent event)` (maps event → RiveCatController.play + dialogue line + bubble auto-clear timer); method `void onUserTapAfterReminder()` → emits `praise`; `void applySettings(Settings)`; wires scheduler+sensor streams (respecting enable flags); `void dispose()`. Mapping `PetEvent → PetVisualState`: tap→happy, drag→dragged, idle→sleepy, water→remind, stand→remind, lateNight→care, praise→praise.

- [ ] **Step 1: Implement PetBrain**

Create `lib/behavior/pet_brain.dart`:
```dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../pet/rive_controller.dart';
import '../settings/settings.dart';
import 'activity_sensor.dart';
import 'dialogue_book.dart';
import 'pet_event.dart';
import 'reminder_scheduler.dart';

class PetBrain extends ChangeNotifier {
  PetBrain({
    required this.cat,
    required this.scheduler,
    required this.sensor,
    required this.book,
    required Settings settings,
  }) : _settings = settings;

  final RiveCatController cat;
  final ReminderScheduler scheduler;
  final ActivitySensor sensor;
  final DialogueBook book;
  Settings _settings;

  String? bubbleText;
  Timer? _bubbleTimer;
  StreamSubscription? _schedSub;
  StreamSubscription? _sensorSub;

  static const _visual = {
    PetEvent.tap: PetVisualState.happy,
    PetEvent.drag: PetVisualState.dragged,
    PetEvent.idle: PetVisualState.sleepy,
    PetEvent.water: PetVisualState.remind,
    PetEvent.stand: PetVisualState.remind,
    PetEvent.lateNight: PetVisualState.care,
    PetEvent.praise: PetVisualState.praise,
  };

  void start() {
    _schedSub = scheduler.events.listen(_onScheduled);
    _sensorSub = sensor.events.listen(_onScheduled);
    scheduler.start();
    sensor.start();
  }

  void _onScheduled(PetEvent event) {
    if (event == PetEvent.water && !_settings.waterEnabled) return;
    if (event == PetEvent.stand && !_settings.standEnabled) return;
    if (event == PetEvent.lateNight && !_settings.careEnabled) return;
    handle(event);
  }

  void handle(PetEvent event) {
    cat.play(_visual[event] ?? PetVisualState.idle);
    final line = book.lineFor(event);
    if (line != null) _showBubble(line);
  }

  void onUserTapAfterReminder() => handle(PetEvent.praise);

  void _showBubble(String text) {
    bubbleText = text;
    notifyListeners();
    _bubbleTimer?.cancel();
    _bubbleTimer = Timer(const Duration(milliseconds: 3000), () {
      bubbleText = null;
      notifyListeners();
    });
  }

  void applySettings(Settings s) {
    _settings = s;
    scheduler.updateIntervals(
      water: Duration(minutes: s.waterMinutes),
      stand: Duration(minutes: s.standMinutes),
    );
  }

  @override
  void dispose() {
    _bubbleTimer?.cancel();
    _schedSub?.cancel();
    _sensorSub?.cancel();
    super.dispose();
  }
}
```

- [ ] **Step 2: Rewrite main.dart to production wiring**

Rewrite `lib/main.dart` to: init window, load settings, build the controllers/sensor/scheduler/brain, render `SpeechBubble` (driven by `PetBrain.bubbleText` via `AnimatedBuilder`/`ListenableBuilder`) above `PetView`, tap→`brain.handle(PetEvent.tap)`, drag→`cat.play(dragged)` + `windowManager.startDragging()`, and start `ClickThroughController`. Build `ActivitySensor` with `readIdle: IdleTime().sinceLastInput`, `now: DateTime.now`, thresholds from settings.
```dart
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'window/pet_window.dart';
import 'pet/pet_view.dart';
import 'pet/rive_controller.dart';
import 'pet/speech_bubble.dart';
import 'platform/idle_time.dart';
import 'behavior/pet_event.dart';
import 'behavior/pet_brain.dart';
import 'behavior/dialogue_book.dart';
import 'behavior/reminder_scheduler.dart';
import 'behavior/activity_sensor.dart';
import 'settings/settings_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  await configurePetWindow();
  final settings = await SettingsStore().load();

  final cat = RiveCatController();
  final scheduler = ReminderScheduler(
    water: Duration(minutes: settings.waterMinutes),
    stand: Duration(minutes: settings.standMinutes),
  );
  final sensor = ActivitySensor(
    idleThreshold: Duration(minutes: settings.idleMinutes),
    lateNightHour: settings.lateHour, lateNightMinute: settings.lateMinute,
    readIdle: IdleTime().sinceLastInput, now: DateTime.now,
  );
  final brain = PetBrain(cat: cat, scheduler: scheduler, sensor: sensor,
      book: DialogueBook(), settings: settings)..start();

  runApp(MeowPalApp(cat: cat, brain: brain));
}

class MeowPalApp extends StatefulWidget {
  const MeowPalApp({super.key, required this.cat, required this.brain});
  final RiveCatController cat;
  final PetBrain brain;
  @override
  State<MeowPalApp> createState() => _MeowPalAppState();
}

class _MeowPalAppState extends State<MeowPalApp> {
  static const Rect _petRect = Rect.fromLTWH(60, 90, 140, 140);
  late final ClickThroughController _clickThrough =
      ClickThroughController(petBounds: () => _petRect)..start();

  @override
  void dispose() {
    _clickThrough.dispose();
    widget.brain.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
            ListenableBuilder(
              listenable: widget.brain,
              builder: (_, __) => SpeechBubble(text: widget.brain.bubbleText),
            ),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () => widget.brain.handle(PetEvent.tap),
              onPanStart: (_) {
                widget.cat.play(PetVisualState.dragged);
                windowManager.startDragging();
              },
              child: SizedBox(width: 140, height: 140,
                  child: PetView(controller: widget.cat)),
            ),
          ]),
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Run full test suite + MANUALLY VERIFY end-to-end**

Run: `flutter test` (all logic tests pass), then `flutter run -d macos`.
Verify: cat idles; tapping reacts + bubble; leaving it idle >5 min (or temporarily lower `idleMinutes`) triggers sleepy + occasional line; temporarily set water interval to 1 min to confirm the reminder fires with animation + bubble.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat: PetBrain wiring events to visuals and speech bubble"
```

---

### Task 9: Settings window

**Files:**
- Create: `lib/settings/settings_window.dart`
- Modify: `lib/main.dart` (route/open settings; multi-window or dialog)

**Interfaces:**
- Consumes: `Settings`, `SettingsStore`, `PetBrain`.
- Produces: `SettingsPanel` widget — shows switches (water/stand/care) + sliders (water 15-120, stand 10-120, idle 1-30 min); on change, calls `SettingsStore().save(next)` and `brain.applySettings(next)`. Opened as an in-window overlay panel toggled by a boolean (simplest; avoids multi-window complexity in MVP).

- [ ] **Step 1: Build the settings panel**

Create `lib/settings/settings_window.dart` with a `SettingsPanel({required Settings initial, required ValueChanged<Settings> onChanged, required VoidCallback onClose})` — a `Card` with `SwitchListTile`s and `Slider`s, each rebuilding local state and calling `onChanged`. (Full widget code: switches bound to `waterEnabled/standEnabled/careEnabled`; sliders bound to minutes with `divisions` and labels; a close button calling `onClose`.)

- [ ] **Step 2: Toggle the panel from main**

In `_MeowPalAppState`: add `bool _showSettings = false;` and a small gear `IconButton` (only visible on hover over the pet, or always in a corner). When shown, overlay `SettingsPanel` in a `Stack`. Wire `onChanged` to persist + `brain.applySettings`. Ensure the settings panel area is included in `_petRect` (or expand click-through bounds while open) so it's interactive.

- [ ] **Step 3: Run and MANUALLY VERIFY**

Run: `flutter run -d macos`. Open settings, toggle water off → confirm no water reminder fires; change stand slider → confirm cadence changes; reopen app → confirm settings persisted.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat: settings panel with live-apply and persistence"
```

---

### Task 10: System tray (open settings / quit)

**Files:**
- Create: `lib/tray/tray.dart`
- Modify: `lib/main.dart` (init tray; wire menu actions)
- Add: a small tray icon asset (e.g. `assets/icons/tray.png`) + declare it

**Interfaces:**
- Consumes: callbacks for "open settings" and "quit".
- Produces: `class PetTray { Future<void> init({required VoidCallback onOpenSettings, required Future<void> Function() onQuit}); }` using `tray_manager` (`TrayManager` + `Menu`/`MenuItem`, `onTrayMenuItemClick`).

- [ ] **Step 1: Add dependency + icon**

Run: `flutter pub add tray_manager`. Add `assets/icons/tray.png` (a simple monochrome paw/cat, 22px) and declare it in `pubspec.yaml`.

- [ ] **Step 2: Implement PetTray**

Create `lib/tray/tray.dart` registering a tray icon and a context menu with items `open_settings` and `quit`; implement `TrayListener.onTrayMenuItemClick` to route to the injected callbacks. `onQuit` calls `windowManager.destroy()`.

- [ ] **Step 3: Init tray in main**

In `main`, after building `brain`, `await PetTray().init(onOpenSettings: () => /* set _showSettings=true via a global key or callback */, onQuit: () async => windowManager.destroy());`.

- [ ] **Step 4: Run and MANUALLY VERIFY (macOS + Windows)**

Run on macOS then Windows: confirm tray icon appears, "Open Settings" shows the panel, "Quit" exits the app cleanly. This is also the Windows parity checkpoint — verify Task 1's transparency/click-through, Task 6's idle reading, and reminders all work on Windows; fix platform gaps here.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: system tray with open-settings and quit"
```

---

## Self-Review

**Spec coverage:**
- Floating/transparent/always-on-top/draggable → Task 1 ✅
- Rive cat + states → Task 2 ✅
- Tap/drag/idle interactions → Tasks 1,2,6,8 ✅
- Water + stand reminders (on-screen only) → Tasks 5,8 ✅
- Late-night care → Tasks 6,8 ✅
- Settings (toggles/intervals/care) + persistence → Tasks 7,9 ✅
- Cross-platform macOS+Windows → Tasks 1,6,10 ✅
- System tray (no autostart) → Task 10 ✅
- Dialogue: Chinese, 3-5 lines, no immediate repeat → Task 3 ✅
- Out-of-scope items → none implemented ✅

**Placeholder scan:** Tasks 9 and 10 describe some widget code prose-style rather than full code blocks (settings sliders, tray menu). These are conventional Flutter widgets; the implementer should write them out fully during execution. All logic-layer tasks (3,5,6,7,8) contain complete code.

**Type consistency:** `PetEvent`/`PetVisualState` names consistent across Tasks 3,2,8. `Settings` fields consistent across 7,8,9. `RiveCatController.play`, `ReminderScheduler.updateIntervals`, `ActivitySensor` constructor consistent across producer/consumer tasks.

**Known verification points (API certainty):** window_manager method names (Task 1), Rive state-machine input API (Task 2), tray_manager API (Task 10), and native idle snippets (Task 6) should be checked against the resolved package versions / platform runner templates during execution, as flagged inline.
