import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:provider/provider.dart';

import 'package:flutter_video_editor/core/models/project_model.dart';
import 'package:flutter_video_editor/features/editor/controllers/editor_controller.dart';
import 'package:flutter_video_editor/features/editor/utils/editor_helpers.dart';
import 'package:flutter_video_editor/features/editor/utils/keyframe_curves.dart';

// ============================================================================
// KEYFRAMES: CapCut style
//
// What changed:
//  1. Every curve is manually editable. Linear / Ease in / Ease out / Custom /
//     Overshoot / Fast start / Slow down are all cubic beziers with two drag
//     handles. Old keyframes saved as linear/easeIn/easeOut are converted to
//     their bezier equivalent the first time you edit them.
//     Bounce and Random: drag the graph up/down for bounciness / intensity,
//     use the steppers for count / detail.
//  2. No Slider widget anywhere. Only custom steppers and drag gestures.
//  3. CapCut look: pure black, rounded cards, white selection, cyan handles,
//     filled curve graph and a live dot that follows the playhead.
//
// keyframe_curves.dart needs no change.
// ============================================================================
const double _kfFps = 30;

const Color _kfBg = bgToken;
const Color _kfPanel = Color(0xFF111111);
const Color _kfCard = Color(0xFF1C1C1E);
const Color _kfCardOn = Color(0xFF262628);
const Color _kfLine = Color(0xFF2C2C2E);
const Color _kfText = Color(0xFFFFFFFF);
const Color _kfMuted = Color(0xFF8E8E93);
const Color _kfDim = Color(0xFF48484A);
const Color _kfAccent = Color(0xFF25F4EE);

String _kfTimecode(double s) {
  final int fps = _kfFps.toInt();
  final int total = ((s < 0 ? 0.0 : s) * _kfFps).round();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(total ~/ (fps * 60))}:${two((total ~/ fps) % 60)}:${two(total % fps)}';
}

T? _kfFind<T>(Iterable<T> items, bool Function(T) test) {
  for (final T i in items) {
    if (test(i)) return i;
  }
  return null;
}

double _r2(double v) => (v * 100).round() / 100;

// ----------------------------------------------------------------------------
// Curve presets (all bezier except Bounce / Random)
// ----------------------------------------------------------------------------
class _CurveOption {
  const _CurveOption(
    this.label,
    this.curveType, [
    this.cp1x = 0.25,
    this.cp1y = 0.10,
    this.cp2x = 0.25,
    this.cp2y = 1.00,
  ]);
  final String label;
  final CurveType curveType;
  final double cp1x;
  final double cp1y;
  final double cp2x;
  final double cp2y;
}

const List<_CurveOption> _kfOptions = <_CurveOption>[
  _CurveOption('Linear', CurveType.cubicBezier, 0.0, 0.0, 1.0, 1.0),
  _CurveOption('Ease in', CurveType.cubicBezier, 0.42, 0.0, 1.0, 1.0),
  _CurveOption('Ease out', CurveType.cubicBezier, 0.0, 0.0, 0.58, 1.0),
  _CurveOption('Custom', CurveType.cubicBezier, 0.25, 0.10, 0.25, 1.00),
  _CurveOption('Overshoot', CurveType.cubicBezier, 0.34, 1.56, 0.64, 1.00),
  _CurveOption('Bounce', CurveType.bounce),
  _CurveOption('Random', CurveType.random),
  _CurveOption('Fast start', CurveType.cubicBezier, 0.05, 0.70, 0.10, 1.00),
  _CurveOption('Slow down', CurveType.cubicBezier, 0.90, 0.00, 0.95, 0.30),
];

/// Old linear / easeIn / easeOut keyframes become editable beziers.
Keyframe _eff(Keyframe k) {
  switch (k.curveType) {
    case CurveType.linear:
      return k.copyWith(
          curveType: CurveType.cubicBezier, cp1x: 0.0, cp1y: 0.0, cp2x: 1.0, cp2y: 1.0);
    case CurveType.easeIn:
      return k.copyWith(
          curveType: CurveType.cubicBezier, cp1x: 0.42, cp1y: 0.0, cp2x: 1.0, cp2y: 1.0);
    case CurveType.easeOut:
      return k.copyWith(
          curveType: CurveType.cubicBezier, cp1x: 0.0, cp1y: 0.0, cp2x: 0.58, cp2y: 1.0);
    default:
      return k;
  }
}

