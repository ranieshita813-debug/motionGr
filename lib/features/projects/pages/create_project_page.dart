import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:provider/provider.dart';

import 'package:flutter_video_editor/core/models/project_model.dart';
import 'package:flutter_video_editor/features/editor/controllers/editor_controller.dart';
import 'package:flutter_video_editor/features/editor/widgets/tool_sheets/editor_tool_sheets.dart'
    show CanvasRatio, canvasRatioNotifier;
import 'package:flutter_video_editor/features/media_picker/pages/media_picker_page.dart';
import 'package:flutter_video_editor/features/projects/controllers/projects_controller.dart';

const Color _bg = Color(0xFF0F1115);
const Color _surface = Color(0xFF181A20);
const Color _elevated = Color(0xFF222630);
const Color _border = Color(0xFF2E323D);
const Color _text = Color(0xFFFFFFFF);
const Color _muted = Color(0xFF9E9EA7);
const Color _accent = Color(0xFF2DE2E6);
const String _font = 'Fredoka';

class CreateProjectPage extends StatefulWidget {
  const CreateProjectPage({super.key});

  @override
  State<CreateProjectPage> createState() => _CreateProjectPageState();
}

class _CreateProjectPageState extends State<CreateProjectPage> {
  final TextEditingController _nameController = TextEditingController();
  AspectRatioPreset _selectedRatio = AspectRatioPreset.nineSixteen;
  String _selectedResolution = '1080p';
  int _selectedFps = 30;

  final List<({AspectRatioPreset preset, String label, String platform, PhosphorIconData icon, CanvasRatio canvasRatio})> _ratioOptions = [
    (
      preset: AspectRatioPreset.nineSixteen,
      label: '9:16',
      platform: 'TikTok / Shorts / Reels',
      icon: PhosphorIconsRegular.deviceMobile,
      canvasRatio: CanvasRatio.r9x16,
    ),
    (
      preset: AspectRatioPreset.sixteenNine,
      label: '16:9',
      platform: 'YouTube / Landscape',
      icon: PhosphorIconsRegular.television,
      canvasRatio: CanvasRatio.r16x9,
    ),
    (
      preset: AspectRatioPreset.oneOne,
      label: '1:1',
      platform: 'Instagram / Post',
      icon: PhosphorIconsRegular.square,
      canvasRatio: CanvasRatio.r1x1,
    ),
    (
      preset: AspectRatioPreset.fourFive,
      label: '4:5',
      platform: 'Instagram Portrait',
      icon: PhosphorIconsRegular.rectangle,
      canvasRatio: CanvasRatio.r4x5,
    ),
  ];

