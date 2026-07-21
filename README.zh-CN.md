# meow_pal 🐱

[English](README.md) · **简体中文**

一只用 Flutter 做的**跨平台桌面宠物猫**。它悬浮在桌面上陪着你,并到点温柔地
提醒你喝水、起身活动——全程只用不打扰的桌面表现(不发系统通知、不出声)。

## 功能

- 🐈‍⬛ 透明、永远置顶的猫,浮在所有窗口之上,可随意拖动。窗口除了猫本体,
  其余区域鼠标可**点击穿透**到底层。
- 👆 交互反应:**点击**是克制的"察觉"(弹簧驱动的轻颤 + 侧头),**拖动**可以
  拎着它到处走(会晃)。
- ⏰ **喝水 / 站立提醒**,间隔可自定义——到点时猫会有反应,冒出气泡和飘动的
  emoji 粒子。
- ✨ 没人理时会有**自发小动作**,让它像活的;还会**偶尔溜达**到屏幕另一处
  (一天几次)。
- ⚙️ **设置**(右键或长按猫打开):各提醒的开关和间隔,设置会本地持久化;
  也从这里退出。

## 操作

| 操作 | 效果 |
| --- | --- |
| 左键点击 | 触发反应 |
| 拖动 | 移动猫 |
| 右键 / 长按 | 打开设置 |

## 技术栈

- Flutter 桌面(macOS + Windows),Flutter 3.44+
- [`window_manager`](https://pub.dev/packages/window_manager) —— 透明、无边框、
  置顶窗口 + 点击穿透
- [`screen_retriever`](https://pub.dev/packages/screen_retriever) —— 光标 / 屏幕
  几何信息
- [`rive`](https://pub.dev/packages/rive) `^0.13` —— 猫的形象
- [`shared_preferences`](https://pub.dev/packages/shared_preferences) —— 设置持久化

反应都在 **Flutter 层**用代码做(弹簧物理、挤压拉伸),不依赖美术资源本身的
动画,所以**任何只有待机/静态的 `.riv` 都能直接用**。

## 运行

```bash
flutter pub get
flutter run -d macos      # 或:flutter run -d windows
```

> macOS 透明说明:猫渲染在无边框窗口里,并设了
> `flutterViewController.backgroundColor = .clear`(见
> `macos/Runner/MainFlutterWindow.swift`)。自 Flutter 3.7 起,不这么设的话
> 透明内容会被渲染成黑色。

## 替换宠物形象(换成你自己的)

宠物就是一个 Rive `.riv` 文件,反应是代码驱动的,所以**换成任何猫/生物都行**,
不用为每个素材单独接动画。

1. **找一个 `.riv`**(例如 [rive.app 社区](https://rive.app/community/files/))。
   尽量选授权宽松、且**画板本身没有背景块**的。
2. **放进项目**,覆盖 `assets/rive/cat.riv`(保持文件名;或到
   `lib/pet_view.dart` 改路径)。
3. **状态机名字**:代码加载的是 `'State Machine 1'`。如果你的不一样,改
   `lib/pet_view.dart` 里两处(`stateMachines: [...]` 和
   `StateMachineController.fromArtboard(artboard, '...')`)。在 Rive 编辑器里
   打开文件可查到名字。
4. **自带背景?** 在 Rive 编辑器里删掉;或在 `RiveCatController.onRiveInit`
   (`lib/pet_view.dart`)里按形状名在运行时隐藏:
   ```dart
   final bg = artboard.component<Shape>('BG'); // 换成你那个背景形状的名字
   bg?..scaleX = 0..scaleY = 0;
   ```
5. **更新署名**:改 `lib/settings_panel.dart` 里的授权/署名那行,以及下面的
   "署名与许可"。
6. **比例差很多?** 到 `lib/main.dart` 调点击区(`_petRect`)和猫的尺寸
   (`SizedBox`)。
7. **完整重启**(`flutter run`)——资源改动热重载不生效。

## 署名与许可

- 猫咪素材:**rive.app 社区**(marketplace `4014-8344`),许可 **CC BY 4.0**
  —— 应用的设置面板内已署名。
- 代码:请自行补充你选择的开源许可。
