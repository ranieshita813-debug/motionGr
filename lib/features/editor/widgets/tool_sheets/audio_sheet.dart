import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:flutter_video_editor/features/editor/controllers/editor_controller.dart';
import 'package:flutter_video_editor/features/editor/utils/editor_helpers.dart';
import 'audio_properties.dart';

const Color _bg = bgToken;
const Color _card = Color(0xFF1C1C1E);
const Color _cardOn = Color(0xFF2C2C2E);
const Color _text = Color(0xFFFFFFFF);
const Color _muted = Color(0xFF8E8E93);
const Color _dim = Color(0xFF48484A);
const Color _accent = Color(0xFF25F4EE);

enum _Tool { volume, fade, speed, enhance, voice }

// ============================================================================
// CapCut-style audio sheet
//
//   [ waveform strip with fade + volume envelope ]
//   [ panel of the selected tool                 ]
//   [ Volume | Fade | Speed | Enhance | Voice    ]
//
// The clip's AudioProperties is the single source of truth (no local copy),
// so the preview player, the timeline and export all read the same values.
//
// Needs on the clip model + controller:
//   clip.audioProperties                    -> AudioProperties
//   editor.updateAudioProperties(props)     -> notifyListeners()
// ============================================================================
class AudioSheet extends StatefulWidget {
  const AudioSheet({
    super.key,
    required this.durationSeconds,
    this.waveform,
  });

  /// Source length of the (trimmed) clip in seconds.
  final double durationSeconds;

  /// Normalized peaks 0..1. If null a soft placeholder is drawn.
  final List<double>? waveform;

  @override
  State<AudioSheet> createState() => _AudioSheetState();
}

class _AudioSheetState extends State<AudioSheet> {
  _Tool _tool = _Tool.volume;

  void _set(EditorController e, AudioProperties p) => e.updateAudioProperties(p);

