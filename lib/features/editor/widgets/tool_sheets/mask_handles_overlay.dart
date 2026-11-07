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

// Must match where MaskGeometry places the radius handle (inset from the
// right edge, in px). Keep in sync with mask_geometry.dart.
const double _radiusHandleInset = 40;

// Snap distance in px.
const double _snapThresholdPx = 10;

// corner / band modes removed: nothing ever entered them.
enum _Mode { none, move, rotate, feather, radius }

// ============================================================================
// Transparent overlay placed EXACTLY over the video rect in the main player.
// Draws outline + handles and writes straight into the clip's MaskProperties.
// The real masking is done by MaskedLayer.
//
//   Stack(
//     clipBehavior: Clip.none, // so handles outside the video stay visible
//     children: [
//       MaskedLayer.fromProps(props: clip.maskProperties, child: video),
//       if (editor.isMaskEditing) const Positioned.fill(child: MaskHandlesOverlay()),
//     ],
//   )
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

  @override
  bool operator ==(Object other) =>
      other is _MaskSnapLine && other.vertical == vertical && other.pos == pos;

  @override
  int get hashCode => Object.hash(vertical, pos);
}

class _MaskHandlesOverlayState extends State<MaskHandlesOverlay> {
  static const double _hit = 30;
  static const List<double> _snapTargets = <double>[
    0.0,
    1.0 / 3.0,
    0.5,
    2.0 / 3.0,
    1.0,
  ];

  _Mode _mode = _Mode.none;
  MaskXform _start = const MaskXform();
  List<_MaskSnapLine> _snapLines = const <_MaskSnapLine>[];
  String _lastSnapSig = '';

  // Raw (unsnapped) centre, accumulated during a move drag. Snapping is
  // computed from this, so slow drags can break out of a snap.
  double _rawCx = 0;
  double _rawCy = 0;

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

  void _updateSnapLines(List<_MaskSnapLine> lines) {
    final String sig = lines
        .map((l) => '${l.vertical}${l.pos.toStringAsFixed(1)}')
        .join('|');
    if (sig == _lastSnapSig) return; // nothing changed -> no setState
    if (sig.isNotEmpty) tapFeedback();
    _lastSnapSig = sig;
    if (mounted) setState(() => _snapLines = lines);
  }

