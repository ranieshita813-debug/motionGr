// lib/features/editor/widgets/music_sheet.dart
//
// Online music library, CapCut style: search, mood chips, tap to preview,
// download once, then add to the timeline as an audio clip.
//
// Source: Jamendo (Creative Commons music, official API).
// Get a free client ID at https://devportal.jamendo.com, then run with:
//   flutter run --dart-define=JAMENDO_CLIENT_ID=your_id
//
// Dependencies (pubspec.yaml):
//   http: ^1.2.2
//   just_audio: ^0.9.40
//   path_provider: ^2.1.4
//   path: ^1.9.0
//
// Licensing: every track has its own Creative Commons licence. All require
// attribution, and many are NonCommercial. The free API tier is for
// non-commercial apps; commercial use needs Jamendo Licensing.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:provider/provider.dart';
import 'package:flutter_video_editor/features/editor/controllers/editor_controller.dart';
import 'package:flutter_video_editor/features/editor/theme/editor_tokens.dart';

const Color _card = Color(0xFF232327);
const Color _line = Color(0xFF2C2C31);
const Color _accent = Color(0xFF2DE2E6);

// ----------------------------------------------------------------------------
// Model
// ----------------------------------------------------------------------------

@immutable
class MusicTrack {
  const MusicTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.duration,
    required this.coverUrl,
    required this.streamUrl,
    required this.downloadUrl,
    required this.licenseUrl,
  });

  final String id;
  final String title;
  final String artist;
  final Duration duration;
  final String coverUrl;
  final String streamUrl; // preview
  final String downloadUrl; // full file
  final String licenseUrl;

  bool get nonCommercial => licenseUrl.contains('-nc');

  /// Text to show in your video description or credits.
  String get credit => '"$title" by $artist (Jamendo) $licenseUrl';

  static MusicTrack? fromJamendo(Map<String, dynamic> j) {
    final bool allowed = j['audiodownload_allowed'] == true;
    final String dl = (j['audiodownload'] as String?) ?? '';
    final String stream = (j['audio'] as String?) ?? '';
    if (!allowed || dl.isEmpty || stream.isEmpty) return null;
    return MusicTrack(
      id: j['id'].toString(),
      title: (j['name'] as String?) ?? 'Untitled',
      artist: (j['artist_name'] as String?) ?? 'Unknown',
      duration: Duration(seconds: int.tryParse('${j['duration']}') ?? 0),
      coverUrl: (j['image'] as String?) ?? '',
      streamUrl: stream,
      downloadUrl: dl,
      licenseUrl: (j['license_ccurl'] as String?) ?? '',
    );
  }
}

class MusicPage {
  const MusicPage(this.items, this.nextOffset, this.hasMore);
  final List<MusicTrack> items;
  final int nextOffset;
  final bool hasMore;
}

// ----------------------------------------------------------------------------
// Repository
// ----------------------------------------------------------------------------

class MusicRepository {
  MusicRepository({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  static const String _clientId = String.fromEnvironment('JAMENDO_CLIENT_ID');
  static const int pageSize = 30;

  Future<MusicPage> fetch({String? query, String? tag, int offset = 0}) async {
    final Map<String, String> params = <String, String>{
      'client_id': _clientId,
      'format': 'json',
      'limit': '$pageSize',
      'offset': '$offset',
      'imagesize': '200',
      'audiodlformat': 'mp32',
      'order': 'popularity_week',
    };
    if (query != null && query.trim().isNotEmpty) params['search'] = query.trim();
    if (tag != null && tag.isNotEmpty) params['tags'] = tag;

    final Uri uri = Uri.https('api.jamendo.com', '/v3.0/tracks/', params);
    final http.Response res =
        await _client.get(uri).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw HttpException('Music library error (${res.statusCode})');
    }

    final Object? json = jsonDecode(res.body);
    if (json is! Map || json['results'] is! List) {
      throw const FormatException('Unexpected music library response');
    }
    final List raw = json['results'] as List;
    final List<MusicTrack> items = <MusicTrack>[
      for (final Object? e in raw)
        if (e is Map<String, dynamic>)
          if (MusicTrack.fromJamendo(e) case final MusicTrack t) t,
    ];
    // Page by what the server returned, not by what survived filtering.
    return MusicPage(items, offset + raw.length, raw.length >= pageSize);
  }

  Future<Directory> _dir() async {
    final Directory base = await getApplicationDocumentsDirectory();
    final Directory d = Directory(p.join(base.path, 'music'));
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  Future<File> _fileFor(MusicTrack t) async =>
      File(p.join((await _dir()).path, '${t.id}.mp3'));

  Future<bool> isCached(MusicTrack t) async => (await _fileFor(t)).exists();

  /// Downloads (or returns the cached file) and reports progress 0..1.
  Future<File> download(MusicTrack t, {void Function(double)? onProgress}) async {
    final File file = await _fileFor(t);
    if (await file.exists()) return file;

    final http.StreamedResponse res = await _client
        .send(http.Request('GET', Uri.parse(t.downloadUrl)))
        .timeout(const Duration(seconds: 25));
    if (res.statusCode != 200) {
      throw HttpException('Download failed (${res.statusCode})');
    }

    final File tmp = File('${file.path}.part');
    final IOSink sink = tmp.openWrite();
    final int total = res.contentLength ?? 0;
    int received = 0;
    try {
      await for (final List<int> chunk in res.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) onProgress?.call(received / total);
      }
      await sink.flush();
      await sink.close();
      return await tmp.rename(file.path); // atomic: no half-downloaded files
    } catch (e) {
      await sink.close();
      if (await tmp.exists()) await tmp.delete();
      rethrow;
    }
  }
}

// ----------------------------------------------------------------------------
// Sheet
// ----------------------------------------------------------------------------

class MusicSheet extends StatefulWidget {
  const MusicSheet({super.key});