  @override
  Widget build(BuildContext context) {
    final EditorController editor = context.watch<EditorController>();
    final AudioProperties p = editor.selectedClip?.audioProperties ?? const AudioProperties();
    final double bottom = MediaQuery.paddingOf(context).bottom;
    final double playback = p.playbackSeconds(widget.durationSeconds);

    return ColoredBox(
      color: _bg,
      child: Padding(
        padding: EdgeInsets.only(bottom: 8 + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // ---- waveform + envelope ---------------------------------------
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: SizedBox(
                height: 64,
                width: double.infinity,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: CustomPaint(
                    painter: _WavePainter(
                      props: p,
                      playback: playback,
                      peaks: widget.waveform,
                    ),
                  ),
                ),
              ),
            ),

            // ---- tool panel ------------------------------------------------
            SizedBox(
              height: 118,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                child: KeyedSubtree(
                  key: ValueKey<_Tool>(_tool),
                  child: _panel(editor, p),
                ),
              ),
            ),

            // ---- tool bar --------------------------------------------------
            SizedBox(
              height: 72,
              child: Row(
                children: <Widget>[
                  for (final _ToolDef t in _tools)
                    Expanded(
                      child: _ToolTile(
                        icon: t.icon,
                        label: t.label,
                        selected: _tool == t.tool,
                        badge: _hasChange(t.tool, p),
                        onTap: () {
                          tapFeedback();
                          setState(() => _tool = t.tool);
                        },
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _hasChange(_Tool t, AudioProperties p) => switch (t) {
        _Tool.volume => (p.volume - 1).abs() > 0.001,
        _Tool.fade => p.fadeIn > 0 || p.fadeOut > 0,
        _Tool.speed => (p.speed - 1).abs() > 0.001,
        _Tool.enhance => p.noiseReduction || p.normalize || p.enhanceVoice,
        _Tool.voice => p.voice != VoiceEffect.none,
      };

  Widget _panel(EditorController e, AudioProperties p) {
    switch (_tool) {
      case _Tool.volume:
        return _PanelPad(
          children: <Widget>[
            _CapSlider(
              label: 'Volume',
              value: p.volume * 100,
              min: 0,
              max: 200,
              display: '${(p.volume * 100).round()}',
              onChanged: (double v) => _set(e, p.copyWith(volume: v / 100)),
            ),
            _Reset(
              show: (p.volume - 1).abs() > 0.001,
              onTap: () => _set(e, p.copyWith(volume: 1.0)),
            ),
          ],
        );

      case _Tool.fade:
        final double maxFade = math.max(0.5, math.min(5.0, widget.durationSeconds / 2));
        return _PanelPad(
          children: <Widget>[
            _CapSlider(
              label: 'Fade in',
              value: p.fadeIn.clamp(0, maxFade).toDouble(),
              min: 0,
              max: maxFade,
              display: '${p.fadeIn.toStringAsFixed(1)}s',
              onChanged: (double v) =>
                  _set(e, p.copyWith(fadeIn: (v * 10).round() / 10)),
            ),
            _CapSlider(
              label: 'Fade out',
              value: p.fadeOut.clamp(0, maxFade).toDouble(),
              min: 0,
              max: maxFade,
              display: '${p.fadeOut.toStringAsFixed(1)}s',
              onChanged: (double v) =>
                  _set(e, p.copyWith(fadeOut: (v * 10).round() / 10)),
            ),
          ],
        );

      case _Tool.speed:
        return _PanelPad(
          children: <Widget>[
            _CapSlider(
              label: 'Speed',
              value: p.speed,
              min: 0.25,
              max: 4.0,
              display: '${p.speed.toStringAsFixed(2)}x',
              onChanged: (double v) => _set(e, p.copyWith(speed: (v * 20).round() / 20)),
            ),
            Row(
              children: <Widget>[
                for (final double s in <double>[0.5, 1.0, 1.5, 2.0]) ...<Widget>[
                  _Chip(
                    label: '${s}x',
                    selected: (p.speed - s).abs() < 0.001,
                    onTap: () {
                      tapFeedback();
                      _set(e, p.copyWith(speed: s));
                    },
                  ),
                  const SizedBox(width: 8),
                ],
                const Spacer(),
                const Text('Keep pitch', style: TextStyle(color: _muted, fontSize: 12)),
                const SizedBox(width: 6),
                _Toggle(
                  value: p.keepPitch,
                  onChanged: (bool v) => _set(e, p.copyWith(keepPitch: v)),
                ),
              ],
            ),
          ],
        );

      case _Tool.enhance:
        return _PanelPad(
          gap: 0,
          children: <Widget>[
            _SwitchRow(
              label: 'Reduce noise',
              value: p.noiseReduction,
              onChanged: (bool v) => _set(e, p.copyWith(noiseReduction: v)),
            ),
            _SwitchRow(
              label: 'Normalize loudness',
              value: p.normalize,
              onChanged: (bool v) => _set(e, p.copyWith(normalize: v)),
            ),
            _SwitchRow(
              label: 'Enhance voice',
              value: p.enhanceVoice,
              onChanged: (bool v) => _set(e, p.copyWith(enhanceVoice: v)),
            ),
          ],
        );

      case _Tool.voice:
        return ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
          children: <Widget>[
            for (final VoiceEffect v in VoiceEffect.values) ...<Widget>[
              _VoiceTile(
                icon: _voiceIcon(v),
                label: v.label,
                selected: p.voice == v,
                onTap: () {
                  tapFeedback();
                  _set(e, p.copyWith(voice: v));
                },
              ),
              const SizedBox(width: 10),
            ],
          ],
        );
    }
  }
}

IconData _voiceIcon(VoiceEffect v) => switch (v) {
      VoiceEffect.none => Icons.block_rounded,
      VoiceEffect.man => Icons.man_rounded,
      VoiceEffect.woman => Icons.woman_rounded,
      VoiceEffect.child => Icons.child_care_rounded,
      VoiceEffect.deep => Icons.south_rounded,
      VoiceEffect.robot => Icons.smart_toy_outlined,
      VoiceEffect.tremble => Icons.vibration_rounded,
      VoiceEffect.echo => Icons.surround_sound_outlined,
    };

class _ToolDef {
  const _ToolDef(this.tool, this.label, this.icon);
  final _Tool tool;
  final String label;
  final IconData icon;
}

const List<_ToolDef> _tools = <_ToolDef>[
  _ToolDef(_Tool.volume, 'Volume', Icons.volume_up_rounded),
  _ToolDef(_Tool.fade, 'Fade', Icons.gradient_rounded),
  _ToolDef(_Tool.speed, 'Speed', Icons.speed_rounded),
  _ToolDef(_Tool.enhance, 'Enhance', Icons.auto_fix_high_rounded),
  _ToolDef(_Tool.voice, 'Voice', Icons.record_voice_over_rounded),
];

// ----------------------------------------------------------------------------
// Waveform with live envelope (shows volume + fades while you drag)
// ----------------------------------------------------------------------------
class _WavePainter extends CustomPainter {
  _WavePainter({required this.props, required this.playback, required this.peaks});
  final AudioProperties props;
  final double playback;
  final List<double>? peaks;

  double _peak(int i, int n) {
    final List<double>? pk = peaks;
    if (pk != null && pk.isNotEmpty) return pk[(i * pk.length / n).floor().clamp(0, pk.length - 1)];
    // soft placeholder
    return (0.35 + 0.35 * math.sin(i * 0.37) * math.cos(i * 0.11) + 0.2 * math.sin(i * 1.3))
        .abs()
        .clamp(0.08, 1.0)
        .toDouble();
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = _card);

    final int n = (size.width / 4).floor();
    final double mid = size.height / 2;
    final double maxH = size.height * 0.46;
    final Paint ghost = Paint()
      ..color = _muted.withValues(alpha: 0.25)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final Paint bar = Paint()
      ..color = _accent
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final Path env = Path();
    for (int i = 0; i < n; i++) {
      final double x = (i + 0.5) * size.width / n;
      final double t = playback * i / math.max(1, n - 1);
      final double a = _peak(i, n);
      final double g = props.gainAt(t, playback);

      // original level (ghost)
      final double h0 = a * maxH;
      canvas.drawLine(Offset(x, mid - h0), Offset(x, mid + h0), ghost);

      // after volume/fades
      final double h = math.min(a * g, 1.0) * maxH;
      canvas.drawLine(Offset(x, mid - math.max(1.0, h)), Offset(x, mid + math.max(1.0, h)), bar);

      final double ey = mid - math.min(g / 2, 1.0) * maxH * 1.9;
      i == 0 ? env.moveTo(x, ey) : env.lineTo(x, ey);
    }

    canvas.drawPath(
      env,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _WavePainter o) =>
      o.props != props || o.playback != playback || o.peaks != peaks;
}

// ----------------------------------------------------------------------------
// Small pieces
// ----------------------------------------------------------------------------
class _PanelPad extends StatelessWidget {
  const _PanelPad({required this.children, this.gap = 6});
  final List<Widget> children;
  final double gap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            for (int i = 0; i < children.length; i++) ...<Widget>[
              if (i > 0) SizedBox(height: gap),
              children[i],
            ],
          ],
        ),
      );
}

class _CapSlider extends StatelessWidget {
  const _CapSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.display,
    required this.onChanged,
  });
  final String label, display;
  final double value, min, max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        SizedBox(
          width: 64,
          child: Text(label, style: const TextStyle(color: _muted, fontSize: 12)),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              activeTrackColor: _text,
              inactiveTrackColor: _dim,
              thumbColor: _text,
              overlayColor: Colors.white24,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
              trackShape: const RoundedRectSliderTrackShape(),
            ),
            child: Slider(
              value: value.clamp(min, max).toDouble(),
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ),
        SizedBox(
          width: 46,
          child: Text(
            display,
            textAlign: TextAlign.right,
            style: const TextStyle(color: _text, fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _Reset extends StatelessWidget {
  const _Reset({required this.show, required this.onTap});
  final bool show;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 30,
        child: Align(
          alignment: Alignment.centerRight,
          child: show
              ? GestureDetector(
                  onTap: () {
                    tapFeedback();
                    onTap();
                  },
                  child: const Text('Reset',
                      style: TextStyle(color: _accent, fontSize: 12, fontWeight: FontWeight.w600)),
                )
              : null,
        ),
      );
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? _cardOn : _card,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: selected ? _text : Colors.transparent, width: 1.2),
          ),
          child: Text(label,
              style: TextStyle(
                color: selected ? _text : _muted,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              )),
        ),
      );
}

