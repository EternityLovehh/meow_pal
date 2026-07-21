# meow_pal 🐱

**English** · [简体中文](README.zh-CN.md)

A cross-platform **desktop pet cat**, built with Flutter. It floats on your
desktop, keeps you company, and nudges you to drink water and stand up — all
with gentle, non-intrusive on-screen reactions (no system notifications, no
sound).

## Features

- 🐈‍⬛ A transparent, always-on-top cat that floats over everything and can be
  dragged anywhere. The window is click-through everywhere except the cat.
- 👆 Reactions: **click** for a subtle "notice" (a spring-driven perk + head
  tilt), **drag** to carry it around (it swings).
- ⏰ **Water / stand reminders** on your own schedule — the cat reacts with a
  speech bubble and floating emoji particles.
- ✨ Idle micro-actions so it feels alive when left alone, plus an occasional
  stroll to a new spot on screen (a few times a day).
- ⚙️ **Settings** (right-click or long-press the cat): toggle each reminder and
  set its interval. Settings persist locally. Quit from here too.

## Controls

| Action | Result |
| --- | --- |
| Left-click | pet reaction |
| Drag | move the cat |
| Right-click / long-press | open settings |

## Tech

- Flutter desktop (macOS + Windows), Flutter 3.44+
- [`window_manager`](https://pub.dev/packages/window_manager) — transparent,
  borderless, always-on-top window + click-through
- [`screen_retriever`](https://pub.dev/packages/screen_retriever) — cursor /
  display geometry
- [`rive`](https://pub.dev/packages/rive) `^0.13` — the cat art
- [`shared_preferences`](https://pub.dev/packages/shared_preferences) — settings

Reactions are done at the Flutter layer (spring physics, squash & stretch)
rather than in the art, so any static/idle `.riv` works.

## Run

```bash
flutter pub get
flutter run -d macos      # or: flutter run -d windows
```

> macOS transparency note: the cat is rendered in a borderless window with
> `flutterViewController.backgroundColor = .clear` (see
> `macos/Runner/MainFlutterWindow.swift`). Since Flutter 3.7 this is required
> or transparent content renders black.

## Replace the pet (use your own art)

The pet is just a Rive `.riv` file, and reactions are code-driven, so any
cat/creature works — no per-asset animation wiring needed.

1. **Get a `.riv`** (e.g. from the [rive.app community](https://rive.app/community/files/)).
   Prefer a permissive license and an artboard **without a baked background**.
2. **Drop it in** as `assets/rive/cat.riv` (overwrite). Keep the filename, or
   change the path in `lib/pet_view.dart`.
3. **State-machine name:** the code loads `'State Machine 1'`. If yours differs,
   update both spots in `lib/pet_view.dart` (`stateMachines: [...]` and
   `StateMachineController.fromArtboard(artboard, '...')`). Open the file in the
   Rive editor to find the name.
4. **Baked background?** Remove it in the Rive editor, or hide it at load time
   by shape name in `RiveCatController.onRiveInit` (`lib/pet_view.dart`):
   ```dart
   final bg = artboard.component<Shape>('BG'); // your shape's name
   bg?..scaleX = 0..scaleY = 0;
   ```
5. **Update attribution:** the license/credit line in `lib/settings_panel.dart`
   and the Credits section below.
6. **Different proportions?** Tweak the clickable area (`_petRect`) and the cat
   size (`SizedBox`) in `lib/main.dart`.
7. **Cold-rebuild** (`flutter run`) — asset changes aren't picked up by hot reload.

## Credits & license

- Cat art: **rive.app community** (marketplace `4014-8344`), licensed
  **CC BY 4.0** — attribution shown in the app's settings panel.
- Code: add your preferred license.