  @override
  State<MusicSheet> createState() => _MusicSheetState();
}

class _MusicSheetState extends State<MusicSheet> {
  static const List<(String, String)> _moods = <(String, String)>[
    ('All', ''),
    ('Chill', 'chill'),
    ('Happy', 'happy'),
    ('Cinematic', 'cinematic'),
    ('Energetic', 'energetic'),
    ('Lofi', 'lofi'),
    ('Piano', 'piano'),
    ('Hip hop', 'hiphop'),
  ];

  final MusicRepository _repo = MusicRepository();
  final AudioPlayer _player = AudioPlayer();
  final ScrollController _scroll = ScrollController();
  Timer? _debounce;

  String _query = '';
  String _tag = '';

  final List<MusicTrack> _items = <MusicTrack>[];
  final Set<String> _cached = <String>{};
  final Map<String, double> _progress = <String, double>{};
  int _offset = 0;
  bool _hasMore = true;
  bool _loading = false;
  String? _error;
  int _requestId = 0; // drops stale responses

  String? _playingId;
  bool _previewBusy = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.hasClients &&
          _scroll.position.pixels > _scroll.position.maxScrollExtent - 300) {
        _load();
      }
    });
    _player.playerStateStream.listen((s) {
      if (s.processingState == ProcessingState.completed && mounted) {
        setState(() => _playingId = null);
      }
    });
    _load(reset: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll.dispose();
    _player.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  // ---- Data -----------------------------------------------------------------

  Future<void> _load({bool reset = false}) async {
    if (_loading && !reset) return;
    if (!reset && !_hasMore) return;

    final int id = ++_requestId;
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
      final MusicPage page =
          await _repo.fetch(query: _query, tag: _tag, offset: _offset);
      final Set<String> cachedIds = <String>{};
      for (final MusicTrack t in page.items) {
        if (await _repo.isCached(t)) cachedIds.add(t.id);
      }
      if (!mounted || id != _requestId) return;
      setState(() {
        _items.addAll(page.items);
        _cached.addAll(cachedIds);
        _offset = page.nextOffset;
        _hasMore = page.hasMore;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || id != _requestId) return;
      setState(() {
        _loading = false;
        _error = "Couldn't load music. Check your connection";
      });
    }
  }

  void _onSearch(String q) {
    _query = q;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () => _load(reset: true));
  }

  void _onMood(String tag) {
    setState(() => _tag = tag);
    _load(reset: true);
  }

  // ---- Preview --------------------------------------------------------------

  Future<void> _togglePreview(MusicTrack t) async {
    if (_previewBusy) return;
    _previewBusy = true;
    try {
      if (_playingId == t.id) {
        await _player.pause();
        if (mounted) setState(() => _playingId = null);
        return;
      }
      setState(() => _playingId = t.id);
      final File local = await _repo._fileFor(t);
      if (await local.exists()) {
        await _player.setFilePath(local.path);
      } else {
        await _player.setUrl(t.streamUrl);
      }
      unawaited(_player.play());
    } catch (_) {
      if (mounted) setState(() => _playingId = null);
      _toast("Couldn't play that track");
    } finally {
      _previewBusy = false;
    }
  }

  // ---- Use ------------------------------------------------------------------

  Future<void> _use(MusicTrack t) async {
    if (_progress.containsKey(t.id)) return; // already downloading
    final EditorController editor = context.read<EditorController>();

    try {
      setState(() => _progress[t.id] = 0.0);
      final File file = await _repo.download(t, onProgress: (double v) {
        if (mounted) setState(() => _progress[t.id] = v);
      });
      if (!mounted) return;
      setState(() => _cached.add(t.id));

      // Adjust to your EditorController API.
      editor.addAudioClip(file.path, title: t.title, duration: t.duration);
      HapticFeedback.mediumImpact();
      _toast('Added "${t.title}"');
    } catch (_) {
      _toast("Download failed. Try again");
    } finally {
      if (mounted) setState(() => _progress.remove(t.id));
    }
  }

  // ---- Build ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _searchField(),
        _moodChips(),
        Expanded(child: _list()),
      ],
    );
  }

  Widget _searchField() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      height: 38,
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const SizedBox(width: 10),
          const Icon(PhosphorIconsRegular.magnifyingGlass,
              size: 16, color: EditorTokens.muted),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              onChanged: _onSearch,
              style: const TextStyle(
                  color: EditorTokens.text, fontSize: 13, fontFamily: 'Ubuntu'),
              cursorColor: _accent,
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Search music...',
                hintStyle: TextStyle(
                    color: EditorTokens.muted, fontSize: 13, fontFamily: 'Ubuntu'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _moodChips() {
    return SizedBox(
      height: 30,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _moods.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final (String label, String tag) = _moods[i];
          final bool on = tag == _tag;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              HapticFeedback.selectionClick();
              _onMood(tag);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: on ? _accent.withAlpha(30) : _card,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: on ? _accent : Colors.transparent),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: on ? _accent : EditorTokens.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Ubuntu',
                ),
              ),
            ),
          );
        },
      ),
    ).withTopPadding(12);
  }

  Widget _message(IconData icon, String text, {String? action, VoidCallback? onTap}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 38, color: EditorTokens.muted),
          const SizedBox(height: 10),
          Text(text,
              style: const TextStyle(
                  color: EditorTokens.muted, fontSize: 13, fontFamily: 'Ubuntu')),
          if (action != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                foregroundColor: _accent,
                side: const BorderSide(color: _accent),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              ),
              child: Text(action),
            ),
          ],
        ],
      ),
    );
  }

  Widget _list() {
    if (_error != null && _items.isEmpty) {
      return _message(PhosphorIconsRegular.wifiSlash, _error!,
          action: 'Retry', onTap: () => _load(reset: true));
    }
    if (!_loading && _items.isEmpty) {
      return _message(PhosphorIconsRegular.musicNotes, 'No music found');
    }

    final bool skeleton = _loading && _items.isEmpty;
    final int count = skeleton ? 8 : _items.length + (_hasMore ? 1 : 0);

    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: count,
      itemBuilder: (context, i) {
        if (skeleton || i >= _items.length) return const _SkeletonRow();
        final MusicTrack t = _items[i];
        return _TrackRow(
          track: t,
          playing: _playingId == t.id,
          cached: _cached.contains(t.id),
          progress: _progress[t.id],
          onPreview: () => _togglePreview(t),
          onUse: () => _use(t),
        );
      },
    );
  }
}

