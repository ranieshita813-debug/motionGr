import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:flutter_video_editor/core/models/project_model.dart';
import 'package:flutter_video_editor/features/editor/controllers/editor_controller.dart';
import 'package:flutter_video_editor/features/editor/utils/editor_helpers.dart';
import 'mask_geometry.dart';

const Color _accent = Color(0xFF25F4EE);
const Color _ink = Color(0xFF0B1B1E);

enum _Mode { none, move, rotate, corner, band, feather, radius }

// ============================================================================
// Transparent overlay placed EXACTLY over the video rect in the main player.
// Draws outline + handles and writes straight into the clip's MaskProperties.
// The real masking is done by MaskedLayer.
//
//   Stack(children: [
//     MaskedLayer.fromProps(props: clip.maskProperties, child: video),
//     if (editor.isMaskEditing) const Positioned.fill(child: MaskHandlesOverlay()),
//   ])
// ============================================================================
class MaskHandlesOverlay extends StatefulWidget {
  const MaskHandlesOverlay({super.key});

  @override
  State<MaskHandlesOverlay> createState() => _MaskHandlesOverlayState();
}

class _MaskSnapLine {
  const _MaskSnapLine(this.vertical, this.pos);
  final bool vertical;
  final double pos; // in pixels
}

class _MaskHandlesOverlayState extends State<MaskHandlesOverlay> {
  static const double _hit = 30;

  _Mode _mode = _Mode.none;
  MaskXform _start = const MaskXform();
  List<_MaskSnapLine> _snapLines = const <_MaskSnapLine>[];
  String _lastSnapSig = '';

  void _setMode(_Mode m) {
    if (_mode == m) return;
    if (m != _Mode.none && m != _Mode.move) HapticFeedback.selectionClick();
    setState(() => _mode = m);
  }

  Offset _toLocal(Offset p, MaskGeometry g) {
    final Offset d = p - g.c;
    final double c = math.cos(g.x.rot), s = math.sin(g.x.rot);
    return Offset(d.dx * c + d.dy * s, -d.dx * s + d.dy * c);
  }

  MaskProperties? _current(EditorController e) {
    final clip = e.selectedClip;
    if (clip == null) return null;
    final relTime = e.playhead - clip.start;
    return getInterpolatedMaskProperties(clip, relTime);
  }

  void _writeX(MaskXform x) {
    final EditorController e = context.read<EditorController>();
    final MaskProperties? p = _current(e);
    if (p == null || !p.isActive) return;
    e.updateMaskProperties(p.withXform(x));
  }

  void _writeFeather(double f) {
    final EditorController e = context.read<EditorController>();
    final MaskProperties? p = _current(e);
    if (p == null || !p.isActive) return;
    e.updateMaskProperties(p.withXform(MaskXform.fromProps(p), feather: f));
  }

