// Professional SVG editor (self-contained, CapCut-style dark UI).
//
// Usage:
//   final svg = await Navigator.push<String>(context, MaterialPageRoute(
//     builder: (_) => SvgEditorPro(source: currentSvg, title: 'Graphic 1')));
//   if (svg != null) { /* save */ }
//
// Tools : Select (move / scale / rotate) · Node edit (anchors, bezier handles,
//         add / delete / smooth / corner) · Pen (click, drag for curves, tap the
//         first point to close) · Line · Rectangle · Ellipse · Polygon · Star
// Panels: Style (fill, stroke, width, cap, join, dash, opacity) · Arrange
//         (rotate, corner radius, flip, align, duplicate, convert to path)
//         · Node · Layers (select, reorder, lock, hide)
// Canvas: pinch / scroll zoom, two-finger pan, grid snap, undo / redo.
// I/O   : imports rect, circle, ellipse, line, polygon and path (M L H V C Z,
//         absolute + relative). data-* attributes are preserved on export, so
//         physics attributes survive a round-trip.
//
// Only depends on flutter/material. No dependency on svg_model.dart.

import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _bg = Color(0xFF0D0D0D);
const _panel = Color(0xFF161616);
const _card = Color(0xFF202020);
const _field = Color(0xFF2A2A2A);
const _accent = Color(0xFF2DE2D0);
const _lbl = TextStyle(color: Color(0xFFB4B4B4), fontSize: 11.5);
const _strong = TextStyle(color: Colors.white, fontSize: 13);

const _palette = <Color>[
  Color(0xFFFFFFFF), Color(0xFF2DE2D0), Color(0xFFFF5C7A), Color(0xFFFFC94D), Color(0xFF7C6CFF),
  Color(0xFF3FA9F5), Color(0xFF6DD58C), Color(0xFFFF8A3D), Color(0xFF9A9A9A), Color(0xFF000000),
];

// ───────────────────────── MODEL ─────────────────────────

enum _Kind { rect, ellipse, path }
enum _Tool { select, node, pen, line, rect, ellipse, polygon, star }
enum _Mode { none, move, scale, rotate, anchor, hIn, hOut, draw, penDrag }

Offset _rot(Offset o, Offset c, double a) {
  final d = o - c;
  final s = math.sin(a), k = math.cos(a);
  return c + Offset(d.dx * k - d.dy * s, d.dx * s + d.dy * k);
}

Offset _bez(Offset a, Offset b, Offset c, Offset d, double t) {
  final u = 1 - t;
  return a * (u * u * u) + b * (3 * u * u * t) + c * (3 * u * t * t) + d * (t * t * t);
}

String _n(double v) {
  var s = v.toStringAsFixed(2);
  if (s.contains('.')) s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  return s;
}

String _hex(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

Color? _col(String? s) {
  if (s == null) return null;
  var h = s.trim();
  if (h == 'none' || !h.startsWith('#')) return h == 'none' ? null : const Color(0xFF000000);
  h = h.substring(1);
  if (h.length == 3) h = h.split('').map((c) => c + c).join();
  if (h.length != 6) return const Color(0xFF000000);
  return Color(int.parse('FF$h', radix: 16));
}

class _Anchor {
  _Anchor(this.p, {this.hIn, this.hOut, this.smooth = false});
  Offset p;
  Offset? hIn, hOut;
  bool smooth;

  _Anchor clone() => _Anchor(p, hIn: hIn, hOut: hOut, smooth: smooth);
  void shift(Offset d) {
    p += d;
    if (hIn != null) hIn = hIn! + d;
    if (hOut != null) hOut = hOut! + d;
  }

  void map(Offset Function(Offset) f) {
    p = f(p);
    if (hIn != null) hIn = f(hIn!);
    if (hOut != null) hOut = f(hOut!);
  }
}

Path _anchorsPath(List<_Anchor> a, bool closed) {
  final p = Path();
  if (a.isEmpty) return p;
  p.moveTo(a[0].p.dx, a[0].p.dy);
  final n = a.length;
  final cnt = closed ? n : n - 1;
  for (var i = 0; i < cnt; i++) {
    final x = a[i], y = a[(i + 1) % n];
    if (x.hOut == null && y.hIn == null) {
      p.lineTo(y.p.dx, y.p.dy);
    } else {
      final c1 = x.hOut ?? x.p, c2 = y.hIn ?? y.p;
      p.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, y.p.dx, y.p.dy);
    }
  }
  if (closed) p.close();
  return p;
}

String _anchorsD(List<_Anchor> a, bool closed) {
  if (a.isEmpty) return '';
  final b = StringBuffer('M${_n(a[0].p.dx)} ${_n(a[0].p.dy)}');
  final n = a.length;
  final cnt = closed ? n : n - 1;
  for (var i = 0; i < cnt; i++) {
    final x = a[i], y = a[(i + 1) % n];
    if (x.hOut == null && y.hIn == null) {
      b.write(' L${_n(y.p.dx)} ${_n(y.p.dy)}');
    } else {
      final c1 = x.hOut ?? x.p, c2 = y.hIn ?? y.p;
      b.write(' C${_n(c1.dx)} ${_n(c1.dy)} ${_n(c2.dx)} ${_n(c2.dy)} ${_n(y.p.dx)} ${_n(y.p.dy)}');
    }
  }
  if (closed) b.write(' Z');
  return b.toString();
}

class _Shape {
  _Shape({
    required this.id,
    required this.kind,
    this.box = Rect.zero,
    this.rx = 0,
    this.rot = 0,
    List<_Anchor>? anchors,
    this.closed = false,
    this.fill,
    this.stroke,
    this.sw = 0,
    this.opacity = 1,
    this.cap = StrokeCap.butt,
    this.join = StrokeJoin.miter,
    this.dash = false,
    this.name = '',
    this.visible = true,
    this.locked = false,
    Map<String, String>? attrs,
  })  : anchors = anchors ?? [],
        attrs = attrs ?? {};

  final int id;
  _Kind kind;
  Rect box;
  double rx, rot; // rot in degrees (rect / ellipse only)
  List<_Anchor> anchors;
  bool closed;
  Color? fill, stroke;
  double sw, opacity;
  StrokeCap cap;
  StrokeJoin join;
  bool dash;
  String name;
  bool visible, locked;
  Map<String, String> attrs;

  _Shape clone() => _Shape(
        id: id, kind: kind, box: box, rx: rx, rot: rot, anchors: anchors.map((a) => a.clone()).toList(),
        closed: closed, fill: fill, stroke: stroke, sw: sw, opacity: opacity, cap: cap, join: join,
        dash: dash, name: name, visible: visible, locked: locked, attrs: Map.of(attrs),
      );

  Path _rotPath(Path p) {
    if (rot == 0) return p;
    final c = box.center;
    final m = Matrix4.translationValues(c.dx, c.dy, 0) *
        Matrix4.rotationZ(rot * math.pi / 180) *
        Matrix4.translationValues(-c.dx, -c.dy, 0);
    return p.transform(m.storage);
  }

  Path path() {
    switch (kind) {
      case _Kind.rect:
        return _rotPath(Path()..addRRect(RRect.fromRectXY(box, rx, rx)));
      case _Kind.ellipse:
        return _rotPath(Path()..addOval(box));
      case _Kind.path:
        return _anchorsPath(anchors, closed);
    }
  }

  Rect get bounds => path().getBounds();

