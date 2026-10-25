// pubspec.yaml additions:
//   flutter_svg: ^2.0.10
//   xml: ^6.5.0
//   path_drawing: ^1.0.1
//   file_picker: ^8.0.0
//
// EditorController needs: addSvgElementClip(String svg, String name)
//
// Usage (CapCut-style bottom sheet):
//   showModalBottomSheet(
//     context: context,
//     isScrollControlled: true,
//     backgroundColor: Colors.transparent,
//     builder: (_) => ChangeNotifierProvider.value(
//       value: context.read<EditorController>(),
//       child: const ElementsSheet(),
//     ),
//   );

import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:flutter_video_editor/core/models/project_model.dart';
import 'package:flutter_video_editor/features/editor/controllers/editor_controller.dart';
import 'package:flutter_video_editor/core/models/svg_model.dart';
import 'package:flutter_video_editor/features/editor/widgets/svg_editor.dart';

// ───────────────────────── CAPCUT-STYLE TOKENS ─────────────────────────

const _sheet = Color(0xFF161616);
const _tile = Color(0xFF242424);
const _field = Color(0xFF2A2A2A);
const _accent = Color(0xFF2DE2D0); // CapCut-like cyan highlight
const _textHi = Colors.white;
const _textLo = Color(0xFF8E8E93);
const _font = 'Ubuntu';

// ───────────────────────── SHAPES ─────────────────────────

class _Asset {
  _Asset(this.name, this.svg);
  final String name;
  final String svg;
}

// White by default, like CapCut stickers/shapes (recolor in the editor).
String svgForShape(ElementShape s) {
  const o = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">';
  const f = 'fill="#FFFFFF"';
  switch (s.name.toLowerCase()) {
    case 'circle':
      return '$o<circle cx="50" cy="50" r="42" $f/></svg>';
    case 'ellipse':
      return '$o<ellipse cx="50" cy="50" rx="46" ry="30" $f/></svg>';
    case 'triangle':
      return '$o<polygon points="50,8 94,90 6,90" $f/></svg>';
    case 'star':
      return '$o<polygon points="50,5 61,38 95,38 67,58 78,92 50,71 22,92 33,58 5,38 39,38" $f/></svg>';
    case 'heart':
      return '$o<path d="M50 88 C10 60 5 30 28 18 C40 12 50 20 50 30 C50 20 60 12 72 18 C95 30 90 60 50 88Z" $f/></svg>';
    case 'arrow':
      return '$o<polygon points="10,40 60,40 60,20 95,50 60,80 60,60 10,60" $f/></svg>';
    case 'hexagon':
    case 'polygon':
      return '$o<polygon points="50,5 90,27 90,73 50,95 10,73 10,27" $f/></svg>';
    case 'line':
      return '$o<line x1="8" y1="50" x2="92" y2="50" stroke="#FFFFFF" stroke-width="6" stroke-linecap="round"/></svg>';
    default:
      return '$o<rect x="10" y="10" width="80" height="80" rx="10" $f/></svg>';
  }
}

const _categories = <String, Set<String>>{
  'All': {},
  'Basic': {'circle', 'ellipse', 'rectangle', 'rect', 'square', 'rounded', 'triangle', 'hexagon', 'polygon'},
  'Symbols': {'star', 'heart'},
  'Arrows & Lines': {'arrow', 'line'},
};

// ───────────────────────── SHEET ─────────────────────────

class ElementsSheet extends StatefulWidget {
  const ElementsSheet({super.key});
  @override
  State<ElementsSheet> createState() => _ElementsSheetState();
}

