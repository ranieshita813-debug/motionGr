import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:provider/provider.dart';
import 'package:flutter_video_editor/core/models/project_model.dart';
import 'package:flutter_video_editor/features/editor/controllers/editor_controller.dart';
import 'package:flutter_video_editor/features/editor/theme/editor_tokens.dart';
import 'package:flutter_video_editor/features/editor/utils/editor_helpers.dart';
import 'package:flutter_video_editor/core/widgets/caption_widgets.dart';

/// CapCut-style caption styling sheet.
///
/// Tabs: Style, Font, Color, Stroke, Effects, Animate, Layout.
/// Requires the extra [TextStyleProperties] fields and the undo/redo helpers
/// on [EditorController] described in INTEGRATION.md.
class CaptionStyleSheet extends StatefulWidget {
  const CaptionStyleSheet({super.key, this.onOpenEdit});

  /// Called when the user taps "Edit". Wire this to open [CaptionsEditSheet].
  final VoidCallback? onOpenEdit;

  @override
  State<CaptionStyleSheet> createState() => _CaptionStyleSheetState();
}

enum _Tab { style, font, color, stroke, effects, animate, layout }

const Color _accent = Color(0xFF25F4EE);
const Color _tileBg = Color(0xFF1E1E1E);

class _CaptionStyleSheetState extends State<CaptionStyleSheet> {
  /// true = every caption, false = only the selected caption.
  bool? _scopeAll;
  _Tab _tab = _Tab.style;

  static const List<Color> _swatches = <Color>[
    Color(0xFFFFFFFF),
    Color(0xFFFFD700),
    Color(0xFF00E5FF),
    Color(0xFF00FF66),
    Color(0xFFFF007F),
    Color(0xFFFF6600),
    Color(0xFFA855F7),
    Color(0xFF000000),
  ];

  static const List<_Preset> _presets = <_Preset>[
    _Preset('Classic', 'color', Color(0xFFFFD700), Colors.transparent, 28),
    _Preset('Bold', 'scale', Color(0xFFFFFFFF), Colors.transparent, 36),
    _Preset('Badge', 'badge', Color(0xFF000000), Color(0xFFFFFFFF), 30),
    _Preset('Glow', 'outline', Color(0xFF00E5FF), Colors.transparent, 32),
    _Preset('Marker', 'badge', Color(0xFF000000), Color(0xFFFFD700), 30),
    _Preset('Neon', 'outline', Color(0xFFFF007F), Colors.transparent, 32),
    _Preset('Cyber', 'badge', Color(0xFF00FF66), Color(0xFF1A1A2E), 30),
    _Preset('Karaoke', 'scale', Color(0xFFFF3366), Colors.transparent, 34),
    _Preset('Gradient', 'color', Color(0xFF00C4D6), Colors.transparent, 30),
    _Preset('Minimal', 'color', Color(0xFFBDBDBD), Colors.transparent, 26),
    _Preset('Comic', 'badge', Color(0xFF000000), Color(0xFFFFCC00), 32),
    _Preset('Vlog', 'badge', Color(0xFFFFFFFF), Color(0xFFE63946), 28),
    _Preset('Retro', 'outline', Color(0xFFFF9900), Colors.transparent, 30),
  ];

  /// Label -> fontFamily. Replace the values with fonts bundled in pubspec.yaml.
  static const Map<String, String> _fonts = <String, String>{
    'Sans': '',
    'Serif': 'Georgia',
    'Mono': 'RobotoMono',
    'Impact': 'Impact',
    'Script': 'BrushScript',
  };

  static const Map<String, String> _tabLabels = <String, String>{
    'style': 'Style',
    'font': 'Font',
    'color': 'Color',
    'stroke': 'Stroke',
    'effects': 'Effects',
    'animate': 'Animate',
    'layout': 'Layout',
  };

  // --------------------------------------------------------------------------
  // Apply helpers
  // --------------------------------------------------------------------------

  void _apply(EditorController editor, TextStyleProperties next, bool all) {
    if (all) {
      editor.applyCaptionStyleToAll(next);
    } else {
      editor.updateSelectedClipTextStyle(next);
    }
  }