  List<_Anchor> toAnchors() {
    final c = box.center;
    Offset rp(Offset o) => _rot(o, c, rot * math.pi / 180);
    const k = .5523;
    final res = <_Anchor>[];
    if (kind == _Kind.ellipse) {
      final a = box.width / 2, b = box.height / 2;
      res.addAll([
        _Anchor(Offset(c.dx, box.top), hIn: Offset(c.dx - a * k, box.top), hOut: Offset(c.dx + a * k, box.top), smooth: true),
        _Anchor(Offset(box.right, c.dy), hIn: Offset(box.right, c.dy - b * k), hOut: Offset(box.right, c.dy + b * k), smooth: true),
        _Anchor(Offset(c.dx, box.bottom), hIn: Offset(c.dx + a * k, box.bottom), hOut: Offset(c.dx - a * k, box.bottom), smooth: true),
        _Anchor(Offset(box.left, c.dy), hIn: Offset(box.left, c.dy + b * k), hOut: Offset(box.left, c.dy - b * k), smooth: true),
      ]);
    } else {
      final r = math.min(rx, math.min(box.width, box.height) / 2);
      final cs = [
        (box.topLeft, const Offset(0, -1), const Offset(1, 0)),
        (box.topRight, const Offset(1, 0), const Offset(0, 1)),
        (box.bottomRight, const Offset(0, 1), const Offset(-1, 0)),
        (box.bottomLeft, const Offset(-1, 0), const Offset(0, -1)),
      ];
      for (final (cn, di, dout) in cs) {
        if (r <= .01) {
          res.add(_Anchor(cn));
        } else {
          final p1 = cn - di * r, p2 = cn + dout * r;
          res.add(_Anchor(p1, hOut: p1 + di * (r * k)));
          res.add(_Anchor(p2, hIn: p2 - dout * (r * k)));
        }
      }
    }
    for (final a in res) {
      a.map(rp);
    }
    return res;
  }

  void toPath() {
    if (kind == _Kind.path) return;
    anchors = toAnchors();
    kind = _Kind.path;
    closed = true;
    box = Rect.zero;
    rot = 0;
    rx = 0;
  }

  void shift(Offset d) {
    if (kind == _Kind.path) {
      for (final a in anchors) {
        a.shift(d);
      }
    } else {
      box = box.shift(d);
    }
  }

  void scaleAbout(Offset o, double k) {
    if (kind == _Kind.path) {
      for (final a in anchors) {
        a.map((q) => o + (q - o) * k);
      }
    } else {
      final c = o + (box.center - o) * k;
      box = Rect.fromCenter(center: c, width: box.width * k, height: box.height * k);
      rx *= k;
    }
  }

  void rotateAbout(Offset o, double rad) {
    if (kind == _Kind.path) {
      for (final a in anchors) {
        a.map((q) => _rot(q, o, rad));
      }
    } else {
      final c = _rot(box.center, o, rad);
      box = Rect.fromCenter(center: c, width: box.width, height: box.height);
      rot += rad * 180 / math.pi;
    }
  }

  void flip(bool horizontal) {
    final c = bounds.center;
    if (kind == _Kind.path) {
      for (final a in anchors) {
        a.map((q) => horizontal ? Offset(2 * c.dx - q.dx, q.dy) : Offset(q.dx, 2 * c.dy - q.dy));
      }
    } else {
      rot = -rot;
    }
  }

  bool hit(Offset p, double tol) {
    final pa = path();
    if (fill != null && pa.contains(p)) return true;
    final reach = tol + sw / 2;
    for (final m in pa.computeMetrics()) {
      for (var d = 0.0; d <= m.length; d += math.max(2, tol / 2)) {
        final t = m.getTangentForOffset(d);
        if (t != null && (t.position - p).distance <= reach) return true;
      }
    }
    return false;
  }

  String _style() {
    final b = StringBuffer(' fill="${fill == null ? 'none' : _hex(fill!)}"');
    if (stroke != null && sw > 0) {
      b.write(' stroke="${_hex(stroke!)}" stroke-width="${_n(sw)}"');
      if (cap != StrokeCap.butt) b.write(' stroke-linecap="${cap == StrokeCap.round ? 'round' : 'square'}"');
      if (join != StrokeJoin.miter) b.write(' stroke-linejoin="${join == StrokeJoin.round ? 'round' : 'bevel'}"');
      if (dash) b.write(' stroke-dasharray="${_n(sw * 3)} ${_n(sw * 2)}"');
    }
    if (opacity < 1) b.write(' opacity="${_n(opacity)}"');
    attrs.forEach((k, v) => b.write(' $k="$v"'));
    return b.toString();
  }

  String toElement() {
    final id_ = ' id="${name.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_')}$id"';
    final tr = rot == 0 ? '' : ' transform="rotate(${_n(rot)} ${_n(box.center.dx)} ${_n(box.center.dy)})"';
    switch (kind) {
      case _Kind.rect:
        return '<rect$id_ x="${_n(box.left)}" y="${_n(box.top)}" width="${_n(box.width)}" height="${_n(box.height)}"'
            '${rx > 0 ? ' rx="${_n(rx)}"' : ''}$tr${_style()}/>';
      case _Kind.ellipse:
        return '<ellipse$id_ cx="${_n(box.center.dx)}" cy="${_n(box.center.dy)}" rx="${_n(box.width / 2)}" ry="${_n(box.height / 2)}"$tr${_style()}/>';
      case _Kind.path:
        return '<path$id_ d="${_anchorsD(anchors, closed)}"${_style()}/>';
    }
  }
}

// ───────────────────────── SVG IMPORT ─────────────────────────

class _Parsed {
  _Parsed(this.w, this.h, this.shapes);
  final double w, h;
  final List<_Shape> shapes;
}

