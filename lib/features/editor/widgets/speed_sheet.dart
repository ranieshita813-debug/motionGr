// lib/features/editor/widgets/speed_sheet.dart
//
// Speed tool, CapCut-style:
//  - Top tabs: Normal / Curve (underlined), reset icon on the right.
//  - Normal: ruler-style log slider with a value bubble above the thumb,
//    Duration readout, toggle rows.
//  - Curve: preset tiles with mini curves, graph with round keyframes,
//    Add / Delete pills.
//  - Bottom bar: X  ·  Speed  ·  check.
//
// Nothing is persisted until the check is tapped; X restores the clip speed.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:provider/provider.dart';

import 'package:flutter_video_editor/core/models/project_model.dart';
import 'package:flutter_video_editor/core/models/speed_settings.dart';
import 'package:flutter_video_editor/features/editor/controllers/editor_controller.dart';
import 'package:flutter_video_editor/features/editor/theme/editor_tokens.dart';

// ---- Tokens -------------------------------------------------------------------

const String _font = 'Fredoka';

TextStyle _ts(Color color, double size, [FontWeight w = FontWeight.w500]) =>
    TextStyle(color: color, fontSize: size, fontWeight: w, fontFamily: _font);

const List<FontFeature> _tab = <FontFeature>[FontFeature.tabularFigures()];

const Map<String, List<SpeedPoint>> _curvePresets = <String, List<SpeedPoint>>{
  'Custom': <SpeedPoint>[SpeedPoint(0, 1), SpeedPoint(1, 1)],
  'Montage': <SpeedPoint>[
    SpeedPoint(0, 1), SpeedPoint(.25, .3), SpeedPoint(.5, 3),
    SpeedPoint(.75, .3), SpeedPoint(1, 1),
  ],
  'Hero': <SpeedPoint>[
    SpeedPoint(0, 1.5), SpeedPoint(.3, .4), SpeedPoint(.7, .4), SpeedPoint(1, 1.5),
  ],
  'Bullet': <SpeedPoint>[
    SpeedPoint(0, 3), SpeedPoint(.4, .2), SpeedPoint(.6, .2), SpeedPoint(1, 3),
  ],
  'Jumper': <SpeedPoint>[
    SpeedPoint(0, .5), SpeedPoint(.35, 4), SpeedPoint(.65, 4), SpeedPoint(1, .5),
  ],
  'Flash in': <SpeedPoint>[SpeedPoint(0, .3), SpeedPoint(1, 3)],
  'Flash out': <SpeedPoint>[SpeedPoint(0, 3), SpeedPoint(1, .3)],
};

const List<double> _sliderMarks = <double>[0.1, 1, 2, 5, 10];

// ---- Helpers ------------------------------------------------------------------

double _toT(double speed) => ((math.log(speed) / math.ln10) + 1) / 2;
double _fromT(double t) => math.pow(10, t * 2 - 1).toDouble();

String _fmtDur(double sec) => '${sec.toStringAsFixed(1)}s';

String _fmtSpeed(double v) {
  String s = v.toStringAsFixed(2);
  if (s.endsWith('0')) s = s.substring(0, s.length - 1);
  return '${s}x';
}

String _fmtMark(double v) => v == v.roundToDouble() ? '${v.toInt()}x' : '${v}x';

/// Bottom sheet for constant speed and speed curves.
///
/// Nothing is applied to the clip until the user taps the check button.
/// Returns the applied settings, or null if cancelled.
class SpeedSheet extends StatefulWidget {
  const SpeedSheet({super.key, this.initial, this.onApply, this.onClose});

  final SpeedSettings? initial;
  final ValueChanged<SpeedSettings>? onApply;

  /// Set when embedded in a panel instead of shown with [show].
  final VoidCallback? onClose;

  static Future<SpeedSettings?> show(
    BuildContext context, {
    SpeedSettings? initial,
    ValueChanged<SpeedSettings>? onApply,
  }) {
    return showModalBottomSheet<SpeedSettings>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: EditorTokens.surface,
      barrierColor: Colors.black38,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SpeedSheet(initial: initial, onApply: onApply),
    );
  }

  @override
  State<SpeedSheet> createState() => _SpeedSheetState();
}