bool _sameCp(_CurveOption o, Keyframe k) =>
    (o.cp1x - k.cp1x).abs() < 0.03 &&
    (o.cp1y - k.cp1y).abs() < 0.03 &&
    (o.cp2x - k.cp2x).abs() < 0.03 &&
    (o.cp2y - k.cp2y).abs() < 0.03;

bool _optionIsOn(_CurveOption o, Keyframe raw) {
  final Keyframe k = _eff(raw);
  if (o.curveType != k.curveType) return false;
  if (o.curveType != CurveType.cubicBezier) return true;
  if (o.label == 'Custom') {
    // "Custom" lights up when no named preset matches the handles.
    return !_kfOptions.any((p) =>
        p.label != 'Custom' && p.curveType == CurveType.cubicBezier && _sameCp(p, k));
  }
  return _sameCp(o, k);
}

// Plot mapping: y range is -0.5..1.5 so overshoot and bounce stay visible.
const double _plotPadX = 22;
const double _plotPadY = 16;

double _gx(Size s, double v) => _plotPadX + v.clamp(0.0, 1.0) * (s.width - _plotPadX * 2);
double _gy(Size s, double v) =>
    _plotPadY + (1.5 - v.clamp(-0.5, 1.5)) / 2 * (s.height - _plotPadY * 2);
Offset _gp(Size s, double x, double y) => Offset(_gx(s, x), _gy(s, y));

// ----------------------------------------------------------------------------
// Sheet
// ----------------------------------------------------------------------------
class KeyframeSheet extends StatefulWidget {
  const KeyframeSheet({super.key});

  @override
  State<KeyframeSheet> createState() => _KeyframeSheetState();
}

class _KeyframeSheetState extends State<KeyframeSheet> {
  Object? _selId;
  bool _lockScroll = false;

  void _toast(String msg) => ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final editor = context.read<EditorController>();
    final clip = context.select<EditorController, TimelineClip?>((e) => e.selectedClip);
    final playhead = context.select<EditorController, Duration>((e) => e.playhead);

    final List<Keyframe> all = <Keyframe>[...?clip?.keyframes]
      ..sort((a, b) => a.time.compareTo(b.time));

    final double total = clip == null ? 1.0 : math.max(secondsOf(clip.duration), 0.1);
    final double rel = clip == null ? 0.0 : secondsOf(playhead - clip.start);
    final bool inClip = clip != null && rel >= 0 && rel <= total;
    const double tol = 0.5 / _kfFps;

    final Keyframe? atHead = _kfFind(all, (k) => (secondsOf(k.time) - rel).abs() < tol);
    final Keyframe? selected = _selId == null ? null : _kfFind(all, (k) => k.id == _selId);
    final int selIndex = selected == null ? -1 : all.indexWhere((k) => k.id == selected.id);
    final bool hasNext = selIndex >= 0 && selIndex < all.length - 1;
    final Keyframe? nextKf = hasNext ? all[selIndex + 1] : null;
    final Keyframe? sel = selected == null ? null : _eff(selected);

    double? progress;
    if (selected != null && nextKf != null) {
      final double a = secondsOf(selected.time);
      final double b = secondsOf(nextKf.time);
      if (b > a) {
        final double p = (rel - a) / (b - a);
        if (p >= 0 && p <= 1) progress = p;
      }
    }

    void seekTo(double s) {
      if (clip == null) return;
      seekPlayhead(editor, secondsOf(clip.start) + s.clamp(0.0, total).toDouble());
    }

    void prev() {
      final List<Keyframe> c = all.where((k) => secondsOf(k.time) < rel - tol).toList();
      if (c.isEmpty) return;
      seekTo(secondsOf(c.last.time));
      setState(() => _selId = c.last.id);
    }

    void next() {
      final List<Keyframe> c = all.where((k) => secondsOf(k.time) > rel + tol).toList();
      if (c.isEmpty) return;
      seekTo(secondsOf(c.first.time));
      setState(() => _selId = c.first.id);
    }

