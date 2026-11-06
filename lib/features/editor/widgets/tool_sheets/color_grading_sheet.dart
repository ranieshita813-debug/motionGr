import 'package:phosphor_icons/phosphor_icons.dart';
// lib/features/editor/widgets/color_grade_sheet.dart
//
// Color grading panel, CapCut style.
//   Looks    one-tap filters with a strength slider
//   Adjust   one big slider on top, a row of icon tiles below (pick a tool)
//   Wheels   shadows / midtones / highlights color wheels + luma
//   Curves   master / R / G / B point curves
//
// Footer:  X  |  Looks  Adjust  Wheels  Curves  |  check
// Top row: hold-to-compare, current tool name, Reset.
//
// Edits stream to [onChanged] for live preview (use grade.toColorFilter());
// check commits via [onApply], X reverts the preview. Export: grade.toFfmpeg().

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_video_editor/core/models/color_grade.dart';
import 'package:flutter_video_editor/features/editor/utils/editor_helpers.dart';

const Color _bg = bgToken;
const Color _card = Color(0xFF1C1C1E);
const Color _cardOn = Color(0xFF2C2C2E);
const Color _field = Color(0xFF141416);
const Color _line = Color(0xFF2A2A2D);
const Color _track = Color(0xFF3A3A3C);
const Color _text = Color(0xFFFFFFFF);
const Color _muted = Color(0xFF8E8E93);
const Color _accent = Color(0xFF2DE2E6);

enum _Tab {
  looks('Looks'),
  adjust('Adjust'),
  wheels('Wheels'),
  curves('Curves');

  const _Tab(this.label);
  final String label;
}

const List<GradeParam> _order = <GradeParam>[
  GradeParam.exposure,
  GradeParam.contrast,
  GradeParam.saturation,
  GradeParam.vibrance,
  GradeParam.highlights,
  GradeParam.shadows,
  GradeParam.whites,
  GradeParam.blacks,
  GradeParam.temperature,
  GradeParam.tint,
  GradeParam.fade,
  GradeParam.sharpen,
  GradeParam.vignette,
  GradeParam.grain,
];

IconData _paramIcon(GradeParam p) => switch (p) {
      GradeParam.exposure => Icons.wb_sunny_outlined,
      GradeParam.contrast => Icons.contrast_rounded,
      GradeParam.saturation => Icons.opacity_rounded,
      GradeParam.vibrance => Icons.flare_rounded,
      GradeParam.highlights => Icons.brightness_high_rounded,
      GradeParam.shadows => Icons.brightness_low_rounded,
      GradeParam.whites => Icons.circle_outlined,
      GradeParam.blacks => Icons.circle,
      GradeParam.temperature => Icons.thermostat_rounded,
      GradeParam.tint => Icons.water_drop_outlined,
      GradeParam.fade => Icons.gradient_rounded,
      GradeParam.sharpen => Icons.change_history_rounded,
      GradeParam.vignette => Icons.vignette_rounded,
      GradeParam.grain => Icons.grain_rounded,
    };

List<Color>? _gradient(GradeParam p) => switch (p) {
      GradeParam.temperature => const <Color>[
          Color(0xFF3B82F6), Color(0xFF6B6B72), Color(0xFFF5A524)],
      GradeParam.tint => const <Color>[
          Color(0xFF4ADE80), Color(0xFF6B6B72), Color(0xFFE879F9)],
      _ => null,
    };

Color _channelColor(CurveChannel c) => switch (c) {
      CurveChannel.master => const Color(0xFFEDEDED),
      CurveChannel.red => const Color(0xFFFF5A5A),
      CurveChannel.green => const Color(0xFF5AE08A),
      CurveChannel.blue => const Color(0xFF5A9CFF),
    };

class ColorGradeSheet extends StatefulWidget {
  const ColorGradeSheet({
    super.key,
    this.initial = ColorGrade.identity,
    this.onChanged,
    required this.onApply,
    required this.onClose,
  });

  final ColorGrade initial;
  final ValueChanged<ColorGrade>? onChanged;
  final ValueChanged<ColorGrade> onApply;
  final VoidCallback onClose;