_Parsed _parseSvg(String src) {
  final attrRe = RegExp(r'([\w:-]+)\s*=\s*"([^"]*)"');
  Map<String, String> at(String s) => {for (final m in attrRe.allMatches(s)) m.group(1)!: m.group(2)!};

  var w = 400.0, h = 400.0;
  final root = RegExp(r'<svg\b([^>]*)>').firstMatch(src);
  if (root != null) {
    final a = at(root.group(1)!);
    final vb = a['viewBox']?.split(RegExp(r'[\s,]+')).map(double.tryParse).toList();
    if (vb != null && vb.length == 4 && vb[2] != null && vb[3] != null) {
      w = vb[2]!;
      h = vb[3]!;
    } else {
      w = double.tryParse(a['width'] ?? '') ?? w;
      h = double.tryParse(a['height'] ?? '') ?? h;
    }
  }

  var id = 1;
  final out = <_Shape>[];
  double num_(Map<String, String> a, String k, [double d = 0]) => double.tryParse(a[k] ?? '') ?? d;

  _Shape base(_Kind k, Map<String, String> a, {bool line = false}) {
    final s = _Shape(
      id: id++,
      kind: k,
      fill: line ? null : (a.containsKey('fill') ? _col(a['fill']) : const Color(0xFF000000)),
      stroke: _col(a['stroke']),
      sw: num_(a, 'stroke-width', a.containsKey('stroke') ? 1 : 0),
      opacity: num_(a, 'opacity', 1),
      cap: a['stroke-linecap'] == 'round' ? StrokeCap.round : a['stroke-linecap'] == 'square' ? StrokeCap.square : StrokeCap.butt,
      join: a['stroke-linejoin'] == 'round' ? StrokeJoin.round : a['stroke-linejoin'] == 'bevel' ? StrokeJoin.bevel : StrokeJoin.miter,
      dash: a.containsKey('stroke-dasharray'),
      attrs: {for (final e in a.entries) if (e.key.startsWith('data-')) e.key: e.value},
    );
    s.name = a['id'] ?? 'Shape';
    return s;
  }

  for (final m in RegExp(r'<(rect|ellipse|circle|line|polygon|polyline|path)\b([^>]*?)/?>').allMatches(src)) {
    final tag = m.group(1)!;
    final a = at(m.group(2)!);
    final rm = RegExp(r'rotate\(\s*(-?[\d.]+)').firstMatch(a['transform'] ?? '');
    final rot = rm == null ? 0.0 : double.parse(rm.group(1)!);
    switch (tag) {
      case 'rect':
        out.add(base(_Kind.rect, a)
          ..box = Rect.fromLTWH(num_(a, 'x'), num_(a, 'y'), num_(a, 'width'), num_(a, 'height'))
          ..rx = num_(a, 'rx', num_(a, 'ry'))
          ..rot = rot);
      case 'ellipse':
        out.add(base(_Kind.ellipse, a)
          ..box = Rect.fromCenter(center: Offset(num_(a, 'cx'), num_(a, 'cy')), width: num_(a, 'rx') * 2, height: num_(a, 'ry') * 2)
          ..rot = rot);
      case 'circle':
        final r = num_(a, 'r');
        out.add(base(_Kind.ellipse, a)..box = Rect.fromCircle(center: Offset(num_(a, 'cx'), num_(a, 'cy')), radius: r));
      case 'line':
        out.add(base(_Kind.path, a, line: true)
          ..anchors = [_Anchor(Offset(num_(a, 'x1'), num_(a, 'y1'))), _Anchor(Offset(num_(a, 'x2'), num_(a, 'y2')))]);
      case 'polygon' || 'polyline':
        final n = RegExp(r'-?\d*\.?\d+').allMatches(a['points'] ?? '').map((e) => double.parse(e.group(0)!)).toList();
        final pts = <_Anchor>[for (var i = 0; i + 1 < n.length; i += 2) _Anchor(Offset(n[i], n[i + 1]))];
        if (pts.length > 1) out.add(base(_Kind.path, a)..anchors = pts..closed = tag == 'polygon');
      case 'path':
        for (final (anchors, closed) in _parseD(a['d'] ?? '')) {
          out.add(base(_Kind.path, a)..anchors = anchors..closed = closed);
        }
    }
  }
  for (final s in out) {
    s.name = '${s.name} ${s.id}'.trim();
  }
  return _Parsed(w, h, out);
}

List<(List<_Anchor>, bool)> _parseD(String d) {
  final tk = RegExp(r'([a-zA-Z])|(-?\d*\.?\d+(?:[eE][-+]?\d+)?)').allMatches(d).map((m) => m.group(0)!).toList();
  final res = <(List<_Anchor>, bool)>[];
  var i = 0;
  var cmd = '';
  var cur = Offset.zero, start = Offset.zero;
  var cs = <_Anchor>[];
  var closed = false;
  double n() => double.parse(tk[i++]);
  bool isCmd(String s) => RegExp(r'^[a-zA-Z]$').hasMatch(s);
  void flush() {
    if (cs.length > 1) res.add((cs, closed));
    cs = [];
    closed = false;
  }

  while (i < tk.length) {
    if (isCmd(tk[i])) cmd = tk[i++];
    if (cmd.isEmpty) break;
    final rel = cmd == cmd.toLowerCase();
    switch (cmd.toUpperCase()) {
      case 'M':
        final p = Offset(n(), n());
        cur = rel ? cur + p : p;
        flush();
        cs = [_Anchor(cur)];
        start = cur;
        cmd = rel ? 'l' : 'L';
      case 'L':
        final p = Offset(n(), n());
        cur = rel ? cur + p : p;
        cs.add(_Anchor(cur));
      case 'H':
        final x = n();
        cur = Offset(rel ? cur.dx + x : x, cur.dy);
        cs.add(_Anchor(cur));
      case 'V':
        final y = n();
        cur = Offset(cur.dx, rel ? cur.dy + y : y);
        cs.add(_Anchor(cur));
      case 'C':
        var c1 = Offset(n(), n());
        var c2 = Offset(n(), n());
        var p = Offset(n(), n());
        if (rel) {
          c1 += cur;
          c2 += cur;
          p += cur;
        }
        if (cs.isNotEmpty) cs.last.hOut = c1;
        cs.add(_Anchor(p, hIn: c2));
        cur = p;
      case 'Z':
        closed = true;
        if (cs.length > 1 && (cs.last.p - cs.first.p).distance < .01) {
          final l = cs.removeLast();
          cs.first.hIn = l.hIn;
        }
        cur = start;
        flush();
      default:
        while (i < tk.length && !isCmd(tk[i])) {
          i++;
        }
    }
  }
  flush();
  return res;
}

// ───────────────────────── EDITOR PAGE ─────────────────────────

class SvgEditorPro extends StatefulWidget {
  const SvgEditorPro({super.key, required this.source, required this.title});
  final String source;
  final String title;

  @override
  State<SvgEditorPro> createState() => _SvgEditorProState();
}

class _SvgEditorProState extends State<SvgEditorPro> {
  double _w = 400, _h = 400;
  List<_Shape> _shapes = [];
  int _nextId = 1;
  int? _sel;
  int _aSel = -1;
  _Tool _tool = _Tool.select;
  _Mode _mode = _Mode.none;
  _Shape? _draft;

  double _scale = 1;
  Offset _off = Offset.zero;
  Size _cs = Size.zero;
  bool _fitted = false;
  bool _snap = false;
  int _tab = 0;
  bool _open = true;
  int _sides = 5;

  Color? _fillNew = _accent;
  Color? _strokeNew = Colors.white;
  double _swNew = 0;

  final _hist = <List<_Shape>>[];
  final _redoS = <List<_Shape>>[];

  // gesture state
  final _ptr = <int, Offset>{};
  bool _multi = false, _dragPushed = false, _moved = false;
  double _pinchD0 = 0, _pinchS0 = 1;
  Offset _pinchDoc = Offset.zero, _downS = Offset.zero, _last = Offset.zero, _fixed = Offset.zero, _rc = Offset.zero, _drawStart = Offset.zero;
  double _d0 = 1, _lastK = 1, _a0 = 0;

  @override
  void initState() {
    super.initState();
    try {
      final p = _parseSvg(widget.source);
      _w = p.w;
      _h = p.h;
      _shapes = p.shapes;
      _nextId = _shapes.fold(0, (m, s) => math.max(m, s.id)) + 1;
    } catch (_) {}
  }

  // ── helpers ──
  _Shape? get _selShape {
    for (final s in _shapes) {
      if (s.id == _sel) return s;
    }
    return null;
  }

  Offset _toDoc(Offset s) => (s - _off) / _scale;
  Offset _sp(Offset p) => _snap ? Offset((p.dx / 20).round() * 20.0, (p.dy / 20).round() * 20.0) : p;

  List<_Shape> _cl(List<_Shape> l) => l.map((e) => e.clone()).toList();

  void _pushHist() {
    _hist.add(_cl(_shapes));
    if (_hist.length > 60) _hist.removeAt(0);
    _redoS.clear();
  }

  void _beginEdit() {
    if (!_dragPushed) {
      _pushHist();
      _dragPushed = true;
    }
  }

  void _undo() {
    if (_hist.isEmpty) return;
    setState(() {
      _redoS.add(_cl(_shapes));
      _shapes = _hist.removeLast();
      if (_selShape == null) _sel = null;
      _aSel = -1;
    });
  }

