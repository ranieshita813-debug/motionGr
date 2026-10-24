import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'package:flutter_video_editor/core/models/project_model.dart' hide ExportSettings;
import 'package:flutter_video_editor/features/export/models/export_settings.dart';
import 'package:flutter_video_editor/features/export/models/timeline_dto.dart';
import 'package:flutter_video_editor/features/export/services/export_service.dart';

enum ExportStatus {
  idle,
  preparing,
  exporting,
  done,
  failed,
  cancelled,
}

class ExportController extends ChangeNotifier {
  ExportController({ExportService? exportService})
      : _exportService = exportService ?? ExportService() {
    _subscription = _exportService.progressStream.listen(_onProgressEvent, onError: _onProgressError);
  }

  final ExportService _exportService;
  StreamSubscription<Map<String, dynamic>>? _subscription;

  ExportStatus _status = ExportStatus.idle;
  double _progress = 0.0;
  String _stage = '';
  String? _outputPath;
  String? _errorMessage;
  ExportSettings _exportSettings = const ExportSettings();

  ExportStatus get status => _status;
  bool get isExporting => _status == ExportStatus.preparing || _status == ExportStatus.exporting;
  double get progress => _progress;
  String get stage => _stage;
  String? get outputPath => _outputPath;
  String? get errorMessage => _errorMessage;
  ExportSettings get exportSettings => _exportSettings;

  void updateSettings(ExportSettings settings) {
    _exportSettings = settings;
    notifyListeners();
  }

  void _onProgressEvent(Map<String, dynamic> data) {
    if (_status == ExportStatus.cancelled || _status == ExportStatus.failed) return;

    final p = (data['progress'] as num?)?.toDouble() ?? 0.0;
    final s = (data['stage'] as String?) ?? '';

    _progress = p.clamp(0.0, 1.0);
    _stage = s;
    if (_status == ExportStatus.preparing && p > 0.0) {
      _status = ExportStatus.exporting;
    }
    notifyListeners();
  }

  void _onProgressError(dynamic error) {
    _status = ExportStatus.failed;
    _errorMessage = error.toString();
    notifyListeners();
  }

  Future<String?> startExport(Project project, [ExportSettings? settings]) async {
    if (settings != null) {
      _exportSettings = settings;
    }

    _status = ExportStatus.preparing;
    _progress = 0.0;
    _stage = 'Preparing timeline...';
    _outputPath = null;
    _errorMessage = null;
    notifyListeners();

    try {
      final dto = TimelineDto.fromProject(project, _exportSettings);
      _status = ExportStatus.exporting;
      notifyListeners();

      final resultPath = await _exportService.exportTimeline(dto.toJson());

      if (_status != ExportStatus.cancelled) {
        _status = ExportStatus.done;
        _progress = 1.0;
        _stage = 'Completed';
        _outputPath = resultPath;
        notifyListeners();
        return resultPath;
      }
    } catch (e) {
      if (_status != ExportStatus.cancelled) {
        _status = ExportStatus.failed;
        _errorMessage = e.toString();
        notifyListeners();
      }
    }
    return null;
  }

  Future<void> cancelExport() async {
    if (!isExporting) return;
    _status = ExportStatus.cancelled;
    _stage = 'Cancelled';
    notifyListeners();
    await _exportService.cancelExport();
  }

  Future<String?> exportSingleFrame(Project project, Duration playhead, ExportFormat format) async {
    _status = ExportStatus.preparing;
    _progress = 0.2;
    _stage = 'Capturing frame image...';
    _outputPath = null;
    _errorMessage = null;
    notifyListeners();

    try {
      _status = ExportStatus.exporting;
      _progress = 0.5;
      _stage = 'Rendering frame (${format.name.toUpperCase()})...';
      notifyListeners();

      TimelineClip? activeClip;
      for (final clip in project.clips) {
        if ((clip.clipType == ClipType.video || clip.clipType == ClipType.image) &&
            playhead >= clip.start &&
            playhead <= clip.end) {
          activeClip = clip;
          break;
        }
      }
      activeClip ??= project.clips.firstWhere(
        (c) => c.clipType == ClipType.video || c.clipType == ClipType.image,
        orElse: () => project.clips.isNotEmpty ? project.clips.first : throw Exception('No clips in project.'),
      );

      if (activeClip.sourcePath == null || activeClip.sourcePath!.isEmpty) {
        throw Exception('No media source found for current frame export.');
      }

      final relativeTimeMs = (playhead - activeClip.start + activeClip.trimIn)
          .inMilliseconds
          .clamp(0, activeClip.duration.inMilliseconds);

      final bytes = await _exportService.frameAt(
        activeClip.sourcePath!,
        relativeTimeMs,
        maxHeight: 1080,
        quality: 100,
      );

      if (bytes == null || bytes.isEmpty) {
        throw Exception('Failed to capture frame image bytes.');
      }

      final tempDir = await getTemporaryDirectory();
      final isPng = format == ExportFormat.png;
      final ext = isPng ? 'png' : 'jpg';
      final file = File('${tempDir.path}/frame_${DateTime.now().millisecondsSinceEpoch}.$ext');
      await file.writeAsBytes(bytes);

      _status = ExportStatus.done;
      _progress = 1.0;
      _stage = 'Completed';
      _outputPath = file.path;
      notifyListeners();
      return file.path;
    } catch (e) {
      if (_status != ExportStatus.cancelled) {
        _status = ExportStatus.failed;
        _errorMessage = e.toString();
        notifyListeners();
      }
      return null;
    }
  }

  Future<Map<String, dynamic>> probe(String path) {
    return _exportService.probe(path);
  }

  Future<List<String>> thumbnails(String path, int count, int height) {
    return _exportService.thumbnails(path, count, height);
  }

  Future<List<double>> waveform(String path, int buckets) {
    return _exportService.waveform(path, buckets);
  }

  void setOutputPath(String path) {
    _status = ExportStatus.done;
    _progress = 1.0;
    _stage = 'Completed';
    _outputPath = path;
    notifyListeners();
  }

  void resetStatus() {
    _status = ExportStatus.idle;
    _progress = 0.0;
    _stage = '';
    _outputPath = null;
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _exportService.dispose();
    super.dispose();
  }
}
