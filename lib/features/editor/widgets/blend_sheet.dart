import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:flutter_video_editor/core/models/project_model.dart';
import 'package:flutter_video_editor/features/editor/controllers/editor_controller.dart';
import 'package:flutter_video_editor/features/editor/utils/editor_helpers.dart';

const Color _bkBg = bgToken;
const Color _bkCard = Color(0xFF1C1C1E);
const Color _bkText = Color(0xFFFFFFFF);
const Color _bkMuted = Color(0xFF8E8E93);
const Color _bkDim = Color(0xFF48484A);
const Color _bkAccent = Color(0xFF25F4EE);

const double _tileBox = 52;
const double _tileW = 58;

String _bkCap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

// ============================================================================
// ASSUMED MODEL (add to project_model.dart if you don't have it yet):
//
//   enum BlendType { normal, darken, multiply, colorBurn, lighten, screen,
//                    colorDodge, overlay, softLight, hardLight, difference,
//                    exclusion }
//
//   class BlendProperties {
//     const BlendProperties({this.type = BlendType.normal, this.opacity = 1.0});
//     final BlendType type;
//     final double opacity; // 0..1
//     bool get isActive => type != BlendType.normal;
//     BlendProperties copyWith({BlendType? type, double? opacity}) =>
//         BlendProperties(type: type ?? this.type, opacity: opacity ?? this.opacity);
//   }
//
//   ClipModel.blendProperties            (default const BlendProperties())
//   EditorController.updateBlendProperties(BlendProperties)
//
// Render side: wrap the clip layer with
//   Opacity(opacity: b.opacity, child: ColorFiltered(
//     colorFilter: ColorFilter.mode(Colors.transparent, flutterBlendMode(b.type)), ...
// or paint it in a saveLayer with Paint()..blendMode = flutterBlendMode(b.type).
// ============================================================================

BlendMode flutterBlendMode(BlendType t) {
  switch (t) {
    case BlendType.normal:
      return BlendMode.srcOver;
    case BlendType.darken:
      return BlendMode.darken;
    case BlendType.multiply:
      return BlendMode.multiply;
    case BlendType.colorBurn:
      return BlendMode.colorBurn;
    case BlendType.lighten:
      return BlendMode.lighten;
    case BlendType.screen:
      return BlendMode.screen;
    case BlendType.colorDodge:
      return BlendMode.colorDodge;
    case BlendType.overlay:
      return BlendMode.overlay;
    case BlendType.softLight:
      return BlendMode.softLight;
    case BlendType.hardLight:
      return BlendMode.hardLight;
    case BlendType.difference:
      return BlendMode.difference;
    case BlendType.exclusion:
      return BlendMode.exclusion;
  }
}

String _blendLabel(BlendType t) {
  switch (t) {
    case BlendType.colorBurn:
      return 'Burn';
    case BlendType.colorDodge:
      return 'Dodge';
    case BlendType.softLight:
      return 'Soft';
    case BlendType.hardLight:
      return 'Hard';
    case BlendType.difference:
      return 'Diff';
    default:
      return _bkCap(t.name);
  }
}

// ============================================================================
// Bottom bar:  opacity slider row, then  Normal, Darken, Multiply, ...
// The real player shows the result. The clip's BlendProperties is the single
// source of truth, so the sheet keeps no local copy of the state.
// ============================================================================
class BlendSheet extends StatelessWidget {
  const BlendSheet({super.key});

  BlendProperties _props(EditorController e) =>
      e.selectedClip?.blendProperties ?? const BlendProperties();