  void _redo() {
    if (_redoS.isEmpty) return;
    setState(() {
      _hist.add(_cl(_shapes));
      _shapes = _redoS.removeLast();
      if (_selShape == null) _sel = null;
      _aSel = -1;
    });
  }

  void _fit() {
    const m = 24.0;
    final s = math.max(.05, math.min((_cs.width - m * 2) / _w, (_cs.height - m * 2) / _h));
    _scale = s;
    _off = Offset((_cs.width - _w * s) / 2, (_cs.height - _h * s) / 2);
  }

  String toSvg() {
    final b = StringBuffer('<svg xmlns="http://www.w3.org/2000/svg" width="${_n(_w)}" height="${_n(_h)}" viewBox="0 0 ${_n(_w)} ${_n(_h)}">\n');
    for (final s in _shapes) {
      if (s.visible) b.writeln('  ${s.toElement()}');
    }
    b.write('</svg>');
    return b.toString();
  }

  void _applyDefaults(_Shape s, {bool stroked = false}) {
    if (stroked) {
      s.fill = null;
      s.stroke = _strokeNew ?? _fillNew ?? Colors.white;
      s.sw = math.max(_swNew, 3);
      s.cap = StrokeCap.round;
      s.join = StrokeJoin.round;
    } else {
      s.fill = _fillNew;
      s.stroke = _strokeNew;
      s.sw = _swNew;
    }
  }

  void _setTool(_Tool t) {
    if (_tool == _Tool.pen && t != _Tool.pen && _draft != null) _finishPen();
    setState(() {
      _tool = t;
      _mode = _Mode.none;
      _aSel = -1;
      if (t == _Tool.node) {
        final s = _selShape;
        if (s != null && s.kind != _Kind.path) {
          _pushHist();
          s.toPath();
        }
        _tab = 2;
      }
    });
  }

  // ── pointer plumbing ──
  void _down(PointerDownEvent e) {
    _ptr[e.pointer] = e.localPosition;
    if (_ptr.length == 2) {
      _multi = true;
      _mode = _Mode.none;
      _draft = _tool == _Tool.pen ? _draft : null;
      final a = _ptr.values.first, b = _ptr.values.last;
      _pinchD0 = math.max(1, (a - b).distance);
      _pinchS0 = _scale;
      _pinchDoc = _toDoc((a + b) / 2);
    } else if (_ptr.length == 1) {
      _multi = false;
      _toolDown(e.localPosition);
    }
  }

  void _move(PointerMoveEvent e) {
    if (!_ptr.containsKey(e.pointer)) return;
    _ptr[e.pointer] = e.localPosition;
    if (_ptr.length >= 2) {
      final a = _ptr.values.first, b = _ptr.values.last;
      final f = (a + b) / 2;
      setState(() {
        _scale = (_pinchS0 * (a - b).distance / _pinchD0).clamp(.05, 60.0);
        _off = f - _pinchDoc * _scale;
      });
    } else if (!_multi) {
      _toolMove(e.localPosition);
    }
  }

  void _up(PointerEvent e, {bool cancel = false}) {
    final single = _ptr.length == 1 && !_multi;
    _ptr.remove(e.pointer);
    if (single && !cancel) _toolUp();
    if (_ptr.isEmpty) _multi = false;
  }

  void _signal(PointerSignalEvent e) {
    if (e is PointerScrollEvent) {
      final f = e.scrollDelta.dy < 0 ? 1.1 : 1 / 1.1;
      final d = _toDoc(e.localPosition);
      setState(() {
        _scale = (_scale * f).clamp(.05, 60.0);
        _off = e.localPosition - d * _scale;
      });
    }
  }

  // ── tools ──
  void _toolDown(Offset s) {
    _dragPushed = false;
    _moved = false;
    _downS = s;
    final p = _toDoc(s);
    _last = p;
    switch (_tool) {
      case _Tool.select:
        _selectDown(p);
      case _Tool.node:
        _nodeDown(p);
      case _Tool.pen:
        _penDown(p);
      case _Tool.line || _Tool.rect || _Tool.ellipse || _Tool.polygon || _Tool.star:
        _drawStart = _sp(p);
        _mode = _Mode.draw;
        final k = _tool == _Tool.rect ? _Kind.rect : _tool == _Tool.ellipse ? _Kind.ellipse : _Kind.path;
        _draft = _Shape(id: _nextId++, kind: k, closed: _tool == _Tool.polygon || _tool == _Tool.star);
        _applyDefaults(_draft!, stroked: _tool == _Tool.line);
    }
    setState(() {});
  }

  void _selectDown(Offset p) {
    final sh = _selShape;
    final tol = 14 / _scale;
    if (sh != null && !sh.locked) {
      final b = sh.bounds;
      final r = b.inflate(6 / _scale);
      final rotP = Offset(r.center.dx, r.top - 26 / _scale);
      if ((p - rotP).distance < tol) {
        _mode = _Mode.rotate;
        _rc = b.center;
        _a0 = math.atan2(p.dy - _rc.dy, p.dx - _rc.dx);
        return;
      }
      final cr = [r.topLeft, r.topRight, r.bottomRight, r.bottomLeft];
      final bc = [b.topLeft, b.topRight, b.bottomRight, b.bottomLeft];
      for (var i = 0; i < 4; i++) {
        if ((p - cr[i]).distance < tol) {
          _mode = _Mode.scale;
          _fixed = bc[(i + 2) % 4];
          _d0 = math.max(1, (bc[i] - _fixed).distance);
          _lastK = 1;
          return;
        }
      }
    }
    for (var i = _shapes.length - 1; i >= 0; i--) {
      final s = _shapes[i];
      if (s.visible && !s.locked && s.hit(p, 8 / _scale)) {
        _sel = s.id;
        _mode = _Mode.move;
        return;
      }
    }
    _sel = null;
    _mode = _Mode.none;
  }

  void _nodeDown(Offset p) {
    var sh = _selShape;
    final tol = 12 / _scale;
    if (sh == null || sh.kind != _Kind.path) {
      for (var i = _shapes.length - 1; i >= 0; i--) {
        final s = _shapes[i];
        if (s.visible && !s.locked && s.hit(p, 8 / _scale)) {
          _pushHist();
          s.toPath();
          _sel = s.id;
          _aSel = -1;
          return;
        }
      }
      return;
    }
    if (_aSel >= 0 && _aSel < sh.anchors.length) {
      final a = sh.anchors[_aSel];
      if (a.hIn != null && (a.hIn! - p).distance < tol) {
        _mode = _Mode.hIn;
        return;
      }
      if (a.hOut != null && (a.hOut! - p).distance < tol) {
        _mode = _Mode.hOut;
        return;
      }
    }
    for (var i = 0; i < sh.anchors.length; i++) {
      if ((sh.anchors[i].p - p).distance < tol) {
        _aSel = i;
        _mode = _Mode.anchor;
        return;
      }
    }
    final hit = _segHit(sh, p, tol);
    if (hit != null) {
      _pushHist();
      _aSel = _insertAt(sh, hit.$1, hit.$2);
      _mode = _Mode.anchor;
      _dragPushed = true;
      return;
    }
    for (var i = _shapes.length - 1; i >= 0; i--) {
      final s = _shapes[i];
      if (s.visible && !s.locked && s.id != sh.id && s.hit(p, 8 / _scale)) {
        _pushHist();
        s.toPath();
        _sel = s.id;
        _aSel = -1;
        return;
      }
    }
    _aSel = -1;
  }

