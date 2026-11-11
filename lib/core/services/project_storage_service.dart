import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:flutter_video_editor/core/logger/app_logger.dart';
import 'package:flutter_video_editor/core/models/project_model.dart';

class ProjectStorageService {
  ProjectStorageService._();
  static final ProjectStorageService instance = ProjectStorageService._();

  Directory? _projectsDir;

  Future<Directory> _getProjectsDirectory() async {
    if (_projectsDir != null && await _projectsDir!.exists()) {
      return _projectsDir!;
    }
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final dir = Directory('${docsDir.path}/motionGr_projects');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      _projectsDir = dir;
      return dir;
    } catch (_) {
      final tempDir = Directory('${Directory.systemTemp.path}/motionGr_projects');
      if (!await tempDir.exists()) {
        await tempDir.create(recursive: true);
      }
      _projectsDir = tempDir;
      return tempDir;
    }
  }

  static const String projectExtension = '.mgr';

  /// Serializes a project to JSON string content.
  String serializeProject(Project project) {
    final jsonMap = project.toJson();
    jsonMap['schemaVersion'] = 1;
    jsonMap['format'] = 'motionGr';
    jsonMap['extension'] = 'mgr';
    return jsonEncode(jsonMap);
  }

  /// Deserializes a project from JSON string content.
  Project deserializeProject(String content) {
    final Map<String, dynamic> jsonMap = jsonDecode(content) as Map<String, dynamic>;
    return Project.fromJson(jsonMap);
  }

  /// Packages a project and all its referenced media assets into a .mgr zip archive.
  /// Archive structure:
  /// - project.json
  /// - assets/<unique_filename>
  Future<Uint8List> createMgrBundle(Project project) async {
    final archive = Archive();
    final updatedClips = <TimelineClip>[];
    int assetIndex = 0;

    for (final clip in project.clips) {
      String? bundledPath = clip.sourcePath;

      if (clip.sourcePath != null && clip.sourcePath!.isNotEmpty) {
        final srcFile = File(clip.sourcePath!);
        if (srcFile.existsSync()) {
          final ext = p.extension(clip.sourcePath!);
          final arcFileName = 'assets/clip_${clip.id}_${assetIndex++}$ext';
          final bytes = await srcFile.readAsBytes();
          archive.addFile(ArchiveFile(arcFileName, bytes.length, bytes));
          bundledPath = arcFileName;
        }
      }

      String? bundledSticker = clip.stickerAssetPath;
      if (clip.stickerAssetPath != null && clip.stickerAssetPath!.isNotEmpty) {
        final stickerFile = File(clip.stickerAssetPath!);
        if (stickerFile.existsSync()) {
          final ext = p.extension(clip.stickerAssetPath!);
          final arcFileName = 'assets/sticker_${clip.id}_${assetIndex++}$ext';
          final bytes = await stickerFile.readAsBytes();
          archive.addFile(ArchiveFile(arcFileName, bytes.length, bytes));
          bundledSticker = arcFileName;
        }
      }

      var elProps = clip.elementProperties;
      if (elProps.svgPath != null && elProps.svgPath!.isNotEmpty && !elProps.svgPath!.trim().startsWith('<')) {
        final svgFile = File(elProps.svgPath!);
        if (svgFile.existsSync()) {
          final arcFileName = 'assets/element_${clip.id}_${assetIndex++}.svg';
          final bytes = await svgFile.readAsBytes();
          archive.addFile(ArchiveFile(arcFileName, bytes.length, bytes));
          elProps = elProps.copyWith(svgPath: arcFileName);
        }
      }

      updatedClips.add(clip.copyWith(
        sourcePath: bundledPath,
        stickerAssetPath: bundledSticker,
        elementProperties: elProps,
      ));
    }

    final projectForArchive = project.copyWith(clips: updatedClips);
    final jsonStr = serializeProject(projectForArchive);
    final jsonBytes = utf8.encode(jsonStr);
    archive.addFile(ArchiveFile('project.json', jsonBytes.length, jsonBytes));

    final zipEncoder = ZipEncoder();
    final encoded = zipEncoder.encode(archive);
    return Uint8List.fromList(encoded);
  }

  /// Extracts a .mgr bundle (zip archive or plain JSON) and unpacks its assets.
  /// Returns the reconstructed Project with local file paths.
  Future<Project> extractMgrBundle(Uint8List bytes, {String? targetDir}) async {
    // Check if this is a Zip archive (starts with PK\x03\x04 or standard zip magic)
    final bool isZip = bytes.length >= 4 &&
        bytes[0] == 0x50 &&
        bytes[1] == 0x4B &&
        (bytes[2] == 0x03 || bytes[2] == 0x05 || bytes[2] == 0x07);

    if (!isZip) {
      // Plain JSON fallback
      final content = utf8.decode(bytes);
      return deserializeProject(content);
    }

    final archive = ZipDecoder().decodeBytes(bytes);
    ArchiveFile? projectFile;

    for (final file in archive.files) {
      if (file.name == 'project.json' || file.name.endsWith('.json')) {
        projectFile = file;
        break;
      }
    }

    if (projectFile == null) {
      throw const FormatException('Invalid .mgr bundle: missing project.json');
    }

    final projectJsonStr = utf8.decode(projectFile.content as List<int>);
    final rawProject = deserializeProject(projectJsonStr);

    final destDir = Directory(targetDir ?? '${(await _getProjectsDirectory()).path}/${rawProject.id}_assets');
    if (!await destDir.exists()) {
      await destDir.create(recursive: true);
    }

    final Map<String, String> unpackedAssets = <String, String>{};

    for (final file in archive.files) {
      if (file.name != projectFile.name && !file.isDirectory) {
        final outFilePath = p.join(destDir.path, p.basename(file.name));
        final outFile = File(outFilePath);
        await outFile.writeAsBytes(file.content as List<int>, flush: true);
        unpackedAssets[file.name] = outFilePath;
        unpackedAssets[p.basename(file.name)] = outFilePath;
      }
    }

    final remappedClips = <TimelineClip>[];
    for (final clip in rawProject.clips) {
      String? remapSource = clip.sourcePath;
      if (remapSource != null && (unpackedAssets.containsKey(remapSource) || unpackedAssets.containsKey(p.basename(remapSource)))) {
        remapSource = unpackedAssets[remapSource] ?? unpackedAssets[p.basename(remapSource)];
      }

      String? remapSticker = clip.stickerAssetPath;
      if (remapSticker != null && (unpackedAssets.containsKey(remapSticker) || unpackedAssets.containsKey(p.basename(remapSticker)))) {
        remapSticker = unpackedAssets[remapSticker] ?? unpackedAssets[p.basename(remapSticker)];
      }

      var elProps = clip.elementProperties;
      if (elProps.svgPath != null && (unpackedAssets.containsKey(elProps.svgPath!) || unpackedAssets.containsKey(p.basename(elProps.svgPath!)))) {
        elProps = elProps.copyWith(svgPath: unpackedAssets[elProps.svgPath!] ?? unpackedAssets[p.basename(elProps.svgPath!)]);
      }

      remappedClips.add(clip.copyWith(
        sourcePath: remapSource,
        stickerAssetPath: remapSticker,
        elementProperties: elProps,
      ));
    }

    return rawProject.copyWith(clips: remappedClips);
  }

  Future<List<Project>> loadAllProjects() async {
    try {
      final dir = await _getProjectsDirectory();
      final List<FileSystemEntity> entities = await dir.list().toList();
      final Map<String, Project> projectsById = <String, Project>{};

      for (final entity in entities) {
        if (entity is File &&
            (entity.path.endsWith('.mgr') || entity.path.endsWith('.json')) &&
            !entity.path.contains('recovery_')) {
          try {
            final bytes = await entity.readAsBytes();
            final project = await extractMgrBundle(bytes);
            if (!projectsById.containsKey(project.id) || entity.path.endsWith('.mgr')) {
              projectsById[project.id] = project;
            }
          } catch (e, stack) {
            AppLogger.error('Failed to parse project file ${entity.path}', tag: 'ProjectStorage', error: e, stackTrace: stack);
          }
        }
      }

      final List<Project> projects = projectsById.values.toList();
      projects.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return projects;
    } on MissingPluginException catch (_) {
      return <Project>[];
    } catch (e, stack) {
      AppLogger.error('Failed to load projects from storage', tag: 'ProjectStorage', error: e, stackTrace: stack);
      return <Project>[];
    }
  }

  Future<void> saveProject(Project project) async {
    try {
      final dir = await _getProjectsDirectory();
      final tempFile = File('${dir.path}/${project.id}.tmp');
      final targetFile = File('${dir.path}/${project.id}.mgr');

      // Save as bundle package with media assets
      final bundleBytes = await createMgrBundle(project);

      await tempFile.writeAsBytes(bundleBytes, flush: true);
      await tempFile.rename(targetFile.path);

      // Clean up legacy .json project file if it exists
      final legacyFile = File('${dir.path}/${project.id}.json');
      if (await legacyFile.exists()) {
        try {
          await legacyFile.delete();
        } catch (_) {}
      }

      AppLogger.info('Saved project ${project.id} to local storage as .mgr bundle', tag: 'ProjectStorage');
    } on MissingPluginException catch (_) {
      // Ignored in test environment without native channel
    } catch (e, stack) {
      AppLogger.error('Failed to save project ${project.id}', tag: 'ProjectStorage', error: e, stackTrace: stack);
    }
  }

  Future<void> deleteProject(String projectId) async {
    try {
      final dir = await _getProjectsDirectory();
      final mgrFile = File('${dir.path}/$projectId.mgr');
      if (await mgrFile.exists()) {
        await mgrFile.delete();
      }
      final jsonFile = File('${dir.path}/$projectId.json');
      if (await jsonFile.exists()) {
        await jsonFile.delete();
      }
      final assetsDir = Directory('${dir.path}/${projectId}_assets');
      if (await assetsDir.exists()) {
        await assetsDir.delete(recursive: true);
      }
      AppLogger.info('Deleted project $projectId from local storage', tag: 'ProjectStorage');
    } on MissingPluginException catch (_) {
      // Ignored in test environment
    } catch (e, stack) {
      AppLogger.error('Failed to delete project $projectId', tag: 'ProjectStorage', error: e, stackTrace: stack);
    }
  }

  Future<void> saveRecoveryState(Project project) async {
    try {
      final dir = await _getProjectsDirectory();
      final tempFile = File('${dir.path}/recovery_active.tmp');
      final targetFile = File('${dir.path}/recovery_active.mgr');
      final jsonStr = serializeProject(project);

      await tempFile.writeAsString(jsonStr, flush: true);
      await tempFile.rename(targetFile.path);
    } on MissingPluginException catch (_) {
      // Ignored in test environment
    } catch (e, stack) {
      AppLogger.error('Failed to save recovery state', tag: 'ProjectStorage', error: e, stackTrace: stack);
    }
  }

  Future<Project?> loadRecoveryState() async {
    try {
      final dir = await _getProjectsDirectory();
      final mgrFile = File('${dir.path}/recovery_active.mgr');
      if (await mgrFile.exists()) {
        final bytes = await mgrFile.readAsBytes();
        return await extractMgrBundle(bytes);
      }
      final legacyFile = File('${dir.path}/recovery_active.json');
      if (await legacyFile.exists()) {
        final bytes = await legacyFile.readAsBytes();
        return await extractMgrBundle(bytes);
      }
    } on MissingPluginException catch (_) {
      return null;
    } catch (e, stack) {
      AppLogger.error('Failed to load recovery state', tag: 'ProjectStorage', error: e, stackTrace: stack);
    }
    return null;
  }

  Future<void> clearRecoveryState() async {
    try {
      final dir = await _getProjectsDirectory();
      final mgrFile = File('${dir.path}/recovery_active.mgr');
      if (await mgrFile.exists()) {
        await mgrFile.delete();
      }
      final jsonFile = File('${dir.path}/recovery_active.json');
      if (await jsonFile.exists()) {
        await jsonFile.delete();
      }
    } catch (_) {}
  }
}
