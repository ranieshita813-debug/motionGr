import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_video_editor/core/logger/app_logger.dart';
import 'package:flutter_video_editor/core/models/project_model.dart';
import 'package:flutter_video_editor/core/services/project_storage_service.dart';

class ProjectsController extends ChangeNotifier {
  ProjectsController() {
    _loadProjectsFromStorage();
  }

  final List<Project> _projects = <Project>[];
  bool _isLoading = false;

  List<Project> get projects => List<Project>.unmodifiable(_projects);
  bool get isLoading => _isLoading;

  Future<void> _loadProjectsFromStorage() async {
    _isLoading = true;
    notifyListeners();
    final loaded = await ProjectStorageService.instance.loadAllProjects();
    _projects.clear();
    _projects.addAll(loaded);
    _isLoading = false;
    notifyListeners();
  }

  Future<void> refresh() async {
    await _loadProjectsFromStorage();
  }

  Project createProject({
    String? name,
    AspectRatioPreset aspectRatio = AspectRatioPreset.nineSixteen,
    List<TimelineClip>? clips,
  }) {
    final id = 'proj_${DateTime.now().millisecondsSinceEpoch}';
    final project = Project(
      id: id,
      name: name ?? 'New Project ${_projects.length + 1}',
      aspectRatio: aspectRatio,
      clips: clips,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _projects.insert(0, project);
    ProjectStorageService.instance.saveProject(project);
    notifyListeners();
    return project;
  }

  void renameProject(String id, String newName) {
    final index = _projects.indexWhere((p) => p.id == id);
    if (index != -1) {
      final updated = _projects[index].copyWith(
        name: newName,
        updatedAt: DateTime.now(),
      );
      _projects[index] = updated;
      ProjectStorageService.instance.saveProject(updated);
      notifyListeners();
    }
  }

  Project? duplicateProject(String id) {
    final index = _projects.indexWhere((p) => p.id == id);
    if (index != -1) {
      final original = _projects[index];
      final duplicated = original.copyWith(
        id: 'proj_${DateTime.now().millisecondsSinceEpoch}',
        name: '${original.name} (Copy)',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      _projects.insert(index + 1, duplicated);
      ProjectStorageService.instance.saveProject(duplicated);
      notifyListeners();
      return duplicated;
    }
    return null;
  }

  void deleteProject(String id) {
    _projects.removeWhere((p) => p.id == id);
    ProjectStorageService.instance.deleteProject(id);
    notifyListeners();
  }

  void saveProject(Project updatedProject) {
    final updated = updatedProject.copyWith(updatedAt: DateTime.now());
    final index = _projects.indexWhere((p) => p.id == updated.id);
    if (index != -1) {
      _projects[index] = updated;
    } else {
      _projects.insert(0, updated);
    }
    ProjectStorageService.instance.saveProject(updated);
    notifyListeners();
  }

  Project? getProject(String id) {
    try {
      return _projects.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Exports project data as a .mgr bundle (archive bytes with media assets).
  Future<Uint8List> exportProjectToBundleBytes(String id) async {
    final project = getProject(id);
    if (project == null) {
      throw Exception('Project not found: $id');
    }
    return ProjectStorageService.instance.createMgrBundle(project);
  }

  /// Exports project as a .mgr bundle file (with assets) to target folder or downloads directory.
  Future<String?> exportProjectToFile(String id, {String? targetDirectory}) async {
    final project = getProject(id);
    if (project == null) return null;

    try {
      String? dirPath = targetDirectory;
      if (dirPath == null) {
        try {
          dirPath = await FilePicker.platform.getDirectoryPath(
            dialogTitle: 'Select destination folder for .mgr file',
          );
        } catch (_) {}
      }

      final bundleBytes = await ProjectStorageService.instance.createMgrBundle(project);
      final sanitizedName = project.name
          .replaceAll(RegExp(r'[^\w\s\.-]'), '_')
          .trim()
          .replaceAll(' ', '_');
      final fileName = '${sanitizedName}_${project.id}.mgr';

      if (dirPath != null && dirPath.isNotEmpty) {
        final file = File(p.join(dirPath, fileName));
        await file.writeAsBytes(bundleBytes, flush: true);
        AppLogger.info('Exported project ${project.id} with assets to ${file.path}', tag: 'ProjectsController');
        return file.path;
      } else {
        // Fallback to system temp folder
        final file = File(p.join(Directory.systemTemp.path, fileName));
        await file.writeAsBytes(bundleBytes, flush: true);
        return file.path;
      }
    } catch (e, stack) {
      AppLogger.error('Failed to export project $id', tag: 'ProjectsController', error: e, stackTrace: stack);
      rethrow;
    }
  }

  /// Imports a project from .mgr bundle bytes (or plain JSON string).
  Future<Project> importProjectFromBytes(Uint8List bytes, {String? customName}) async {
    final parsed = await ProjectStorageService.instance.extractMgrBundle(bytes);
    final id = 'proj_${DateTime.now().millisecondsSinceEpoch}';
    final imported = parsed.copyWith(
      id: id,
      name: customName ?? (parsed.name.contains('(Imported)') ? parsed.name : '${parsed.name} (Imported)'),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _projects.insert(0, imported);
    ProjectStorageService.instance.saveProject(imported);
    notifyListeners();
    return imported;
  }

  /// Prompts user to pick a .mgr (or .json) project file and imports it with all assets.
  Future<Project?> pickAndImportProject() async {
    try {
      FilePickerResult? result;
      try {
        result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: const ['mgr', 'json'],
          withData: true,
        );
      } catch (_) {
        result = await FilePicker.platform.pickFiles(
          type: FileType.any,
          withData: true,
        );
      }

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        Uint8List bytes;
        if (file.bytes != null && file.bytes!.isNotEmpty) {
          bytes = file.bytes!;
        } else if (file.path != null && file.path!.isNotEmpty) {
          bytes = await File(file.path!).readAsBytes();
        } else {
          return null;
        }

        final imported = await importProjectFromBytes(bytes);
        return imported;
      }
    } catch (e, stack) {
      AppLogger.error('Failed picking and importing project', tag: 'ProjectsController', error: e, stackTrace: stack);
      rethrow;
    }
    return null;
  }

  /// Exports project JSON string (legacy helper).
  Future<String> exportProjectToString(String id) async {
    final project = getProject(id);
    if (project == null) throw Exception('Project not found: $id');
    return ProjectStorageService.instance.serializeProject(project);
  }

  /// Imports project from JSON string (legacy helper).
  Future<Project> importProjectFromString(String content, {String? customName}) async {
    final bytes = Uint8List.fromList(utf8.encode(content));
    return importProjectFromBytes(bytes, customName: customName);
  }
}
