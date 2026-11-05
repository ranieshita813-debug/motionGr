import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:flutter_video_editor/core/models/project_model.dart';
import 'package:flutter_video_editor/features/editor/controllers/editor_controller.dart';
import 'package:flutter_video_editor/features/editor/utils/editor_helpers.dart';
import 'mask_geometry.dart';

const Color _mkBg = bgToken;
const Color _mkCard = Color(0xFF1C1C1E);
const Color _mkCardOn = Color(0xFF2C2C2E);
const Color _mkText = Color(0xFFFFFFFF);
const Color _mkMuted = Color(0xFF8E8E93);
const Color _mkDim = Color(0xFF48484A);

String _mkCap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

// ============================================================================
// Bottom bar only:  [Invert] | None, Linear, Mirror, Circle, ...
// No preview here. The REAL player shows the mask (MaskedLayer) and the
// handles (MaskHandlesOverlay). The clip's MaskProperties is the single source
// of truth, so the sheet keeps no local copy of the state.
// ============================================================================
class MaskSheet extends StatefulWidget {
  const MaskSheet({super.key});

  @override
  State<MaskSheet> createState() => _MaskSheetState();
}

class _MaskSheetState extends State<MaskSheet> {
  late final EditorController _editor;

  @override
  void initState() {
    super.initState();
    _editor = context.read<EditorController>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _editor.setMaskEditing(true);
    });
  }

  @override
  void dispose() {
    // notifyListeners must not run while the tree is being torn down
    Future<void>.microtask(() => _editor.setMaskEditing(false));
    super.dispose();
  }

  MaskProperties _props() => _editor.selectedClip?.maskProperties ?? const MaskProperties();

  void _select(MaskType t) {
    final MaskProperties p = _props();
    _editor.updateMaskProperties(
      p.withXform(
        MaskXform.fromProps(p),
        type: t,
        feather: p.isActive ? p.feather : 10.0,
      ),
    );
  }

  void _toggleInvert() {
    final MaskProperties p = _props();
    if (!p.isActive) return;
    _editor.updateMaskProperties(p.withXform(MaskXform.fromProps(p), invert: !p.invert));
  }

  void _clear() {
    // Removes the mask (see EditorController note in INTEGRATION.md)
    _editor.updateMaskProperties(const MaskProperties());
  }

  @override
  Widget build(BuildContext context) {
    final EditorController editor = context.watch<EditorController>();
    final MaskProperties p = editor.selectedClip?.maskProperties ?? const MaskProperties();
    final bool has = p.isActive;
    final double bottom = MediaQuery.paddingOf(context).bottom;

    return ColoredBox(
      color: _mkBg,
      child: Padding(
        padding: EdgeInsets.only(top: 6, bottom: 6 + bottom),
        child: SizedBox(
          height: 72,
          child: Row(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: _MaskTile(
                  label: 'Invert',
                  name: 'invert',
                  selected: has && p.invert,
                  enabled: has,
                  onTap: () {
                    tapFeedback();
                    _toggleInvert();
                  },
                ),
              ),
              Container(
                width: 1,
                height: 36,
                margin: const EdgeInsets.symmetric(horizontal: 10),
                color: _mkDim,
              ),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(right: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _MaskTile(
                        label: 'None',
                        name: 'none',
                        selected: !has,
                        onTap: () {
                          tapFeedback();
                          _clear();
                        },
                      ),
                      for (final MaskType type in MaskType.values)
                        if (type != MaskType.none) ...<Widget>[
                          const SizedBox(width: 8),
                          _MaskTile(
                            label: _mkCap(type.name),
                            name: type.name,
                            selected: has && type == p.type,
                            onTap: () {
                              tapFeedback();
                              _select(type);
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
    );
  }
}

// ----------------------------------------------------------------------------
// Tile
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
        width: 50,
        child: Column(
          children: <Widget>[
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: selected ? _mkCardOn : _mkCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: selected ? _mkText : Colors.transparent, width: 1.5),
              ),
              child: name == 'invert'
                  ? Icon(Icons.invert_colors_rounded, size: 22, color: fg)
                  : Padding(
                      padding: const EdgeInsets.all(11),
                      child: CustomPaint(painter: _IconPainter(name: name, color: fg)),
                    ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: fg,
                fontSize: 11,
                fontFamily: 'HelveticaNeue',
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
    if (maskIsLine(name)) {
      canvas.drawRRect(frame, line);
      canvas.save();
      canvas.clipRRect(frame);
      canvas.drawRect(Rect.fromLTRB(r.left, r.top, r.right, r.center.dy), fill);
      canvas.restore();
      canvas.drawLine(Offset(r.left, r.center.dy), Offset(r.right, r.center.dy), line);
      return;
    }
    if (maskIsMirror(name)) {
      canvas.drawRRect(frame, line);
      final Rect band = Rect.fromLTRB(
          r.left, r.top + r.height * 0.3, r.right, r.bottom - r.height * 0.3);
      canvas.drawRect(band, fill);
      canvas.drawLine(band.topLeft, band.topRight, line);
      canvas.drawLine(band.bottomLeft, band.bottomRight, line);
      return;
    }
    final Path p = maskShapePath(name, r);
    canvas.drawPath(p, fill);
    canvas.drawPath(p, line);
  }

  @override
  bool shouldRepaint(covariant _IconPainter o) => o.name != name || o.color != color;
}