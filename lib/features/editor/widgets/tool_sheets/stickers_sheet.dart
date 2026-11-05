import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_video_editor/features/editor/controllers/editor_controller.dart';
import 'package:flutter_video_editor/features/editor/models/sticker_item.dart';
import 'package:flutter_video_editor/features/editor/services/sticker_repository.dart';
import 'package:flutter_video_editor/features/editor/theme/editor_tokens.dart';
import 'package:flutter_video_editor/features/editor/widgets/tool_search_header.dart';

enum _Source { online, emoji }

class StickersSheet extends StatefulWidget {
  const StickersSheet({super.key});

  @override
  State<StickersSheet> createState() => _StickersSheetState();
}

class _StickersSheetState extends State<StickersSheet> {
  final _repo = StickerRepository();
  final _scroll = ScrollController();
  Timer? _debounce;

  _Source _source = _Source.online;
  String _searchQuery = '';
  String _selectedTag = 'All';

  // online state
  final List<StickerItem> _items = [];
  final Set<String> _cached = {};
  final Map<String, double> _progress = {};
  int _offset = 0;
  bool _hasMore = true;
  bool _loading = false;
  String? _error;
  int _requestId = 0; // drops stale responses

  static const List<Map<String, String>> _emojis = [
    {'emoji': '🔥', 'tag': 'Popular'},
    {'emoji': '✨', 'tag': 'Popular'},
    {'emoji': '⚡', 'tag': 'Trending'},
    {'emoji': '🎉', 'tag': 'Popular'},
    {'emoji': '❤️', 'tag': 'Popular'},
    {'emoji': '🌟', 'tag': 'Trending'},
    {'emoji': '🎬', 'tag': 'Cinematic'},
    {'emoji': '👏', 'tag': 'Popular'},
    {'emoji': '🚀', 'tag': 'Trending'},
    {'emoji': '💯', 'tag': 'Trending'},
    {'emoji': '💥', 'tag': 'Glitch'},
    {'emoji': '⭐', 'tag': 'Popular'},
    {'emoji': '🎈', 'tag': 'Popular'},
    {'emoji': '🏆', 'tag': 'Trending'},
    {'emoji': '💎', 'tag': 'Trending'},
  ];

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_source == _Source.online &&
          _scroll.position.pixels > _scroll.position.maxScrollExtent - 300) {
        _load();
      }
    });
    _load(reset: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  String get _effectiveQuery {
    final q = _searchQuery.trim();
    if (q.isNotEmpty) return q;
    return _selectedTag == 'All' ? '' : _selectedTag;
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading && !reset) return;
    if (!reset && !_hasMore) return;

    final id = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _items.clear();
        _offset = 0;
        _hasMore = true;
      }
    });

    try {
      final page = await _repo.fetch(query: _effectiveQuery, offset: _offset);
      if (!mounted || id != _requestId) return;

      final cachedIds = <String>{};
      for (final s in page.items) {
        if (await _repo.isCached(s)) cachedIds.add(s.id);
      }
      if (!mounted || id != _requestId) return;

      setState(() {
        _items.addAll(page.items);
        _cached.addAll(cachedIds);
        _offset = page.nextOffset;
        _hasMore = page.hasMore;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || id != _requestId) return;
      setState(() {
        _loading = false;
        _error = 'Couldn\'t load stickers. Check your connection.';
      });
    }
  }

  void _onSearch(String q) {
    setState(() => _searchQuery = q);
    if (_source == _Source.online) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 450), () => _load(reset: true));
    }
  }

  void _onTag(String t) {
    setState(() => _selectedTag = t);
    if (_source == _Source.online) _load(reset: true);
  }

  Future<void> _onStickerTap(StickerItem s) async {
    if (_progress.containsKey(s.id)) return; // already downloading
    final editor = context.read<EditorController>();
    final messenger = ScaffoldMessenger.of(context);

    try {
      if (!_cached.contains(s.id)) {
        setState(() => _progress[s.id] = 0.0);
        await _repo.download(s, onProgress: (p) {
          if (mounted) setState(() => _progress[s.id] = p);
        });
        if (mounted) setState(() => _cached.add(s.id));
      }
      final file = await _repo.download(s); // returns cached file instantly
      editor.addStickerOverlay(file.path); // <-- see note below
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Download failed. Tap to retry.')),
      );
    } finally {
      if (mounted) setState(() => _progress.remove(s.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SourceTabs(
          source: _source,
          onChanged: (s) {
            setState(() => _source = s);
            if (s == _Source.online && _items.isEmpty) _load(reset: true);
          },
        ),
        ToolSearchHeader(
          onSearchChanged: _onSearch,
          onTagSelected: _onTag,
          selectedTag: _selectedTag,
          placeholder: _source == _Source.online
              ? 'Search stickers online...'
              : 'Search emojis...',
        ),
        Expanded(
          child: _source == _Source.online ? _buildOnline() : _buildEmoji(),
        ),
      ],
    );
  }

  // ---------------- Online ----------------
  Widget _buildOnline() {
    if (_error != null && _items.isEmpty) {
      return _StateMessage(
        icon: Icons.wifi_off_rounded,
        text: _error!,
        action: 'Retry',
        onAction: () => _load(reset: true),
      );
    }
    if (!_loading && _items.isEmpty) {
      return const _StateMessage(
        icon: Icons.search_off_rounded,
        text: 'No stickers found',
      );
    }

    final showSkeleton = _loading && _items.isEmpty;
    final count = showSkeleton ? 15 : _items.length + (_hasMore ? 1 : 0);

    return GridView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: count,
      itemBuilder: (context, i) {
        if (showSkeleton || i >= _items.length) return const _SkeletonTile();
        final s = _items[i];
        return _StickerTile(
          sticker: s,
          cached: _cached.contains(s.id),
          progress: _progress[s.id],
          onTap: () => _onStickerTap(s),
        );
      },
    );
  }

  // ---------------- Emoji ----------------
  Widget _buildEmoji() {
    final filtered = _emojis.where((s) {
      if (_selectedTag != 'All' && s['tag'] != _selectedTag) return false;
      if (_searchQuery.isNotEmpty && !s['emoji']!.contains(_searchQuery)) return false;
      return true;
    }).toList();

    final editor = context.read<EditorController>();
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: filtered.length,
      itemBuilder: (context, i) {
        final emoji = filtered[i]['emoji']!;
        return _Pressable(
          onTap: () => editor.addTextOverlay(emoji, fontFamily: 'Ubuntu'),
          child: Container(
            decoration: BoxDecoration(
              color: EditorTokens.elevated,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(emoji, style: const TextStyle(fontSize: 30)),
          ),
        );
      },
    );
  }
}

