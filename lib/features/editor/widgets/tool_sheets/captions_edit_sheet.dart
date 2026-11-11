import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:provider/provider.dart';
import 'package:flutter_video_editor/core/models/project_model.dart';
import 'package:flutter_video_editor/features/editor/controllers/editor_controller.dart';
import 'package:flutter_video_editor/features/editor/theme/editor_tokens.dart';
import 'package:flutter_video_editor/features/editor/utils/editor_helpers.dart';
// ignore: unused_import
import 'package:flutter_video_editor/core/widgets/caption_widgets.dart';

const _font = 'Fredoka';

/// Sheet 1 of 2: edit caption text and timing. Styling lives in
/// [CaptionStyleSheet].
class CaptionsEditSheet extends StatefulWidget {
  const CaptionsEditSheet({super.key, this.onOpenStyle});

  /// Called when the user taps "Style". Wire this to open [CaptionStyleSheet].
  final VoidCallback? onOpenStyle;

  @override
  State<CaptionsEditSheet> createState() => _CaptionsEditSheetState();
}

class _CaptionsEditSheetState extends State<CaptionsEditSheet> {
  static const double _rowExtent = 116;

  final ScrollController _scroll = ScrollController();
  bool _isGenerating = false;
  int _lastActiveIndex = -1;
  String _selectedSpeechLanguage = 'Bengali';

  static const List<Map<String, String>> _speechLanguages = [
    {'code': 'auto', 'name': 'Auto-Detect', 'label': 'Auto'},
    {'code': 'bn', 'name': 'Bengali', 'label': 'বাংলা'},
    {'code': 'en', 'name': 'English', 'label': 'English'},
    {'code': 'hi', 'name': 'Hindi', 'label': 'हिन्दी'},
    {'code': 'es', 'name': 'Spanish', 'label': 'Español'},
    {'code': 'fr', 'name': 'French', 'label': 'Français'},
    {'code': 'de', 'name': 'German', 'label': 'Deutsch'},
    {'code': 'ar', 'name': 'Arabic', 'label': 'العربية'},
    {'code': 'zh', 'name': 'Chinese', 'label': '中文'},
    {'code': 'ja', 'name': 'Japanese', 'label': '日本語'},
  ];

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _generate(EditorController editor) async {
    if (_isGenerating) return;
    setState(() => _isGenerating = true);
    tapFeedback();
    try {
      final lang = (_selectedSpeechLanguage == 'Auto-Detect' ||
              _selectedSpeechLanguage == 'Auto')
          ? null
          : _selectedSpeechLanguage;
      await editor.generateWhisperCaptions(language: lang);
      if (!mounted) return;
      final n = editor.project.captions.length;
      if (n > 0) {
        _toast(
            'Generated $n caption${n == 1 ? '' : 's'} in $_selectedSpeechLanguage');
      } else {
        _toast('No speech detected in audio.');
      }
    } catch (e) {
      if (!mounted) return;
      final cleanMsg = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      _toast('Auto captions failed: $cleanMsg');
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _import(EditorController editor) async {
    tapFeedback();
    try {
      final count = await editor.importCaptionFile();
      if (!mounted || count <= 0) return;
      _toast('Imported $count caption${count == 1 ? '' : 's'}');
    } catch (e) {
      if (!mounted) return;
      _toast('Import failed: $e');
    }
  }

  void _addCue(EditorController editor) {
    tapFeedback();
    editor.addCaptionCue(
      CaptionCue(
        id: 'cue_${DateTime.now().microsecondsSinceEpoch}',
        start: editor.playhead,
        end: editor.playhead + const Duration(seconds: 3),
        text: 'New caption',
      ),
    );
  }

  /// Make timeline actions (split/merge) target this cue.
  /// NOTE: adapt `selectClip` to your controller's selection method.
  void _selectCue(EditorController editor, CaptionCue cue) {
    editor.selectClip('caption_${cue.id}');
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ));
  }