    void toggle() {
      if (atHead != null) {
        editor.removeKeyframe(atHead.id);
        setState(() => _selId = null);
      } else if (!inClip) {
        _toast('Move the playhead inside the clip first.');
      } else {
        editor.addKeyframeAtPlayhead();
      }
    }

    void pick(Keyframe kf, _CurveOption o) {
      tapFeedback();
      Keyframe updated = _eff(kf).copyWith(
        curveType: o.curveType,
        cp1x: o.cp1x,
        cp1y: o.cp1y,
        cp2x: o.cp2x,
        cp2y: o.cp2y,
      );
      if (o.curveType == CurveType.random) {
        updated = updated.copyWith(randomSeed: math.Random().nextInt(9999) + 1);
      }
      editor.addKeyframe(updated);
    }

    return ColoredBox(
      color: _kfBg,
      child: ListView(
        physics: (_lockScroll && selected != null) ? const NeverScrollableScrollPhysics() : null,
        padding: EdgeInsets.fromLTRB(0, 6, 0, 16 + MediaQuery.paddingOf(context).bottom),
        children: <Widget>[
          // ---- toolbar -------------------------------------------------------
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: <Widget>[
                _KfAction(
                  icon: PhosphorIconsRegular.caretLeft,
                  tooltip: 'Previous keyframe',
                  onTap: clip == null ? null : prev,
                ),
                _KfAction(
                  icon: atHead != null
                      ? PhosphorIcons.diamond(PhosphorIconsStyle.fill)
                      : PhosphorIconsRegular.diamond,
                  tooltip: atHead != null ? 'Remove keyframe' : 'Add keyframe',
                  active: atHead != null,
                  onTap: clip == null ? null : toggle,
                ),
                _KfAction(
                  icon: PhosphorIconsRegular.caretRight,
                  tooltip: 'Next keyframe',
                  onTap: clip == null ? null : next,
                ),
                Expanded(
                  child: Text(
                    _kfTimecode(rel),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _kfText,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                _KfAction(
                  icon: PhosphorIconsRegular.trash,
                  tooltip: 'Delete selected keyframe',
                  onTap: selected == null
                      ? null
                      : () {
                          editor.removeKeyframe(selected.id);
                          setState(() => _selId = null);
                        },
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),

          // ---- track ---------------------------------------------------------
          if (clip == null)
            const _KfHint('Select a clip to animate it.')
          else ...<Widget>[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: _kfPanel,
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.only(top: 6),
              child: _KfTrack(
                keys: all,
                selectedId: selected?.id,
                selectedIndex: selIndex,
                total: total,
                playhead: rel,
                onSeek: seekTo,
                onSelect: (k) {
                  if (k == null) {
                    setState(() => _selId = null);
                  } else {
                    seekTo(secondsOf(k.time));
                    setState(() => _selId = k.id);
                  }
                },
              ),
            ),
            if (all.isEmpty)
              const _KfHint('No keyframes yet. Move the playhead and tap the diamond.')
            else if (selected == null)
              const _KfHint('Tap a diamond to edit its curve.')
            else if (!hasNext)
              const _KfHint('The last keyframe has no curve. Select an earlier one.'),
          ],

          // ---- curve section -------------------------------------------------
          if (sel != null && nextKf != null) ...<Widget>[
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  const Text(
                    'Curve',
                    style: TextStyle(color: _kfText, fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  _KfChip(
                    '${secondsOf(sel.time).toStringAsFixed(1)}s  →  '
                    '${secondsOf(nextKf.time).toStringAsFixed(1)}s',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 92,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _kfOptions.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, i) {
                  final _CurveOption opt = _kfOptions[i];
                  return SizedBox(
                    width: 64,
                    child: _CurveTile(
                      option: opt,
                      on: _optionIsOn(opt, sel),
                      onTap: () => pick(sel, opt),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _CurveEditor(
                keyframe: sel,
                progress: progress,
                onChanged: editor.addKeyframe,
                onDragStateChanged: (dragging) {
                  if (_lockScroll != dragging) setState(() => _lockScroll = dragging);
                },
              ),
            ),
          ],

          // ---- clear ---------------------------------------------------------
          if (all.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            Center(
              child: _KfPill(
                icon: PhosphorIconsRegular.trash,
                label: 'Clear all keyframes',
                onTap: () {
                  for (final Keyframe k in all) {
                    editor.removeKeyframe(k.id);
                  }
                  setState(() {
                    _selId = null;
                    _lockScroll = false;
                  });
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// Small widgets
// ----------------------------------------------------------------------------
class _KfChip extends StatelessWidget {
  const _KfChip(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: _kfCard,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: _kfMuted,
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
            fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
          ),
        ),
      );
}

class _KfHint extends StatelessWidget {
  const _KfHint(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: _kfMuted, fontSize: 12),
        ),
      );
}

/// Custom pill button (replaces TextButton / OutlinedButton).
class _KfPill extends StatelessWidget {
  const _KfPill({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          tapFeedback();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: _kfCard,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 15, color: _kfText),
              const SizedBox(width: 6),
              Text(label,
                  style: const TextStyle(
                      color: _kfText, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );
}

class _KfAction extends StatelessWidget {
  const _KfAction({
    required this.icon,
    required this.tooltip,
    this.onTap,
    this.active = false,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final Color fg = onTap == null ? _kfDim : (active ? _kfBg : _kfText);
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap == null
            ? null
            : () {
                tapFeedback();
                onTap!();
              },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 44,
          height: 44,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? _kfText : Colors.transparent,
          ),
          child: Icon(icon, size: 22, color: fg),
        ),
      ),
    );
  }
}

/// Custom stepper: label, - value +. Replaces every Slider.
class _KfStepper extends StatelessWidget {
  const _KfStepper({
    required this.label,
    required this.display,
    required this.onMinus,
    required this.onPlus,
  });
  final String label;
  final String display;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

  Widget _btn(IconData icon, VoidCallback? onTap) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap == null
            ? null
            : () {
                tapFeedback();
                onTap();
              },
        child: Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: _kfCardOn),
          child: Icon(icon, size: 18, color: onTap == null ? _kfDim : _kfText),
        ),
      );

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      color: _kfText, fontSize: 13, fontWeight: FontWeight.w500)),
            ),
            _btn(Icons.remove_rounded, onMinus),
            SizedBox(
              width: 56,
              child: Text(
                display,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _kfAccent,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                ),
              ),
            ),
            _btn(Icons.add_rounded, onPlus),
          ],
        ),
      );
}

