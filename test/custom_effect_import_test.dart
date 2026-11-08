import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_video_editor/core/models/shader_effect_model.dart';
import 'package:flutter_video_editor/features/effects/services/custom_effect_import_service.dart';
import 'package:flutter_video_editor/features/effects/services/shader_database_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('effect_test_');
    ShaderDatabaseService.instance.resetMemoryRegistry();
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('CustomEffectImportService Tests', () {
    test('Imports effect successfully from directory structure', () async {
      final manifestJson = jsonEncode({
        'id': 'test_glow_pkg',
        'name': 'Test Glow Package',
        'description': 'A beautiful glow shader',
        'category': 'glow',
        'author': 'Tester',
        'parameters': [
          {
            'id': 'glow_radius',
            'name': 'glow_radius',
            'label': 'Glow Radius',
            'type': 'float',
            'value': 2.5,
            'defaultValue': 2.5,
            'min': 0.0,
            'max': 10.0,
          }
        ]
      });

      const glslSource = '''
#version 300 es
precision mediump float;
out vec4 fragColor;
void main() {
  fragColor = vec4(1.0, 0.5, 0.2, 1.0);
}
''';

      final manifestFile = File('${tempDir.path}/manifest.json');
      await manifestFile.writeAsString(manifestJson);

      final shaderFile = File('${tempDir.path}/shader.glsl');
      await shaderFile.writeAsString(glslSource);

      final effect = await CustomEffectImportService.instance.importFromDirectory(tempDir.path);

      expect(effect.id, equals('test_glow_pkg'));
      expect(effect.name, equals('Test Glow Package'));
      expect(effect.category, equals(ShaderEffectCategory.glow));
      expect(effect.parameters.length, equals(1));
      expect(effect.parameters.first.id, equals('glow_radius'));
      expect(effect.shaderSource, contains('fragColor = vec4(1.0, 0.5, 0.2, 1.0);'));
      expect(effect.isDownloaded, isTrue);

      final retrieved = ShaderDatabaseService.instance.getEffectById('test_glow_pkg');
      expect(retrieved, isNotNull);
      expect(retrieved!.name, equals('Test Glow Package'));
    });

    test('Throws FormatException when manifest.json is missing in directory', () async {
      final shaderFile = File('${tempDir.path}/shader.glsl');
      await shaderFile.writeAsString('void main() {}');

      expect(
        () => CustomEffectImportService.instance.importFromDirectory(tempDir.path),
        throwsA(isA<FormatException>()),
      );
    });

    test('Throws FormatException when shader.glsl is missing in directory', () async {
      final manifestFile = File('${tempDir.path}/manifest.json');
      await manifestFile.writeAsString('{"name": "No Shader"}');

      expect(
        () => CustomEffectImportService.instance.importFromDirectory(tempDir.path),
        throwsA(isA<FormatException>()),
      );
    });

    test('Imports effect from single .glsl or .frag file with bytes', () async {
      const shaderCode = '''
#version 300 es
precision mediump float;
out vec4 fragColor;
void main() {
  fragColor = vec4(0.0, 1.0, 0.0, 1.0);
}
''';

      final platformFile = PlatformFile(
        name: 'neon_green_matrix.glsl',
        size: shaderCode.length,
        bytes: Uint8List.fromList(utf8.encode(shaderCode)),
      );

      final effect = await CustomEffectImportService.instance.importFromFile(platformFile);

      expect(effect.name, equals('Neon green matrix'));
      expect(effect.shaderSource, contains('fragColor = vec4(0.0, 1.0, 0.0, 1.0);'));
      expect(effect.parameters.isNotEmpty, isTrue);
      expect(effect.parameters.first.id, equals('intensity'));
    });

    test('Imports effect from single manifest .json file with embedded shader', () async {
      final manifestJson = jsonEncode({
        'id': 'embedded_blur',
        'name': 'Embedded Blur',
        'shader': 'void main() { gl_FragColor = vec4(1.0); }',
        'category': 'blur',
      });

      final platformFile = PlatformFile(
        name: 'embedded_blur.json',
        size: manifestJson.length,
        bytes: Uint8List.fromList(utf8.encode(manifestJson)),
      );

      final effect = await CustomEffectImportService.instance.importFromFile(platformFile);

      expect(effect.id, equals('embedded_blur'));
      expect(effect.name, equals('Embedded Blur'));
      expect(effect.category, equals(ShaderEffectCategory.blur));
      expect(effect.shaderSource, contains('gl_FragColor = vec4(1.0);'));
    });

    test('Imports effect from file on disk via file.path', () async {
      final glslPath = '${tempDir.path}/cyber_pulse.frag';
      final file = File(glslPath);
      await file.writeAsString('void main() { gl_FragColor = vec4(0.2, 0.4, 0.8, 1.0); }');

      final platformFile = PlatformFile(
        name: 'cyber_pulse.frag',
        size: 100,
        path: glslPath,
      );

      final effect = await CustomEffectImportService.instance.importFromFile(platformFile);

      expect(effect.name, equals('Cyber pulse'));
      expect(effect.shaderSource, contains('0.2, 0.4, 0.8'));
    });
  });
}