  void _autoScrollTo(int index) {
    if (index < 0 || index == _lastActiveIndex) return;
    _lastActiveIndex = index;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final target = (index * _rowExtent - _rowExtent)
          .clamp(0.0, _scroll.position.maxScrollExtent);
      _scroll.animateTo(target,
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    });
  }

  @override
  Widget build(BuildContext context) {
    final editor = context.watch<EditorController>();
    final captions = editor.project.captions;

    return Container(
      color: EditorTokens.bg,
      child: Column(
        children: [
          _buildTopBar(editor),
          _buildLanguageTabs(),
          Expanded(
            child: captions.isEmpty ? _empty(editor) : _list(editor, captions),
          ),
        ],
      ),
    );
  }

  // ---------------- Top bar ----------------
  Widget _barIcon(PhosphorIconData icon, String tip, VoidCallback? onTap) {
    return IconButton(
      tooltip: tip,
      icon: PhosphorIcon(
        icon,
        color: onTap == null ? EditorTokens.muted : EditorTokens.text,
        size: 20,
      ),
      onPressed: onTap,
    );
  }

  Widget _buildTopBar(EditorController editor) {
    return Container(
      height: 46,
      decoration: const BoxDecoration(
        border:
            Border(bottom: BorderSide(color: EditorTokens.border, width: 0.5)),
      ),
      child: Row(
        children: [
          _isGenerating
              ? const SizedBox(
                  width: 48,
                  child: Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: EditorTokens.text,
                        backgroundColor: EditorTokens.border,
                      ),
                    ),
                  ),
                )
              : _barIcon(PhosphorIconsRegular.sparkle, 'Auto captions',
                  () => _generate(editor)),
          _barIcon(PhosphorIconsRegular.fileArrowUp, 'Import .srt / .vtt',
              () => _import(editor)),
          _barIcon(PhosphorIconsRegular.plus, 'Add caption at playhead',
              () => _addCue(editor)),
          const Spacer(),
          if (widget.onOpenStyle != null) ...[
            Container(width: 1, height: 16, color: EditorTokens.border),
            _barIcon(PhosphorIconsRegular.textAa, 'Style', widget.onOpenStyle),
          ],
        ],
      ),
    );
  }

  Widget _buildLanguageTabs() {
    return Container(
      height: 40,
      decoration: const BoxDecoration(
        border:
            Border(bottom: BorderSide(color: EditorTokens.border, width: 0.5)),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        itemCount: _speechLanguages.length,
        itemBuilder: (_, i) {
          final lang = _speechLanguages[i];
          final active = lang['name'] == _selectedSpeechLanguage;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (active) return;
              tapFeedback();
              setState(() => _selectedSpeechLanguage = lang['name']!);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    lang['label']!,
                    style: TextStyle(
                      color: active ? EditorTokens.text : EditorTokens.muted,
                      fontSize: 14,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      fontFamily: _font,
                    ),
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
        },
      ),
    );
  }

  // ---------------- Empty / List ----------------
  Widget _empty(EditorController editor) {
    return _StateMessage(
      icon: PhosphorIconsRegular.closedCaptioning,
      text: 'No captions yet',
      action: _isGenerating ? null : 'Auto captions ($_selectedSpeechLanguage)',
      onAction: () => _generate(editor),
    );
  }

  Widget _list(EditorController editor, List<CaptionCue> captions) {
    final p = editor.playhead;
    final active = captions.indexWhere((c) => p >= c.start && p < c.end);
    _autoScrollTo(active);

    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
      itemExtent: _rowExtent,
      itemCount: captions.length + 1,
      itemBuilder: (context, i) {
        if (i == captions.length) {
          return Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: EditorTokens.text,
                  side: const BorderSide(color: EditorTokens.border),
                  textStyle: const TextStyle(
                      fontFamily: _font, fontWeight: FontWeight.w600),
                ),
                onPressed: () => _addCue(editor),
                icon: const PhosphorIcon(PhosphorIconsRegular.plus,
                    size: 16, color: EditorTokens.text),
                label: const Text('Add caption at playhead'),
              ),
            ),
          );
        }
        final cue = captions[i];
        return _CueRow(
          key: ValueKey(cue.id),
          cue: cue,
          index: i + 1,
          active: i == active,
          onSeek: () {
            tapFeedback();
            seekPlayhead(editor, secondsOf(cue.start));
          },
          onTextChanged: (t) => editor.updateCaptionCue(cue.copyWith(text: t)),
          onSplit: () {
            tapFeedback();
            _selectCue(editor, cue);
            editor.splitSelectedClip();
          },
          onMerge: i == captions.length - 1
              ? null
              : () {
                  tapFeedback();
                  _selectCue(editor, cue);
                  editor.mergeNextCaptionClip();
                },
          onDelete: () {
            tapFeedback();
            editor.deleteCaptionCue(cue.id);
          },
        );
      },
    );
  }
}