  void _penDown(Offset p) {
    final tol = 12 / _scale;
    _draft ??= _Shape(id: _nextId++, kind: _Kind.path);
    final d = _draft!;
    if (d.anchors.isEmpty) _applyDefaults(d, stroked: true);
    if (d.anchors.length >= 3 && (p - d.anchors.first.p).distance < tol) {
      _finishPen(close: true);
      return;
    }
    d.anchors.add(_Anchor(_sp(p)));
    _mode = _Mode.penDrag;
  }

  void _finishPen({bool close = false}) {
    final d = _draft;
    _draft = null;
    _mode = _Mode.none;
    if (d == null || d.anchors.length < 2) {
      setState(() {});
      return;
    }
    d.closed = close;
    if (close) d.fill = _fillNew;
    d.name = 'Path ${d.id}';
    _pushHist();
    _shapes.add(d);
    _sel = d.id;
    _aSel = -1;
    setState(() => _tool = _Tool.node);
  }

  void _toolMove(Offset s) {
    if ((s - _downS).distance > 4) _moved = true;
    final p = _toDoc(s);
    final sh = _selShape;
    switch (_mode) {
      case _Mode.move:
        if (sh != null && _moved) {
          _beginEdit();
          sh.shift(p - _last);
          _last = p;
        }
      case _Mode.scale:
        if (sh != null) {
          _beginEdit();
          final k = math.max(.02, (p - _fixed).distance / _d0);
          sh.scaleAbout(_fixed, k / _lastK);
          _lastK = k;
        }
      case _Mode.rotate:
        if (sh != null) {
          _beginEdit();
          final a = math.atan2(p.dy - _rc.dy, p.dx - _rc.dx);
          sh.rotateAbout(_rc, a - _a0);
          _a0 = a;
        }
      case _Mode.anchor:
        if (sh != null && _aSel >= 0 && _moved) {
          _beginEdit();
          final a = sh.anchors[_aSel];
          a.shift(_sp(p) - a.p);
        }
      case _Mode.hIn || _Mode.hOut:
        if (sh != null && _aSel >= 0) {
          _beginEdit();
          final a = sh.anchors[_aSel];
          final q = _sp(p);
          if (_mode == _Mode.hOut) {
            a.hOut = q;
            if (a.smooth) a.hIn = a.p * 2 - q;
          } else {
            a.hIn = q;
            if (a.smooth) a.hOut = a.p * 2 - q;
          }
        }
      case _Mode.penDrag:
        final d = _draft;
        if (d != null && d.anchors.isNotEmpty) {
          final a = d.anchors.last;
          final v = _sp(p) - a.p;
          if (v.distance > 4 / _scale) {
            a.hOut = a.p + v;
            a.hIn = a.p - v;
            a.smooth = true;
          }
        }
      case _Mode.draw:
        final d = _draft;
        if (d == null) break;
        final q = _sp(p);
        switch (_tool) {
          case _Tool.rect || _Tool.ellipse:
            d.box = Rect.fromPoints(_drawStart, q);
          case _Tool.line:
            d.anchors = [_Anchor(_drawStart), _Anchor(q)];
          case _Tool.polygon || _Tool.star:
            d.anchors = _poly(_drawStart, (q - _drawStart).distance, _sides, star: _tool == _Tool.star);
          default:
        }
      case _Mode.none:
        break;
    }
    setState(() {});
  }

  void _toolUp() {
    if (_mode == _Mode.draw && _draft != null && _tool != _Tool.pen) {
      final d = _draft!;
      _draft = null;
      final ok = d.kind == _Kind.path ? d.bounds.longestSide > 3 : d.box.shortestSide > 2;
      if (ok) {
        _pushHist();
        d.name = '${_tool.name[0].toUpperCase()}${_tool.name.substring(1)} ${d.id}';
        _shapes.add(d);
        _sel = d.id;
        _tool = _Tool.select;
      }
    }
    _mode = _Mode.none;
    _dragPushed = false;
    setState(() {});
  }

  List<_Anchor> _poly(Offset c, double r, int n, {bool star = false}) {
    final cnt = star ? n * 2 : n;
    return [
      for (var i = 0; i < cnt; i++)
        _Anchor(c + Offset(math.cos(-math.pi / 2 + i * 2 * math.pi / cnt), math.sin(-math.pi / 2 + i * 2 * math.pi / cnt)) * (star && i.isOdd ? r * .45 : r)),
    ];
  }

  (int, double)? _segHit(_Shape sh, Offset p, double tol) {
    final a = sh.anchors, n = a.length;
    final cnt = sh.closed ? n : n - 1;
    var bi = -1;
    var bt = 0.0;
    var bd = tol;
    for (var i = 0; i < cnt; i++) {
      final x = a[i], y = a[(i + 1) % n];
      final c1 = x.hOut ?? x.p, c2 = y.hIn ?? y.p;
      for (var k = 0; k <= 24; k++) {
        final t = k / 24;
        final d = (_bez(x.p, c1, c2, y.p, t) - p).distance;
        if (d < bd) {
          bd = d;
          bi = i;
          bt = t;
        }
      }
    }
    return bi < 0 ? null : (bi, bt);
  }

  int _insertAt(_Shape sh, int i, double t) {
    final a = sh.anchors;
    final x = a[i], y = a[(i + 1) % a.length];
    final curved = x.hOut != null || y.hIn != null;
    late _Anchor na;
    if (!curved) {
      na = _Anchor(Offset.lerp(x.p, y.p, t)!);
    } else {
      final p1 = x.hOut ?? x.p, p2 = y.hIn ?? y.p;
      Offset l(Offset u, Offset v) => Offset.lerp(u, v, t)!;
      final q0 = l(x.p, p1), q1 = l(p1, p2), q2 = l(p2, y.p);
      final r0 = l(q0, q1), r1 = l(q1, q2);
      x.hOut = q0;
      y.hIn = q2;
      na = _Anchor(l(r0, r1), hIn: r0, hOut: r1, smooth: true);
    }
    a.insert(i + 1, na);
    return i + 1;
  }

  // ── actions on selection ──
  void _edit(void Function(_Shape s) fn) {
    final s = _selShape;
    if (s == null) return;
    setState(() {
      _pushHist();
      fn(s);
    });
  }

  void _duplicate() {
    final s = _selShape;
    if (s == null) return;
    setState(() {
      _pushHist();
      final c = s.clone();
      final n = _Shape(id: _nextId++, kind: c.kind, box: c.box, rx: c.rx, rot: c.rot, anchors: c.anchors, closed: c.closed, fill: c.fill, stroke: c.stroke, sw: c.sw, opacity: c.opacity, cap: c.cap, join: c.join, dash: c.dash, name: '${s.name} copy', attrs: c.attrs);
      n.shift(const Offset(14, 14));
      _shapes.add(n);
      _sel = n.id;
    });
  }

  void _delete() {
    final s = _selShape;
    if (s == null) return;
    setState(() {
      _pushHist();
      _shapes.removeWhere((e) => e.id == s.id);
      _sel = null;
      _aSel = -1;
    });
  }

  void _align(int how) {
    final s = _selShape;
    if (s == null) return;
    final b = s.bounds;
    final d = switch (how) {
      0 => Offset(-b.left, 0),
      1 => Offset(_w / 2 - b.center.dx, 0),
      2 => Offset(_w - b.right, 0),
      3 => Offset(0, -b.top),
      4 => Offset(0, _h / 2 - b.center.dy),
      _ => Offset(0, _h - b.bottom),
    };
    _edit((x) => x.shift(d));
  }

