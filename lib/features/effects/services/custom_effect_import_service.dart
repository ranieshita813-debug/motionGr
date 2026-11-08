import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_video_editor/core/error/app_exceptions.dart';
import 'package:flutter_video_editor/core/logger/app_logger.dart';
import 'package:flutter_video_editor/core/models/shader_effect_model.dart';
import 'package:flutter_video_editor/core/services/permission_service.dart';
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
  ///
  /// Requests storage permissions beforehand to prevent permission denied errors,
  /// and gracefully falls back to single-file picking (.glsl / .frag / .json) if
  /// directory picking is cancelled or restricted by scoped storage.
  Future<ShaderEffect?> pickAndImportPackage({bool preferFilePicker = false}) async {
    try {
      if (preferFilePicker) {
        return await pickAndImportFile();
      }

      try {
        final selectedDirectory = await FilePicker.platform.getDirectoryPath(
          dialogTitle: 'Select Custom Effect Package Folder',
        );

        if (selectedDirectory != null && selectedDirectory.isNotEmpty) {
          try {
            return await importFromDirectory(selectedDirectory);
          } catch (fsErr) {
            AppLogger.warning('Directory access failed ($fsErr). Falling back to file picker.',
                tag: 'CustomEffectImportService');
            return await pickAndImportFile();
          }
        }
      } catch (e) {
        AppLogger.warning('Directory picker failed ($e). Falling back to file picker.',
            tag: 'CustomEffectImportService');
        return await pickAndImportFile();
      }
    } on PermissionException {
      rethrow;
    } catch (e, stack) {
      AppLogger.error('Failed picking custom effect package',
          tag: 'CustomEffectImportService', error: e, stackTrace: stack);
      rethrow;
    }
    return null;
  }

  /// Prompts user to select an individual shader (.glsl, .frag) or manifest (.json) file.
  /// Uses SAF system picker which does not require external storage permissions.
  Future<ShaderEffect?> pickAndImportFile() async {
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['glsl', 'frag', 'vert', 'json', 'txt'],
        withData: true,
      );
    } catch (_) {
      // Some file pickers or OS versions fail with custom types, fall back to FileType.any
      result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: true,
      );
    }

    if (result != null && result.files.isNotEmpty) {
      return await importFromFile(result.files.first);
    }
    return null;
  }

  /// Imports a custom effect from a picked file (either `.glsl`/`.frag` or `.json`).
  Future<ShaderEffect> importFromFile(PlatformFile file) async {
    final ext = (file.extension ?? p.extension(file.name).replaceAll('.', '')).toLowerCase();
    String content;

    if (file.bytes != null && file.bytes!.isNotEmpty) {
      content = utf8.decode(file.bytes!);
    } else if (file.path != null && file.path!.isNotEmpty) {
      final f = File(file.path!);
      if (!await f.exists()) {
        throw FileSystemException('Effect file does not exist', file.path);
      }
      content = await f.readAsString();
    } else {
      throw const FormatException('Cannot read file content for effect import.');
    }

    if (ext == 'json') {
      // Manifest or combined package JSON
      final Map<String, dynamic> jsonMap = jsonDecode(content) as Map<String, dynamic>;
      String shaderSource = (jsonMap['shader'] as String?) ??
          (jsonMap['shaderSource'] as String?) ??
          (jsonMap['glsl'] as String?) ??
          (jsonMap['code'] as String?) ??
          '';

      if (shaderSource.trim().isEmpty && jsonMap['assets'] is Map) {
        final assetsMap = jsonMap['assets'] as Map;
        final assetShader = assetsMap['shader'] as String?;
        if (assetShader != null && assetShader.trim().isNotEmpty) {
          shaderSource = assetShader;
        }
      }

      if (shaderSource.trim().isEmpty) {
        // If manifest points to external shader file in same directory
        if (file.path != null) {
          final dirPath = p.dirname(file.path!);
          for (final candidate in ['shader.glsl', 'shader.frag', 'effect.frag', 'effect.glsl']) {
            final f = File(p.join(dirPath, candidate));
            if (await f.exists()) {
              shaderSource = await f.readAsString();
              break;
            }
          }
          if (shaderSource.isNotEmpty) {
            return await importFromData(
              manifestJsonStr: content,
              shaderGlslStr: shaderSource,
            );
          }
        }
        throw const FormatException('Manifest JSON does not contain shader source or companion shader file');
      }

      return await importFromData(
        manifestJsonStr: content,
        shaderGlslStr: shaderSource,
      );
    } else {
      // Direct shader source (.glsl, .frag)
      final rawName = p.basenameWithoutExtension(file.name);
      final displayName = rawName
          .replaceAll('_', ' ')
          .replaceAll('-', ' ')
          .trim();
      final capitalized = displayName.isNotEmpty
          ? displayName[0].toUpperCase() + displayName.substring(1)
          : 'Custom Effect';

      final manifestJson = jsonEncode({
        'id': 'custom_${rawName.toLowerCase()}_${DateTime.now().millisecondsSinceEpoch}',
        'name': capitalized,
        'description': 'Custom shader imported from ${file.name}',
        'author': 'User',
        'category': 'glow',
      });

      return await importFromData(
        manifestJsonStr: manifestJson,
        shaderGlslStr: content,
      );
    }
  }

  /// Imports a custom effect from a folder containing `manifest.json` and `shader.glsl`.
  Future<ShaderEffect> importFromDirectory(String directoryPath) async {
    final hasPerm = await PermissionService.instance.requestStoragePermission();
    if (!hasPerm) {
      throw PermissionException('Storage permission is required to read effect folder.');
    }

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