  @override
  void initState() {
    super.initState();
    final projectsCtrl = Provider.of<ProjectsController>(context, listen: false);
    _nameController.text = 'Project ${projectsCtrl.projects.length + 1}';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _applyCanvasRatio() {
    final matched = _ratioOptions.firstWhere(
      (opt) => opt.preset == _selectedRatio,
      orElse: () => _ratioOptions.first,
    );
    canvasRatioNotifier.value = matched.canvasRatio;
  }

  void _createBlankProject() {
    final name = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : 'Untitled Project';

    final projectsCtrl = Provider.of<ProjectsController>(context, listen: false);
    final editor = Provider.of<EditorController>(context, listen: false);

    final project = projectsCtrl.createProject(
      name: name,
      aspectRatio: _selectedRatio,
    );

    _applyCanvasRatio();
    editor.loadProject(project);

    Navigator.of(context).pushReplacementNamed('/editor');
  }

  void _createWithMedia() {
    final name = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : 'Untitled Project';

    final projectsCtrl = Provider.of<ProjectsController>(context, listen: false);
    final editor = Provider.of<EditorController>(context, listen: false);

    final project = projectsCtrl.createProject(
      name: name,
      aspectRatio: _selectedRatio,
    );

    _applyCanvasRatio();
    editor.loadProject(project);

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        settings: const RouteSettings(
          arguments: MediaPickerArgs(appendToCurrent: true, isOverlay: false),
        ),
        builder: (_) => const MediaPickerPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: _bg,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: _bg,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarDividerColor: _bg,
      ),
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: _bg,
          elevation: 0,
          leading: IconButton(
            icon: const PhosphorIcon(PhosphorIconsRegular.caretLeft, color: _text, size: 22),
            onPressed: () => Navigator.of(context).pop(),
          ),
          centerTitle: true,
          title: const Text(
            'New Project',
            style: TextStyle(
              color: _text,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: _font,
            ),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Project name input
                      const Text(
                        'Project Name',
                        style: TextStyle(
                          color: _text,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          fontFamily: _font,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: _surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _border),
                        ),
                        child: TextField(
                          controller: _nameController,
                          cursorColor: _accent,
                          style: const TextStyle(
                            color: _text,
                            fontSize: 15,
                            fontFamily: _font,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            hintText: 'Enter project name',
                            hintStyle: TextStyle(color: _muted, fontFamily: _font),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Aspect Ratio Selection
                      const Text(
                        'Aspect Ratio',
                        style: TextStyle(
                          color: _text,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          fontFamily: _font,
                        ),
                      ),
                      const SizedBox(height: 12),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.8,
                        ),
                        itemCount: _ratioOptions.length,
                        itemBuilder: (context, idx) {
                          final opt = _ratioOptions[idx];
                          final isSelected = opt.preset == _selectedRatio;
                          return GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _selectedRatio = opt.preset);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isSelected ? _accent.withValues(alpha: 0.12) : _surface,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected ? _accent : _border,
                                  width: isSelected ? 1.8 : 1.0,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: isSelected ? _accent.withValues(alpha: 0.2) : _elevated,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: PhosphorIcon(
                                      opt.icon,
                                      color: isSelected ? _accent : _muted,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          opt.label,
                                          style: TextStyle(
                                            color: isSelected ? _text : _text.withValues(alpha: 0.9),
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            fontFamily: _font,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          opt.platform,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: isSelected ? _accent : _muted,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w500,
                                            fontFamily: _font,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 24),

                      // Canvas Quality & Frame Rate
                      const Text(
                        'Format & Frame Rate',
                        style: TextStyle(
                          color: _text,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          fontFamily: _font,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: _surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _border),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Resolution',
                                    style: TextStyle(color: _muted, fontSize: 11, fontFamily: _font),
                                  ),
                                  const SizedBox(height: 6),
                                  DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _selectedResolution,
                                      isDense: true,
                                      isExpanded: true,
                                      dropdownColor: _surface,
                                      style: const TextStyle(
                                        color: _text,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: _font,
                                      ),
                                      items: const [
                                        DropdownMenuItem(value: '720p', child: Text('720p HD')),
                                        DropdownMenuItem(value: '1080p', child: Text('1080p FHD')),
                                        DropdownMenuItem(value: '4K', child: Text('4K UHD')),
                                      ],
                                      onChanged: (v) {
                                        if (v != null) setState(() => _selectedResolution = v);
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: _surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _border),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Frame Rate',
                                    style: TextStyle(color: _muted, fontSize: 11, fontFamily: _font),
                                  ),
                                  const SizedBox(height: 6),
                                  DropdownButtonHideUnderline(
                                    child: DropdownButton<int>(
                                      value: _selectedFps,
                                      isDense: true,
                                      isExpanded: true,
                                      dropdownColor: _surface,
                                      style: const TextStyle(
                                        color: _text,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: _font,
                                      ),
                                      items: const [
                                        DropdownMenuItem(value: 24, child: Text('24 fps (Cinema)')),
                                        DropdownMenuItem(value: 30, child: Text('30 fps (Standard)')),
                                        DropdownMenuItem(value: 60, child: Text('60 fps (Smooth)')),
                                      ],
                                      onChanged: (v) {
                                        if (v != null) setState(() => _selectedFps = v);
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                    ],
                  ),
                ),
              ),

              // Bottom Actions
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: _surface,
                  border: Border(top: BorderSide(color: _border)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _createBlankProject,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _text,
                          side: const BorderSide(color: _border),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text(
                          'Blank Project',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            fontFamily: _font,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _createWithMedia,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _text,
                          foregroundColor: _bg,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const PhosphorIcon(PhosphorIconsBold.filmStrip, size: 18),
                        label: const Text(
                          'Select Media',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            fontFamily: _font,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
