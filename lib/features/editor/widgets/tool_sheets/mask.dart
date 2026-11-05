import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:flutter_video_editor/core/models/project_model.dart';
import 'package:flutter_video_editor/features/editor/controllers/editor_controller.dart';
import 'package:flutter_video_editor/features/editor/utils/editor_helpers.dart';

// ============================================================================
// MASK: modeled on CapCut's mask tool
//
//  Layout
//   - Big preview on top; bottom bar = [Invert] | None, Linear, Mirror, Circle,
//     Rectangle, Heart, Star ... (flex row, scrolls sideways).
//
//  Behaviour (same ideas CapCut documents: size, position, rotation, feather,
//  invert)
//   - Linear / Split : a single edge line across the frame. Move, rotate, feather.
//   - Mirror         : a band between two lines. Move, rotate, band width, feather.
//   - Circle / Rectangle / Heart / Star : move, resize (corner dots), rotate,
//                      feather. Rectangle also has a round-corner handle.
//   - Pinch resizes and twist rotates anywhere on the preview.
//   - Invert swaps the visible side.
//   - Feather: drag the ⟩ handle. No sliders, no buttons, no box outline.
//
// REQUIRED fields on MaskProperties (use in preview AND export):
//   final double centerX;       // 0..1,  default 0.5
//   final double centerY;       // 0..1,  default 0.5
//   final double width;         // fraction of frame width,  default 0.5
//   final double height;        // fraction of frame height, default 0.5
//   final double rotation;      // radians, default 0
//   final double cornerRadius;  // 0..1 (rectangle only), default 0
//   final bool invert;          // default false
//
// "None": add a way to remove the mask in EditorController and call it from
// _clear() below (marked TODO).
// ============================================================================
const double _mkAspect = 16 / 9; // set to your project's aspect ratio

const Color _mkBg = Color(0xFF000000);
const Color _mkCard = Color(0xFF1C1C1E);
const Color _mkCardOn = Color(0xFF2C2C2E);
const Color _mkText = Color(0xFFFFFFFF);
const Color _mkMuted = Color(0xFF8E8E93);
const Color _mkDim = Color(0xFF48484A);
const Color _mkAccent = Color(0xFF25F4EE);

const double _mkMaxFeather = 50;

String _mkCap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

bool _isLine(String n) {
  final String s = n.toLowerCase();
  return s.contains('linear') || s.contains('split') || s.contains('horizontal');
}

bool _isMirror(String n) => n.toLowerCase().contains('mirror');
bool _isRect(String n) {
  final String s = n.toLowerCase();
  return s.contains('rect') || s.contains('square');
}

// ----------------------------------------------------------------------------
// Closed shapes drawn inside a rect
// ----------------------------------------------------------------------------
Path _mkShape(String name, Rect r, {double? corner}) {
  final String n = name.toLowerCase();
  final Offset c = r.center;
  if (n.contains('circle') || n.contains('ellipse') || n.contains('oval')) {
    return Path()..addOval(r);
  }
  if (n.contains('heart')) {
    final double w = r.width, h = r.height;
    return Path()
      ..moveTo(c.dx, r.top + h * 0.28)
      ..cubicTo(c.dx, r.top - h * 0.02, r.left, r.top + h * 0.02, r.left, r.top + h * 0.34)
      ..cubicTo(r.left, r.top + h * 0.62, c.dx - w * 0.1, r.top + h * 0.78, c.dx, r.bottom)
      ..cubicTo(c.dx + w * 0.1, r.top + h * 0.78, r.right, r.top + h * 0.62, r.right,
          r.top + h * 0.34)
      ..cubicTo(r.right, r.top + h * 0.02, c.dx, r.top - h * 0.02, c.dx, r.top + h * 0.28)
      ..close();
  }
  if (n.contains('star')) {
    final double rx = r.width / 2, ry = r.height / 2;
    final Path p = Path();
    for (int i = 0; i < 10; i++) {
      final double k = i.isEven ? 1.0 : 0.45;
      final double a = -math.pi / 2 + i * math.pi / 5;
      final Offset o = c + Offset(math.cos(a) * rx * k, math.sin(a) * ry * k);
      if (i == 0) {
        p.moveTo(o.dx, o.dy);
      } else {
        p.lineTo(o.dx, o.dy);
      }
    }
    return p..close();
  }
  return Path()
    ..addRRect(RRect.fromRectAndRadius(r, Radius.circular(corner ?? r.shortestSide * 0.1)));
}