// ======================= Widgets =======================

class _SourceTabs extends StatelessWidget {
  const _SourceTabs({required this.source, required this.onChanged});
  final _Source source;
  final ValueChanged<_Source> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget tab(String label, _Source s) {
      final selected = source == s;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(s),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 180),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? Colors.white : Colors.white54,
                ),
                child: Text(label),
              ),
              const SizedBox(height: 6),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 2.5,
                width: selected ? 22 : 0,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Row(children: [
        tab('Stickers', _Source.online),
        tab('Emoji', _Source.emoji),
      ]),
    );
  }
}

class _StickerTile extends StatelessWidget {
  const _StickerTile({
    required this.sticker,
    required this.cached,
    required this.progress,
    required this.onTap,
  });

  final StickerItem sticker;
  final bool cached;
  final double? progress; // null = idle
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final downloading = progress != null;
    return _Pressable(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: EditorTokens.elevated,
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: CachedNetworkImage(
                imageUrl: sticker.previewUrl,
                fit: BoxFit.contain,
                fadeInDuration: const Duration(milliseconds: 150),
                placeholder: (_, __) => const _SkeletonTile(),
                errorWidget: (_, __, ___) =>
                    const Icon(Icons.broken_image_outlined, color: Colors.white24),
              ),
            ),
            if (!cached && !downloading)
              Positioned(
                right: 4,
                bottom: 4,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_downward_rounded,
                      size: 12, color: Colors.white),
                ),
              ),
            if (downloading)
              Container(
                color: Colors.black45,
                alignment: Alignment.center,
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    value: (progress ?? 0) > 0 ? progress : null,
                    color: Colors.white,
                    backgroundColor: Colors.white24,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Subtle pulsing placeholder (CapCut-like skeleton).
class _SkeletonTile extends StatefulWidget {
  const _SkeletonTile();
  @override
  State<_SkeletonTile> createState() => _SkeletonTileState();
}

class _SkeletonTileState extends State<_SkeletonTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Container(
        decoration: BoxDecoration(
          color: Color.lerp(EditorTokens.elevated, Colors.white10, _c.value),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
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
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.92 : 1,
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
  final IconData icon;
  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: Colors.white30),
          const SizedBox(height: 10),
          Text(text, style: const TextStyle(color: Colors.white54, fontSize: 13)),
          if (action != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onAction, child: Text(action!)),
          ],
        ],
      ),
    );
  }
}