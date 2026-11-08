import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_video_editor/core/models/project_model.dart' hide ExportSettings;
import 'package:flutter_video_editor/features/editor/widgets/tool_sheets/editor_tool_sheets.dart'
    show CanvasRatio, canvasRatioNotifier;
import 'package:flutter_video_editor/features/effects/services/custom_effect_import_service.dart';
import 'package:flutter_video_editor/features/export/models/export_settings.dart';
import 'package:flutter_video_editor/features/export/models/timeline_dto.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Export Aspect Ratio and Dimensions Tests', () {
    test('ExportSettings.toJson adjusts dimensions to portrait 9:16 aspect ratio', () {
      const settings = ExportSettings(
        width: 1920,
        height: 1080,
        aspectRatioValue: 9 / 16,
      );

      final json = settings.toJson();
      expect(json['aspectRatioValue'], closeTo(9 / 16, 0.001));
      expect(json['height'], equals(1080));
      expect(json['width'], equals(608));
    });

    test('ExportSettings.toJson adjusts dimensions to 1:1 aspect ratio', () {
      const settings = ExportSettings(
        width: 1920,
        height: 1080,
        aspectRatioValue: 1.0,
      );

      final json = settings.toJson();
      expect(json['aspectRatioValue'], equals(1.0));
      expect(json['width'], equals(1920));
      expect(json['height'], equals(1920));
    });

    test('TimelineDto.fromProject adapts settings to active canvas ratio', () {
      canvasRatioNotifier.value = CanvasRatio.r9x16;
      final project = Project(
        id: 'ratio_proj',
        name: 'Ratio Test',
        aspectRatio: AspectRatioPreset.original,
      );

      const settings = ExportSettings(
        width: 1920,
        height: 1080,
      );

      final dto = TimelineDto.fromProject(project, settings);
      final json = dto.toJson();
      final settingsJson = json['settings'] as Map<String, dynamic>;

      expect(settingsJson['aspectRatioValue'], closeTo(9 / 16, 0.001));
      expect(settingsJson['width'], equals(608));
      expect(settingsJson['height'], equals(1080));

      // Reset
      canvasRatioNotifier.value = CanvasRatio.r16x9;
    });

    test('ClipDto serializes and deserializes blendProperties', () {
      final clip = TimelineClip(
        id: 'clip_blend',
        label: 'Blended Clip',
        start: Duration.zero,
        end: const Duration(seconds: 4),
        clipType: ClipType.image,
        blendProperties: const BlendProperties(type: BlendType.screen, opacity: 0.8),
      );

      final dto = ClipDto.fromTimelineClip(clip);
      final json = dto.toJson();
      expect(json['blendProperties'], isNotNull);
      expect(json['blendProperties']['type'], equals('screen'));

      final restored = ClipDto.fromJson(json);
      expect(restored.blendProperties['type'], equals('screen'));
    });
  });

  group('Custom Effect Import Format Enhancements', () {
    test('Imports effect from JSON manifest with code field', () async {
      final manifestJson = jsonEncode({
        'id': 'code_shader',
        'name': 'Code Shader',
        'code': 'void main() { gl_FragColor = vec4(0.5); }',
        'category': 'glow',
      });

      final platformFile = PlatformFile(
        name: 'code_shader.json',
        size: manifestJson.length,
        bytes: Uint8List.fromList(utf8.encode(manifestJson)),
      );

      final effect = await CustomEffectImportService.instance.importFromFile(platformFile);
      expect(effect.id, equals('code_shader'));
      expect(effect.shaderSource, contains('gl_FragColor = vec4(0.5);'));
    });

    test('Imports effect from JSON manifest with assets.shader field', () async {
      final manifestJson = jsonEncode({
        'id': 'asset_shader',
        'name': 'Asset Shader',
        'assets': {
          'shader': 'void main() { gl_FragColor = vec4(1.0, 0.0, 0.0, 1.0); }'
        },
        'category': 'cinematic',
      });

      final platformFile = PlatformFile(
        name: 'asset_shader.json',
        size: manifestJson.length,
        bytes: Uint8List.fromList(utf8.encode(manifestJson)),
      );

      final effect = await CustomEffectImportService.instance.importFromFile(platformFile);
      expect(effect.id, equals('asset_shader'));
      expect(effect.shaderSource, contains('vec4(1.0, 0.0, 0.0, 1.0)'));
    });
  });
}