class _Toggle extends StatelessWidget {
  const _Toggle({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () {
          tapFeedback();
          onChanged(!value);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 40,
          height: 24,
          padding: const EdgeInsets.all(2),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          decoration: BoxDecoration(
            color: value ? _accent : _dim,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: value ? Colors.black : Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ),
      );
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({required this.label, required this.value, required this.onChanged});
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 38,
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(label, style: const TextStyle(color: _text, fontSize: 14)),
            ),
            _Toggle(value: value, onChanged: onChanged),
          ],
        ),
      );
}

class _VoiceTile extends StatelessWidget {
  const _VoiceTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color fg = selected ? _text : _muted;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 58,
        child: Column(
          children: <Widget>[
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: selected ? _cardOn : _card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: selected ? _text : Colors.transparent, width: 1.5),
              ),
              child: Icon(icon, size: 24, color: fg),
            ),
            const SizedBox(height: 6),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: fg,
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class _ToolTile extends StatelessWidget {
  const _ToolTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.badge,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool selected, badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color fg = selected ? _text : _muted;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Icon(icon, size: 24, color: fg),
              if (badge)
                const Positioned(
                  right: -4,
                  top: -2,
                  child: CircleAvatar(radius: 3.5, backgroundColor: _accent),
                ),
            ],
          ),
          const SizedBox(height: 5),
          Text(label,
              style: TextStyle(
                  color: fg,
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
        ],
      ),
    );
  }
}