class _ElementsSheetState extends State<ElementsSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  String _category = 'All';
  int _tab = 0; // 0 = Shapes, 1 = My graphics
  final List<_Asset> _mine = [];
  _Asset? _flash; // tile that was just added (shows a check)

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ───── actions ─────

  Future<void> _importFile() async {
    final res = await FilePicker.platform
        .pickFiles(type: FileType.custom, allowedExtensions: ['svg'], withData: true);
    if (!mounted) return;
    final f = res?.files.single;
    if (f?.bytes == null) return;
    _addImported(
        f!.name.replaceAll(RegExp(r'\.svg$', caseSensitive: false), ''), utf8.decode(f.bytes!));
  }

  Future<void> _pasteCode() async {
    final c = TextEditingController();
    try {
      final code = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        backgroundColor: _sheet,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
        builder: (ctx) => Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Paste SVG code',
                style: TextStyle(color: _textHi, fontSize: 16, fontWeight: FontWeight.w700, fontFamily: _font)),
            const SizedBox(height: 12),
            TextField(
              controller: c,
              maxLines: 8,
              autofocus: true,
              style: const TextStyle(color: _textHi, fontSize: 12, fontFamily: 'monospace'),
              decoration: InputDecoration(
                hintText: '<svg ...>',
                hintStyle: const TextStyle(color: _textLo),
                filled: true,
                fillColor: _field,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: _pillButton('Cancel', filled: false, onTap: () => Navigator.pop(ctx)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _pillButton('Import', filled: true, onTap: () => Navigator.pop(ctx, c.text)),
              ),
            ]),
          ]),
        ),
      );
      if (!mounted) return;
      if (code != null && code.trim().isNotEmpty) _addImported('Pasted SVG', code);
    } finally {
      c.dispose();
    }
  }

  void _addImported(String name, String svg) {
    try {
      SvgDoc.parse(svg); // validate
      if (!mounted) return;
      setState(() {
        _mine.insert(0, _Asset(name, svg));
        _tab = 1;
        _query = '';
        _searchCtrl.clear();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Invalid SVG: $e')));
    }
  }

  Future<void> _draw() async {
    final editor = context.read<EditorController>();
    final out = await Navigator.of(context).push<String>(MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const SvgEditorPage(
            source: '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 200"></svg>',
            title: 'New graphic')));
    if (!mounted || out == null) return;
    setState(() {
      _mine.insert(0, _Asset('Drawing ${_mine.length + 1}', out));
      _tab = 1;
    });
    editor.addSvgElementClip(out, 'Drawing');
  }

  Future<void> _edit(_Asset a) async {
    final editor = context.read<EditorController>();
    final out = await Navigator.of(context).push<String>(MaterialPageRoute(
        fullscreenDialog: true, builder: (_) => SvgEditorPage(source: a.svg, title: a.name)));
    if (!mounted || out == null) return;
    setState(() {
      _mine.insert(0, _Asset('${a.name} (edited)', out));
      _tab = 1;
    });
    editor.addSvgElementClip(out, a.name);
  }

  void _add(_Asset a) {
    HapticFeedback.selectionClick();
    context.read<EditorController>().addSvgElementClip(a.svg, a.name);
    setState(() => _flash = a);
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted && _flash == a) setState(() => _flash = null);
    });
  }

  void _showOptions(_Asset a) {
    HapticFeedback.mediumImpact();
    final isMine = _mine.contains(a);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _sheet,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          _handle(),
          const SizedBox(height: 12),
          SizedBox(
              width: 72,
              height: 72,
              child: DecoratedBox(
                decoration: BoxDecoration(color: _tile, borderRadius: BorderRadius.circular(12)),
                child: Padding(padding: const EdgeInsets.all(14), child: SvgPicture.string(a.svg)),
              )),
          const SizedBox(height: 8),
          Text(a.name, style: const TextStyle(color: _textHi, fontSize: 13, fontFamily: _font)),
          const SizedBox(height: 8),
          _optionRow(Icons.add_circle_outline, 'Add to timeline', () {
            Navigator.pop(ctx);
            _add(a);
          }),
          _optionRow(Icons.tune, 'Customize', () {
            Navigator.pop(ctx);
            _edit(a);
          }),
          if (isMine)
            _optionRow(Icons.delete_outline, 'Delete', () {
              Navigator.pop(ctx);
              setState(() => _mine.remove(a));
            }, color: const Color(0xFFFF5C5C)),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  // ───── build ─────

  @override
  Widget build(BuildContext context) {
    final q = _query.toLowerCase();
    List<_Asset> assets;
    if (_tab == 0) {
      final cat = _categories[_category] ?? {};
      assets = ElementShape.values
          .where((s) => cat.isEmpty || cat.contains(s.name.toLowerCase()))
          .map((s) => _Asset(s.name, svgForShape(s)))
          .toList();
    } else {
      assets = _mine;
    }
    final filtered = assets.where((a) => a.name.toLowerCase().contains(q)).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scroll) => Container(
        decoration: const BoxDecoration(
          color: _sheet,
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        child: Column(children: [
          const SizedBox(height: 8),
          _handle(),
          _header(),
          _searchBar(),
          _tabs(),
          if (_tab == 0) _chips(),
          Expanded(child: _grid(filtered, scroll)),
        ]),
      ),
    );
  }

  Widget _handle() => Container(
      width: 36, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)));

  Widget _header() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 4),
        child: Row(children: [
          const Text('Elements',
              style: TextStyle(color: _textHi, fontSize: 17, fontWeight: FontWeight.w700, fontFamily: _font)),
          const Spacer(),
          IconButton(
              tooltip: 'Close',
              onPressed: () => Navigator.maybePop(context),
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _textHi, size: 28)),
        ]),
      );

  Widget _searchBar() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Container(
          height: 40,
          decoration: BoxDecoration(color: _field, borderRadius: BorderRadius.circular(20)),
          child: Row(children: [
            const SizedBox(width: 12),
            const Icon(Icons.search_rounded, size: 20, color: _textLo),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _query = v),
                style: const TextStyle(color: _textHi, fontSize: 14, fontFamily: _font),
                cursorColor: _accent,
                decoration: const InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    hintText: 'Search elements',
                    hintStyle: TextStyle(color: _textLo, fontSize: 14, fontFamily: _font)),
              ),
            ),
            if (_query.isNotEmpty)
              GestureDetector(
                onTap: () => setState(() {
                  _query = '';
                  _searchCtrl.clear();
                }),
                child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Icon(Icons.cancel, size: 18, color: _textLo)),
              ),
          ]),
        ),
      );

  Widget _tabs() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(children: [
          _tabBtn('Shapes', 0),
          _tabBtn(_mine.isEmpty ? 'My graphics' : 'My graphics · ${_mine.length}', 1),
        ]),
      );

  Widget _tabBtn(String t, int i) {
    final on = _tab == i;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _tab = i),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(t,
              style: TextStyle(
                  color: on ? _textHi : _textLo,
                  fontSize: 14,
                  fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                  fontFamily: _font)),
          const SizedBox(height: 4),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 2.5,
            width: on ? 18 : 0,
            decoration: BoxDecoration(color: _accent, borderRadius: BorderRadius.circular(2)),
          ),
        ]),
      ),
    );
  }

  Widget _chips() => SizedBox(
        height: 40,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          scrollDirection: Axis.horizontal,
          itemCount: _categories.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final name = _categories.keys.elementAt(i);
            final on = name == _category;
            return GestureDetector(
              onTap: () => setState(() => _category = name),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: on ? Colors.white : _field,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(name,
                    style: TextStyle(
                        color: on ? Colors.black : const Color(0xFFD0D0D0),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        fontFamily: _font)),
              ),
            );
          },
        ),
      );

  Widget _grid(List<_Asset> items, ScrollController scroll) {
    final showActions = _tab == 1;
    // My tab: first row = quick-action tiles (Import / Paste / Draw)
    return CustomScrollView(
      controller: scroll,
      slivers: [
        if (showActions)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Row(children: [
                Expanded(child: _actionTile(Icons.file_upload_outlined, 'Import', _importFile, primary: true)),
                const SizedBox(width: 10),
                Expanded(child: _actionTile(Icons.code_rounded, 'Paste', _pasteCode)),
                const SizedBox(width: 10),
                Expanded(child: _actionTile(Icons.brush_outlined, 'Draw', _draw)),
              ]),
            ),
          ),
        if (items.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(_tab == 1 ? Icons.auto_awesome_outlined : Icons.search_off_rounded,
                      size: 38, color: Colors.white24),
                  const SizedBox(height: 10),
                  Text(_tab == 1 ? 'Add your own SVG graphics' : 'No results',
                      style: const TextStyle(color: _textLo, fontSize: 13, fontFamily: _font)),
                ]),
              ),
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(16, 10, 16, 16 + MediaQuery.of(context).padding.bottom),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 1),
              delegate: SliverChildBuilderDelegate(
                (_, i) => _ElementTile(
                  asset: items[i],
                  added: identical(_flash, items[i]),
                  onTap: () => _add(items[i]),
                  onLongPress: () => _showOptions(items[i]),
                ),
                childCount: items.length,
              ),
            ),
          ),
      ],
    );
  }

  // ───── small widgets ─────

  Widget _actionTile(IconData icon, String label, VoidCallback onTap, {bool primary = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: primary ? _accent : _field,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 20, color: primary ? Colors.black : _textHi),
          const SizedBox(height: 3),
          Text(label,
              style: TextStyle(
                  color: primary ? Colors.black : _textHi,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  fontFamily: _font)),
        ]),
      ),
    );
  }

  Widget _pillButton(String label, {required bool filled, required VoidCallback onTap}) => GestureDetector(
        onTap: onTap,
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: filled ? _accent : _field,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Text(label,
              style: TextStyle(
                  color: filled ? Colors.black : _textHi,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  fontFamily: _font)),
        ),
      );

  Widget _optionRow(IconData icon, String label, VoidCallback onTap, {Color color = _textHi}) => ListTile(
        dense: true,
        leading: Icon(icon, color: color, size: 22),
        title: Text(label, style: TextStyle(color: color, fontSize: 14, fontFamily: _font)),
        onTap: onTap,
      );
}

// ───────────────────────── TILE ─────────────────────────

class _ElementTile extends StatefulWidget {
  const _ElementTile({required this.asset, required this.added, required this.onTap, required this.onLongPress});
  final _Asset asset;
  final bool added;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  State<_ElementTile> createState() => _ElementTileState();
}

class _ElementTileState extends State<_ElementTile> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _down ? 0.93 : 1,
        duration: const Duration(milliseconds: 100),
        child: Container(
          decoration: BoxDecoration(color: _tile, borderRadius: BorderRadius.circular(10)),
          child: Stack(children: [
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: SvgPicture.string(widget.asset.svg, fit: BoxFit.contain),
              ),
            ),
            // "added" confirmation overlay
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedOpacity(
                  opacity: widget.added ? 1 : 0,
                  duration: const Duration(milliseconds: 150),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.check_circle_rounded, color: _accent, size: 28),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}