class _CurveTile extends StatelessWidget {
  const _CurveTile({required this.option, required this.on, required this.onTap});
  final _CurveOption option;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: <Widget>[
          AspectRatio(
            aspectRatio: 1,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              decoration: BoxDecoration(
                color: on ? _kfCardOn : _kfCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: on ? _kfText : Colors.transparent, width: 1.6),
              ),
              padding: const EdgeInsets.all(12),
              child: CustomPaint(painter: _CurveThumbPainter(option: option, on: on)),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            option.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: on ? _kfText : _kfMuted,
              fontSize: 11,
              fontWeight: on ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _CurveThumbPainter extends CustomPainter {
  _CurveThumbPainter({required this.option, required this.on});
  final _CurveOption option;
  final bool on;

  @override
  void paint(Canvas canvas, Size size) {
    final Path p = Path();
    const int steps = 40;
    for (int i = 0; i <= steps; i++) {
      final double t = i / steps;
      final double v = evalKeyframeCurve(
        t,
        option.curveType,
        cp1x: option.cp1x,
        cp1y: option.cp1y,
        cp2x: option.cp2x,
        cp2y: option.cp2y,
      ).clamp(-0.2, 1.2);
      final double x = t * size.width;
      final double y = size.height - (v * 0.8 + 0.1) * size.height;
      if (i == 0) {
        p.moveTo(x, y);
      } else {
        p.lineTo(x, y);
      }
    }
    canvas.drawPath(
      p,
      Paint()
        ..color = on ? _kfText : _kfMuted
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _CurveThumbPainter o) => o.option != option || o.on != on;
}

// ----------------------------------------------------------------------------
// Track: ruler + single lane
// ----------------------------------------------------------------------------
class _KfTrack extends StatelessWidget {
  const _KfTrack({
    required this.keys,
    required this.selectedId,
    required this.selectedIndex,
    required this.total,
    required this.playhead,
    required this.onSeek,
    required this.onSelect,
  });

  final List<Keyframe> keys;
  final Object? selectedId;
  final int selectedIndex;
  final double total;
  final double playhead;
  final ValueChanged<double> onSeek;
  final ValueChanged<Keyframe?> onSelect;

  static const double _pad = 20;
  static const double _h = 72;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final double w = c.maxWidth;
      final double usable = math.max(w - _pad * 2, 1);
      double xOf(double sec) => _pad + sec / total * usable;
      double secOf(double dx) => ((dx - _pad) / usable * total).clamp(0.0, total).toDouble();

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (d) {
          Keyframe? hit;
          double best = 24;
          for (final Keyframe k in keys) {
            final double dist = (xOf(secondsOf(k.time)) - d.localPosition.dx).abs();
            if (dist < best) {
              best = dist;
              hit = k;
            }
          }
          tapFeedback();
          if (hit != null) {
            onSelect(hit);
          } else {
            onSeek(secOf(d.localPosition.dx));
            onSelect(null);
          }
        },
        onHorizontalDragUpdate: (d) => onSeek(secOf(d.localPosition.dx)),
        child: CustomPaint(
          size: Size(w, _h),
          painter: _TrackPainter(
            keys: keys,
            selectedId: selectedId,
            selectedIndex: selectedIndex,
            total: total,
            xOf: xOf,
            playheadX: xOf(playhead.clamp(0.0, total).toDouble()),
          ),
        ),
      );
    });
  }
}

