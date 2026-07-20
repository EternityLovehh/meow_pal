import 'package:flutter/material.dart';

/// A rounded speech bubble above the pet that pops in (scale + fade) when text
/// appears and shrinks out when it clears. Pass null to hide.
class SpeechBubble extends StatefulWidget {
  const SpeechBubble({super.key, required this.text});

  final String? text;

  @override
  State<SpeechBubble> createState() => _SpeechBubbleState();
}

class _SpeechBubbleState extends State<SpeechBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _pop;
  String? _shown; // keep the last text visible while animating out

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
    _pop = CurvedAnimation(
      parent: _c,
      curve: Curves.easeOutBack, // slight overshoot = "pop"
      reverseCurve: Curves.easeIn,
    );
    _shown = widget.text;
    if (_shown != null) _c.value = 1;
  }

  @override
  void didUpdateWidget(SpeechBubble old) {
    super.didUpdateWidget(old);
    if (widget.text == old.text) return;
    if (widget.text != null) {
      setState(() => _shown = widget.text);
      _c.forward(from: 0);
    } else {
      _c.reverse(); // keep _shown during the exit animation
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        if (_shown == null || _c.value == 0) return const SizedBox.shrink();
        return Opacity(
          opacity: _c.value.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: 0.8 + 0.2 * _pop.value,
            alignment: Alignment.bottomCenter,
            child: _box(_shown!),
          ),
        );
      },
    );
  }

  Widget _box(String text) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 220),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 13,
          color: Color(0xFF222222),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
