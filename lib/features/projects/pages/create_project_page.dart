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

// CapCut-like palette: true black, soft dark cards, cyan accent.
const Color _bg = Color(0xFF000000);
const Color _surface = Color(0xFF141414);
const Color _elevated = Color(0xFF1F1F1F);
const Color _border = Color(0xFF2A2A2A);
const Color _text = Color(0xFFFFFFFF);
const Color _muted = Color(0xFF8A8A92);
const Color _accent = Color(0xFF2DE2E6);
const String _font = 'Fredoka';

typedef _RatioOption = ({
  AspectRatioPreset preset,
  String label,
  String platform,
  double ratio,
  CanvasRatio canvasRatio,
});

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

  final List<_RatioOption> _ratioOptions = [
    (
      preset: AspectRatioPreset.nineSixteen,
      label: '9:16',
      platform: 'TikTok',
      ratio: 9 / 16,
      canvasRatio: CanvasRatio.r9x16,
    ),
    (
      preset: AspectRatioPreset.sixteenNine,
      label: '16:9',
      platform: 'YouTube',
      ratio: 16 / 9,
      canvasRatio: CanvasRatio.r16x9,
    ),
    (
      preset: AspectRatioPreset.oneOne,
      label: '1:1',
      platform: 'Post',
      ratio: 1,
      canvasRatio: CanvasRatio.r1x1,
    ),
    (
      preset: AspectRatioPreset.fourFive,
      label: '4:5',
      platform: 'Portrait',
      ratio: 4 / 5,
      canvasRatio: CanvasRatio.r4x5,
    ),
  ];

  static const _resolutions = ['720p', '1080p', '4K'];
  static const _fpsOptions = [24, 30, 60];

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

  _RatioOption get _currentOption => _ratioOptions.firstWhere(
        (o) => o.preset == _selectedRatio,
        orElse: () => _ratioOptions.first,
      );

  void _applyCanvasRatio() {
    canvasRatioNotifier.value = _currentOption.canvasRatio;
  }

  String get _projectName => _nameController.text.trim().isNotEmpty
      ? _nameController.text.trim()
      : 'Untitled Project';

  void _createBlankProject() {
    final projectsCtrl = Provider.of<ProjectsController>(context, listen: false);
    final editor = Provider.of<EditorController>(context, listen: false);

    final project = projectsCtrl.createProject(
      name: _projectName,
      aspectRatio: _selectedRatio,
    );

    _applyCanvasRatio();
    editor.loadProject(project);

    Navigator.of(context).pushReplacementNamed('/editor');
  }

  void _createWithMedia() {
    final projectsCtrl = Provider.of<ProjectsController>(context, listen: false);
    final editor = Provider.of<EditorController>(context, listen: false);

    final project = projectsCtrl.createProject(
      name: _projectName,
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
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          backgroundColor: _bg,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const PhosphorIcon(PhosphorIconsRegular.x, color: _text, size: 22),
            onPressed: () => Navigator.of(context).pop(),
          ),
          centerTitle: true,
          title: const Text(
            'New Project',
            style: TextStyle(
              color: _text,
              fontSize: 17,
              fontWeight: FontWeight.w600,
              fontFamily: _font,
            ),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPreview(),
                      const SizedBox(height: 24),
                      _buildNameField(),
                      const SizedBox(height: 28),
                      const _SectionTitle('Aspect Ratio'),
                      const SizedBox(height: 12),
                      _buildRatioRow(),
                      const SizedBox(height: 28),
                      const _SectionTitle('Resolution'),
                      const SizedBox(height: 12),
                      _ChipRow<String>(
                        values: _resolutions,
                        selected: _selectedResolution,
                        labelOf: (v) => v,
                        onSelected: (v) => setState(() => _selectedResolution = v),
                      ),
                      const SizedBox(height: 24),
                      const _SectionTitle('Frame rate'),
                      const SizedBox(height: 12),
                      _ChipRow<int>(
                        values: _fpsOptions,
                        selected: _selectedFps,
                        labelOf: (v) => '$v fps',
                        onSelected: (v) => setState(() => _selectedFps = v),
                      ),
                    ],
                  ),
                ),
              ),
              _buildBottomBar(),
            ],
          ),
        ),
      ),
    );
  }

  // Live canvas preview that morphs as the ratio changes.
  Widget _buildPreview() {
    final opt = _currentOption;
    return Container(
      height: 220,
      width: double.infinity,
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          LayoutBuilder(
            builder: (context, c) {
              const pad = 24.0;
              final maxW = c.maxWidth - pad * 2;
              final maxH = c.maxHeight - pad * 2;
              double w = maxW;
              double h = w / opt.ratio;
              if (h > maxH) {
                h = maxH;
                w = h * opt.ratio;
              }
              return AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                width: w,
                height: h,
                decoration: BoxDecoration(
                  color: _elevated,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _accent.withValues(alpha: 0.7), width: 1.5),
                ),
                child: const Center(
                  child: PhosphorIcon(PhosphorIconsRegular.plus, color: _muted, size: 26),
                ),
              );
            },
          ),
          Positioned(
            right: 12,
            bottom: 10,
            child: Text(
              '${opt.label}  •  $_selectedResolution  •  $_selectedFps fps',
              style: const TextStyle(
                color: _muted,
                fontSize: 11,
                fontWeight: FontWeight.w500,
                fontFamily: _font,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNameField() {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextField(
        controller: _nameController,
        cursorColor: _accent,
        textInputAction: TextInputAction.done,
        style: const TextStyle(
          color: _text,
          fontSize: 15,
          fontFamily: _font,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          hintText: 'Project name',
          hintStyle: const TextStyle(color: _muted, fontFamily: _font),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: _nameController,
            builder: (context, value, _) {
              if (value.text.isEmpty) return const SizedBox.shrink();
              return IconButton(
                icon: const PhosphorIcon(PhosphorIconsFill.xCircle, color: _muted, size: 18),
                onPressed: _nameController.clear,
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildRatioRow() {
    return SizedBox(
      height: 104,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: _ratioOptions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
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
              width: 84,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? _accent.withValues(alpha: 0.10) : _surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? _accent : Colors.transparent,
                  width: 1.6,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Mini shape that actually matches the ratio.
                  SizedBox(
                    width: 30,
                    height: 30,
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: opt.ratio,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: isSelected ? _accent : _muted,
                              width: 1.6,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    opt.label,
                    style: TextStyle(
                      color: isSelected ? _text : _text.withValues(alpha: 0.85),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
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
          );
        },
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: const BoxDecoration(
        color: _bg,
        border: Border(top: BorderSide(color: _border, width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: SizedBox(
              height: 52,
              child: TextButton(
                onPressed: _createBlankProject,
                style: TextButton.styleFrom(
                  backgroundColor: _elevated,
                  foregroundColor: _text,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                ),
                child: const Text(
                  'Blank Project',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontFamily: _font,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 6,
            child: SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _createWithMedia,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                ),
                icon: const PhosphorIcon(PhosphorIconsBold.plus, size: 18),
                label: const Text(
                  'Select Media',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    fontFamily: _font,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: _text,
        fontSize: 15,
        fontWeight: FontWeight.w600,
        fontFamily: _font,
      ),
    );
  }
}

/// Pill-style selector row (CapCut export-settings look).
class _ChipRow<T> extends StatelessWidget {
  const _ChipRow({
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
  });

  final List<T> values;
  final T selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (int i = 0; i < values.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onSelected(values[i]);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: values[i] == selected ? _text : _surface,
                  borderRadius: BorderRadius.circular(21),
                ),
                child: Text(
                  labelOf(values[i]),
                  style: TextStyle(
                    color: values[i] == selected ? Colors.black : _muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    fontFamily: _font,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}