  @override
  State<ColorGradeSheet> createState() => _ColorGradeSheetState();
}

class _ColorGradeSheetState extends State<ColorGradeSheet> {
  late ColorGrade _g = widget.initial;
  _Tab _tab = _Tab.adjust;
  GradeLook? _activeLook;
  double _strength = 1;
  CurveChannel _ch = CurveChannel.master;
  GradeParam _param = GradeParam.exposure;

  // ---- state ----------------------------------------------------------------

  void _emit(ColorGrade g) {
    setState(() {
      _g = g;
      _activeLook = null; // manual edit detaches from the look
    });
    widget.onChanged?.call(g);
  }

  void _setParam(GradeParam p, double v) {
    final double old = _g[p];
    final ColorGrade next = _g.setParam(p, v);
    if (next == _g) return;
    if (old != 0 && next[p] == 0) HapticFeedback.selectionClick();
    _emit(next);
  }

  void _pickLook(GradeLook? look) {
    HapticFeedback.selectionClick();
    final ColorGrade g = look == null ? ColorGrade.identity : look.grade;
    setState(() {
      _activeLook = look;
      _strength = 1;
      _g = g;
    });
    widget.onChanged?.call(g);
  }

  void _setStrength(double v) {
    final GradeLook? l = _activeLook;
    if (l == null) return;
    final double s = (v / 100).clamp(0.0, 1.0).toDouble();
    final ColorGrade g = ColorGrade.scaled(l.grade, s);
    setState(() {
      _strength = s;
      _g = g;
    });
    widget.onChanged?.call(g);
  }

  void _resetAll() {
    HapticFeedback.selectionClick();
    setState(() {
      _g = ColorGrade.identity;
      _activeLook = null;
      _strength = 1;
    });
    widget.onChanged?.call(_g);
  }

  void _cancel() {
    widget.onChanged?.call(widget.initial); // revert live preview
    widget.onClose();
  }

  void _apply() {
    HapticFeedback.lightImpact();
    if (_g != widget.initial) widget.onApply(_g);
    widget.onClose();
  }

  bool _edited(_Tab t) => switch (t) {
        _Tab.looks => _activeLook != null,
        _Tab.adjust => _order.any((p) => _g[p] != 0),
        _Tab.wheels => GradeRange.values.any((r) => !_g.wheel(r).isIdentity),
        _Tab.curves => _g.curves.isNotEmpty,
      };