  @override
  Widget build(BuildContext context) {
    final EditorController editor = context.watch<EditorController>();
    final MaskProperties? p = _current(editor);
    if (p == null || !p.isActive) return const SizedBox.shrink();

    final String name = p.type.name;
    final MaskXform x = MaskXform.fromProps(p);

    return LayoutBuilder(builder: (BuildContext context, BoxConstraints box) {
      final Size size = Size(box.maxWidth, box.maxHeight);

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onScaleStart: (ScaleStartDetails d) {
          _start = x;
          if (d.pointerCount > 1) {
            _setMode(_Mode.move);
            return;
          }
          final MaskGeometry g = MaskGeometry(name, size, x);
          final Offset l = _toLocal(d.localFocalPoint, g);
          bool near(Offset o) => (l - o).distance < _hit;

          if (near(g.feather)) {
            _setMode(_Mode.feather);
          } else if (g.radius != null && near(g.radius!)) {
            _setMode(_Mode.radius);
          } else if (near(g.rotate)) {
            _setMode(_Mode.rotate);
          } else {
            _setMode(_Mode.move);
          }
        },
        onScaleUpdate: (ScaleUpdateDetails d) {
          final MaskProperties? now = _current(context.read<EditorController>());
          if (now == null || !now.isActive) return;
          final MaskXform cur = MaskXform.fromProps(now);
          final MaskGeometry g = MaskGeometry(name, size, cur);

          switch (_mode) {
            case _Mode.rotate:
              final Offset v = d.localFocalPoint - g.c;
              _writeX(cur.copyWith(rot: math.atan2(v.dy, v.dx) + math.pi / 2));
              break;
            case _Mode.corner:
              final Offset l = _toLocal(d.localFocalPoint, g);
              _writeX(cur.copyWith(
                w: (2 * l.dx.abs() / size.width).clamp(0.08, 2.0).toDouble(),
                h: (2 * l.dy.abs() / size.height).clamp(0.08, 2.0).toDouble(),
              ));
              break;
            case _Mode.band:
              final Offset l = _toLocal(d.localFocalPoint, g);
              _writeX(cur.copyWith(
                h: (2 * l.dy.abs() / size.height).clamp(0.02, 2.0).toDouble(),
              ));
              break;
            case _Mode.radius:
              final double mr = g.maxR;
              if (mr > 0) {
                final Offset l = _toLocal(d.localFocalPoint, g);
                final double r = (l.dx + g.hw - 40).clamp(0.0, mr).toDouble();
                _writeX(cur.copyWith(corner: r / mr));
              }
              break;
            case _Mode.feather:
              final double c0 = math.cos(cur.rot), s0 = math.sin(cur.rot);
              final double dl = d.focalPointDelta.dx * c0 + d.focalPointDelta.dy * s0;
              _writeFeather((now.feather + dl * 0.35).clamp(0.0, kMaskMaxFeather).toDouble());
              break;
            case _Mode.move:
              double targetCx = (cur.cx + d.focalPointDelta.dx / size.width).clamp(0.0, 1.0).toDouble();
              double targetCy = (cur.cy + d.focalPointDelta.dy / size.height).clamp(0.0, 1.0).toDouble();

              // Magnetic snap targets in normalized coordinates (0..1)
              const double snapDistThreshold = 14.0; // pixels
              final double thX = snapDistThreshold / size.width;
              final double thY = snapDistThreshold / size.height;

              final List<double> snapTargetsX = <double>[0.0, 1.0 / 3.0, 0.5, 2.0 / 3.0, 1.0];
              final List<double> snapTargetsY = <double>[0.0, 1.0 / 3.0, 0.5, 2.0 / 3.0, 1.0];

              final List<_MaskSnapLine> activeLines = <_MaskSnapLine>[];

              for (final double tx in snapTargetsX) {
                if ((targetCx - tx).abs() < thX) {
                  targetCx = tx;
                  activeLines.add(_MaskSnapLine(true, tx * size.width));
                  break;
                }
              }

              for (final double ty in snapTargetsY) {
                if ((targetCy - ty).abs() < thY) {
                  targetCy = ty;
                  activeLines.add(_MaskSnapLine(false, ty * size.height));
                  break;
                }
              }

              final String sig = activeLines.map((l) => '${l.vertical}${l.pos.toStringAsFixed(1)}').join('|');
              if (sig.isNotEmpty && sig != _lastSnapSig) {
                tapFeedback();
              }
              _lastSnapSig = sig;

              if (mounted) {
                setState(() => _snapLines = activeLines);
              }

              MaskXform n = cur.copyWith(
                cx: targetCx,
                cy: targetCy,
              );
              if (d.pointerCount > 1) {
                final bool line = maskIsLine(name);
                n = n.copyWith(
                  w: (_start.w * d.scale).clamp(0.08, 2.0).toDouble(),
                  h: line ? n.h : (_start.h * d.scale).clamp(0.02, 2.0).toDouble(),
                  rot: _start.rot + d.rotation,
                );
              }
              _writeX(n);
              break;
            case _Mode.none:
              break;
          }
        },
        onScaleEnd: (_) {
          if (_snapLines.isNotEmpty) {
            setState(() {
              _snapLines = const <_MaskSnapLine>[];
              _lastSnapSig = '';
            });
          }
          _setMode(_Mode.none);
        },
        child: CustomPaint(
          size: size,
          painter: _HandlesPainter(
            name: name,
            feather: p.feather,
            x: x,
            mode: _mode,
            snapLines: _snapLines,
          ),
        ),
      );
    });
  }
}

class _HandlesPainter extends CustomPainter {
  _HandlesPainter({
    required this.name,
    required this.feather,
    required this.x,
    required this.mode,
    this.snapLines = const <_MaskSnapLine>[],
  });

  final String name;
  final double feather;
  final MaskXform x;
  final _Mode mode;
  final List<_MaskSnapLine> snapLines;

  // ---- helpers -------------------------------------------------------------

  void _drawDashedLine(Canvas canvas, Offset a, Offset b, Paint p) {
    final double total = (b - a).distance;
    if (total <= 0) return;
    final Offset dir = (b - a) / total;
    double d = 0;
    while (d < total) {
      canvas.drawLine(a + dir * d, a + dir * math.min(d + 6, total), p);
      d += 10;
    }
  }

