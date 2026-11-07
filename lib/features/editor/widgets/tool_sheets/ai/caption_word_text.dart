import 'package:flutter/material.dart';
import 'package:flutter_video_editor/core/models/project_model.dart';

/// Renders one caption with word-by-word highlight, stroke, glow, shadow,
/// background box and entrance animation. Use it in the video preview and
/// anywhere else captions are drawn so the sheet and the output always match.
///
/// [captionKey] should change whenever the visible caption changes (for
/// example the clip id) so the entrance animation replays.
class CaptionWordText extends StatelessWidget {
  const CaptionWordText({
    super.key,
    required this.text,
    required this.highlightIndex,
    required this.style,
    required this.captionKey,
    this.scale = 1.0,
  });

  final String text;

  /// Index of the word being spoken, or -1 for none.
  final int highlightIndex;
  final TextStyleProperties style;
  final Object captionKey;

  /// Multiplier for the font size (preview vs. export resolution).
  final double scale;

  @override
  Widget build(BuildContext context) {
    final words = text.split(' ').where((w) => w.isNotEmpty).toList();

    final box = Container(
      padding: style.boxOpacity > 0
          ? const EdgeInsets.symmetric(horizontal: 10, vertical: 4)
          : EdgeInsets.zero,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: style.boxOpacity),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6 * scale,
        runSpacing: 2 * scale,
        children: [
          for (var i = 0; i < words.length; i++)
            _word(words[i], highlighted: style.enableHighlight && i == highlightIndex),
        ],
      ),
    );

    return _Entrance(
      key: ValueKey<Object>(captionKey),
      animation: style.animation,
      child: box,
    );
  }

  Widget _word(String word, {required bool highlighted}) {
    final shadows = <Shadow>[
      if (style.shadow)
        const Shadow(color: Color(0xD9000000), blurRadius: 4, offset: Offset(0, 2)),
      if (style.glowRadius > 0)
        Shadow(color: style.glowColor, blurRadius: style.glowRadius),
      if (highlighted && style.highlightStyle == 'outline')
        Shadow(color: style.highlightColor, blurRadius: 12),
    ];

    // Colorless base so it can be reused for both the stroke and fill layers.
    final base = TextStyle(
      fontSize: style.fontSize * scale,
      fontWeight: style.bold ? FontWeight.w700 : FontWeight.w400,
      fontFamily: style.fontFamily.isEmpty ? null : style.fontFamily,
      height: 1.2,
      shadows: shadows.isEmpty ? null : shadows,
    );

    final fill = highlighted ? style.highlightColor : style.textColor;

    Widget text = Text(word, style: base.copyWith(color: fill));

    if (style.strokeWidth > 0) {
      text = Stack(
        children: [
          Text(
            word,
            style: base.copyWith(
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = style.strokeWidth * 2 * scale
                ..strokeJoin = StrokeJoin.round
                ..color = style.strokeColor,
            ),
          ),
          text,
        ],
      );
    }

    if (highlighted && style.highlightStyle == 'badge') {
      final bg = style.highlightBackgroundColor;
      if (bg.a > 0) {
        text = Container(
          padding: EdgeInsets.symmetric(horizontal: 6 * scale),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(4),
          ),
          child: text,
        );
      }
    }

    if (highlighted && style.highlightStyle == 'scale') {
      text = Transform.scale(scale: 1.18, child: text);
    }

    return text;
  }
}

class _Entrance extends StatelessWidget {
  const _Entrance({super.key, required this.animation, required this.child});

  final String animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (animation == 'none') return child;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
      child: child,
      builder: (context, t, child) {
        switch (animation) {
          case 'pop':
            return Opacity(
              opacity: t,
              child: Transform.scale(scale: 0.6 + 0.4 * t, child: child),
            );
          case 'slide':
            return Opacity(
              opacity: t,
              child: Transform.translate(
                offset: Offset(0, 18 * (1 - t)),
                child: child,
              ),
            );
          case 'zoom':
            return Opacity(
              opacity: t,
              child: Transform.scale(scale: 1.5 - 0.5 * t, child: child),
            );
          case 'fade':
          default:
            return Opacity(opacity: t, child: child);
        }
      },
    );
  }
}