  /// One discrete change = one undo step.
  void _commit(EditorController editor, TextStyleProperties next, bool all) {
    editor.pushStyleUndo();
    _apply(editor, next, all);
  }

  @override
  Widget build(BuildContext context) {
    final editor = context.watch<EditorController>();
    final sel = editor.selectedClip;
    final hasCaptionSelected = sel != null && sel.clipType == ClipType.caption;

    // No caption selected -> can only target all captions.
    final all = !hasCaptionSelected || (_scopeAll ?? false);
    final style = (hasCaptionSelected ? sel.textStyle : null) ??
        const TextStyleProperties();

    return Container(
      color: EditorTokens.bg,
      child: Column(
        children: [
          MonoSheetHeader(
            title: 'Caption style',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _IconBtn(
                  icon: PhosphorIconsRegular.arrowUUpLeft,
                  enabled: editor.canUndoStyle,
                  onTap: editor.undoStyle,
                ),
                _IconBtn(
                  icon: PhosphorIconsRegular.arrowUUpRight,
                  enabled: editor.canRedoStyle,
                  onTap: editor.redoStyle,
                ),
                _IconBtn(
                  icon: PhosphorIconsRegular.arrowCounterClockwise,
                  enabled: true,
                  onTap: () =>
                      _commit(editor, const TextStyleProperties(), all),
                ),
                if (widget.onOpenEdit != null) ...[
                  const SizedBox(width: 6),
                  MonoButton(
                    label: 'Edit',
                    icon: PhosphorIconsRegular.pencilSimple,
                    onTap: widget.onOpenEdit,
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: MonoSegmented<bool>(
              options: const {true: 'All captions', false: 'Selected'},
              value: all,
              onChanged: (v) {
                if (!v && !hasCaptionSelected) {
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(const SnackBar(
                      content: Text('Select a caption on the timeline first'),
                      duration: Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                    ));
                  return;
                }
                tapFeedback();
                setState(() => _scopeAll = v);
              },
            ),
          ),
          _tabBar(),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: SingleChildScrollView(
                key: ValueKey<_Tab>(_tab),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                child: _body(context, editor, style, all),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Tab bar
  // --------------------------------------------------------------------------

  Widget _tabBar() {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: EditorTokens.border)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            for (final t in _Tab.values)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  tapFeedback();
                  setState(() => _tab = t);
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 22),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: t == _tab ? Colors.white : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Text(
                    _tabLabels[t.name]!,
                    style: TextStyle(
                      color: t == _tab ? Colors.white : EditorTokens.muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      fontFamily: CaptionMono.font,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Tab bodies
  // --------------------------------------------------------------------------

  Widget _body(
    BuildContext context,
    EditorController editor,
    TextStyleProperties s,
    bool all,
  ) {
    void commit(TextStyleProperties n) => _commit(editor, n, all);
    void live(TextStyleProperties n) => _apply(editor, n, all);

    switch (_tab) {
      case _Tab.style:
        return _styleTab(s, commit);

      case _Tab.font:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const MonoLabel('Typeface'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in _fonts.entries)
                  SizedBox(
                    width: 76,
                    height: 56,
                    child: _Tile(
                      selected: s.fontFamily == e.value,
                      onTap: () => commit(s.copyWith(fontFamily: e.value)),
                      child: Text(
                        e.key,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontFamily: e.value.isEmpty ? null : e.value,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 22),
            _toggleRow(
              title: 'Bold',
              subtitle: 'Heavier caption weight',
              value: s.bold,
              onChanged: (v) => commit(s.copyWith(bold: v)),
            ),
          ],
        );

      case _Tab.color:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _toggleRow(
              title: 'Highlight spoken word',
              subtitle: 'Follows the speech, word by word',
              value: s.enableHighlight,
              onChanged: (v) => commit(s.copyWith(enableHighlight: v)),
            ),
            const SizedBox(height: 22),
            const MonoLabel('Effect'),
            MonoSegmented<String>(
              options: const {
                'color': 'Color',
                'badge': 'Badge',
                'scale': 'Pop',
                'outline': 'Glow',
              },
              value: s.highlightStyle,
              onChanged: (v) {
                tapFeedback();
                commit(s.copyWith(highlightStyle: v));
              },
            ),
            const SizedBox(height: 22),
            const MonoLabel('Text color'),
            _swatchRow(
              selected: s.textColor,
              onPick: (c) => commit(s.copyWith(textColor: c)),
            ),
            const SizedBox(height: 22),
            const MonoLabel('Highlight color'),
            _swatchRow(
              selected: s.highlightColor,
              onPick: (c) => commit(s.copyWith(highlightColor: c)),
            ),
            if (s.highlightStyle == 'badge') ...[
              const SizedBox(height: 22),
              const MonoLabel('Badge color'),
              _swatchRow(
                selected: s.highlightBackgroundColor,
                withNone: true,
                onPick: (c) =>
                    commit(s.copyWith(highlightBackgroundColor: c)),
              ),
            ],
          ],
        );

      case _Tab.stroke:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _slider(
              label: 'Width',
              valueText: '${s.strokeWidth.round()}px',
              value: s.strokeWidth,
              min: 0,
              max: 8,
              onStart: editor.pushStyleUndo,
              onChanged: (v) => live(s.copyWith(strokeWidth: v)),
            ),
            const SizedBox(height: 22),
            const MonoLabel('Stroke color'),
            _swatchRow(
              selected: s.strokeColor,
              onPick: (c) => commit(s.copyWith(strokeColor: c)),
            ),
          ],
        );

      case _Tab.effects:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _slider(
              label: 'Glow',
              valueText: '${s.glowRadius.round()}px',
              value: s.glowRadius,
              min: 0,
              max: 24,
              onStart: editor.pushStyleUndo,
              onChanged: (v) => live(s.copyWith(glowRadius: v)),
            ),
            const SizedBox(height: 22),
            const MonoLabel('Glow color'),
            _swatchRow(
              selected: s.glowColor,
              onPick: (c) => commit(s.copyWith(glowColor: c)),
            ),
            const SizedBox(height: 22),
            _toggleRow(
              title: 'Drop shadow',
              subtitle: 'Soft shadow under the text',
              value: s.shadow,
              onChanged: (v) => commit(s.copyWith(shadow: v)),
            ),
            const SizedBox(height: 22),
            _slider(
              label: 'Background box',
              valueText: '${(s.boxOpacity * 100).round()}%',
              value: s.boxOpacity * 100,
              min: 0,
              max: 100,
              onStart: editor.pushStyleUndo,
              onChanged: (v) => live(s.copyWith(boxOpacity: v / 100)),
            ),
          ],
        );

      case _Tab.animate:
        const anims = <String, String>{
          'none': 'None',
          'pop': 'Pop',
          'fade': 'Fade',
          'slide': 'Slide',
          'zoom': 'Zoom',
        };
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const MonoLabel('Entrance'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in anims.entries)
                  SizedBox(
                    width: 76,
                    height: 56,
                    child: _Tile(
                      selected: s.animation == e.key,
                      onTap: () => commit(s.copyWith(animation: e.key)),
                      child: Text(
                        e.value,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontFamily: CaptionMono.font,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        );

      case _Tab.layout:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const MonoLabel('Position'),
            MonoSegmented<String>(
              options: const {
                'top': 'Top',
                'middle': 'Middle',
                'bottom': 'Bottom',
              },
              value: s.position,
              onChanged: (v) {
                tapFeedback();
                commit(s.copyWith(position: v));
              },
            ),
            const SizedBox(height: 22),
            _slider(
              label: 'Size',
              valueText: '${s.fontSize.round()}',
              value: s.fontSize.clamp(14, 60).toDouble(),
              min: 14,
              max: 60,
              onStart: editor.pushStyleUndo,
              onChanged: (v) => live(s.copyWith(fontSize: v)),
            ),
          ],
        );
    }
  }

  Widget _styleTab(
    TextStyleProperties s,
    void Function(TextStyleProperties) commit,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const MonoLabel('Templates'),
        SizedBox(
          height: 136,
          child: GridView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _presets.length + 1,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              mainAxisExtent: 64,
            ),
            itemBuilder: (context, i) {
              // First tile turns the highlight off, like CapCut's "none".
              if (i == 0) {
                return _Tile(
                  selected: !s.enableHighlight,
                  onTap: () {
                    tapFeedback();
                    commit(s.copyWith(enableHighlight: false));
                  },
                  child: const PhosphorIcon(
                    PhosphorIconsRegular.prohibit,
                    size: 20,
                    color: Colors.white54,
                  ),
                );
              }
              final p = _presets[i - 1];
              final selected = s.enableHighlight &&
                  s.highlightStyle == p.effect &&
                  s.highlightColor.toARGB32() == p.color.toARGB32() &&
                  s.highlightBackgroundColor.toARGB32() == p.badge.toARGB32();
              return _Tile(
                selected: selected,
                onTap: () {
                  tapFeedback();
                  commit(
                    s.copyWith(
                      enableHighlight: true,
                      highlightStyle: p.effect,
                      highlightColor: p.color,
                      highlightBackgroundColor: p.badge,
                      fontSize: p.size,
                    ),
                  );
                },
                child: _PresetSample(preset: p),
              );
            },
          ),
        ),
      ],
    );
  }

  // --------------------------------------------------------------------------
  // Shared controls
  // --------------------------------------------------------------------------

  Widget _slider({
    required String label,
    required String valueText,
    required double value,
    required double min,
    required double max,
    required VoidCallback onStart,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            MonoLabel(label, bottom: 0),
            Text(
              valueText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                fontFamily: CaptionMono.font,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 2,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
          ),
          child: Slider(
            value: value.clamp(min, max).toDouble(),
            min: min,
            max: max,
            activeColor: _accent,
            inactiveColor: EditorTokens.border,
            // One slider drag = one undo step.
            onChangeStart: (_) => onStart(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _toggleRow({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      fontFamily: CaptionMono.font)),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: const TextStyle(
                      color: EditorTokens.muted,
                      fontSize: 12,
                      fontFamily: CaptionMono.font)),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: (v) {
            tapFeedback();
            onChanged(v);
          },
          activeThumbColor: Colors.black,
          activeTrackColor: _accent,
          inactiveThumbColor: EditorTokens.muted,
          inactiveTrackColor: EditorTokens.elevated,
          trackOutlineColor: WidgetStateProperty.all(EditorTokens.border),
        ),
      ],
    );
  }

  Widget _swatchRow({
    required Color selected,
    required ValueChanged<Color> onPick,
    bool withNone = false,
  }) {
    final items = <Color>[if (withNone) Colors.transparent, ..._swatches];
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final c = items[i];
          final none = c == Colors.transparent;
          final sel = selected.toARGB32() == c.toARGB32();
          return GestureDetector(
            onTap: () {
              tapFeedback();
              onPick(c);
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: none ? null : c,
                shape: BoxShape.circle,
                border: Border.all(
                  color: sel ? _accent : EditorTokens.border,
                  width: sel ? 2 : 1,
                ),
              ),
              child: none
                  ? const Center(
                      child: PhosphorIcon(PhosphorIconsRegular.prohibit,
                          size: 16, color: Colors.white70))
                  : null,
            ),
          );
        },
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// Small private widgets
// ----------------------------------------------------------------------------

class _Preset {
  const _Preset(this.name, this.effect, this.color, this.badge, this.size);
  final String name;
  final String effect;
  final Color color;
  final Color badge;
  final double size;
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.selected,
    required this.onTap,
    required this.child,
  });

  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _tileBg,
          borderRadius: BorderRadius.circular(CaptionMono.radius),
          border: Border.all(
            color: selected ? _accent : Colors.transparent,
            width: 2,
          ),
        ),
        child: child,
      ),
    );
  }
}

class _PresetSample extends StatelessWidget {
  const _PresetSample({required this.preset});
  final _Preset preset;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: preset.badge == Colors.transparent ? null : preset.badge,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        'Aa',
        style: TextStyle(
          color: preset.color,
          fontWeight: FontWeight.w900,
          fontSize: 18,
          fontFamily: CaptionMono.font,
          shadows: preset.effect == 'outline'
              ? [Shadow(color: preset.color, blurRadius: 10)]
              : null,
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final PhosphorIconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled
          ? () {
              tapFeedback();
              onTap();
            }
          : null,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: PhosphorIcon(
          icon,
          size: 20,
          color: enabled ? Colors.white : Colors.white24,
        ),
      ),
    );
  }
}