  /// Round handle: soft shadow, white body, accent ring, optional glyph.
  /// The glyph is counter-rotated so it always stays upright.
  void _roundHandle(
    Canvas canvas,
    Offset p, {
    required double radius,
    required bool active,
    required void Function(Canvas c) glyph,
  }) {
    final double r = active ? radius * 1.18 : radius;
    canvas.drawCircle(
      p.translate(0, 1.5),
      r + 1,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawCircle(p, r, Paint()..color = active ? _accent : Colors.white);
    canvas.drawCircle(
      p,
      r,
      Paint()
        ..color = active ? Colors.white : _accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.save();
    canvas.translate(p.dx, p.dy);
    canvas.rotate(-x.rot);
    glyph(canvas);
    canvas.restore();
  }

  Paint _glyph(double w) => Paint()
    ..color = _ink
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  void _rotateGlyph(Canvas c) {
    c.drawArc(Rect.fromCircle(center: Offset.zero, radius: 4.8),
        -math.pi / 2, math.pi * 1.5, false, _glyph(1.9));
    c.drawPath(
      Path()
        ..moveTo(-8, 0.8)
        ..lineTo(-1.6, 0.8)
        ..lineTo(-4.8, -3.6)
        ..close(),
      Paint()..color = _ink,
    );
  }

  void _featherGlyph(Canvas c) {
    final Paint p = _glyph(1.9);
    c.drawLine(const Offset(-5, 0), const Offset(5, 0), p);
    c.drawPath(
      Path()
        ..moveTo(-2.6, -2.8)
        ..lineTo(-5.4, 0)
        ..lineTo(-2.6, 2.8),
      p,
    );
    c.drawPath(
      Path()
        ..moveTo(2.6, -2.8)
        ..lineTo(5.4, 0)
        ..lineTo(2.6, 2.8),
      p,
    );
  }

  void _radiusGlyph(Canvas c) {
    c.drawPath(
      Path()
        ..moveTo(-3.5, 3.5)
        ..lineTo(-3.5, -0.5)
        ..quadraticBezierTo(-3.5, -3.5, -0.5, -3.5)
        ..lineTo(3.5, -3.5),
      _glyph(1.9),
    );
  }

  void _stroke(Canvas canvas, MaskGeometry g, Paint paint) {
    if (g.line) {
      canvas.drawLine(Offset(-g.big, 0), Offset(g.big, 0), paint);
    } else if (g.mirror) {
      for (final double y in <double>[-g.hh, g.hh]) {
        canvas.drawLine(Offset(-g.big, y), Offset(g.big, y), paint);
      }
    } else {
      canvas.drawPath(g.shape(), paint);
    }
  }

  // ---- paint ---------------------------------------------------------------

  @override
  void paint(Canvas canvas, Size size) {
    final MaskGeometry g = MaskGeometry(name, size, x);
    canvas.save();
    canvas.clipRect(Offset.zero & size);

    // Dim everything outside the mask.
    if (!g.line && !g.mirror) {
      canvas.saveLayer(Offset.zero & size, Paint());
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = Colors.black.withValues(alpha: 0.38),
      );
      canvas.save();
      canvas.translate(g.c.dx, g.c.dy);
      canvas.rotate(x.rot);
      canvas.drawPath(g.shape(), Paint()..blendMode = BlendMode.clear);
      canvas.restore();
      canvas.restore(); // saveLayer
    }

    canvas.translate(g.c.dx, g.c.dy);
    canvas.rotate(x.rot);

    // Outline: dark halo + accent line.
    _stroke(
      canvas,
      g,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.6
        ..strokeJoin = StrokeJoin.round,
    );
    _stroke(
      canvas,
      g,
      Paint()
        ..color = _accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.7
        ..strokeJoin = StrokeJoin.round,
    );

    // 4) Stems.
    final Paint stem = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..strokeWidth = 1.2;
    final Offset rot = g.rotate;
    final Offset fh = g.feather;
    canvas.drawLine(Offset(0, -g.hh), rot, stem);
    canvas.drawLine(Offset(g.vhw, 0), fh, stem);

    // 6) Round-corner handle (rectangle only).
    final Offset? rd = g.radius;
    if (rd != null) {
      _roundHandle(canvas, rd,
          radius: 11, active: mode == _Mode.radius, glyph: _radiusGlyph);
    }

    // 7) Rotate handle.
    _roundHandle(canvas, rot,
        radius: 13, active: mode == _Mode.rotate, glyph: _rotateGlyph);

    // 8) Feather handle.
    _roundHandle(canvas, fh,
        radius: 14, active: mode == _Mode.feather, glyph: _featherGlyph);

    canvas.restore();

    // Render Magnetic Snap Guidelines when dragging
    if (snapLines.isNotEmpty) {
      final Paint guidePaint = Paint()
        ..color = _accent.withValues(alpha: 0.9)
        ..strokeWidth = 1.0;
      for (final line in snapLines) {
        if (line.vertical) {
          _drawDashedLine(canvas, Offset(line.pos, 0), Offset(line.pos, size.height), guidePaint);
        } else {
          _drawDashedLine(canvas, Offset(0, line.pos), Offset(size.width, line.pos), guidePaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HandlesPainter o) =>
      o.name != name ||
      o.feather != feather ||
      o.mode != mode ||
      o.snapLines != snapLines ||
      o.x.cx != x.cx ||
      o.x.cy != x.cy ||
      o.x.w != x.w ||
      o.x.h != x.h ||
      o.x.rot != x.rot ||
      o.x.corner != x.corner;
}