  @override
  Widget build(BuildContext context) {
    final EditorController editor = context.watch<EditorController>();
    final BlendProperties p = _props(editor);

    return ColoredBox(
      color: _bkBg,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          _OpacityRow(
            value: p.opacity,
            onChanged: (double v) =>
                editor.updateBlendProperties(p.copyWith(opacity: v)),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 78,
            child: Stack(
              children: <Widget>[
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      for (int i = 0; i < BlendType.values.length; i++) ...<Widget>[
                        if (i > 0) const SizedBox(width: 8),
                        _BlendTile(
                          label: _blendLabel(BlendType.values[i]),
                          type: BlendType.values[i],
                          selected: BlendType.values[i] == p.type,
                          onTap: () {
                            tapFeedback();
                            editor.updateBlendProperties(
                                p.copyWith(type: BlendType.values[i]));
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                // Soft fade on the right edge: hints that the list scrolls.
                Positioned(
                  top: 0,
                  bottom: 0,
                  right: 0,
                  width: 24,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: <Color>[_bkBg.withValues(alpha: 0), _bkBg],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// Opacity row
// ----------------------------------------------------------------------------
class _OpacityRow extends StatelessWidget {
  const _OpacityRow({required this.value, required this.onChanged});
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: Row(
        children: <Widget>[
          const SizedBox(width: 16),
          const Text(
            'Opacity',
            style: TextStyle(
              color: _bkMuted,
              fontSize: 11,
              fontFamily: 'Fredoka',
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                activeTrackColor: _bkAccent,
                inactiveTrackColor: _bkDim,
                thumbColor: _bkAccent,
                overlayColor: _bkAccent.withValues(alpha: 0.14),
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
              ),
              child: Slider(
                value: value.clamp(0.0, 1.0),
                onChanged: onChanged,
              ),
            ),
          ),
          SizedBox(
            width: 44,
            child: Text(
              '${(value * 100).round()}%',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _bkText,
                fontSize: 11,
                fontFamily: 'Fredoka',
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// Tile
// ----------------------------------------------------------------------------
class _BlendTile extends StatelessWidget {
  const _BlendTile({
    required this.label,
    required this.type,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final BlendType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color fg = selected ? _bkAccent : _bkMuted;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: _tileW,
          child: Column(
            children: <Widget>[
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: _tileBox,
                height: _tileBox,
                decoration: BoxDecoration(
                  color: selected ? _bkAccent.withValues(alpha: 0.14) : _bkCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected ? _bkAccent : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(13),
                  child: CustomPaint(painter: _BlendIconPainter(type: type, color: fg)),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                label,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.fade,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected ? _bkText : fg,
                  fontSize: 11,
                  fontFamily: 'Fredoka',
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Two overlapping circles. The lens where they overlap is painted differently
// per mode, so each tile hints at what the blend does.
class _BlendIconPainter extends CustomPainter {
  _BlendIconPainter({required this.type, required this.color});
  final BlendType type;
  final Color color;

  // Overlap alpha per mode: dark modes sink, light modes glow.
  double get _lens {
    switch (type) {
      case BlendType.normal:
        return 0.0; // handled separately (top circle covers)
      case BlendType.darken:
      case BlendType.multiply:
      case BlendType.colorBurn:
        return 0.85;
      case BlendType.lighten:
      case BlendType.screen:
      case BlendType.colorDodge:
        return 0.30;
      case BlendType.overlay:
      case BlendType.softLight:
      case BlendType.hardLight:
        return 0.55;
      case BlendType.difference:
      case BlendType.exclusion:
        return 0.0; // outlined only, "knocked out"
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double d = size.width * 0.66;
    final double rad = d / 2;
    final Offset c1 = Offset(rad, size.height / 2 - size.height * 0.0);
    final Offset c2 = Offset(size.width - rad, size.height / 2);

    final Paint line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final Paint soft = Paint()..color = color.withValues(alpha: 0.22);

    final Path a = Path()..addOval(Rect.fromCircle(center: c1, radius: rad));
    final Path b = Path()..addOval(Rect.fromCircle(center: c2, radius: rad));
    final Path lens = Path.combine(PathOperation.intersect, a, b);

    if (type == BlendType.normal) {
      // Back circle faint, front circle solid-ish: the top layer simply covers.
      canvas.drawPath(a, soft);
      canvas.drawPath(b, Paint()..color = color.withValues(alpha: 0.6));
      canvas.drawPath(a, line);
      canvas.drawPath(b, line);
      return;
    }

    canvas.drawPath(a, soft);
    canvas.drawPath(b, soft);
    if (_lens > 0) {
      canvas.drawPath(lens, Paint()..color = color.withValues(alpha: _lens));
    }
    canvas.drawPath(a, line);
    canvas.drawPath(b, line);

    if (type == BlendType.difference || type == BlendType.exclusion) {
      // Knocked-out lens: thicker outline, no fill.
      canvas.drawPath(
        lens,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = type == BlendType.difference ? 2.6 : 1.2,
      );
    }
    if (type == BlendType.softLight || type == BlendType.overlay) {
      // Subtle highlight dot to separate from Hard.
      canvas.drawCircle(lens.getBounds().center, 1.6, Paint()..color = _bkBg);
    }
  }

  @override
  bool shouldRepaint(covariant _BlendIconPainter o) => o.type != type || o.color != color;
}