  void _clearSnapLines() {
    if (_snapLines.isEmpty && _lastSnapSig.isEmpty) return;
    _lastSnapSig = '';
    if (mounted) setState(() => _snapLines = const <_MaskSnapLine>[]);
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
          _rawCx = x.cx;
          _rawCy = x.cy;
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
              final double target = math.atan2(v.dy, v.dx) + math.pi / 2;
              // Unwrap relative to the current rotation so crossing +-pi
              // doesn't jump by 2*pi.
              final double delta = target - cur.rot;
              final double wrapped = math.atan2(math.sin(delta), math.cos(delta));
              _writeX(cur.copyWith(rot: cur.rot + wrapped));
              break;

            case _Mode.radius:
              final double mr = g.maxR;
              if (mr > 0) {
                final Offset l = _toLocal(d.localFocalPoint, g);
                final double r =
                    (l.dx + g.hw - _radiusHandleInset).clamp(0.0, mr).toDouble();
                _writeX(cur.copyWith(corner: r / mr));
              }
              break;

            case _Mode.feather:
              final double c0 = math.cos(cur.rot), s0 = math.sin(cur.rot);
              final double dl =
                  d.focalPointDelta.dx * c0 + d.focalPointDelta.dy * s0;
              _writeFeather(
                  (now.feather + dl * 0.35).clamp(0.0, kMaskMaxFeather).toDouble());
              break;

            case _Mode.move:
              // Accumulate the RAW position; snap from it, never from the
              // already-snapped value.
              _rawCx = (_rawCx + d.focalPointDelta.dx / size.width)
                  .clamp(-0.5, 1.5)
                  .toDouble();
              _rawCy = (_rawCy + d.focalPointDelta.dy / size.height)
                  .clamp(-0.5, 1.5)
                  .toDouble();

              final double thX = _snapThresholdPx / size.width;
              final double thY = _snapThresholdPx / size.height;

              double snappedCx = _rawCx;
              double snappedCy = _rawCy;
              final List<_MaskSnapLine> activeLines = <_MaskSnapLine>[];

              for (final double t in _snapTargets) {
                if ((_rawCx - t).abs() < thX) {
                  snappedCx = t;
                  activeLines.add(_MaskSnapLine(true, t * size.width));
                  break;
                }
              }
              for (final double t in _snapTargets) {
                if ((_rawCy - t).abs() < thY) {
                  snappedCy = t;
                  activeLines.add(_MaskSnapLine(false, t * size.height));
                  break;
                }
              }

              _updateSnapLines(activeLines);

              MaskXform n = cur.copyWith(cx: snappedCx, cy: snappedCy);
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
          _clearSnapLines();
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

  // Reused paints (no per-frame allocation, no per-frame blur setup).
  static final Paint _shadowPaint = Paint()
    ..color = Colors.black.withValues(alpha: 0.4)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
  static final Paint _dimPaint = Paint()
    ..color = Colors.black.withValues(alpha: 0.38);
  static final Paint _clearPaint = Paint()..blendMode = BlendMode.clear;
  static final Paint _haloPaint = Paint()
    ..color = Colors.black.withValues(alpha: 0.5)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3.6
    ..strokeJoin = StrokeJoin.round;
  static final Paint _outlinePaint = Paint()
    ..color = _accent
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.7
    ..strokeJoin = StrokeJoin.round;
  static final Paint _stemPaint = Paint()
    ..color = Colors.white.withValues(alpha: 0.85)
    ..strokeWidth = 1.2;
  static final Paint _guidePaint = Paint()
    ..color = _accent.withValues(alpha: 0.9)
    ..strokeWidth = 1.0;

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
    canvas.drawCircle(p.translate(0, 1.5), r + 1, _shadowPaint);
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
    final Rect bounds = Offset.zero & size;

    // Dim + outline are clipped to the video rect. Handles are NOT, so the
    // rotate/feather handles stay visible when the mask is near an edge
    // (the parent Stack must use clipBehavior: Clip.none).
    canvas.save();
    canvas.clipRect(bounds);

    // Dim everything outside the mask.
    if (!g.line && !g.mirror) {
      canvas.saveLayer(bounds, Paint());
      canvas.drawRect(bounds, _dimPaint);
      canvas.save();
      canvas.translate(g.c.dx, g.c.dy);
      canvas.rotate(x.rot);
      canvas.drawPath(g.shape(), _clearPaint);
      canvas.restore();
      canvas.restore(); // saveLayer
    }

    canvas.save();
    canvas.translate(g.c.dx, g.c.dy);
    canvas.rotate(x.rot);
    _stroke(canvas, g, _haloPaint);
    _stroke(canvas, g, _outlinePaint);
    canvas.restore();

    // Snap guidelines (still clipped to the video rect).
    for (final _MaskSnapLine line in snapLines) {
      if (line.vertical) {
        _drawDashedLine(
            canvas, Offset(line.pos, 0), Offset(line.pos, size.height), _guidePaint);
      } else {
        _drawDashedLine(
            canvas, Offset(0, line.pos), Offset(size.width, line.pos), _guidePaint);
      }
    }
    canvas.restore(); // clip

    // Handles: unclipped.
    canvas.save();
    canvas.translate(g.c.dx, g.c.dy);
    canvas.rotate(x.rot);

    final Offset rot = g.rotate;
    final Offset fh = g.feather;
    canvas.drawLine(Offset(0, -g.hh), rot, _stemPaint);
    canvas.drawLine(Offset(g.vhw, 0), fh, _stemPaint);

    final Offset? rd = g.radius;
    if (rd != null) {
      _roundHandle(canvas, rd,
          radius: 11, active: mode == _Mode.radius, glyph: _radiusGlyph);
    }
    _roundHandle(canvas, rot,
        radius: 13, active: mode == _Mode.rotate, glyph: _rotateGlyph);
    _roundHandle(canvas, fh,
        radius: 14, active: mode == _Mode.feather, glyph: _featherGlyph);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _HandlesPainter o) =>
      o.name != name ||
      o.feather != feather ||
      o.mode != mode ||
      !_sameLines(o.snapLines, snapLines) ||
      o.x.cx != x.cx ||
      o.x.cy != x.cy ||
      o.x.w != x.w ||
      o.x.h != x.h ||
      o.x.rot != x.rot ||
      o.x.corner != x.corner;

  static bool _sameLines(List<_MaskSnapLine> a, List<_MaskSnapLine> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}