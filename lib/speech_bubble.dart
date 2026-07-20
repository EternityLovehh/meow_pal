import 'package:flutter/material.dart';

/// A small rounded speech bubble shown above the pet.
/// Renders nothing when [text] is null.
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
        text!,
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
