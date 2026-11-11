import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_video_editor/core/models/project_model.dart';
import 'package:flutter_video_editor/core/services/project_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Project Data Model and Serialization Unit Tests', () {
    test('Project serialization to and from JSON is lossless', () {
      final clip = TimelineClip(
        id: 'c1',
        label: 'Video Clip 1',
        start: Duration.zero,
        end: const Duration(seconds: 5),
        clipType: ClipType.video,
        volume: 0.8,
        speed: 1.2,
        textStyle: const TextStyleProperties(
          fontSize: 32,
          textColor: Colors.cyan,
          textAlign: TextAlign.left,
        ),
        colorGrading: const ColorGradingSettings(
          brightness: 0.1,
          contrast: 1.1,
          saturation: 1.2,
        ),
      );

      final project = Project(
        id: 'p1',
        name: 'Test Project',
        aspectRatio: AspectRatioPreset.sixteenNine,
        resolution: ExportResolution.res1080p,
        clips: [clip],
        captions: [
          CaptionCue(
            id: 'cap1',
            start: Duration.zero,
            end: const Duration(seconds: 5),
            text: 'Hello World',
          ),
        ],
      );

      final json = project.toJson();
      final restored = Project.fromJson(json);

      expect(restored.id, equals(project.id));
      expect(restored.name, equals(project.name));
      expect(restored.aspectRatio, equals(project.aspectRatio));
      expect(restored.resolution, equals(project.resolution));
      expect(restored.clips.length, equals(1));

      final restoredClip = restored.clips.first;
      expect(restoredClip.id, equals(clip.id));
      expect(restoredClip.label, equals(clip.label));
      expect(restoredClip.volume, equals(0.8));
      expect(restoredClip.speed, equals(1.2));
      expect(restoredClip.textStyle.fontSize, equals(32));
      expect(restoredClip.colorGrading.brightness, equals(0.1));
      expect(restored.captions.length, equals(1));
      expect(restored.captions.first.text, equals('Hello World'));
    });

    test('.mgr bundle creates zip archive containing project.json and media assets', () async {
      // Create temporary mock asset files
      final tempDir = Directory.systemTemp.createTempSync('mgr_test_assets_');
      final videoFile = File('${tempDir.path}/sample_video.mp4');
      await videoFile.writeAsBytes(Uint8List.fromList([1, 2, 3, 4, 5]));

      final stickerFile = File('${tempDir.path}/sample_sticker.png');
      await stickerFile.writeAsBytes(Uint8List.fromList([10, 20, 30]));

      final project = Project(
        id: 'proj_bundle_1',
        name: 'Bundle Test Project',
        clips: [
          TimelineClip(
            id: 'c_vid',
            label: 'Video',
            clipType: ClipType.video,
            sourcePath: videoFile.path,
            start: Duration.zero,
            end: const Duration(seconds: 10),
          ),
          TimelineClip(
            id: 'c_stk',
            label: 'Sticker',
            clipType: ClipType.sticker,
            stickerAssetPath: stickerFile.path,
            start: Duration.zero,
            end: const Duration(seconds: 5),
          ),
        ],
      );

      final bundleBytes = await ProjectStorageService.instance.createMgrBundle(project);
      expect(bundleBytes.isNotEmpty, isTrue);

      // Verify zip archive contents
      final archive = ZipDecoder().decodeBytes(bundleBytes);
      final fileNames = archive.files.map((f) => f.name).toList();

      expect(fileNames, contains('project.json'));
      expect(fileNames.any((name) => name.startsWith('assets/clip_c_vid')), isTrue);
      expect(fileNames.any((name) => name.startsWith('assets/sticker_c_stk')), isTrue);

      // Verify extracting bundle unpacks assets and remaps paths
      final extractTargetDir = Directory('${tempDir.path}/extracted');
      final extractedProject = await ProjectStorageService.instance.extractMgrBundle(
        bundleBytes,
        targetDir: extractTargetDir.path,
      );

      expect(extractedProject.id, equals('proj_bundle_1'));
      expect(extractedProject.clips.length, equals(2));

      final extractedVid = extractedProject.clips.firstWhere((c) => c.id == 'c_vid');
      expect(extractedVid.sourcePath, isNotNull);
      expect(File(extractedVid.sourcePath!).existsSync(), isTrue);
      expect(await File(extractedVid.sourcePath!).readAsBytes(), equals([1, 2, 3, 4, 5]));

      final extractedStk = extractedProject.clips.firstWhere((c) => c.id == 'c_stk');
      expect(extractedStk.stickerAssetPath, isNotNull);
      expect(File(extractedStk.stickerAssetPath!).existsSync(), isTrue);
      expect(await File(extractedStk.stickerAssetPath!).readAsBytes(), equals([10, 20, 30]));

      tempDir.deleteSync(recursive: true);
    });

    test('.mgr fallback extracts plain JSON string content seamlessly', () async {
      final project = Project(
        id: 'proj_json_legacy',
        name: 'Legacy Project',
      );

      final jsonStr = ProjectStorageService.instance.serializeProject(project);
      final bytes = Uint8List.fromList(jsonStr.codeUnits);

      final extracted = await ProjectStorageService.instance.extractMgrBundle(bytes);
      expect(extracted.id, equals('proj_json_legacy'));
      expect(extracted.name, equals('Legacy Project'));
    });
  });
}
