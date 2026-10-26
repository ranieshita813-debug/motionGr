import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_video_editor/core/logger/app_logger.dart';
import 'package:flutter_video_editor/core/models/shader_effect_model.dart';
import 'package:flutter_video_editor/features/effects/services/shader_database_service.dart';
import 'package:path/path.dart' as p;

/// Service responsible for importing and registering custom effect packages.
///
/// Custom Effect Package Directory Structure:
/// ```
/// custom_effect_package/
/// ├── manifest.json            # Package metadata (id, name, description, category, author, version)
/// ├── shader.glsl              # GLSL shader source code
/// ├── thumbnail.png            # (Optional) Preview thumbnail image
/// └── config.json              # (Optional) Parameter definitions
/// ```
class CustomEffectImportService {
  CustomEffectImportService._internal();
  static final CustomEffectImportService instance = CustomEffectImportService._internal();

  /// Prompts user to select a custom effect package folder or file using file picker
  /// and imports the custom effect into the system registry.
  Future<ShaderEffect?> pickAndImportPackage() async {
    try {
      final selectedDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select Custom Effect Package Folder',
      );

      if (selectedDirectory != null && selectedDirectory.isNotEmpty) {
        return await importFromDirectory(selectedDirectory);
      }
    } catch (e, stack) {
      AppLogger.error('Failed picking custom effect package',
          tag: 'CustomEffectImportService', error: e, stackTrace: stack);
      rethrow;
    }
    return null;
  }

  /// Imports a custom effect from a folder containing `manifest.json` and `shader.glsl`.
  Future<ShaderEffect> importFromDirectory(String directoryPath) async {
    final dir = Directory(directoryPath);
    if (!await dir.exists()) {
      throw FileSystemException('Effect package directory does not exist', directoryPath);
    }

    final manifestFile = File(p.join(directoryPath, 'manifest.json'));
    if (!await manifestFile.exists()) {
      throw const FormatException('Missing required manifest.json in custom effect package.');
    }

    final shaderFile = File(p.join(directoryPath, 'shader.glsl'));
    if (!await shaderFile.exists()) {
      throw const FormatException('Missing required shader.glsl in custom effect package.');
    }

    final manifestContent = await manifestFile.readAsString();
    final shaderSource = await shaderFile.readAsString();

    String? configContent;
    final configFile = File(p.join(directoryPath, 'config.json'));
    if (await configFile.exists()) {
      configContent = await configFile.readAsString();
    }

    String? thumbnailPath;
    final thumbFile = File(p.join(directoryPath, 'thumbnail.png'));
    if (await thumbFile.exists()) {
      thumbnailPath = thumbFile.path;
    }

    return await importFromData(
      manifestJsonStr: manifestContent,
      shaderGlslStr: shaderSource,
      configJsonStr: configContent,
      thumbnailSourcePath: thumbnailPath,
    );
  }

  /// Imports a custom effect from raw string contents / source files.
  Future<ShaderEffect> importFromData({
    required String manifestJsonStr,
    required String shaderGlslStr,
    String? configJsonStr,
    String? thumbnailSourcePath,
  }) async {
    if (manifestJsonStr.trim().isEmpty) {
      throw const FormatException('Manifest JSON content is empty.');
    }
    if (shaderGlslStr.trim().isEmpty) {
      throw const FormatException('Shader GLSL source is empty.');
    }

    final Map<String, dynamic> manifest = jsonDecode(manifestJsonStr) as Map<String, dynamic>;

    final effectId = (manifest['id'] as String?)?.trim() ??
        'custom_${DateTime.now().millisecondsSinceEpoch}';
    final name = (manifest['name'] as String?)?.trim() ?? 'Custom Effect';
    final description = (manifest['description'] as String?)?.trim() ?? 'User imported custom shader effect';
    final author = (manifest['author'] as String?)?.trim() ?? 'User';

    final categoryStr = manifest['category'] as String? ?? 'custom';
    final category = ShaderEffectCategory.values.firstWhere(
      (e) => e.name == categoryStr || e.displayName.toLowerCase() == categoryStr.toLowerCase(),
      orElse: () => ShaderEffectCategory.glow,
    );

    List<ShaderParameter> parameters = <ShaderParameter>[];

    if (configJsonStr != null && configJsonStr.trim().isNotEmpty) {
      final configMap = jsonDecode(configJsonStr);
      if (configMap is Map && configMap.containsKey('parameters')) {
        final paramList = configMap['parameters'] as List<dynamic>?;
        if (paramList != null) {
          parameters = paramList
              .map((e) => ShaderParameter.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
        }
      } else if (configMap is List) {
        parameters = configMap
            .map((e) => ShaderParameter.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    } else if (manifest.containsKey('parameters')) {
      final paramList = manifest['parameters'] as List<dynamic>?;
      if (paramList != null) {
        parameters = paramList
            .map((e) => ShaderParameter.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    }

    // Default fallback parameters if none provided
    if (parameters.isEmpty) {
      parameters = const <ShaderParameter>[
        ShaderParameter(
          id: 'intensity',
          name: 'intensity',
          label: 'Intensity',
          type: ParameterType.float,
          value: 1.0,
          defaultValue: 1.0,
          min: 0.0,
          max: 2.0,
        ),
      ];
    }

    final effect = ShaderEffect(
      id: effectId,
      name: name,
      description: description,
      category: category,
      type: EffectType.custom,
      author: author,
      parameters: parameters,
      shaderSource: shaderGlslStr,
      thumbnailUrl: thumbnailSourcePath ?? '',
      isFavorite: false,
      isDownloaded: true,
      updatedAt: DateTime.now(),
    );

    final savedEffect = await ShaderDatabaseService.instance.saveDownloadedEffect(effect, shaderGlslStr);
    AppLogger.info('Successfully imported custom effect package: ${savedEffect.name} (${savedEffect.id})',
        tag: 'CustomEffectImportService');

    return savedEffect;
  }
}