// ----------------------------------------------------------------------------
// Widgets
// ----------------------------------------------------------------------------

class _TrackRow extends StatelessWidget {
  const _TrackRow({
    required this.track,
    required this.playing,
    required this.cached,
    required this.progress,
    required this.onPreview,
    required this.onUse,
  });

  final MusicTrack track;
  final bool playing;
  final bool cached;
  final double? progress; // null = idle
  final VoidCallback onPreview;
  final VoidCallback onUse;

  String get _time {
    final int s = track.duration.inSeconds;
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final bool downloading = progress != null;
    return Container(
      height: 64,
      margin: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          // Cover with play / pause overlay.
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onPreview();
            },
            child: Stack(
              alignment: Alignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 48,
                    height: 48,
                    color: _card,
                    child: track.coverUrl.isEmpty
                        ? const Icon(PhosphorIconsRegular.musicNote,
                            color: EditorTokens.muted)
                        : Image.network(
                            track.coverUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                                PhosphorIconsRegular.musicNote,
                                color: EditorTokens.muted),
                          ),
                  ),
                ),
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(playing ? 130 : 70),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    playing ? PhosphorIconsFill.pause : PhosphorIconsFill.play,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: playing ? _accent : EditorTokens.text,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Ubuntu',
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '${track.artist}  ·  $_time',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: EditorTokens.muted,
                            fontSize: 11,
                            fontFamily: 'Ubuntu'),
                      ),
                    ),
                    if (track.nonCommercial) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          border: Border.all(color: _line),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('NC',
                            style: TextStyle(
                                color: EditorTokens.muted,
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Ubuntu')),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              HapticFeedback.selectionClick();
              onUse();
            },
            child: SizedBox(
              width: 40,
              height: 40,
              child: Center(
                child: downloading
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          value: (progress ?? 0) > 0 ? progress : null,
                          color: _accent,
                          backgroundColor: Colors.white24,
                        ),
                      )
                    : Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: cached ? _accent : Colors.transparent,
                          border: Border.all(color: cached ? _accent : _line, width: 1.5),
                        ),
                        child: Icon(
                          cached
                              ? PhosphorIconsBold.plus
                              : PhosphorIconsRegular.arrowDown,
                          size: 16,
                          color: cached ? Colors.black : EditorTokens.text,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonRow extends StatefulWidget {
  const _SkeletonRow();
  @override
  State<_SkeletonRow> createState() => _SkeletonRowState();
}

class _SkeletonRowState extends State<_SkeletonRow>
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
      builder: (_, __) {
        final Color c = Color.lerp(_card, Colors.white10, _c.value)!;
        return Container(
          height: 64,
          margin: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(8)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 140,
                      height: 11,
                      decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(4)),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 90,
                      height: 9,
                      decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(4)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

extension on Widget {
  Widget withTopPadding(double v) => Padding(padding: EdgeInsets.only(top: v), child: this);
}