class _TrackPainter extends CustomPainter {
  _TrackPainter({
    required this.keys,
    required this.selectedId,
    required this.selectedIndex,
    required this.total,
    required this.xOf,
    required this.playheadX,
  });

  final List<Keyframe> keys;
  final Object? selectedId;
  final int selectedIndex;
  final double total;
  final double Function(double) xOf;
  final double playheadX;

  @override
  void paint(Canvas canvas, Size size) {
    const double rulerH = 22;
    final double cy = rulerH + (size.height - rulerH) / 2;

    const List<double> steps = <double>[0.5, 1, 2, 5, 10, 30, 60];
    double step = steps.last;
    for (final double s in steps) {
      if ((xOf(s) - xOf(0)) >= 48) {
        step = s;
        break;
      }
    }
    final Paint tick = Paint()
      ..color = _kfDim
      ..strokeWidth = 1;
    for (double t = 0; t <= total + 0.0001; t += step) {
      final double x = xOf(t);
      canvas.drawLine(Offset(x, rulerH - 6), Offset(x, rulerH - 1), tick);
      final TextPainter tp = TextPainter(
        text: TextSpan(
          text: step < 1 ? '${t.toStringAsFixed(1)}s' : '${t.toInt()}s',
          style: const TextStyle(color: _kfMuted, fontSize: 9.5),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, 0));
      final double mid = xOf(t + step / 2);
      if (t + step / 2 <= total) {
        canvas.drawLine(Offset(mid, rulerH - 4), Offset(mid, rulerH - 1), tick);
      }
    }

    // lane
    canvas.drawLine(
      Offset(xOf(0), cy),
      Offset(xOf(total), cy),
      Paint()
        ..color = _kfLine
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );

    // segments
    for (int i = 0; i + 1 < keys.length; i++) {
      final bool on = i == selectedIndex;
      canvas.drawLine(
        Offset(xOf(secondsOf(keys[i].time)), cy),
        Offset(xOf(secondsOf(keys[i + 1].time)), cy),
        Paint()
          ..color = on ? _kfAccent : _kfDim
          ..strokeWidth = on ? 4 : 3
          ..strokeCap = StrokeCap.round,
      );
    }

    // diamonds
    for (final Keyframe k in keys) {
      final double x = xOf(secondsOf(k.time));
      final bool on = k.id == selectedId;
      final double r = on ? 10 : 8;
      final Path p = Path()
        ..moveTo(x, cy - r)
        ..lineTo(x + r, cy)
        ..lineTo(x, cy + r)
        ..lineTo(x - r, cy)
        ..close();
      canvas.drawPath(p, Paint()..color = on ? _kfText : _kfBg);
      canvas.drawPath(
        p,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = on ? _kfBg : _kfMuted,
      );
    }

    // playhead
    final Paint ph = Paint()
      ..color = _kfText
      ..strokeWidth = 1.6;
    canvas.drawLine(Offset(playheadX, 4), Offset(playheadX, size.height), ph);
    canvas.drawCircle(Offset(playheadX, 4), 3.5, ph);
  }

