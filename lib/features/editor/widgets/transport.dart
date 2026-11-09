import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:flutter_video_editor/core/models/project_model.dart';
import 'package:flutter_video_editor/features/editor/controllers/editor_controller.dart';
import 'package:flutter_video_editor/features/editor/utils/editor_helpers.dart';
import 'package:flutter_video_editor/features/editor/widgets/keyframe_controls.dart';

class TransportBar extends StatelessWidget {
  const TransportBar({super.key, required this.editor});
  final EditorController editor;

  Widget _icon(IconData i, String tip, VoidCallback onTap, double s) => IconButton(
        tooltip: tip,
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: BoxConstraints.tightFor(width: 40 * s, height: 40 * s),
        icon: Icon(i, color: Colors.white, size: 22 * s),
        onPressed: () {
          tapFeedback();
          onTap();
        },
      );

  void _showMoreMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF161616),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final clip = editor.selectedClip;
        final hasGroup = clip?.groupId != null;
        final isTextOrCaption = clip != null && (clip.clipType == ClipType.text || clip.clipType == ClipType.caption);
        final multiCount = editor.selectedLayerCount;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                if (multiCount > 1 || clip != null)
                  ListTile(
                    leading: const Icon(PhosphorIconsRegular.circlesThreePlus, color: Colors.white),
                    title: const Text('Group selected clips', style: TextStyle(color: Colors.white, fontFamily: 'Fredoka')),
                    onTap: () {
                      Navigator.pop(ctx);
                      editor.groupSelectedClips();
                    },
                  ),
                if (hasGroup)
                  ListTile(
                    leading: const Icon(PhosphorIconsRegular.circlesThree, color: Colors.white),
                    title: const Text('Ungroup clips', style: TextStyle(color: Colors.white, fontFamily: 'Fredoka')),
                    onTap: () {
                      Navigator.pop(ctx);
                      editor.ungroupSelectedClips();
                    },
                  ),
                if (isTextOrCaption)
                  ListTile(
                    leading: const Icon(PhosphorIconsRegular.fileSvg, color: Colors.white),
                    title: const Text('Convert to SVG', style: TextStyle(color: Colors.white, fontFamily: 'Fredoka')),
                    onTap: () {
                      Navigator.pop(ctx);
                      editor.convertTextClipToSvg(clip.id);
                    },
                  ),
                ListTile(
                  leading: const Icon(PhosphorIconsRegular.copy, color: Colors.white),
                  title: const Text('Duplicate clip', style: TextStyle(color: Colors.white, fontFamily: 'Fredoka')),
                  enabled: clip != null,
                  onTap: clip != null
                      ? () {
                          Navigator.pop(ctx);
                          editor.duplicateSelectedClip();
                        }
                      : null,
                ),
                ListTile(
                  leading: const Icon(PhosphorIconsRegular.trash, color: Color(0xFFFF5252)),
                  title: const Text('Delete clip', style: TextStyle(color: Color(0xFFFF5252), fontFamily: 'Fredoka')),
                  enabled: clip != null,
                  onTap: clip != null
                      ? () {
                          Navigator.pop(ctx);
                          editor.removeSelectedClip();
                        }
                      : null,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final double s = scaleOf(MediaQuery.sizeOf(context));

    return Container(
      color: bgToken,
      padding: EdgeInsets.symmetric(horizontal: 8 * s, vertical: 2 * s),
      child: Row(
        children: <Widget>[
          KeyframeControls(editor: editor),
          const Spacer(),
          _icon(PhosphorIconsRegular.skipBack, 'Previous frame',
              () => seekPlayhead(editor, secondsOf(editor.playhead) - 1 / fpsToken), s),
          Selector<EditorController, bool>(
            selector: (_, e) => e.isPlaying,
            builder: (_, playing, __) => Semantics(
              button: true,
              label: playing ? 'Pause' : 'Play',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  tapFeedback();
                  editor.togglePlayback();
                },
                child: Container(
                  width: 36 * s,
                  height: 36 * s,
                  margin: EdgeInsets.symmetric(horizontal: 2 * s),
                  alignment: Alignment.center,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 150),
                    child: Icon(
                        playing ? PhosphorIconsFill.pause : PhosphorIconsFill.play,
                        key: ValueKey<bool>(playing),
                        color: Colors.white,
                        size: 24 * s),
                  ),
                ),
              ),
            ),
          ),
          _icon(PhosphorIconsRegular.skipForward, 'Next frame',
              () => seekPlayhead(editor, secondsOf(editor.playhead) + 1 / fpsToken), s),
          const Spacer(),
          _icon(PhosphorIconsRegular.arrowUUpLeft, 'Undo', editor.undo, s),
          _icon(PhosphorIconsRegular.arrowUUpRight, 'Redo', editor.redo, s),
          _icon(PhosphorIconsRegular.dotsThreeVertical, 'More', () => _showMoreMenu(context), s),
        ],
      ),
    );
  }
}
