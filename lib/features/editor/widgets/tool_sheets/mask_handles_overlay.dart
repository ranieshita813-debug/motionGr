import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:flutter_video_editor/core/models/project_model.dart';
import 'package:flutter_video_editor/features/editor/controllers/editor_controller.dart';
import 'mask_geometry.dart';

const Color _accent = Color(0xFF25F4EE);

enum _Mode { none, move, rotate, corner, band, feather, radius }

// ============================================================================
// Transparent overlay placed EXACTLY over the video rect in the main player.
// It draws only the outline + handles and writes straight into the clip's
// MaskProperties. The real masking is done by MaskedLayer.
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

class _MaskHandlesOverlayState extends State<MaskHandlesOverlay> {
  static const double _hit = 26;

  _Mode _mode = _Mode.none;
  MaskXform _start = const MaskXform();

  Offset _toLocal(Offset p, MaskGeometry g) {
    final Offset d = p - g.c;
    final double c = math.cos(g.x.rot), s = math.sin(g.x.rot);
    return Offset(d.dx * c + d.dy * s, -d.dx * s + d.dy * c);
  }

  MaskProperties? _current(EditorController e) => e.selectedClip?.maskProperties;

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
            _mode = _Mode.move;
            return;
          }
          final MaskGeometry g = MaskGeometry(name, size, x);
          final Offset l = _toLocal(d.localFocalPoint, g);
          bool near(Offset o) => (l - o).distance < _hit;

          if (near(g.feather)) {
            _mode = _Mode.feather;
          } else if (g.radius != null && near(g.radius!)) {
            _mode = _Mode.radius;
          } else if (near(g.rotate)) {
            _mode = _Mode.rotate;
          } else if (g.mirror && g.corners.any(near)) {
            _mode = _Mode.band;
          } else if (g.closed && g.corners.any(near)) {
            _mode = _Mode.corner;
          } else {
            _mode = _Mode.move;
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
              MaskXform n = cur.copyWith(
                cx: (cur.cx + d.focalPointDelta.dx / size.width).clamp(0.0, 1.0).toDouble(),
                cy: (cur.cy + d.focalPointDelta.dy / size.height).clamp(0.0, 1.0).toDouble(),
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
        onScaleEnd: (_) => _mode = _Mode.none,
        child: CustomPaint(
          size: size,
          painter: _HandlesPainter(name: name, feather: p.feather, x: x),
        ),
      );
    });
  }
}

class _HandlesPainter extends CustomPainter {
  _HandlesPainter({required this.name, required this.feather, required this.x});
  final String name;
  final double feather;
  final MaskXform x;

  void _dot(Canvas canvas, Offset p) {
    canvas.drawCircle(p, 8, Paint()..color = Colors.black.withValues(alpha: 0.5));
    canvas.drawCircle(p, 6, Paint()..color = Colors.white);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final MaskGeometry g = MaskGeometry(name, size, x);

    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(g.c.dx, g.c.dy);
    canvas.rotate(x.rot);

    final Paint shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.4
      ..strokeJoin = StrokeJoin.round;
    final Paint stroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeJoin = StrokeJoin.round;

    if (g.line) {
      canvas.drawLine(Offset(-g.big, 0), Offset(g.big, 0), shadow);
      canvas.drawLine(Offset(-g.big, 0), Offset(g.big, 0), stroke);
    } else if (g.mirror) {
      for (final double y in <double>[-g.hh, g.hh]) {
        canvas.drawLine(Offset(-g.big, y), Offset(g.big, y), shadow);
        canvas.drawLine(Offset(-g.big, y), Offset(g.big, y), stroke);
      }
    } else {
      final Path s = g.shape();
      canvas.drawPath(s, shadow);
      canvas.drawPath(s, stroke);
    }

    final Paint guide = Paint()
      ..color = Colors.white.withValues(alpha: 0.7)
      ..strokeWidth = 1.4;

    // rotate handle
    final Offset rot = g.rotate;
    canvas.drawLine(Offset(0, -g.hh), rot, guide);
    canvas.drawCircle(rot, 13, Paint()..color = _accent.withValues(alpha: 0.25));
    canvas.drawCircle(rot, 8, Paint()..color = Colors.white);
    canvas.drawCircle(rot, 5.5, Paint()..color = _accent);

    // feather handle  >
    final Offset fh = g.feather;
    canvas.drawLine(Offset(g.vhw, 0), fh, guide);
    canvas.drawCircle(fh, 18, Paint()..color = _accent.withValues(alpha: 0.25));
    canvas.drawCircle(fh, 12, Paint()..color = Colors.white);
    canvas.drawPath(
      Path()
        ..moveTo(fh.dx - 2.5, fh.dy - 5.5)
        ..lineTo(fh.dx + 3, fh.dy)
        ..lineTo(fh.dx - 2.5, fh.dy + 5.5),
      Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: feather.round().toString(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          shadows: <Shadow>[Shadow(blurRadius: 3)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(fh.dx - tp.width / 2, fh.dy + 22));

    // round-corner handle (rectangle only)
    final Offset? rd = g.radius;
    if (rd != null) {
      canvas.drawCircle(rd, 11, Paint()..color = _accent.withValues(alpha: 0.25));
      canvas.drawCircle(rd, 7, Paint()..color = Colors.white);
      canvas.drawPath(
        Path()
          ..moveTo(rd.dx - 3, rd.dy + 3)
          ..lineTo(rd.dx - 3, rd.dy - 1)
          ..quadraticBezierTo(rd.dx - 3, rd.dy - 3, rd.dx - 1, rd.dy - 3)
          ..lineTo(rd.dx + 3, rd.dy - 3),
        Paint()
          ..color = Colors.black
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round,
      );
    }

    for (final Offset o in g.corners) {
      _dot(canvas, o);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _HandlesPainter o) =>
      o.name != name ||
      o.feather != feather ||
      o.x.cx != x.cx ||
      o.x.cy != x.cy ||
      o.x.w != x.w ||
      o.x.h != x.h ||
      o.x.rot != x.rot ||
      o.x.corner != x.corner;
}