class _SpeedSheetState extends State<SpeedSheet> {
  late final SpeedSettings _initial;
  late final double _srcSeconds;
  late SpeedSettings _s;
  int? _selected;
  int? _dragging;

  @override
  void initState() {
    super.initState();
    final clip = context.read<EditorController>().selectedClip;
    _srcSeconds =
        clip == null ? 0 : clip.duration.inMilliseconds / 1000.0 * clip.speed;
    _initial = (widget.initial ??
            clip?.speedSettings ??
            SpeedSettings(
              speed: ((clip?.speed ?? 1.0) as num)
                  .clamp(kMinSpeed, kMaxSpeed)
                  .toDouble(),
            ))
        .normalized();
    _s = _initial;
  }

  bool get _dirty => _s.normalized() != _initial;
  bool get _curve => _s.mode == SpeedMode.curve;

  // ---- state helpers ----------------------------------------------------------

  void _update(SpeedSettings Function(SpeedSettings) f) =>
      setState(() => _s = f(_s));

  void _setMode(SpeedMode m) {
    if (_s.mode == m) return;
    HapticFeedback.selectionClick();
    _update((s) => s.copyWith(mode: m));
  }

  void _setSpeed(double v) {
    _update((s) => s.copyWith(
        speed: double.parse(v.clamp(kMinSpeed, kMaxSpeed).toStringAsFixed(2))));
    if (mounted) {
      context.read<EditorController>().updateSelectedClipSpeed(v);
    }
  }

  void _loadPreset(String name) {
    HapticFeedback.selectionClick();
    _selected = null;
    _update((s) => s.copyWith(
        points: List<SpeedPoint>.of(_curvePresets[name]!), preset: name));
  }

  void _setPoints(List<SpeedPoint> p) =>
      _update((s) => s.copyWith(points: p, preset: 'Custom'));

  bool get _canDelete {
    final int? i = _selected;
    return i != null && i > 0 && i < _s.points.length - 1;
  }

  void _deleteSelected() {
    if (!_canDelete) return;
    HapticFeedback.mediumImpact();
    final List<SpeedPoint> p = List<SpeedPoint>.of(_s.points)
      ..removeAt(_selected!);
    _selected = null;
    _setPoints(p);
  }

  void _addPoint() {
    final List<SpeedPoint> pts = _s.points;
    if (pts.length >= kMaxCurvePoints) {
      HapticFeedback.heavyImpact();
      return;
    }
    int gi = 0;
    double gw = 0;
    for (int i = 0; i < pts.length - 1; i++) {
      final double w = pts[i + 1].x - pts[i].x;
      if (w > gw) {
        gw = w;
        gi = i;
      }
    }
    final double x = pts[gi].x + gw / 2;
    HapticFeedback.selectionClick();
    _selected = gi + 1;
    _setPoints(List<SpeedPoint>.of(pts)
      ..insert(gi + 1, SpeedPoint(x, SpeedSettings.interpolate(pts, x))));
  }

  void _reset() {
    HapticFeedback.selectionClick();
    _selected = null;
    _update((s) => SpeedSettings.identity.copyWith(mode: s.mode));
  }

  // ---- close / apply ----------------------------------------------------------

  void _dismiss([SpeedSettings? result]) {
    final VoidCallback? close = widget.onClose;
    if (close != null) {
      close();
    } else {
      Navigator.of(context).pop(result);
    }
  }

  void _close() {
    if (_dirty && mounted) {
      context.read<EditorController>().updateSelectedClipSpeed(_initial.speed);
    }
    _dismiss();
  }

  void _confirm() {
    if (!_dirty) {
      _dismiss();
      return;
    }
    final EditorController c = context.read<EditorController>();
    final SpeedSettings result = _s.normalized();
    c.updateSelectedClipSpeed(result.averageSpeed, speedSettings: result);
    if (widget.onApply != null) {
      widget.onApply!(result);
    } else {
      c.updateAudioProperties(
        c.selectedClip?.audioProperties.copyWith(
                speed: double.parse(result.averageSpeed.toStringAsFixed(3))) ??
            const AudioProperties(),
      );
    }
    HapticFeedback.lightImpact();
    _dismiss(result);
  }