  @override
  bool shouldRepaint(covariant _TrackPainter o) {
    if (o.playheadX != playheadX ||
        o.selectedId != selectedId ||
        o.selectedIndex != selectedIndex ||
        o.total != total ||
        o.keys.length != keys.length) {
      return true;
    }
    for (int i = 0; i < keys.length; i++) {
      if (o.keys[i].id != keys[i].id || o.keys[i].time != keys[i].time) return true;
    }
    return false;
  }
}

// ----------------------------------------------------------------------------
// Curve editor: graph + custom controls
// ----------------------------------------------------------------------------
class _CurveEditor extends StatefulWidget {
  const _CurveEditor({
    required this.keyframe,
    required this.progress,
    required this.onChanged,
    required this.onDragStateChanged,
  });

  final Keyframe keyframe;
  final double? progress;
  final ValueChanged<Keyframe> onChanged;
  final ValueChanged<bool> onDragStateChanged;

  @override
  State<_CurveEditor> createState() => _CurveEditorState();
}

class _CurveEditorState extends State<_CurveEditor> {
  int? _activeHandle; // 1 / 2 for bezier handles
  bool _paramDrag = false; // bounce / random vertical drag
  bool _locked = false;

  void _lock(bool v) {
    if (_locked != v) {
      _locked = v;
      widget.onDragStateChanged(v);
    }
  }

  void _endDrag() {
    _activeHandle = null;
    _paramDrag = false;
    _lock(false);
  }

