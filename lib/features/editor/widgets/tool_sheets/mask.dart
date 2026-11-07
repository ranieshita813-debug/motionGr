import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:flutter_video_editor/core/models/project_model.dart';
import 'package:flutter_video_editor/features/editor/controllers/editor_controller.dart';
import 'package:flutter_video_editor/features/editor/utils/editor_helpers.dart';
import 'mask_geometry.dart';

const Color _mkBg = bgToken;
const Color _mkCard = Color(0xFF1C1C1E);
const Color _mkText = Color(0xFFFFFFFF);
const Color _mkMuted = Color(0xFF8E8E93);
const Color _mkDim = Color(0xFF48484A);
// Same accent as the handles overlay, so the sheet and the player feel linked.
const Color _mkAccent = Color(0xFF25F4EE);

const double _tileBox = 52;
const double _tileW = 58;

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
    Future<void>.microtask(() {
      try {
        _editor.setMaskEditing(false);
      } catch (_) {}
    });
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
        padding: EdgeInsets.only(top: 8, bottom: 8 + bottom),
        child: SizedBox(
          height: 78,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                height: 40,
                margin: const EdgeInsets.fromLTRB(10, 6, 4, 0),
                color: _mkDim,
              ),
              Expanded(
                child: Stack(
                  children: <Widget>[
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.only(left: 6, right: 28),
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
                              const SizedBox(width: 6),
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
                    // Soft fade on the right edge: hints that the list scrolls.
                    Positioned(
                      top: 0,
                      bottom: 0,
                      right: 0,
                      width: 28,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: <Color>[_mkBg.withValues(alpha: 0), _mkBg],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
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
    final Color fg = !enabled ? _mkDim : (selected ? _mkAccent : _mkMuted);
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        child: SizedBox(
          width: _tileW,
          child: Column(
            children: <Widget>[
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: _tileBox,
                height: _tileBox,
                decoration: BoxDecoration(
                  color: selected ? _mkAccent.withValues(alpha: 0.14) : _mkCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected ? _mkAccent : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(13),
                  child: CustomPaint(painter: _IconPainter(name: name, color: fg)),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                label,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.fade,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected ? _mkText : fg,
                  fontSize: 11,
                  fontFamily: 'Fredoka',
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
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
    final Paint fill = Paint()..color = color.withValues(alpha: 0.22);

    if (name == 'none') {
      canvas.drawOval(r, line);
      canvas.drawLine(r.bottomLeft + const Offset(3, -3), r.topRight + const Offset(-3, 3), line);
      return;
    }

    if (name == 'invert') {
      // Circle with one filled half, drawn in the same stroke style as the rest.
      canvas.drawOval(r, line);
      canvas.drawArc(r, -1.5707963, 3.1415926, true, Paint()..color = color);
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