  // ---- build ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final bool embedded = widget.onClose != null;

    final List<Widget> content = <Widget>[
      _topBar(),
      _curve ? _curveView() : _normalView(),
      _toggles(),
      const SizedBox(height: 8),
      _footer(),
    ];

    if (embedded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: content,
      );
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[_grabber(), ...content],
        ),
      ),
    );
  }

  // ---- Chrome -----------------------------------------------------------------

  Widget _grabber() => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        child: Center(
          child: Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
                color: EditorTokens.border,
                borderRadius: BorderRadius.circular(2)),
          ),
        ),
      );

  Widget _topBar() {
    Widget tab(String label, SpeedMode m) {
      final bool active = _s.mode == m;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _setMode(m),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: _ts(active ? EditorTokens.text : EditorTokens.muted, 14,
                    active ? FontWeight.w700 : FontWeight.w500),
              ),
              const SizedBox(height: 4),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 2,
                width: active ? 16 : 0,
                decoration: BoxDecoration(
                  color: EditorTokens.text,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      height: 46,
      padding: const EdgeInsets.only(left: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: EditorTokens.border, width: 0.5)),
      ),
      child: Row(
        children: [
          tab('Normal', SpeedMode.normal),
          tab('Curve', SpeedMode.curve),
          const Spacer(),
          IconButton(
            tooltip: 'Reset',
            icon: PhosphorIcon(
              PhosphorIconsRegular.arrowCounterClockwise,
              color: _s.isIdentity ? EditorTokens.muted : EditorTokens.text,
              size: 20,
            ),
            onPressed: _s.isIdentity ? null : _reset,
          ),
        ],
      ),
    );
  }

  /// CapCut-style bottom bar: X, title, check.
  Widget _footer() {
    return Container(
      height: 48,
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: EditorTokens.border, width: 0.5)),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Cancel',
            icon: const PhosphorIcon(PhosphorIconsRegular.x,
                color: EditorTokens.text, size: 22),
            onPressed: _close,
          ),
          Expanded(
            child: Text('Speed',
                textAlign: TextAlign.center,
                style: _ts(EditorTokens.text, 14, FontWeight.w700)),
          ),
          IconButton(
            tooltip: 'Apply',
            icon: const PhosphorIcon(PhosphorIconsBold.check,
                color: EditorTokens.text, size: 22),
            onPressed: _confirm,
          ),
        ],
      ),
    );
  }

  Widget _pill(String label, PhosphorIconData icon, VoidCallback? f) {
    return Semantics(
      button: true,
      label: label,
      enabled: f != null,
      child: GestureDetector(
        onTap: f,
        child: Opacity(
          opacity: f == null ? 0.35 : 1,
          child: Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: EditorTokens.elevated,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                PhosphorIcon(icon, color: EditorTokens.text, size: 16),
                const SizedBox(width: 6),
                Text(label, style: _ts(EditorTokens.text, 12, FontWeight.w600)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---- Duration readout ---------------------------------------------------------

  Widget _durationRow() {
    final double out = _srcSeconds * _s.durationFactor;
    final bool changed = (out - _srcSeconds).abs() > 0.05;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Row(
        children: [
          Text('Duration', style: _ts(EditorTokens.muted, 12)),
          const Spacer(),
          Text.rich(
            TextSpan(
              style: _ts(EditorTokens.muted, 12).copyWith(fontFeatures: _tab),
              children: [
                TextSpan(text: '${_fmtDur(_srcSeconds)}  →  '),
                TextSpan(
                  text: _fmtDur(out),
                  style: TextStyle(
                    color: changed ? EditorTokens.text : EditorTokens.muted,
                    fontWeight: changed ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---- Normal mode ------------------------------------------------------------

  Widget _normalView() {
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
          child: _SpeedSlider(speed: _s.speed, onChanged: _setSpeed),
        ),
        _durationRow(),
      ],
    );
  }

  // ---- Curve mode -------------------------------------------------------------

  Widget _curveView() {
    final List<SpeedPoint> pts = _s.points;
    final int? sel =
        _selected != null && _selected! < pts.length ? _selected : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SizedBox(height: 12),
        SizedBox(
          height: 74,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: <Widget>[
              for (final e in _curvePresets.entries)
                _presetTile(e.key, e.value),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: LayoutBuilder(builder: (context, box) {
            final Size size = Size(box.maxWidth, 120);
            Offset toPx(SpeedPoint p) =>
                Offset(p.x * size.width, size.height * (1 - _toT(p.speed)));
            int? nearest(Offset o) {
              int? best;
              double bd = 28;
              for (int i = 0; i < _s.points.length; i++) {
                final double d = (toPx(_s.points[i]) - o).distance;
                if (d < bd) {
                  bd = d;
                  best = i;
                }
              }
              return best;
            }

            return GestureDetector(
              onPanStart: (d) {
                _dragging = nearest(d.localPosition);
                if (_dragging != null) setState(() => _selected = _dragging);
              },
              onPanUpdate: (d) {
                final int? i = _dragging;
                if (i == null || i >= _s.points.length) return;
                final List<SpeedPoint> p = List<SpeedPoint>.of(_s.points);
                final Offset o = d.localPosition;
                double sp = _fromT(
                    (1 - o.dy / size.height).clamp(0.0, 1.0).toDouble());
                if ((sp - 1).abs() < 0.06) sp = 1.0;
                double x = p[i].x;
                if (i != 0 && i != p.length - 1) {
                  x = (o.dx / size.width)
                      .clamp(p[i - 1].x + 0.02, p[i + 1].x - 0.02)
                      .toDouble();
                }
                p[i] = SpeedPoint(x, sp.clamp(kMinSpeed, kMaxSpeed).toDouble());
                _setPoints(p);
              },
              onPanEnd: (_) => _dragging = null,
              onPanCancel: () => _dragging = null,
              onTapUp: (d) {
                final int? i = nearest(d.localPosition);
                if (i != null) setState(() => _selected = i);
              },
              child: Semantics(
                label: 'Speed curve editor with ${pts.length} points',
                child: Container(
                  height: size.height,
                  decoration: BoxDecoration(
                    color: EditorTokens.elevated,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CustomPaint(
                      size: size,
                      painter: _CurvePainter(pts: pts, selected: sel),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _pill('Add', PhosphorIconsRegular.plus,
                  pts.length < kMaxCurvePoints ? _addPoint : null),
              const SizedBox(width: 10),
              _pill('Delete', PhosphorIconsRegular.trash,
                  _canDelete ? _deleteSelected : null),
            ],
          ),
        ),
        const SizedBox(height: 6),
        _durationRow(),
      ],
    );
  }

  Widget _presetTile(String name, List<SpeedPoint> pts) {
    final bool on = _s.preset == name;
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _loadPreset(name),
        child: SizedBox(
          width: 62,
          child: Column(
            children: [
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: EditorTokens.elevated,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: on ? EditorTokens.text : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  padding: const EdgeInsets.all(10),
                  child: CustomPaint(
                    painter: _MiniCurvePainter(
                        pts, on ? EditorTokens.text : EditorTokens.muted),
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _ts(on ? EditorTokens.text : EditorTokens.muted, 11,
                    on ? FontWeight.w700 : FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---- Toggle rows ------------------------------------------------------------

  Widget _toggles() {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        children: [
          _toggleRow('Change audio pitch', !_s.maintainPitch, () {
            HapticFeedback.selectionClick();
            _update((s) => s.copyWith(maintainPitch: !s.maintainPitch));
          }),
          _toggleRow('Smooth slo-mo', _s.smoothSlowMotion, () {
            HapticFeedback.selectionClick();
            _update((s) => s.copyWith(smoothSlowMotion: !s.smoothSlowMotion));
          }),
          _toggleRow('Reverse', _s.reverse, () {
            HapticFeedback.selectionClick();
            _update((s) => s.copyWith(reverse: !s.reverse));
          }),
        ],
      ),
    );
  }

  Widget _toggleRow(String label, bool value, VoidCallback onTap) {
    return Semantics(
      toggled: value,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          child: Row(
            children: [
              Expanded(
                child: Text(label, style: _ts(EditorTokens.text, 13)),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 38,
                height: 22,
                padding: const EdgeInsets.all(2),
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                decoration: BoxDecoration(
                  color: value ? EditorTokens.text : EditorTokens.border,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: value ? EditorTokens.bg : EditorTokens.muted,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---- Ruler-style log slider with value bubble -----------------------------------

class _SpeedSlider extends StatefulWidget {
  const _SpeedSlider({required this.speed, required this.onChanged});
  final double speed;
  final ValueChanged<double> onChanged;

  @override
  State<_SpeedSlider> createState() => _SpeedSliderState();
}

class _SpeedSliderState extends State<_SpeedSlider> {
  double? _snap;

  void _at(double dx, double w) {
    final double t = (dx / w).clamp(0.0, 1.0).toDouble();
    double v = _fromT(t);
    double? snap;
    for (final double m in _sliderMarks) {
      if ((_toT(m) - t).abs() < 0.02) {
        v = m;
        snap = m;
      }
    }
    if (snap != null && snap != _snap) HapticFeedback.selectionClick();
    _snap = snap;
    widget.onChanged(v);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final double w = box.maxWidth;
      return Semantics(
        slider: true,
        label: 'Speed',
        value: _fmtSpeed(widget.speed),
        increasedValue: _fmtSpeed(widget.speed + 0.1),
        decreasedValue: _fmtSpeed(widget.speed - 0.1),
        onIncrease: () => widget.onChanged(widget.speed + 0.1),
        onDecrease: () => widget.onChanged(widget.speed - 0.1),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => _at(d.localPosition.dx, w),
          onHorizontalDragStart: (d) => _at(d.localPosition.dx, w),
          onHorizontalDragUpdate: (d) => _at(d.localPosition.dx, w),
          onHorizontalDragEnd: (_) => _snap = null,
          child: SizedBox(
            height: 76,
            width: w,
            child: CustomPaint(painter: _SliderPainter(widget.speed)),
          ),
        ),
      );
    });
  }
}

class _SliderPainter extends CustomPainter {
  _SliderPainter(this.speed);
  final double speed;

  @override
  void paint(Canvas canvas, Size size) {
    const double cy = 42;
    final double x = _toT(speed) * size.width;

    canvas.drawLine(
      const Offset(0, cy),
      Offset(size.width, cy),
      Paint()
        ..color = EditorTokens.border
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );

    // Minor ruler ticks.
    final Paint minor = Paint()
      ..color = EditorTokens.border
      ..strokeWidth = 1.5;
    for (int i = 0; i <= 40; i++) {
      final double tx = i / 40 * size.width;
      canvas.drawLine(Offset(tx, cy - 3), Offset(tx, cy + 3), minor);
    }

    // Labelled marks.
    for (final double m in _sliderMarks) {
      final double mx = _toT(m) * size.width;
      canvas.drawLine(Offset(mx, cy - 6), Offset(mx, cy + 6),
          Paint()
            ..color = EditorTokens.muted
            ..strokeWidth = 1.5);
      final bool on = (m - speed).abs() < 0.01;
      final TextPainter tp = TextPainter(
        text: TextSpan(
          text: _fmtMark(m),
          style: _ts(on ? EditorTokens.text : EditorTokens.muted, 11,
              on ? FontWeight.w700 : FontWeight.w500),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final double lx = (mx - tp.width / 2).clamp(0.0, size.width - tp.width);
      tp.paint(canvas, Offset(lx, cy + 12));
    }

    // Thumb.
    canvas.drawCircle(Offset(x, cy), 9, Paint()..color = EditorTokens.text);

    // Value bubble above the thumb.
    final TextPainter vp = TextPainter(
      text: TextSpan(
          text: _fmtSpeed(speed),
          style: _ts(EditorTokens.bg, 12, FontWeight.w700)
              .copyWith(fontFeatures: _tab)),
      textDirection: TextDirection.ltr,
    )..layout();
    final double bw = vp.width + 20;
    final double bx = x.clamp(bw / 2, size.width - bw / 2).toDouble();
    final Rect r = Rect.fromCenter(center: Offset(bx, 12), width: bw, height: 24);
    canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(8)),
        Paint()..color = EditorTokens.text);
    vp.paint(canvas, Offset(r.center.dx - vp.width / 2, r.center.dy - vp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _SliderPainter old) => old.speed != speed;
}

// ---- Curve painters ------------------------------------------------------------

class _MiniCurvePainter extends CustomPainter {
  _MiniCurvePainter(this.pts, this.color);
  final List<SpeedPoint> pts;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Path p = Path();
    for (int i = 0; i <= 24; i++) {
      final double x = i / 24;
      final Offset o = Offset(
          x * size.width,
          size.height * (1 - _toT(SpeedSettings.interpolate(pts, x))));
      i == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(
        p,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = color);
  }

  @override
  bool shouldRepaint(covariant _MiniCurvePainter old) =>
      old.color != color || old.pts != pts;
}

class _CurvePainter extends CustomPainter {
  _CurvePainter({required this.pts, required this.selected});
  final List<SpeedPoint> pts;
  final int? selected;

  Offset _px(SpeedPoint p, Size s) =>
      Offset(p.x * s.width, s.height * (1 - _toT(p.speed)));

  void _dashed(Canvas canvas, double y, double w, Paint paint) {
    for (double x = 0; x < w; x += 8) {
      canvas.drawLine(Offset(x, y), Offset(math.min(x + 4, w), y), paint);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final Paint grid = Paint()
      ..color = EditorTokens.border
      ..strokeWidth = 1;

    for (final double f in <double>[.25, .5, .75]) {
      canvas.drawLine(
          Offset(f * size.width, 0), Offset(f * size.width, size.height), grid);
    }

    for (final double v in <double>[0.3, 1, 3]) {
      final double y = size.height * (1 - _toT(v));
      _dashed(canvas, y, size.width,
          v == 1 ? (Paint()..color = Colors.white30..strokeWidth = 1) : grid);
      final TextPainter tp = TextPainter(
        text: TextSpan(text: _fmtMark(v), style: _ts(EditorTokens.muted, 11)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(8, y - tp.height - 2));
    }

    final Path line = Path();
    const int n = 120;
    for (int i = 0; i <= n; i++) {
      final double x = i / n;
      final Offset o = Offset(x * size.width,
          size.height * (1 - _toT(SpeedSettings.interpolate(pts, x))));
      i == 0 ? line.moveTo(o.dx, o.dy) : line.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(
        line,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = EditorTokens.text);

    // Round keyframes: selected one is a filled dot with a ring.
    for (int i = 0; i < pts.length; i++) {
      final Offset o = _px(pts[i], size);
      if (i == selected) {
        canvas.drawCircle(o, 11,
            Paint()..color = EditorTokens.text.withAlpha(46));
        canvas.drawCircle(o, 6.5, Paint()..color = EditorTokens.text);
      } else {
        canvas.drawCircle(o, 5.5, Paint()..color = EditorTokens.elevated);
        canvas.drawCircle(
            o,
            5.5,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2
              ..color = EditorTokens.text);
      }
    }

    if (selected != null) {
      final Offset o = _px(pts[selected!], size);
      final double lx = o.dx.clamp(26.0, size.width - 26).toDouble();
      final double ly = o.dy > 38 ? o.dy - 26 : o.dy + 28;
      final Rect r =
          Rect.fromCenter(center: Offset(lx, ly), width: 46, height: 20);
      canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(6)),
          Paint()..color = EditorTokens.text);
      final TextPainter tp = TextPainter(
        text: TextSpan(
            text: _fmtSpeed(pts[selected!].speed),
            style: _ts(EditorTokens.bg, 11, FontWeight.w700)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas,
          Offset(r.center.dx - tp.width / 2, r.center.dy - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _CurvePainter old) =>
      old.pts != pts || old.selected != selected;
}