  void _reorder(int i, int dir) {
    final j = i + dir;
    if (j < 0 || j >= _shapes.length) return;
    setState(() {
      _pushHist();
      final t = _shapes[i];
      _shapes[i] = _shapes[j];
      _shapes[j] = t;
    });
  }

  void _smoothToggle() {
    final s = _selShape;
    if (s == null || _aSel < 0 || _aSel >= s.anchors.length) return;
    setState(() {
      _pushHist();
      final a = s.anchors[_aSel];
      final n = s.anchors.length;
      if (a.smooth) {
        a.smooth = false;
        return;
      }
      final prev = (_aSel > 0 || s.closed) ? s.anchors[(_aSel - 1 + n) % n].p : null;
      final next = (_aSel < n - 1 || s.closed) ? s.anchors[(_aSel + 1) % n].p : null;
      final from = prev ?? a.p, to = next ?? a.p;
      var dir = to - from;
      if (dir.distance < .01) return;
      dir = dir / dir.distance;
      final len = math.min(prev == null ? 1e9 : (a.p - prev).distance, next == null ? 1e9 : (a.p - next).distance) / 3;
      a.hIn = a.p - dir * len;
      a.hOut = a.p + dir * len;
      a.smooth = true;
    });
  }

  void _deleteAnchor() {
    final s = _selShape;
    if (s == null || _aSel < 0 || _aSel >= s.anchors.length) return;
    setState(() {
      _pushHist();
      s.anchors.removeAt(_aSel);
      _aSel = -1;
      if (s.anchors.length < 2) {
        _shapes.removeWhere((e) => e.id == s.id);
        _sel = null;
      }
    });
  }