  // ---- build ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _bg,
      child: Column(
        children: <Widget>[
          _topRow(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 12),
              child: switch (_tab) {
                _Tab.looks => _looksTab(),
                _Tab.adjust => _adjustTab(),
                _Tab.wheels => _wheelsTab(),
                _Tab.curves => _curvesTab(),
              },
            ),
          ),
          _footer(),
        ],
      ),
    );
  }

  Widget _topRow() {
    final String title = switch (_tab) {
      _Tab.looks => _activeLook?.name ?? 'Original',
      _Tab.adjust => _param.label,
      _Tab.wheels => 'Color wheels',
      _Tab.curves => 'Curves',
    };
    return SizedBox(
      height: 46,
      child: Row(
        children: <Widget>[
          // Press and hold to preview the original.
          SizedBox(
            width: 64,
            child: Listener(
              onPointerDown: (_) => widget.onChanged?.call(ColorGrade.identity),
              onPointerUp: (_) => widget.onChanged?.call(_g),
              onPointerCancel: (_) => widget.onChanged?.call(_g),
              child: Semantics(
                button: true,
                label: 'Hold to compare with original',
                child: const Center(
                  child: Icon(Icons.compare_rounded, size: 22, color: _muted),
                ),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: _text, fontSize: 13.5, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          SizedBox(
            width: 64,
            child: TextButton(
              onPressed: _g.isIdentity ? null : _resetAll,
              style: TextButton.styleFrom(
                foregroundColor: _text,
                disabledForegroundColor: _track,
                minimumSize: const Size(48, 40),
                padding: EdgeInsets.zero,
              ),
              child: const Text('Reset',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _footer() => Container(
        height: 52,
        decoration: const BoxDecoration(
          color: _bg,
          border: Border(top: BorderSide(color: _line)),
        ),
        child: Row(
          children: <Widget>[
            IconButton(
              tooltip: 'Cancel',
              icon: const Icon(PhosphorIconsRegular.x, color: _text),
              onPressed: _cancel,
            ),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[for (final t in _Tab.values) _tabItem(t)],
              ),
            ),
            IconButton(
              tooltip: 'Apply',
              icon: Icon(PhosphorIconsRegular.check,
                  color: _g != widget.initial ? _accent : _text, size: 26),
              onPressed: _apply,
            ),
          ],
        ),
      );

  Widget _tabItem(_Tab t) {
    final bool on = t == _tab;
    final bool edited = _edited(t);
    return Semantics(
      button: true,
      selected: on,
      label: '${t.label}${edited ? ', changed' : ''}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _tab = t);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                t.label,
                style: TextStyle(
                  color: on ? _text : _muted,
                  fontSize: 13.5,
                  fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              if (edited) ...<Widget>[
                const SizedBox(width: 4),
                const CircleAvatar(radius: 2.5, backgroundColor: _accent),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ---- Looks ----------------------------------------------------------------

  Widget _looksTab() {
    return Column(
      children: <Widget>[
        const SizedBox(height: 4),
        if (_activeLook != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _CapSlider(
              value: _strength * 100,
              min: 0,
              resetTo: 100,
              onChanged: _setStrength,
            ),
          )
        else
          const SizedBox(
            height: 58,
            child: Center(
              child: Text('Pick a look to adjust its strength',
                  style: TextStyle(color: _muted, fontSize: 12)),
            ),
          ),
        const SizedBox(height: 10),
        SizedBox(
          height: 104,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: <Widget>[
              _lookTile('Original', null, _g.isIdentity && _activeLook == null),
              for (final l in kGradeLooks) _lookTile(l.name, l, _activeLook == l),
            ],
          ),
        ),
      ],
    );
  }

  Widget _lookTile(String name, GradeLook? look, bool on) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Semantics(
        button: true,
        selected: on,
        label: '$name look',
        child: GestureDetector(
          onTap: () => _pickLook(look),
          child: SizedBox(
            width: 74,
            child: Column(
              children: <Widget>[
                Container(
                  height: 74,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: on ? _text : Colors.transparent, width: 2),
                    color: look == null ? _card : null,
                    gradient: look == null
                        ? null
                        : LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: <Color>[look.a, look.b],
                          ),
                  ),
                  child: look == null
                      ? const Icon(Icons.block_rounded, color: _muted, size: 22)
                      : null,
                ),
                const SizedBox(height: 5),
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: on ? _text : _muted,
                        fontSize: 11,
                        fontWeight: on ? FontWeight.w700 : FontWeight.w500)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---- Adjust ---------------------------------------------------------------

  Widget _adjustTab() {
    final GradeParam p = _param;
    return Column(
      children: <Widget>[
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: _CapSlider(
            value: _g[p],
            min: p.min,
            gradient: _gradient(p),
            onChanged: (v) => _setParam(p, v),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 86,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: <Widget>[for (final q in _order) _paramTile(q)],
          ),
        ),
      ],
    );
  }

  Widget _paramTile(GradeParam p) {
    final bool on = p == _param;
    final bool changed = _g[p] != 0;
    return Semantics(
      button: true,
      selected: on,
      label: '${p.label}${changed ? ', changed' : ''}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _param = p);
        },
        child: SizedBox(
          width: 66,
          child: Column(
            children: <Widget>[
              Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: on ? _cardOn : _card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: on ? _text : Colors.transparent, width: 1.5),
                    ),
                    child: Icon(_paramIcon(p), size: 22, color: on ? _text : _muted),
                  ),
                  if (changed)
                    const Positioned(
                      right: 3,
                      top: 3,
                      child: CircleAvatar(radius: 3.5, backgroundColor: _accent),
                    ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                p.label,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.fade,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: on ? _text : _muted,
                  fontSize: 10.5,
                  fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---- Wheels ---------------------------------------------------------------

  Widget _wheelsTab() {
    const Map<GradeRange, String> names = <GradeRange, String>{
      GradeRange.shadows: 'Shadows',
      GradeRange.midtones: 'Midtones',
      GradeRange.highlights: 'Highlights',
    };
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (final r in GradeRange.values)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: _WheelCard(
                      label: names[r]!,
                      wheel: _g.wheel(r),
                      onChanged: (w) => _emit(_g.setWheel(r, w)),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text('Drag to tint  ·  Double-tap a wheel to reset',
              style: TextStyle(color: _muted, fontSize: 11.5)),
        ),
      ],
    );
  }

  // ---- Curves ---------------------------------------------------------------

  Widget _curvesTab() {
    return Column(
      children: <Widget>[
        const SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[for (final c in CurveChannel.values) _channelChip(c)],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: _CurveEditor(
                key: ValueKey<CurveChannel>(_ch),
                points: _g.curve(_ch),
                color: _channelColor(_ch),
                onChanged: (p) => _emit(_g.setCurve(_ch, p)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _channelChip(CurveChannel c) {
    final bool on = c == _ch;
    final bool edited = _g.curves.containsKey(c);
    final Color col = _channelColor(c);
    return Semantics(
      button: true,
      selected: on,
      label: '${c.name} curve',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _ch = c);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: on ? _cardOn : _card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: on ? _text : Colors.transparent, width: 1.3),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: col, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(
                switch (c) {
                  CurveChannel.master => 'RGB',
                  CurveChannel.red => 'Red',
                  CurveChannel.green => 'Green',
                  CurveChannel.blue => 'Blue',
                },
                style: TextStyle(
                    color: on ? _text : _muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
              if (edited) ...<Widget>[
                const SizedBox(width: 5),
                const CircleAvatar(radius: 2.5, backgroundColor: _accent),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ---- CapCut-style slider -----------------------------------------------------
//
// Thin track, white fill from the zero point, round white thumb and the value
// floating above the thumb. Double-tap resets. Snaps to zero near the middle.

class _CapSlider extends StatelessWidget {
  const _CapSlider({
    required this.value,
    required this.min,
    required this.onChanged,
    this.gradient,
    this.resetTo = 0,
    this.compact = false,
  });

  final double value;
  final double min;
  final double resetTo;
  final bool compact;
  final List<Color>? gradient;
  final ValueChanged<double> onChanged;

  double get _pad => compact ? 10 : 24;
  double get _height => compact ? 30 : 58;

  double _fromDx(double dx, double w) {
    final double t = ((dx - _pad) / (w - _pad * 2)).clamp(0.0, 1.0).toDouble();
    double v = min + (100 - min) * t;
    if (v.abs() < 3) v = 0; // magnet at zero
    return v.roundToDouble();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final double w = box.maxWidth;
      return Semantics(
        slider: true,
        value: '${value.round()}',
        increasedValue: '${(value + 1).round()}',
        decreasedValue: '${(value - 1).round()}',
        onIncrease: () => onChanged((value + 1).clamp(min, 100).toDouble()),
        onDecrease: () => onChanged((value - 1).clamp(min, 100).toDouble()),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => onChanged(_fromDx(d.localPosition.dx, w)),
          onHorizontalDragUpdate: (d) => onChanged(_fromDx(d.localPosition.dx, w)),
          onDoubleTap: () {
            HapticFeedback.selectionClick();
            onChanged(resetTo);
          },
          child: SizedBox(
            height: _height,
            width: w,
            child: CustomPaint(
              painter: _CapSliderPainter(value, min, gradient, compact),
            ),
          ),
        ),
      );
    });
  }
}

class _CapSliderPainter extends CustomPainter {
  _CapSliderPainter(this.value, this.min, this.gradient, this.compact);
  final double value;
  final double min;
  final List<Color>? gradient;
  final bool compact;

  @override
  void paint(Canvas canvas, Size size) {
    final double pad = compact ? 10 : 24;
    final double w = size.width - pad * 2;
    final double y = compact ? size.height / 2 : 40;
    final double r = compact ? 7 : 10;
    double px(double v) => pad + (v - min) / (100 - min) * w;
    final double z = px(0), x = px(value);

    final Rect bar = Rect.fromLTWH(pad, y - 1.5, w, 3);
    final RRect rbar = RRect.fromRectAndRadius(bar, const Radius.circular(1.5));
    if (gradient != null) {
      canvas.drawRRect(
          rbar, Paint()..shader = LinearGradient(colors: gradient!).createShader(bar));
    } else {
      canvas.drawRRect(rbar, Paint()..color = _track);
      if ((x - z).abs() > 0.5) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(math.min(z, x), y - 1.5, math.max(z, x), y + 1.5),
            const Radius.circular(1.5),
          ),
          Paint()..color = _text,
        );
      }
    }
    if (min < 0) {
      canvas.drawLine(
        Offset(z, y - 7),
        Offset(z, y + 7),
        Paint()
          ..color = Colors.white54
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round,
      );
    }

    // thumb
    canvas.drawCircle(
      Offset(x, y + 1),
      r,
      Paint()
        ..color = Colors.black.withAlpha(120)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawCircle(Offset(x, y), r, Paint()..color = _text);

    // value bubble
    if (!compact) {
      final int v = value.round();
      final TextPainter tp = TextPainter(
        text: TextSpan(
          text: '${v > 0 && min < 0 ? '+' : ''}$v',
          style: const TextStyle(
            color: _text,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final double tx = (x - tp.width / 2).clamp(0.0, size.width - tp.width).toDouble();
      tp.paint(canvas, Offset(tx, y - r - 8 - tp.height));
    }
  }

  @override
  bool shouldRepaint(covariant _CapSliderPainter old) =>
      old.value != value ||
      old.min != min ||
      old.gradient != gradient ||
      old.compact != compact;
}

// ---- Color wheel ----------------------------------------------------------------

class _WheelCard extends StatelessWidget {
  const _WheelCard({required this.label, required this.wheel, required this.onChanged});
  final String label;
  final GradeWheel wheel;
  final ValueChanged<GradeWheel> onChanged;

  @override
  Widget build(BuildContext context) {
    final bool edited = !wheel.isIdentity;
    return Column(
      children: <Widget>[
        AspectRatio(
          aspectRatio: 1,
          child: LayoutBuilder(builder: (context, box) {
            final Size size = box.biggest;
            void pick(Offset p) {
              final Offset c = size.center(Offset.zero);
              final double r = size.shortestSide / 2 - 3;
              final Offset d = p - c;
              final double amt = (d.distance / r).clamp(0.0, 1.0).toDouble();
              double h = math.atan2(d.dy, d.dx) * 180 / math.pi;
              if (h < 0) h += 360;
              onChanged(wheel.copyWith(hue: h, amount: amt < 0.04 ? 0 : amt));
            }

            return Semantics(
              label: '$label color wheel',
              child: GestureDetector(
                onPanStart: (d) => pick(d.localPosition),
                onPanUpdate: (d) => pick(d.localPosition),
                onTapDown: (d) => pick(d.localPosition),
                onDoubleTap: () {
                  HapticFeedback.selectionClick();
                  onChanged(GradeWheel(luma: wheel.luma));
                },
                child: CustomPaint(size: size, painter: _WheelPainter(wheel)),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            Expanded(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: edited ? _text : _muted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600)),
            ),
            Text('${wheel.luma > 0 ? '+' : ''}${wheel.luma.round()}',
                style: TextStyle(
                    color: wheel.luma != 0 ? _text : _muted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const <FontFeature>[FontFeature.tabularFigures()])),
          ],
        ),
        _CapSlider(
          compact: true,
          value: wheel.luma,
          min: -100,
          onChanged: (v) => onChanged(wheel.copyWith(luma: v)),
        ),
      ],
    );
  }
}

class _WheelPainter extends CustomPainter {
  _WheelPainter(this.w);
  final GradeWheel w;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = size.center(Offset.zero);
    final double r = size.shortestSide / 2 - 3;
    final Rect rect = Rect.fromCircle(center: c, radius: r);

    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = SweepGradient(colors: <Color>[
          for (int i = 0; i <= 6; i++) HSVColor.fromAHSV(1, i * 60.0, 0.8, 0.95).toColor(),
        ]).createShader(rect),
    );
    // Neutral centre that fades into the hue ring.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const RadialGradient(
          colors: <Color>[Color(0xFF2B2B30), Color(0x002B2B30)],
          stops: <double>[0.15, 1.0],
        ).createShader(rect),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = _line,
    );
    final Paint cross = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1;
    canvas.drawLine(Offset(c.dx - r, c.dy), Offset(c.dx + r, c.dy), cross);
    canvas.drawLine(Offset(c.dx, c.dy - r), Offset(c.dx, c.dy + r), cross);

    final double a = w.hue * math.pi / 180;
    final Offset puck = c + Offset(math.cos(a), math.sin(a)) * (w.amount * r);
    canvas.drawCircle(
      puck,
      7,
      Paint()
        ..color = w.amount == 0
            ? _bg
            : HSVColor.fromAHSV(1, w.hue % 360, 0.8, 0.95).toColor(),
    );
    canvas.drawCircle(
      puck,
      7,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _WheelPainter old) => old.w != w;
}

// ---- Curve editor ---------------------------------------------------------------

class _CurveEditor extends StatefulWidget {
  const _CurveEditor({
    super.key,
    required this.points,
    required this.color,
    required this.onChanged,
  });
  final List<Offset> points;
  final Color color;
  final ValueChanged<List<Offset>> onChanged;

  @override
  State<_CurveEditor> createState() => _CurveEditorState();
}

class _CurveEditorState extends State<_CurveEditor> {
  static const int _maxPoints = 10;
  int? _sel;
  int? _drag;

  Offset _toPx(Offset p, Size s) => Offset(p.dx * s.width, (1 - p.dy) * s.height);

  int? _nearest(Offset o, Size s) {
    int? best;
    double bd = 24;
    for (int i = 0; i < widget.points.length; i++) {
      final double d = (_toPx(widget.points[i], s) - o).distance;
      if (d < bd) {
        bd = d;
        best = i;
      }
    }
    return best;
  }

  void _start(Offset o, Size s) {
    int? i = _nearest(o, s);
    if (i == null) {
      final double x = (o.dx / s.width).clamp(0.03, 0.97).toDouble();
      final double y = (1 - o.dy / s.height).clamp(0.0, 1.0).toDouble();
      // Too close in x to an existing point: select that point instead.
      int? close;
      double cd = 0.04;
      for (int k = 0; k < widget.points.length; k++) {
        final double d = (widget.points[k].dx - x).abs();
        if (d < cd) {
          cd = d;
          close = k;
        }
      }
      if (close != null) {
        setState(() {
          _sel = close;
          _drag = close;
        });
        return;
      }
      if (widget.points.length >= _maxPoints) {
        HapticFeedback.heavyImpact();
        return;
      }
      HapticFeedback.selectionClick();
      final List<Offset> p = List<Offset>.of(widget.points)
        ..add(Offset(x, y))
        ..sort((a, b) => a.dx.compareTo(b.dx));
      i = p.indexWhere((q) => q.dx == x);
      widget.onChanged(p);
    }
    setState(() {
      _sel = i;
      _drag = i;
    });
  }

  void _update(Offset o, Size s) {
    final int? i = _drag;
    final List<Offset> pts = widget.points;
    if (i == null || i >= pts.length) return;
    final List<Offset> p = List<Offset>.of(pts);
    final double y = (1 - o.dy / s.height).clamp(0.0, 1.0).toDouble();
    double x = p[i].dx;
    if (i != 0 && i != p.length - 1) {
      final double lo = p[i - 1].dx + 0.02, hi = p[i + 1].dx - 0.02;
      if (lo <= hi) x = (o.dx / s.width).clamp(lo, hi).toDouble();
    }
    p[i] = Offset(x, y);
    widget.onChanged(p);
  }

  void _deleteAt(int i) {
    final List<Offset> pts = widget.points;
    if (i <= 0 || i >= pts.length - 1) return;
    HapticFeedback.mediumImpact();
    final List<Offset> p = List<Offset>.of(pts)..removeAt(i);
    setState(() => _sel = null);
    widget.onChanged(p);
  }

  @override
  Widget build(BuildContext context) {
    final List<Offset> pts = widget.points;
    final int? sel = _sel != null && _sel! < pts.length ? _sel : null;
    final bool isDefault = pts.length == 2 &&
        (pts[0] - const Offset(0, 0)).distance < 1e-4 &&
        (pts[1] - const Offset(1, 1)).distance < 1e-4;
    return Column(
      children: <Widget>[
        AspectRatio(
          aspectRatio: 1,
          child: LayoutBuilder(builder: (context, box) {
            final Size size = box.biggest;
            return GestureDetector(
              onPanDown: (d) => _start(d.localPosition, size),
              onPanUpdate: (d) => _update(d.localPosition, size),
              onPanEnd: (_) => _drag = null,
              onPanCancel: () => _drag = null,
              onLongPressStart: (d) {
                final int? i = _nearest(d.localPosition, size);
                if (i != null) _deleteAt(i);
              },
              child: Semantics(
                label: 'Curve editor with ${pts.length} points',
                child: Container(
                  decoration: BoxDecoration(
                    color: _field,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _line),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CustomPaint(
                      size: size,
                      painter: _CurvePainter(pts, widget.color, sel),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (sel != null) ...<Widget>[
              _box('In', '${(pts[sel].dx * 100).round()}'),
              const SizedBox(width: 8),
              _box('Out', '${(pts[sel].dy * 100).round()}'),
              const SizedBox(width: 8),
            ] else
              const Padding(
                padding: EdgeInsets.only(right: 12),
                child: Text('Tap to add a point  ·  Hold to delete',
                    style: TextStyle(color: _muted, fontSize: 11.5)),
              ),
            _pill(Icons.restart_alt_rounded, 'Reset', !isDefault, () {
              HapticFeedback.selectionClick();
              setState(() => _sel = null);
              widget.onChanged(ColorGrade.defaultCurve);
            }),
          ],
        ),
      ],
    );
  }

  Widget _box(String label, String value) => Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(label, style: const TextStyle(color: _muted, fontSize: 11.5)),
            const SizedBox(width: 6),
            Text(value,
                style: const TextStyle(
                    color: _text,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    fontFeatures: <FontFeature>[FontFeature.tabularFigures()])),
          ],
        ),
      );

  Widget _pill(IconData icon, String label, bool enabled, VoidCallback f) => Semantics(
        button: true,
        enabled: enabled,
        label: label,
        child: GestureDetector(
          onTap: enabled ? f : null,
          child: Opacity(
            opacity: enabled ? 1 : 0.4,
            child: Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration:
                  BoxDecoration(color: _card, borderRadius: BorderRadius.circular(16)),
              child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
                Icon(icon, size: 16, color: _text),
                const SizedBox(width: 4),
                Text(label,
                    style: const TextStyle(
                        color: _text, fontSize: 12.5, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ),
      );
}

class _CurvePainter extends CustomPainter {
  _CurvePainter(this.pts, this.color, this.selected);
  final List<Offset> pts;
  final Color color;
  final int? selected;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint grid = Paint()
      ..color = _track.withAlpha(90)
      ..strokeWidth = 1;
    for (int i = 1; i < 4; i++) {
      final double f = i / 4;
      canvas.drawLine(Offset(f * size.width, 0), Offset(f * size.width, size.height), grid);
      canvas.drawLine(Offset(0, f * size.height), Offset(size.width, f * size.height), grid);
    }
    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, 0),
      Paint()
        ..color = Colors.white24
        ..strokeWidth = 1,
    );

    final Path line = Path();
    const int n = 96;
    for (int i = 0; i <= n; i++) {
      final double x = i / n;
      final double y = ColorGrade.evalCurve(pts, x);
      final Offset o = Offset(x * size.width, (1 - y) * size.height);
      i == 0 ? line.moveTo(o.dx, o.dy) : line.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );

    for (int i = 0; i < pts.length; i++) {
      final Offset o = Offset(pts[i].dx * size.width, (1 - pts[i].dy) * size.height);
      final bool sel = i == selected;
      canvas.drawCircle(o, sel ? 7.5 : 6, Paint()..color = sel ? color : _bg);
      canvas.drawCircle(
        o,
        sel ? 7.5 : 6,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CurvePainter old) =>
      old.pts != pts || old.color != color || old.selected != selected;
}