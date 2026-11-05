import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_video_editor/features/editor/models/sticker_item.dart';

class StickerRepository {
  StickerRepository({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Run with: --dart-define=GIPHY_API_KEY=xxxx
  static const _apiKey = String.fromEnvironment('GIPHY_API_KEY');
  static const _base = 'https://api.giphy.com/v1/stickers';

  Future<StickerPage> fetch({String? query, int offset = 0, int limit = 30}) async {
    final isSearch = query != null && query.trim().isNotEmpty;
    final uri = Uri.parse(isSearch ? '$_base/search' : '$_base/trending')
        .replace(queryParameters: {
      'api_key': _apiKey,
      'limit': '$limit',
      'offset': '$offset',
      'rating': 'g',
      if (isSearch) 'q': query.trim(),
    });

    final res = await _client.get(uri).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw HttpException('Sticker library error (${res.statusCode})');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final items = (json['data'] as List)
        .map((e) => StickerItem.fromGiphy(e as Map<String, dynamic>))
        .toList();
    final pg = json['pagination'] as Map<String, dynamic>;
    final total = (pg['total_count'] as int?) ?? 0;
    final next = offset + items.length;
    return StickerPage(items, next, items.isNotEmpty && next < total);
  }

  Future<Directory> _dir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/stickers');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> _fileFor(StickerItem s) async {
    final ext = Uri.parse(s.fullUrl).path.split('.').last;
    return File('${(await _dir()).path}/${s.id}.$ext');
  }

  Future<bool> isCached(StickerItem s) async => (await _fileFor(s)).exists();

  /// Downloads (or returns the cached file) and reports progress 0..1.
  Future<File> download(StickerItem s, {void Function(double)? onProgress}) async {
    final file = await _fileFor(s);
    if (await file.exists()) return file;

    final req = http.Request('GET', Uri.parse(s.fullUrl));
    final res = await _client.send(req).timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      throw HttpException('Download failed (${res.statusCode})');
    }

    final tmp = File('${file.path}.part');
    final sink = tmp.openWrite();
    final total = res.contentLength ?? 0;
    var received = 0;
    try {
      await for (final chunk in res.stream) {
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