  Future<Color?> _pickHex() async {
    final c = TextEditingController();
    final r = await showDialog<Color>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _panel,
        title: const Text('Custom color', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: TextField(
          controller: c,
          autofocus: true,
          style: _strong,
          decoration: const InputDecoration(hintText: '#2DE2D0', hintStyle: TextStyle(color: Colors.white38)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _accent, foregroundColor: Colors.black),
            onPressed: () {
              final t = c.text.trim().startsWith('#') ? c.text.trim() : '#${c.text.trim()}';
              Navigator.pop(context, t.length >= 4 ? _col(t) : null);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    return r;
  }

  // ───────────── BUILD ─────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
        title: Text(widget.title, style: const TextStyle(fontSize: 15)),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Grid snap',
            onPressed: () => setState(() => _snap = !_snap),
            icon: Icon(Icons.grid_4x4, color: _snap ? _accent : Colors.white54),
          ),
          IconButton(
            tooltip: 'Fit',
            onPressed: () => setState(_fit),
            icon: const Icon(Icons.fit_screen_outlined, color: Colors.white70),
          ),
          IconButton(
            tooltip: 'Undo',
            onPressed: _hist.isEmpty ? null : _undo,
            icon: Icon(Icons.undo_rounded, color: _hist.isEmpty ? Colors.white24 : Colors.white),
          ),
          IconButton(
            tooltip: 'Redo',
            onPressed: _redoS.isEmpty ? null : _redo,
            icon: Icon(Icons.redo_rounded, color: _redoS.isEmpty ? Colors.white24 : Colors.white),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 10, left: 2),
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: Colors.black,
                visualDensity: VisualDensity.compact,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
              onPressed: () => Navigator.pop(context, toSvg()),
              child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(children: [
          Expanded(child: _canvas()),
          _toolRow(),
          _bottom(),
        ]),
      ),
    );
  }

  static const _hints = {
    _Tool.select: 'Tap to select · drag to move · corners scale · top dot rotates',
    _Tool.node: 'Drag points and handles · tap the path to add a point',
    _Tool.pen: 'Tap to add points · drag for curves · tap first point to close',
    _Tool.line: 'Drag to draw a line',
    _Tool.rect: 'Drag to draw a rectangle',
    _Tool.ellipse: 'Drag to draw an ellipse',
    _Tool.polygon: 'Drag from the center to draw a polygon',
    _Tool.star: 'Drag from the center to draw a star',
  };

  Widget _canvas() {
    return LayoutBuilder(builder: (c, box) {
      _cs = Size(box.maxWidth, box.maxHeight);
      if (!_fitted) {
        _fitted = true;
        WidgetsBinding.instance.addPostFrameCallback((_) => setState(_fit));
      }
      return Stack(children: [
        Positioned.fill(
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: _down,
            onPointerMove: _move,
            onPointerUp: (e) => _up(e),
            onPointerCancel: (e) => _up(e, cancel: true),
            onPointerSignal: _signal,
            child: ClipRect(child: CustomPaint(painter: _Painter(this), size: Size.infinite)),
          ),
        ),
        Positioned(
          left: 12,
          bottom: 8,
          right: 12,
          child: IgnorePointer(
            child: Text(_hints[_tool]!, style: _lbl.copyWith(color: Colors.white54), maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ),
        Positioned(
          right: 10,
          top: 8,
          child: Row(children: [
            if (_draft != null && _tool == _Tool.pen) ...[
              _chipBtn('Cancel', () => setState(() => _draft = null)),
              const SizedBox(width: 6),
              _chipBtn('Done', () => _finishPen(), primary: true),
            ],
            if (_tool == _Tool.polygon || _tool == _Tool.star) ...[
              _chipBtn('−', () => setState(() => _sides = math.max(3, _sides - 1))),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text('$_sides', style: _strong)),
              _chipBtn('+', () => setState(() => _sides = math.min(14, _sides + 1))),
            ],
          ]),
        ),
        Positioned(
          left: 12,
          top: 8,
          child: IgnorePointer(
            child: Text('${(_scale * 100).round()}%', style: _lbl.copyWith(color: Colors.white38)),
          ),
        ),
      ]);
    });
  }

  Widget _chipBtn(String t, VoidCallback f, {bool primary = false}) => GestureDetector(
        onTap: f,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: primary ? _accent : _field, borderRadius: BorderRadius.circular(14)),
          child: Text(t, style: TextStyle(color: primary ? Colors.black : Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
        ),
      );

  Widget _toolRow() {
    const tools = [
      (_Tool.select, Icons.near_me_outlined, 'Select'),
      (_Tool.node, Icons.polyline_outlined, 'Nodes'),
      (_Tool.pen, Icons.edit_outlined, 'Pen'),
      (_Tool.line, Icons.horizontal_rule, 'Line'),
      (_Tool.rect, Icons.crop_square, 'Rectangle'),
      (_Tool.ellipse, Icons.circle_outlined, 'Ellipse'),
      (_Tool.polygon, Icons.hexagon_outlined, 'Polygon'),
      (_Tool.star, Icons.star_border_rounded, 'Star'),
    ];
    return Container(
      height: 72,
      color: _panel,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        children: [
          for (final (t, ic, l) in tools)
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                _setTool(t);
              },
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: SizedBox(
                  width: 58,
                  child: Column(children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 40,
                      height: 38,
                      decoration: BoxDecoration(
                        color: _tool == t ? _accent.withValues(alpha: .16) : _field,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _tool == t ? _accent : Colors.transparent, width: 1.5),
                      ),
                      child: Icon(ic, size: 21, color: _tool == t ? _accent : Colors.white70),
                    ),
                    const SizedBox(height: 3),
                    Text(l, style: TextStyle(fontSize: 10, color: _tool == t ? Colors.white : const Color(0xFF9A9A9A))),
                  ]),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _bottom() {
    Widget tab(int i, IconData ic, String l) {
      final on = _tab == i && _open;
      return Expanded(
        child: InkWell(
          onTap: () => setState(() {
            if (_tab == i) {
              _open = !_open;
            } else {
              _tab = i;
              _open = true;
            }
          }),
          child: Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 6),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(ic, size: 20, color: on ? _accent : Colors.white54),
              const SizedBox(height: 2),
              Text(l, style: TextStyle(fontSize: 10.5, color: on ? Colors.white : Colors.white54, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      );
    }

    return Container(
      color: _panel,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: Colors.white10))),
          child: Row(children: [
            tab(0, Icons.palette_outlined, 'Style'),
            tab(1, Icons.open_with, 'Arrange'),
            tab(2, Icons.timeline, 'Node'),
            tab(3, Icons.layers_outlined, 'Layers'),
          ]),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: _open ? 176 : 0,
          clipBehavior: Clip.hardEdge,
          decoration: const BoxDecoration(),
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: SizedBox(
              height: 176,
              child: switch (_tab) {
                0 => _styleTab(),
                1 => _arrangeTab(),
                2 => _nodeTab(),
                _ => _layersTab(),
              },
            ),
          ),
        ),
      ]),
    );
  }

  // ── tabs ──
  Widget _styleTab() {
    final s = _selShape;
    final fill = s != null ? s.fill : _fillNew;
    final stroke = s != null ? s.stroke : _strokeNew;
    final sw = s != null ? s.sw : _swNew;
    return ListView(padding: const EdgeInsets.fromLTRB(14, 4, 14, 12), children: [
      _sec(s == null ? 'Fill · new shapes' : 'Fill'),
      _swatches(fill, (c) {
        if (s != null) _edit((x) => x.fill = c);
        setState(() => _fillNew = c);
      }),
      _sec('Stroke'),
      _swatches(stroke, (c) {
        if (s != null) {
          _edit((x) {
            x.stroke = c;
            if (c != null && x.sw == 0) x.sw = 2;
          });
        }
        setState(() {
          _strokeNew = c;
          if (c != null && _swNew == 0) _swNew = 2;
        });
      }),
      _slider('Stroke width', sw, 0, 24, (v) {
        if (s != null) s.sw = v;
        setState(() => _swNew = v);
      }),
      if (s != null) ...[
        _slider('Opacity', s.opacity, 0, 1, (v) => setState(() => s.opacity = v), pct: true),
        _sec('Stroke cap'),
        _pills(['Butt', 'Round', 'Square'], s.cap.index, (i) => _edit((x) => x.cap = StrokeCap.values[i])),
        _sec('Stroke join'),
        _pills(['Miter', 'Round', 'Bevel'], s.join.index, (i) => _edit((x) => x.join = StrokeJoin.values[i])),
        _sec('Line style'),
        _pills(['Solid', 'Dashed'], s.dash ? 1 : 0, (i) => _edit((x) => x.dash = i == 1)),
      ],
    ]);
  }

  Widget _arrangeTab() {
    final s = _selShape;
    if (s == null) return _empty('Select a shape to arrange it.');
    final isBox = s.kind != _Kind.path;
    return ListView(padding: const EdgeInsets.fromLTRB(14, 4, 14, 12), children: [
      if (isBox) _slider('Rotation', s.rot.clamp(-180, 180).toDouble(), -180, 180, (v) => setState(() => s.rot = v), unit: '°', digits: 0),
      if (s.kind == _Kind.rect)
        _slider('Corner radius', s.rx, 0, math.max(1, math.min(s.box.width, s.box.height) / 2), (v) => setState(() => s.rx = v)),
      _sec('Actions'),
      Wrap(spacing: 8, runSpacing: 8, children: [
        _act(Icons.copy_outlined, 'Duplicate', _duplicate),
        _act(Icons.delete_outline, 'Delete', _delete),
        _act(Icons.flip, 'Flip H', () => _edit((x) => x.flip(true))),
        _act(Icons.flip_camera_android_outlined, 'Flip V', () => _edit((x) => x.flip(false))),
        _act(Icons.rotate_left, '−15°', () => _edit((x) => x.rotateAbout(x.bounds.center, -math.pi / 12))),
        _act(Icons.rotate_right, '+15°', () => _edit((x) => x.rotateAbout(x.bounds.center, math.pi / 12))),
        if (isBox) _act(Icons.polyline_outlined, 'To path', () => _edit((x) => x.toPath())),
      ]),
      _sec('Align to artboard'),
      Row(children: [
        for (final (i, ic) in [
          Icons.align_horizontal_left,
          Icons.align_horizontal_center,
          Icons.align_horizontal_right,
          Icons.align_vertical_top,
          Icons.align_vertical_center,
          Icons.align_vertical_bottom,
        ].indexed)
          Expanded(
            child: IconButton(onPressed: () => _align(i), icon: Icon(ic, size: 20, color: Colors.white70)),
          ),
      ]),
    ]);
  }

  Widget _nodeTab() {
    final s = _selShape;
    if (s == null || s.kind != _Kind.path) {
      return _empty('Pick the Nodes tool and tap a shape\nto edit its points and curves.');
    }
    final a = (_aSel >= 0 && _aSel < s.anchors.length) ? s.anchors[_aSel] : null;
    return ListView(padding: const EdgeInsets.fromLTRB(14, 8, 14, 12), children: [
      Text(a == null ? '${s.anchors.length} points · tap one to edit' : 'Point ${_aSel + 1} of ${s.anchors.length} · ${a.smooth ? 'smooth' : 'corner'}', style: _lbl),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: [
        _act(a?.smooth == true ? Icons.change_history : Icons.gesture, a?.smooth == true ? 'Make corner' : 'Make smooth', a == null ? null : _smoothToggle),
        _act(Icons.remove_circle_outline, 'Delete point', a == null ? null : _deleteAnchor),
        _act(Icons.vertical_align_center, 'Reset handles', a == null ? null : () => _edit((x) {
              final p = x.anchors[_aSel];
              p.hIn = null;
              p.hOut = null;
              p.smooth = false;
            })),
        _act(s.closed ? Icons.link_off : Icons.link, s.closed ? 'Open path' : 'Close path', () => _edit((x) => x.closed = !x.closed)),
      ]),
    ]);
  }

  Widget _layersTab() {
    if (_shapes.isEmpty) return _empty('No layers yet. Draw something.');
    return ListView(padding: const EdgeInsets.fromLTRB(14, 6, 14, 12), children: [
      for (var i = _shapes.length - 1; i >= 0; i--)
        GestureDetector(
          onTap: () => setState(() {
            _sel = _shapes[i].id;
            _aSel = -1;
          }),
          child: Container(
            margin: const EdgeInsets.only(bottom: 5),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _shapes[i].id == _sel ? _accent : Colors.transparent, width: 1.5),
            ),
            child: Row(children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: _shapes[i].fill ?? _shapes[i].stroke ?? Colors.white24,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(_shapes[i].name, style: _strong.copyWith(fontSize: 12), overflow: TextOverflow.ellipsis)),
              _mini(Icons.keyboard_arrow_up, () => _reorder(i, 1)),
              _mini(Icons.keyboard_arrow_down, () => _reorder(i, -1)),
              _mini(_shapes[i].locked ? Icons.lock_outline : Icons.lock_open_outlined, () => setState(() => _shapes[i].locked = !_shapes[i].locked)),
              _mini(_shapes[i].visible ? Icons.visibility_outlined : Icons.visibility_off_outlined, () => setState(() => _shapes[i].visible = !_shapes[i].visible)),
            ]),
          ),
        ),
    ]);
  }

  // ── small widgets ──
  Widget _mini(IconData i, VoidCallback f) => InkWell(
        onTap: f,
        child: Padding(padding: const EdgeInsets.all(5), child: Icon(i, size: 18, color: Colors.white70)),
      );

  Widget _empty(String t) => Center(child: Text(t, textAlign: TextAlign.center, style: _lbl));

  Widget _sec(String t) => Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 6),
        child: Text(t.toUpperCase(), style: _lbl.copyWith(fontSize: 10, letterSpacing: 1.2, color: Colors.white38)),
      );

  Widget _act(IconData i, String l, VoidCallback? f) => GestureDetector(
        onTap: f,
        child: Opacity(
          opacity: f == null ? .35 : 1,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: _field, borderRadius: BorderRadius.circular(12)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(i, size: 16, color: _accent),
              const SizedBox(width: 6),
              Text(l, style: const TextStyle(color: Colors.white, fontSize: 12)),
            ]),
          ),
        ),
      );

  Widget _pills(List<String> l, int on, ValueChanged<int> f) => Wrap(spacing: 8, children: [
        for (var i = 0; i < l.length; i++)
          GestureDetector(
            onTap: () => f(i),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(color: i == on ? _accent : _field, borderRadius: BorderRadius.circular(16)),
              child: Text(l[i], style: TextStyle(color: i == on ? Colors.black : const Color(0xFFD8D8D8), fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ),
      ]);

  Widget _swatches(Color? cur, ValueChanged<Color?> f) {
    Widget dot(Color? c) {
      final on = c == cur;
      return GestureDetector(
        onTap: () => f(c),
        child: Container(
          width: 30,
          height: 30,
          margin: const EdgeInsets.only(right: 10),
          decoration: BoxDecoration(
            color: c ?? _field,
            shape: BoxShape.circle,
            border: Border.all(color: on ? _accent : Colors.white24, width: on ? 2.5 : 1),
          ),
          child: c == null ? const Icon(Icons.block, size: 16, color: Colors.redAccent) : null,
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        dot(null),
        for (final c in _palette) dot(c),
        GestureDetector(
          onTap: () async {
            final c = await _pickHex();
            if (c != null) f(c);
          },
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _accent)),
            child: const Icon(Icons.add, size: 16, color: _accent),
          ),
        ),
      ]),
    );
  }

  Widget _slider(String label, double v, double mn, double mx, ValueChanged<double> f, {bool pct = false, String unit = '', int digits = 1}) {
    final shown = pct ? '${(v * 100).round()}%' : '${v.toStringAsFixed(digits)}$unit';
    return Column(children: [
      Row(children: [
        Expanded(child: Text(label, style: _lbl)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: _field, borderRadius: BorderRadius.circular(6)),
          child: Text(shown, style: _strong.copyWith(fontSize: 11.5)),
        ),
      ]),
      SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: 3,
          activeTrackColor: _accent,
          inactiveTrackColor: Colors.white12,
          thumbColor: Colors.white,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8, elevation: 2),
          overlayShape: SliderComponentShape.noOverlay,
        ),
        child: Slider(
          value: v.clamp(mn, mx).toDouble(),
          min: mn,
          max: mx,
          onChangeStart: (_) => _pushHist(),
          onChanged: f,
        ),
      ),
    ]);
  }
}