// ======================= Widgets =======================

class _CueRow extends StatelessWidget {
  const _CueRow({
    super.key,
    required this.cue,
    required this.index,
    required this.active,
    required this.onSeek,
    required this.onTextChanged,
    required this.onSplit,
    required this.onMerge,
    required this.onDelete,
  });

  final CaptionCue cue;
  final int index;
  final bool active;
  final VoidCallback onSeek;
  final ValueChanged<String> onTextChanged;
  final VoidCallback onSplit;
  final VoidCallback? onMerge;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final headColor = active ? EditorTokens.text : EditorTokens.muted;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 8),
        decoration: BoxDecoration(
          color: EditorTokens.elevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? EditorTokens.text : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                _Pressable(
                  onTap: onSeek,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('$index',
                            style: TextStyle(
                                color: headColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                fontFamily: _font)),
                        const SizedBox(width: 10),
                        Text(
                          '${formatCueTime(cue.start)} – ${formatCueTime(cue.end)}',
                          style: TextStyle(
                              color: headColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              fontFamily: _font),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                _icon(PhosphorIconsRegular.scissors, 'Split', onSplit),
                _icon(PhosphorIconsRegular.arrowLineDown, 'Merge with next',
                    onMerge),
                _icon(PhosphorIconsRegular.trash, 'Delete', onDelete,
                    color: Colors.redAccent),
              ],
            ),
            Expanded(
              child: Align(
                alignment: Alignment.topLeft,
                child: TextFormField(
                  initialValue: cue.text,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  cursorColor: EditorTokens.text,
                  style: const TextStyle(
                      color: EditorTokens.text,
                      fontSize: 14,
                      height: 1.3,
                      fontFamily: _font),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.only(right: 8),
                    hintText: 'Type caption…',
                    hintStyle: TextStyle(
                        color: EditorTokens.muted, fontFamily: _font),
                  ),
                  onChanged: onTextChanged,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _icon(PhosphorIconData icon, String tip, VoidCallback? onTap,
      {Color color = EditorTokens.text}) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
      padding: EdgeInsets.zero,
      tooltip: tip,
      onPressed: onTap,
      icon: PhosphorIcon(icon,
          size: 16, color: onTap == null ? EditorTokens.border : color),
    );
  }
}

/// Scale-down press feedback.
class _Pressable extends StatefulWidget {
  const _Pressable({required this.child, required this.onTap});
  final Widget child;
  final VoidCallback onTap;
  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.95 : 1,
        duration: const Duration(milliseconds: 100),
        child: widget.child,
      ),
    );
  }
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({
    required this.icon,
    required this.text,
    this.action,
    this.onAction,
  });
  final PhosphorIconData icon;
  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PhosphorIcon(icon, size: 36, color: EditorTokens.muted),
          const SizedBox(height: 10),
          Text(
            text,
            style: const TextStyle(
                color: EditorTokens.muted, fontSize: 13, fontFamily: _font),
          ),
          const SizedBox(height: 4),
          const Text(
            'Generate from speech, import .srt / .vtt, or add by hand.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: EditorTokens.muted, fontSize: 12, fontFamily: _font),
          ),
          if (action != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: EditorTokens.text,
                side: const BorderSide(color: EditorTokens.border),
                textStyle: const TextStyle(
                    fontFamily: _font, fontWeight: FontWeight.w600),
              ),
              onPressed: onAction,
              child: Text(action!),
            ),
          ],
        ],
      ),
    );
  }
}