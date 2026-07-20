/// Which built-in animation a reaction plays.
enum ReactionAnim { bounce, wiggle }

/// A data-driven reaction: an optional animation, a pool of lines to speak,
/// and an optional particle emoji. This is the single place that describes
/// "what the cat does" for a given trigger.
class Reaction {
  const Reaction({
    this.anim,
    this.lines = const <String>[],
    this.emoji,
    this.particleCount = 5,
  });

  final ReactionAnim? anim;
  final List<String> lines;
  final String? emoji;
  final int particleCount;
}

/// All reactions in one table. Add a new behavior here — not scattered across
/// the widget code.
abstract final class Reactions {
  static const Reaction tap = Reaction(
    anim: ReactionAnim.bounce,
    lines: <String>['嗯哼~', '在的在的!', '摸鱼被我抓到啦😼', '喵?'],
    emoji: '❤️',
  );

  static const Reaction drag = Reaction(
    anim: ReactionAnim.wiggle,
    lines: <String>['喵呜——!', '放我下来啦~', '飞起来咯!', '晕…别晃我啦~'],
    emoji: '💫',
    particleCount: 4,
  );

  static const Reaction water = Reaction(
    anim: ReactionAnim.bounce,
    lines: <String>['该喝水啦!', '补个水,冲鸭💧', '干了这杯白开水!', '喉咙渴不渴呀~'],
    emoji: '💧',
  );

  static const Reaction stand = Reaction(
    anim: ReactionAnim.bounce,
    lines: <String>['站起来动动~', '久坐会变石雕哦!', '伸个懒腰,一起!', '起来走两步鸭!'],
    emoji: '✨',
  );

  // Spontaneous idle micro-actions (played when the user leaves it alone).
  static const Reaction idleBounce = Reaction(anim: ReactionAnim.bounce);
  static const Reaction idleWiggle = Reaction(anim: ReactionAnim.wiggle);
  static const Reaction idleQuip = Reaction(
    lines: <String>['喵~', '在忙吗?', '(打了个哈欠)', '陪陪我嘛~', '发会儿呆…'],
    emoji: '💤',
    particleCount: 3,
  );
}