// ───────────────────────── PAINTER ─────────────────────────

class _Painter extends CustomPainter {
  _Painter(this.st);
  final _SvgEditorProState st;

  Path _dashed(Path src, double on, double off) {
    final out = Path();
    for (final m in src.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += on + off) {
        out.addPath(m.extractPath(d, math.min(d + on, m.length)), Offset.zero);
      }
    }
    return out;
  }

  void _drawShape(Canvas c, _Shape s) {
    final pa = s.path();
    if (s.fill != null) {
      c.drawPath(pa, Paint()..style = PaintingStyle.fill..color = s.fill!.withValues(alpha: s.opacity));
    }
    if (s.stroke != null && s.sw > 0) {
      c.drawPath(
        s.dash ? _dashed(pa, s.sw * 3, s.sw * 2) : pa,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s.sw
          ..strokeCap = s.cap
          ..strokeJoin = s.join
          ..color = s.stroke!.withValues(alpha: s.opacity),
      );
    }
  }

  @override
  void paint(Canvas c, Size size) {
    final z = st._scale;
    c.save();
    c.translate(st._off.dx, st._off.dy);
    c.scale(z);
    final art = Rect.fromLTWH(0, 0, st._w, st._h);
    c.drawRect(art, Paint()..color = const Color(0xFF1C1C1C));
    c.save();
    c.clipRect(art);
    if (st._snap) {
      final g = Paint()
        ..color = Colors.white.withValues(alpha: .06)
        ..strokeWidth = 1 / z;
      for (var x = 0.0; x <= st._w; x += 20) {
        c.drawLine(Offset(x, 0), Offset(x, st._h), g);
      }
      for (var y = 0.0; y <= st._h; y += 20) {
        c.drawLine(Offset(0, y), Offset(st._w, y), g);
      }
    }
    for (final s in st._shapes) {
      if (s.visible) _drawShape(c, s);
    }
    final d = st._draft;
    if (d != null) _drawShape(c, d);
    c.restore();
    c.drawRect(art, Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.white24
      ..strokeWidth = 1 / z);

    final line = Paint()
      ..style = PaintingStyle.stroke
      ..color = _accent
      ..strokeWidth = 1.3 / z;
    final handleFill = Paint()..color = Colors.white;
    final u = 1 / z;

    // pen draft markers
    if (d != null && st._tool == _Tool.pen) {
      for (final a in d.anchors) {
        c.drawCircle(a.p, 4 * u, Paint()..color = _accent);
      }
      if (d.anchors.length >= 3) {
        c.drawCircle(d.anchors.first.p, 7 * u, line);
      }
    }

    final sh = st._selShape;
    if (sh != null && sh.visible) {
      if (st._tool == _Tool.node && sh.kind == _Kind.path) {
        c.drawPath(sh.path(), line);
        for (var i = 0; i < sh.anchors.length; i++) {
          final a = sh.anchors[i];
          final on = i == st._aSel;
          if (on) {
            for (final h in [a.hIn, a.hOut]) {
              if (h == null) continue;
              c.drawLine(a.p, h, line);
              c.drawCircle(h, 4.5 * u, handleFill);
              c.drawCircle(h, 4.5 * u, line);
            }
          }
          final r = Rect.fromCenter(center: a.p, width: 9 * u, height: 9 * u);
          c.drawRect(r, Paint()..color = on ? _accent : Colors.white);
          c.drawRect(r, line);
        }
      } else if (st._tool == _Tool.select || st._tool == _Tool.node) {
        final b = sh.bounds;
        final r = b.inflate(6 * u);
        c.drawRect(r, line);
        for (final p in [r.topLeft, r.topRight, r.bottomRight, r.bottomLeft]) {
          final h = Rect.fromCenter(center: p, width: 10 * u, height: 10 * u);
          c.drawRect(h, handleFill);
          c.drawRect(h, line);
        }
        final rp = Offset(r.center.dx, r.top - 26 * u);
        c.drawLine(Offset(r.center.dx, r.top), rp, line);
        c.drawCircle(rp, 6 * u, Paint()..color = _accent);
      }
    }
    c.restore();
  }

  @override
  bool shouldRepaint(covariant _Painter old) => true;
}