  @override
  void dispose() {
    if (_locked) widget.onDragStateChanged(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Keyframe kf = widget.keyframe;
    final bool isBezier = kf.curveType == CurveType.cubicBezier;
    final bool isBounce = kf.curveType == CurveType.bounce;
    final bool isRandom = kf.curveType == CurveType.random;

    return Column(
      children: <Widget>[
        Container(
          decoration: BoxDecoration(
            color: _kfPanel,
            borderRadius: BorderRadius.circular(18),
          ),
          child: SizedBox(
            height: 180,
            width: double.infinity,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final Size size = Size(constraints.maxWidth, constraints.maxHeight);

                void updateHandle(Offset pos) {
                  final double nx =
                      ((pos.dx - _plotPadX) / (size.width - _plotPadX * 2)).clamp(0.0, 1.0);
                  final double ny =
                      (1.5 - (pos.dy - _plotPadY) / (size.height - _plotPadY * 2) * 2)
                          .clamp(-0.5, 1.5);
                  if (_activeHandle == 1) {
                    widget.onChanged(widget.keyframe.copyWith(
                      curveType: CurveType.cubicBezier,
                      cp1x: _r2(nx),
                      cp1y: _r2(ny),
                    ));
                  } else if (_activeHandle == 2) {
                    widget.onChanged(widget.keyframe.copyWith(
                      curveType: CurveType.cubicBezier,
                      cp2x: _r2(nx),
                      cp2y: _r2(ny),
                    ));
                  }
                }

                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanStart: (d) {
                    if (isBezier) {
                      final Offset p1 = _gp(size, kf.cp1x, kf.cp1y);
                      final Offset p2 = _gp(size, kf.cp2x, kf.cp2y);
                      final double d1 = (p1 - d.localPosition).distance;
                      final double d2 = (p2 - d.localPosition).distance;
                      if (d1 < 36 && d1 <= d2) {
                        _activeHandle = 1;
                      } else if (d2 < 36) {
                        _activeHandle = 2;
                      } else if (d1 < 70 && d1 <= d2) {
                        _activeHandle = 1;
                      } else if (d2 < 70) {
                        _activeHandle = 2;
                      } else {
                        _activeHandle = null;
                      }
                      if (_activeHandle != null) {
                        _lock(true);
                        updateHandle(d.localPosition);
                      }
                    } else {
                      _paramDrag = true;
                      _lock(true);
                    }
                  },
                  onPanUpdate: (d) {
                    if (isBezier) {
                      if (_activeHandle != null) updateHandle(d.localPosition);
                    } else if (_paramDrag) {
                      final Keyframe cur = widget.keyframe;
                      final double dv = -d.delta.dy / 160;
                      if (isBounce) {
                        widget.onChanged(cur.copyWith(
                            bounciness: _r2((cur.bounciness + dv * 0.6).clamp(0.2, 0.8))));
                      } else if (isRandom) {
                        widget.onChanged(cur.copyWith(
                            randomAmount: _r2((cur.randomAmount + dv).clamp(0.05, 1.0))));
                      }
                    }
                  },
                  onPanEnd: (_) => _endDrag(),
                  onPanCancel: _endDrag,
                  child: CustomPaint(
                    size: size,
                    painter: _CurvePainter(keyframe: kf, progress: widget.progress),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (isBezier)
          _BezierControls(
            keyframe: kf,
            onReset: () => widget.onChanged(kf.copyWith(
              curveType: CurveType.cubicBezier,
              cp1x: 0.0,
              cp1y: 0.0,
              cp2x: 1.0,
              cp2y: 1.0,
            )),
          )
        else if (isBounce) ...<Widget>[
          const _KfHint('Drag the graph up or down to change bounciness.'),
          _KfStepper(
            label: 'Bounces',
            display: '${kf.bounceCount}',
            onMinus: kf.bounceCount > 1
                ? () => widget.onChanged(kf.copyWith(bounceCount: kf.bounceCount - 1))
                : null,
            onPlus: kf.bounceCount < 6
                ? () => widget.onChanged(kf.copyWith(bounceCount: kf.bounceCount + 1))
                : null,
          ),
          _KfStepper(
            label: 'Bounciness',
            display: '${(kf.bounciness * 100).round()}%',
            onMinus: kf.bounciness > 0.2001
                ? () => widget.onChanged(
                    kf.copyWith(bounciness: _r2((kf.bounciness - 0.05).clamp(0.2, 0.8))))
                : null,
            onPlus: kf.bounciness < 0.7999
                ? () => widget.onChanged(
                    kf.copyWith(bounciness: _r2((kf.bounciness + 0.05).clamp(0.2, 0.8))))
                : null,
          ),
        ] else if (isRandom) ...<Widget>[
          const _KfHint('Drag the graph up or down to change intensity.'),
          _KfStepper(
            label: 'Intensity',
            display: '${(kf.randomAmount * 100).round()}%',
            onMinus: kf.randomAmount > 0.0501
                ? () => widget.onChanged(
                    kf.copyWith(randomAmount: _r2((kf.randomAmount - 0.05).clamp(0.05, 1.0))))
                : null,
            onPlus: kf.randomAmount < 0.9999
                ? () => widget.onChanged(
                    kf.copyWith(randomAmount: _r2((kf.randomAmount + 0.05).clamp(0.05, 1.0))))
                : null,
          ),
          _KfStepper(
            label: 'Detail',
            display: '${kf.randomDetail}',
            onMinus: kf.randomDetail > 3
                ? () => widget.onChanged(kf.copyWith(randomDetail: kf.randomDetail - 1))
                : null,
            onPlus: kf.randomDetail < 24
                ? () => widget.onChanged(kf.copyWith(randomDetail: kf.randomDetail + 1))
                : null,
          ),
          const SizedBox(height: 8),
          _KfPill(
            icon: Icons.casino_outlined,
            label: 'Shuffle',
            onTap: () =>
                widget.onChanged(kf.copyWith(randomSeed: math.Random().nextInt(9999) + 1)),
          ),
        ],
      ],
    );
  }
}

class _BezierControls extends StatelessWidget {
  const _BezierControls({required this.keyframe, required this.onReset});
  final Keyframe keyframe;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final Keyframe k = keyframe;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        _KfChip('P1  ${k.cp1x.toStringAsFixed(2)}, ${k.cp1y.toStringAsFixed(2)}'),
        _KfPill(icon: Icons.refresh_rounded, label: 'Reset', onTap: onReset),
        _KfChip('P2  ${k.cp2x.toStringAsFixed(2)}, ${k.cp2y.toStringAsFixed(2)}'),
      ],
    );
  }
}

class _CurvePainter extends CustomPainter {
  _CurvePainter({required this.keyframe, required this.progress});
  final Keyframe keyframe;
  final double? progress;