// ----------------------------------------------------------------------------
// Mask transform (normalized)
// ----------------------------------------------------------------------------
class _MaskXform {
  const _MaskXform({
    this.cx = 0.5,
    this.cy = 0.5,
    this.w = 0.5,
    this.h = 0.5,
    this.rot = 0.0,
    this.corner = 0.0,
  });
  final double cx, cy, w, h, rot, corner;

  _MaskXform copyWith(
          {double? cx, double? cy, double? w, double? h, double? rot, double? corner}) =>
      _MaskXform(
        cx: cx ?? this.cx,
        cy: cy ?? this.cy,
        w: w ?? this.w,
        h: h ?? this.h,
        rot: rot ?? this.rot,
        corner: corner ?? this.corner,
      );
}

/// Geometry of the mask in its own rotated space (origin = mask center).
class _G {
  _G(this.name, this.size, this.x);
  final String name;
  final Size size;
  final _MaskXform x;

  bool get line => _isLine(name);
  bool get mirror => _isMirror(name);
  bool get rect => _isRect(name);
  bool get closed => !line && !mirror;

  Offset get c => Offset(x.cx * size.width, x.cy * size.height);
  double get hw => x.w * size.width / 2;
  double get hh => line ? 0 : x.h * size.height / 2;
  double get vhw => closed ? hw : size.width * 0.3; // where handles sit for lines
  double get big => size.longestSide * 2;
  double get maxR => math.min(hw, hh);
  double get radiusPx => x.corner * maxR;

  Offset get feather => Offset(vhw + 34, 0);
  Offset get rotate => Offset(0, -hh - 28);
  Offset? get radius => rect ? Offset(-hw + 40 + radiusPx, -hh) : null;
  List<Offset> get corners => closed
      ? <Offset>[Offset(-hw, -hh), Offset(hw, -hh), Offset(hw, hh), Offset(-hw, hh)]
      : mirror
          ? <Offset>[Offset(-vhw, -hh), Offset(-vhw, hh)]
          : <Offset>[];

  Path shape() {
    if (line) return Path()..addRect(Rect.fromLTRB(-big, -big, big, 0));
    if (mirror) return Path()..addRect(Rect.fromLTRB(-big, -hh, big, hh));
    return _mkShape(name, Rect.fromLTRB(-hw, -hh, hw, hh), corner: rect ? radiusPx : null);
  }
}

// ----------------------------------------------------------------------------
// Sheet
// ----------------------------------------------------------------------------
class MaskSheet extends StatefulWidget {
  const MaskSheet({super.key});

  @override
  State<MaskSheet> createState() => _MaskSheetState();
}

class _MaskSheetState extends State<MaskSheet> {
  MaskType? _type;
  double _feather = 10.0;
  bool _invert = false;
  _MaskXform _x = const _MaskXform();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final editor = context.read<EditorController>();
      final clip = editor.selectedClip;
      if (clip != null && clip.maskProperties.type != MaskType.none) {
        setState(() {
          _type = clip.maskProperties.type;
          _feather = clip.maskProperties.feather;
          _invert = clip.maskProperties.invert;
          _x = _MaskXform(
            cx: clip.maskProperties.centerX,
            cy: clip.maskProperties.centerY,
            w: clip.maskProperties.width > 2.0 ? 0.5 : clip.maskProperties.width,
            h: clip.maskProperties.height > 2.0 ? 0.5 : clip.maskProperties.height,
            rot: clip.maskProperties.rotation,
            corner: clip.maskProperties.cornerRadius,
          );
        });
      }
    });
  }

  void _apply(EditorController editor) {
    final MaskType? t = _type;
    if (t == null) return;
    editor.updateMaskProperties(MaskProperties(
      type: t,
      feather: _feather,
      centerX: _x.cx,
      centerY: _x.cy,
      width: _x.w,
      height: _x.h,
      rotation: _x.rot,
      cornerRadius: _x.corner,
      invert: _invert,
    ));
  }

  void _clear(EditorController editor) {
    editor.updateMaskProperties(const MaskProperties());
  }

  @override
  Widget build(BuildContext context) {
    final editor = context.read<EditorController>();
    final double bottom = MediaQuery.paddingOf(context).bottom;
    final bool has = _type != null;

    return ColoredBox(
      color: _mkBg,
      child: Column(
        children: <Widget>[
          // ---- preview ------------------------------------------------------
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Center(
                child: AspectRatio(
                  aspectRatio: _mkAspect,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: _MaskCanvas(
                      name: _type?.name,
                      feather: _feather,
                      invert: _invert,
                      xform: _x,
                      onChanged: (v) {
                        setState(() => _x = v);
                        _apply(editor);
                      },
                      onFeather: (v) {
                        setState(() => _feather = v);
                        _apply(editor);
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ---- bottom bar: Invert | None, shapes ---------------------------
          Padding(
            padding: EdgeInsets.only(bottom: 10 + bottom),
            child: SizedBox(
              height: 86,
              child: Row(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: _MaskTile(
                      label: 'Invert',
                      name: 'invert',
                      selected: has && _invert,
                      enabled: has,
                      onTap: () {
                        tapFeedback();
                        setState(() => _invert = !_invert);
                        _apply(editor);
                      },
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    color: _mkDim,
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.only(right: 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          _MaskTile(
                            label: 'None',
                            name: 'none',
                            selected: _type == null,
                            onTap: () {
                              tapFeedback();
                              setState(() => _type = null);
                              _clear(editor);
                            },
                          ),
                          for (final MaskType type in MaskType.values)
                            if (type != MaskType.none) ...<Widget>[
                              const SizedBox(width: 10),
                              _MaskTile(
                                label: _mkCap(type.name),
                                name: type.name,
                                selected: type == _type,
                                onTap: () {
                                  tapFeedback();
                                  setState(() => _type = type);
                                  _apply(editor);
                                },
                              ),
                            ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// Canvas: preview + direct manipulation
// ----------------------------------------------------------------------------
enum _Mode { none, move, rotate, corner, band, feather, radius }

class _MaskCanvas extends StatefulWidget {
  const _MaskCanvas({
    required this.name,
    required this.feather,
    required this.invert,
    required this.xform,
    required this.onChanged,
    required this.onFeather,
  });
  final String? name;
  final double feather;
  final bool invert;
  final _MaskXform xform;
  final ValueChanged<_MaskXform> onChanged;
  final ValueChanged<double> onFeather;

  @override
  State<_MaskCanvas> createState() => _MaskCanvasState();
}

class _MaskCanvasState extends State<_MaskCanvas> {
  static const double _hit = 26;

  _Mode _mode = _Mode.none;
  _MaskXform _start = const _MaskXform();

  Offset _toLocal(Offset p, _G g) {
    final Offset d = p - g.c;
    final double c = math.cos(g.x.rot), s = math.sin(g.x.rot);
    return Offset(d.dx * c + d.dy * s, -d.dx * s + d.dy * c);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final Size size = Size(box.maxWidth, box.maxHeight);
      final _MaskXform x = widget.xform;
      final bool active = widget.name != null;

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onScaleStart: !active
            ? null
            : (d) {
                _start = x;
                if (d.pointerCount > 1) {
                  _mode = _Mode.move;
                  return;
                }
                final _G g = _G(widget.name!, size, x);
                final Offset l = _toLocal(d.localFocalPoint, g);
                bool near(Offset p) => (l - p).distance < _hit;

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
        onScaleUpdate: !active
            ? null
            : (d) {
                final _MaskXform cur = widget.xform;
                final _G g = _G(widget.name!, size, cur);
                switch (_mode) {
                  case _Mode.rotate:
                    final Offset v = d.localFocalPoint - g.c;
                    widget.onChanged(cur.copyWith(rot: math.atan2(v.dy, v.dx) + math.pi / 2));
                    break;
                  case _Mode.corner:
                    final Offset l = _toLocal(d.localFocalPoint, g);
                    widget.onChanged(cur.copyWith(
                      w: (2 * l.dx.abs() / size.width).clamp(0.08, 2.0).toDouble(),
                      h: (2 * l.dy.abs() / size.height).clamp(0.08, 2.0).toDouble(),
                    ));
                    break;
                  case _Mode.band:
                    final Offset l = _toLocal(d.localFocalPoint, g);
                    widget.onChanged(cur.copyWith(
                      h: (2 * l.dy.abs() / size.height).clamp(0.02, 2.0).toDouble(),
                    ));
                    break;
                  case _Mode.radius:
                    final double mr = g.maxR;
                    if (mr > 0) {
                      final Offset l = _toLocal(d.localFocalPoint, g);
                      final double r = (l.dx + g.hw - 40).clamp(0.0, mr).toDouble();
                      widget.onChanged(cur.copyWith(corner: r / mr));
                    }
                    break;
                  case _Mode.feather:
                    final double c0 = math.cos(cur.rot), s0 = math.sin(cur.rot);
                    final double dl =
                        d.focalPointDelta.dx * c0 + d.focalPointDelta.dy * s0;
                    widget.onFeather(
                        (widget.feather + dl * 0.35).clamp(0.0, _mkMaxFeather).toDouble());
                    break;
                  case _Mode.move:
                    _MaskXform n = cur.copyWith(
                      cx: (cur.cx + d.focalPointDelta.dx / size.width)
                          .clamp(0.0, 1.0)
                          .toDouble(),
                      cy: (cur.cy + d.focalPointDelta.dy / size.height)
                          .clamp(0.0, 1.0)
                          .toDouble(),
                    );
                    if (d.pointerCount > 1) {
                      n = n.copyWith(
                        w: (_start.w * d.scale).clamp(0.08, 2.0).toDouble(),
                        h: (_start.h * d.scale).clamp(0.02, 2.0).toDouble(),
                        rot: _start.rot + d.rotation,
                      );
                    }
                    widget.onChanged(n);
                    break;
                  case _Mode.none:
                    break;
                }
              },
        onScaleEnd: (_) => _mode = _Mode.none,
        child: CustomPaint(
          size: size,
          painter: _CanvasPainter(
            name: widget.name,
            feather: widget.feather,
            invert: widget.invert,
            x: x,
          ),
        ),
      );
    });
  }
}

class _CanvasPainter extends CustomPainter {
  _CanvasPainter({
    required this.name,
    required this.feather,
    required this.invert,
    required this.x,
  });
  final String? name;
  final double feather;
  final bool invert;
  final _MaskXform x;

  void _dot(Canvas canvas, Offset p) {
    canvas.drawCircle(p, 8, Paint()..color = Colors.black.withValues(alpha: 0.5));
    canvas.drawCircle(p, 6, Paint()..color = Colors.white);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final Rect full = Offset.zero & size;
    final Shader shader = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[Color(0xFF3A5BFF), Color(0xFF8A4DFF), Color(0xFFFF5C93)],
    ).createShader(full);

    canvas.drawRect(full, Paint()..shader = shader);
    if (name == null) return;

    final _G g = _G(name!, size, x);
    final Path shape = g.shape();
    final double sigma = feather * (size.width / 340) / 2.2;

    // dim everything, then show the scene through the (feathered) mask
    canvas.drawRect(full, Paint()..color = Colors.black.withValues(alpha: 0.62));
    canvas.saveLayer(full, Paint());
    canvas.save();
    canvas.translate(g.c.dx, g.c.dy);
    canvas.rotate(x.rot);
    canvas.drawPath(
      shape,
      Paint()
        ..color = Colors.white
        ..maskFilter = sigma <= 0 ? null : MaskFilter.blur(BlurStyle.normal, sigma),
    );
    canvas.restore();
    canvas.drawRect(
      full,
      Paint()
        ..shader = shader
        ..blendMode = invert ? BlendMode.srcOut : BlendMode.srcIn,
    );
    canvas.restore();

    // ---- handles (no bounding box) ------------------------------------------
    canvas.save();
    canvas.translate(g.c.dx, g.c.dy);
    canvas.rotate(x.rot);

    final Paint stroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeJoin = StrokeJoin.round;
    if (g.line) {
      canvas.drawLine(Offset(-g.big, 0), Offset(g.big, 0), stroke);
    } else if (g.mirror) {
      canvas.drawLine(Offset(-g.big, -g.hh), Offset(g.big, -g.hh), stroke);
      canvas.drawLine(Offset(-g.big, g.hh), Offset(g.big, g.hh), stroke);
    } else {
      canvas.drawPath(shape, stroke);
    }

    final Paint guide = Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..strokeWidth = 1.4;

    // rotate handle
    final Offset rot = g.rotate;
    canvas.drawLine(Offset(0, -g.hh), rot, guide);
    canvas.drawCircle(rot, 13, Paint()..color = _mkAccent.withValues(alpha: 0.2));
    canvas.drawCircle(rot, 8, Paint()..color = Colors.white);
    canvas.drawCircle(rot, 5.5, Paint()..color = _mkAccent);

    // feather handle: ⟩
    final Offset fh = g.feather;
    canvas.drawLine(Offset(g.vhw, 0), fh, guide);
    canvas.drawCircle(fh, 18, Paint()..color = _mkAccent.withValues(alpha: 0.2));
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
        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(fh.dx - tp.width / 2, fh.dy + 22));

    // round-corner handle (rectangle only)
    final Offset? rd = g.radius;
    if (rd != null) {
      canvas.drawCircle(rd, 11, Paint()..color = _mkAccent.withValues(alpha: 0.2));
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

    for (final Offset p in g.corners) {
      _dot(canvas, p);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CanvasPainter o) =>
      o.name != name ||
      o.feather != feather ||
      o.invert != invert ||
      o.x.cx != x.cx ||
      o.x.cy != x.cy ||
      o.x.w != x.w ||
      o.x.h != x.h ||
      o.x.rot != x.rot ||
      o.x.corner != x.corner;
}

// ----------------------------------------------------------------------------
// Bottom bar tile (icon + label)
// ----------------------------------------------------------------------------
class _MaskTile extends StatelessWidget {
  const _MaskTile({
    required this.label,
    required this.name,
    required this.selected,
    required this.onTap,
    this.enabled = true,
  });
  final String label;
  final String name;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color fg = !enabled ? _mkDim : (selected ? _mkText : _mkMuted);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: SizedBox(
        width: 58,
        child: Column(
          children: <Widget>[
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: selected ? _mkCardOn : _mkCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: selected ? _mkText : Colors.transparent, width: 1.5),
              ),
              child: name == 'invert'
                  ? Icon(Icons.invert_colors_rounded, size: 24, color: fg)
                  : Padding(
                      padding: const EdgeInsets.all(14),
                      child: CustomPaint(painter: _IconPainter(name: name, color: fg)),
                    ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: fg,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconPainter extends CustomPainter {
  _IconPainter({required this.name, required this.color});
  final String name;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect r = Offset.zero & size;
    final Paint line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final Paint fill = Paint()..color = color.withValues(alpha: 0.2);

    if (name == 'none') {
      canvas.drawOval(r, line);
      canvas.drawLine(r.bottomLeft + const Offset(3, -3), r.topRight + const Offset(-3, 3), line);
      return;
    }

    final RRect frame = RRect.fromRectAndRadius(r, const Radius.circular(5));
    if (_isLine(name)) {
      canvas.drawRRect(frame, line);
      canvas.save();
      canvas.clipRRect(frame);
      canvas.drawRect(Rect.fromLTRB(r.left, r.top, r.right, r.center.dy), fill);
      canvas.restore();
      canvas.drawLine(Offset(r.left, r.center.dy), Offset(r.right, r.center.dy), line);
      return;
    }
    if (_isMirror(name)) {
      canvas.drawRRect(frame, line);
      final Rect band = Rect.fromLTRB(
          r.left, r.top + r.height * 0.3, r.right, r.bottom - r.height * 0.3);
      canvas.drawRect(band, fill);
      canvas.drawLine(band.topLeft, band.topRight, line);
      canvas.drawLine(band.bottomLeft, band.bottomRight, line);
      return;
    }
    final Path p = _mkShape(name, r);
    canvas.drawPath(p, fill);
    canvas.drawPath(p, line);
  }

  @override
  bool shouldRepaint(covariant _IconPainter o) => o.name != name || o.color != color;
}