  void _dashed(Canvas c, Offset a, Offset b, Paint p) {
    const double dash = 4, gap = 5;
    final double dist = (b - a).distance;
    if (dist == 0) return;
    final Offset dir = (b - a) / dist;
    double d = 0;
    while (d < dist) {
      final double e = math.min(d + dash, dist);
      c.drawLine(a + dir * d, a + dir * e, p);
      d += dash + gap;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final Keyframe k = keyframe;
    final bool isBezier = k.curveType == CurveType.cubicBezier;

    // grid
    final Paint grid = Paint()
      ..color = _kfLine
      ..strokeWidth = 0.8;
    for (int i = 0; i <= 4; i++) {
      final double x = _gx(size, i / 4);
      canvas.drawLine(Offset(x, _gy(size, 1.5)), Offset(x, _gy(size, -0.5)), grid);
    }
    final Paint ref = Paint()
      ..color = _kfDim
      ..strokeWidth = 1;
    for (final double v in <double>[0, 1]) {
      _dashed(canvas, Offset(_gx(size, 0), _gy(size, v)), Offset(_gx(size, 1), _gy(size, v)), ref);
    }

    final Offset start = _gp(size, 0, 0);
    final Offset end = _gp(size, 1, 1);
    final Offset p1 = _gp(size, k.cp1x, k.cp1y);
    final Offset p2 = _gp(size, k.cp2x, k.cp2y);

    // curve path
    final Path path = Path();
    const int steps = 160;
    for (int i = 0; i <= steps; i++) {
      final double t = i / steps;
      final Offset pt = _gp(size, t, k.ease(t));
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }

    // soft fill under the curve, down to the start value line
    final Path fill = Path.from(path)
      ..lineTo(_gp(size, 1, 0).dx, _gp(size, 1, 0).dy)
      ..lineTo(_gp(size, 0, 0).dx, _gp(size, 0, 0).dy)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[_kfAccent.withValues(alpha: 0.18), _kfAccent.withValues(alpha: 0.0)],
        ).createShader(Offset.zero & size),
    );

    if (isBezier) {
      final Paint handleLine = Paint()
        ..color = Colors.white30
        ..strokeWidth = 1.4;
      canvas.drawLine(start, p1, handleLine);
      canvas.drawLine(end, p2, handleLine);
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );

    // end points
    for (final Offset o in <Offset>[start, end]) {
      canvas.drawCircle(o, 6.5, Paint()..color = _kfPanel);
      canvas.drawCircle(o, 4.5, Paint()..color = Colors.white);
    }

    // bezier handles (halo + ring + dot)
    if (isBezier) {
      for (final Offset pt in <Offset>[p1, p2]) {
        canvas.drawCircle(pt, 16, Paint()..color = _kfAccent.withValues(alpha: 0.18));
        canvas.drawCircle(pt, 9, Paint()..color = Colors.white);
        canvas.drawCircle(pt, 6.5, Paint()..color = _kfAccent);
      }
    }

    // live dot that follows the playhead
    final double? pr = progress;
    if (pr != null) {
      final Offset d = _gp(size, pr, k.ease(pr));
      canvas.drawCircle(d, 9, Paint()..color = Colors.white.withValues(alpha: 0.25));
      canvas.drawCircle(d, 4.5, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant _CurvePainter old) {
    final Keyframe a = old.keyframe;
    final Keyframe b = keyframe;
    return old.progress != progress ||
        a.curveType != b.curveType ||
        a.cp1x != b.cp1x ||
        a.cp1y != b.cp1y ||
        a.cp2x != b.cp2x ||
        a.cp2y != b.cp2y ||
        a.bounceCount != b.bounceCount ||
        a.bounciness != b.bounciness ||
        a.randomAmount != b.randomAmount ||
        a.randomDetail != b.randomDetail ||
        a.randomSeed != b.randomSeed;
  }
}