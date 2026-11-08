import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:flutter_video_editor/features/editor/theme/editor_tokens.dart';
import 'package:flutter_video_editor/core/widgets/loading_wave.dart';

// ───────────────────────── Models ─────────────────────────

enum AiMediaType { image, video }

enum AiCapability { imageInput, audio, editing, fast, textRendering }

const _capabilityLabels = <AiCapability, String>{
  AiCapability.imageInput: 'Image input',
  AiCapability.audio: 'Audio',
  AiCapability.editing: 'Editing',
  AiCapability.fast: 'Fast',
  AiCapability.textRendering: 'Text',
};

/// One selectable AI model. `id` is what you send to your backend.
class AiModelOption {
  const AiModelOption({
    required this.id,
    required this.name,
    required this.provider,
    required this.description,
    required this.type,
    required this.creditsPerUnit,
    this.capabilities = const [],
    this.supportsNegativePrompt = false,
    this.supportsSeed = true,
    this.durations = const [],
    this.badge,
  });

  final String id;
  final String name;
  final String provider;
  final String description;
  final AiMediaType type;

  /// Credits per image, or per second of video (your own pricing).
  final int creditsPerUnit;
  final List<AiCapability> capabilities;
  final bool supportsNegativePrompt;
  final bool supportsSeed;

  /// Allowed clip lengths in seconds (video only).
  final List<int> durations;
  final String? badge;

  bool get supportsReference => capabilities.contains(AiCapability.imageInput);
}

/// Starter catalog. Ids, durations and credit costs are placeholders:
/// map them to what your provider or aggregator actually exposes.
class AiModelCatalog {
  static const defaults = <AiModelOption>[
    // Video
    AiModelOption(
      id: 'veo-3.1',
      name: 'Veo 3.1',
      provider: 'Google',
      description: 'Cinematic video with native audio',
      type: AiMediaType.video,
      creditsPerUnit: 8,
      capabilities: [AiCapability.imageInput, AiCapability.audio],
      durations: [4, 6, 8],
      badge: 'Top quality',
    ),
    AiModelOption(
      id: 'grok-imagine-video',
      name: 'Grok Imagine',
      provider: 'xAI',
      description: 'Great value, longer clips',
      type: AiMediaType.video,
      creditsPerUnit: 5,
      capabilities: [AiCapability.imageInput, AiCapability.editing],
      durations: [5, 10, 15],
      badge: 'Best value',
    ),
    AiModelOption(
      id: 'kling-2.5-pro',
      name: 'Kling 2.5 Pro',
      provider: 'Kuaishou',
      description: 'Consistent characters and scenes',
      type: AiMediaType.video,
      creditsPerUnit: 6,
      capabilities: [AiCapability.imageInput],
      durations: [5, 10],
    ),
    AiModelOption(
      id: 'seedance-1.5-pro',
      name: 'Seedance 1.5 Pro',
      provider: 'ByteDance',
      description: 'Fast multi-shot iteration',
      type: AiMediaType.video,
      creditsPerUnit: 4,
      capabilities: [AiCapability.imageInput, AiCapability.fast],
      durations: [5, 10],
    ),
    AiModelOption(
      id: 'runway-gen-4.5',
      name: 'Gen-4.5',
      provider: 'Runway',
      description: 'Creative control and editing tools',
      type: AiMediaType.video,
      creditsPerUnit: 7,
      capabilities: [AiCapability.imageInput, AiCapability.editing],
      durations: [5, 10],
    ),
    AiModelOption(
      id: 'hailuo-02',
      name: 'Hailuo 02',
      provider: 'MiniMax',
      description: 'Quick, eye-catching clips',
      type: AiMediaType.video,
      creditsPerUnit: 3,
      capabilities: [AiCapability.imageInput, AiCapability.fast],
      durations: [6, 10],
    ),
    AiModelOption(
      id: 'luma-ray-2',
      name: 'Ray 2',
      provider: 'Luma',
      description: 'Physics-accurate motion',
      type: AiMediaType.video,
      creditsPerUnit: 5,
      capabilities: [AiCapability.imageInput],
      durations: [5, 9],
    ),
    AiModelOption(
      id: 'wan-2.5',
      name: 'Wan 2.5',
      provider: 'Alibaba',
      description: 'Open-weight, low cost',
      type: AiMediaType.video,
      creditsPerUnit: 2,
      capabilities: [AiCapability.imageInput, AiCapability.audio],
      durations: [5, 10],
      supportsNegativePrompt: true,
    ),

    // Image
    AiModelOption(
      id: 'gpt-image-2',
      name: 'GPT Image 2',
      provider: 'OpenAI',
      description: 'Best prompt following and edits',
      type: AiMediaType.image,
      creditsPerUnit: 6,
      capabilities: [AiCapability.imageInput, AiCapability.editing, AiCapability.textRendering],
      supportsSeed: false,
      badge: 'Top quality',
    ),
    AiModelOption(
      id: 'nano-banana-2',
      name: 'Nano Banana 2',
      provider: 'Google',
      description: 'Fast, versatile, strong edits',
      type: AiMediaType.image,
      creditsPerUnit: 3,
      capabilities: [AiCapability.imageInput, AiCapability.editing, AiCapability.fast],
      supportsSeed: false,
      badge: 'Popular',
    ),
    AiModelOption(
      id: 'imagen-4',
      name: 'Imagen 4',
      provider: 'Google',
      description: 'Photorealistic with crisp detail',
      type: AiMediaType.image,
      creditsPerUnit: 3,
      capabilities: [AiCapability.textRendering],
    ),
    AiModelOption(
      id: 'flux-2-max',
      name: 'FLUX.2 Max',
      provider: 'Black Forest Labs',
      description: 'Top FLUX quality and edits',
      type: AiMediaType.image,
      creditsPerUnit: 4,
      capabilities: [AiCapability.imageInput, AiCapability.editing],
    ),
    AiModelOption(
      id: 'grok-imagine-image',
      name: 'Grok Imagine',
      provider: 'xAI',
      description: 'Fast and cheap',
      type: AiMediaType.image,
      creditsPerUnit: 1,
      capabilities: [AiCapability.imageInput, AiCapability.editing, AiCapability.fast],
    ),
    AiModelOption(
      id: 'seedream-4',
      name: 'Seedream 4',
      provider: 'ByteDance',
      description: 'Budget quality',
      type: AiMediaType.image,
      creditsPerUnit: 2,
      capabilities: [AiCapability.imageInput, AiCapability.editing],
    ),
    AiModelOption(
      id: 'ideogram-3',
      name: 'Ideogram 3',
      provider: 'Ideogram',
      description: 'Posters, logos, text in images',
      type: AiMediaType.image,
      creditsPerUnit: 3,
      capabilities: [AiCapability.textRendering],
    ),
    AiModelOption(
      id: 'sd-3.5',
      name: 'Stable Diffusion 3.5',
      provider: 'Stability AI',
      description: 'Full control, negative prompts',
      type: AiMediaType.image,
      creditsPerUnit: 1,
      supportsNegativePrompt: true,
    ),
  ];
}

class AiGenerationRequest {
  const AiGenerationRequest({
    required this.type,
    required this.modelId,
    required this.prompt,
    required this.aspectRatio,
    required this.count,
    required this.guidance,
    required this.steps,
    this.negativePrompt,
    this.style,
    this.seed,
    this.durationSeconds,
    this.motionStrength,
    this.referenceImagePath,
  });

  final AiMediaType type;
  final String modelId;
  final String prompt;
  final String? negativePrompt;
  final String? style;
  final String aspectRatio;
  final int count;
  final double guidance;
  final int steps;
  final int? seed;
  final int? durationSeconds;
  final double? motionStrength;
  final String? referenceImagePath;
}

class _Ratio {
  const _Ratio(this.label, this.hint);
  final String label;
  final String hint;
}

// ───────────────────────── Shared style ─────────────────────────

const _font = 'Fredoka';
const _labelWidth = 96.0;

TextStyle _ts(
  double size, {
  FontWeight w = FontWeight.w500,
  Color c = EditorTokens.text,
}) =>
    TextStyle(fontFamily: _font, fontSize: size, fontWeight: w, color: c);

const _fieldStyle = TextStyle(
  color: EditorTokens.text,
  fontSize: 13,
  fontFamily: _font,
);

const _hairlineBottom = BoxDecoration(
  border: Border(bottom: BorderSide(color: EditorTokens.border, width: 0.5)),
);

InputDecoration _decoration(String hint) => InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: EditorTokens.muted, fontSize: 13, fontFamily: _font),
      filled: true,
      fillColor: EditorTokens.elevated,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: EditorTokens.text),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
    );

// ───────────────────────── Entry point ─────────────────────────

/// Opens the generator as a drag-resizable bottom sheet (starts at ~55% height).
Future<void> showAiGenerateSheet(
  BuildContext context, {
  required Future<void> Function(AiGenerationRequest request) onGenerate,
  List<AiModelOption> models = AiModelCatalog.defaults,
  AiMediaType initialType = AiMediaType.video,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: EditorTokens.bg,
    constraints: const BoxConstraints(maxWidth: 760),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      builder: (_, controller) => AiGenerateSheet(
        scrollController: controller,
        onGenerate: onGenerate,
        models: models,
        initialType: initialType,
      ),
    ),
  );
}

// ───────────────────────── Sheet ─────────────────────────

class AiGenerateSheet extends StatefulWidget {
  const AiGenerateSheet({
    super.key,
    required this.onGenerate,
    this.models = AiModelCatalog.defaults,
    this.initialType = AiMediaType.video,
    this.scrollController,
  });

  final Future<void> Function(AiGenerationRequest request) onGenerate;
  final List<AiModelOption> models;
  final AiMediaType initialType;
  final ScrollController? scrollController;

  @override
  State<AiGenerateSheet> createState() => _AiGenerateSheetState();
}

class _AiGenerateSheetState extends State<AiGenerateSheet> {
  static const _ratios = <_Ratio>[
    _Ratio('9:16', 'Vertical'),
    _Ratio('1:1', 'Square'),
    _Ratio('16:9', 'Wide'),
    _Ratio('4:3', 'Classic'),
    _Ratio('3:4', 'Portrait'),
  ];
  static const _styles = ['None', 'Cinematic', 'Anime', '3D render', 'Photo', 'Watercolor'];

  final _promptCtl = TextEditingController();
  final _negCtl = TextEditingController();
  final _seedCtl = TextEditingController();

  late AiMediaType _type = widget.initialType;
  late String _modelId = _modelsOf(widget.initialType).first.id;
  int _ratioIndex = 0;
  int _count = 1;
  int? _duration;
  double _guidance = 7.5;
  int _steps = 30;
  double _motion = 0.5;
  String _style = 'None';
  String? _refPath;
  bool _busy = false;
  String? _promptError;

  List<AiModelOption> _modelsOf(AiMediaType t) =>
      widget.models.where((m) => m.type == t).toList();

  AiModelOption get _model {
    final list = _modelsOf(_type);
    return list.firstWhere((m) => m.id == _modelId, orElse: () => list.first);
  }

  bool get _isVideo => _type == AiMediaType.video;

  int get _credits => _model.creditsPerUnit *
      (_isVideo ? (_duration ?? (_model.durations.isEmpty ? 5 : _model.durations.first)) : _count);

  @override
  void initState() {
    super.initState();
    _syncDuration();
  }

  @override
  void dispose() {
    _promptCtl.dispose();
    _negCtl.dispose();
    _seedCtl.dispose();
    super.dispose();
  }

  void _syncDuration() {
    if (_isVideo && _model.durations.isNotEmpty) {
      _duration = _model.durations.contains(_duration) ? _duration : _model.durations.first;
    } else {
      _duration = null;
    }
  }

  void _setType(AiMediaType t) {
    if (t == _type) return;
    setState(() {
      _type = t;
      _modelId = _modelsOf(t).first.id;
      if (!_model.supportsReference) _refPath = null;
      _syncDuration();
    });
  }

  void _setModel(AiModelOption m) {
    setState(() {
      _modelId = m.id;
      if (!m.supportsReference) _refPath = null;
      _syncDuration();
    });
  }

  Future<void> _openModelPicker() async {
    FocusScope.of(context).unfocus();
    final picked = await showModalBottomSheet<AiModelOption>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: EditorTokens.bg,
      constraints: const BoxConstraints(maxWidth: 760),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _ModelPicker(models: _modelsOf(_type), selectedId: _model.id),
    );
    if (picked != null) _setModel(picked);
  }

  Future<void> _pickReference() async {
    try {
      final res = await FilePicker.platform.pickFiles(type: FileType.image);
      final path = res?.files.single.path;
      if (path != null) setState(() => _refPath = path);
    } catch (_) {
      _toast('Could not open that image');
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 3)));
  }

  Future<void> _generate() async {
    final prompt = _promptCtl.text.trim();
    if (prompt.isEmpty) {
      setState(() => _promptError = 'Describe what you want to create');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      await widget.onGenerate(
        AiGenerationRequest(
          type: _type,
          modelId: _model.id,
          prompt: prompt,
          negativePrompt: _model.supportsNegativePrompt && _negCtl.text.trim().isNotEmpty
              ? _negCtl.text.trim()
              : null,
          style: _style == 'None' ? null : _style,
          aspectRatio: _ratios[_ratioIndex].label,
          count: _isVideo ? 1 : _count,
          guidance: _guidance,
          steps: _steps,
          seed: _model.supportsSeed ? int.tryParse(_seedCtl.text.trim()) : null,
          durationSeconds: _duration,
          motionStrength: _isVideo ? _motion : null,
          referenceImagePath: _refPath,
        ),
      );
      if (mounted) Navigator.of(context).maybePop();
    } catch (_) {
      _toast('Generation failed. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── Sections ──

  /// 46px top bar: underline tabs (Video / Image) and a close button.
  Widget _header() => Container(
        height: 46,
        decoration: _hairlineBottom,
        child: Row(
          children: [
            const SizedBox(width: 6),
            _UnderlineTab(
              label: 'Video',
              icon: PhosphorIconsRegular.videoCamera,
              active: _isVideo,
              onTap: () => _setType(AiMediaType.video),
            ),
            _UnderlineTab(
              label: 'Image',
              icon: PhosphorIconsRegular.image,
              active: !_isVideo,
              onTap: () => _setType(AiMediaType.image),
            ),
            const Spacer(),
            IconButton(
              tooltip: 'Close',
              icon: const PhosphorIcon(PhosphorIconsRegular.x,
                  color: EditorTokens.text, size: 20),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ],
        ),
      );

  Widget _promptField() => TextField(
        controller: _promptCtl,
        minLines: 2,
        maxLines: 4,
        maxLength: 500,
        style: _fieldStyle,
        cursorColor: EditorTokens.text,
        onChanged: (_) {
          if (_promptError != null) setState(() => _promptError = null);
        },
        decoration: _decoration(
          _isVideo
              ? 'A drone shot over a misty forest at sunrise'
              : 'A neon-lit street in the rain, reflections on the road',
        ).copyWith(errorText: _promptError, counterText: ''),
      );

  Widget _modelRow() => _ModelRow(model: _model, onTap: _openModelPicker);

  Widget _pills() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _Pill<int>(
          icon: PhosphorIconsRegular.frameCorners,
          label: _ratios[_ratioIndex].label,
          items: List.generate(_ratios.length, (i) => i),
          labelOf: (i) => '${_ratios[i].label}  ·  ${_ratios[i].hint}',
          onSelected: (i) => setState(() => _ratioIndex = i),
        ),
        if (_isVideo && _model.durations.isNotEmpty)
          _Pill<int>(
            icon: PhosphorIconsRegular.timer,
            label: '${_duration ?? _model.durations.first}s',
            items: _model.durations,
            labelOf: (d) => '$d seconds',
            onSelected: (d) => setState(() => _duration = d),
          )
        else if (!_isVideo)
          _Pill<int>(
            icon: PhosphorIconsRegular.images,
            label: '$_count ${_count == 1 ? 'image' : 'images'}',
            items: const [1, 2, 3, 4],
            labelOf: (n) => '$n ${n == 1 ? 'image' : 'images'}',
            onSelected: (n) => setState(() => _count = n),
          ),
        _Pill<String>(
          icon: PhosphorIconsRegular.paintBrush,
          label: _style == 'None' ? 'Style' : _style,
          items: _styles,
          labelOf: (s) => s,
          onSelected: (s) => setState(() => _style = s),
        ),
        if (_model.supportsReference)
          _RefPill(
            path: _refPath,
            label: _isVideo ? 'Start frame' : 'Reference',
            onPick: _pickReference,
            onClear: () => setState(() => _refPath = null),
          ),
      ],
    );
  }

  Widget _advanced() => _Advanced(
        children: [
          if (_model.supportsNegativePrompt) ...[
            TextField(
              controller: _negCtl,
              minLines: 1,
              maxLines: 2,
              style: _fieldStyle,
              cursorColor: EditorTokens.text,
              decoration: _decoration('Negative prompt: blurry, low quality')
                  .copyWith(fillColor: EditorTokens.bg),
            ),
            const SizedBox(height: 8),
          ],
          _LabeledSlider(
            label: 'Prompt strength',
            valueLabel: _guidance.toStringAsFixed(1),
            value: _guidance,
            min: 1,
            max: 20,
            onChanged: (v) => setState(() => _guidance = (v * 2).round() / 2),
          ),
          _LabeledSlider(
            label: 'Quality steps',
            valueLabel: '$_steps',
            value: _steps.toDouble(),
            min: 10,
            max: 60,
            onChanged: (v) => setState(() => _steps = v.round()),
          ),
          if (_isVideo)
            _LabeledSlider(
              label: 'Motion',
              valueLabel: '${(_motion * 100).round()}%',
              value: _motion,
              min: 0,
              max: 1,
              onChanged: (v) => setState(() => _motion = v),
            ),
          if (_model.supportsSeed)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _seedCtl,
                      keyboardType: TextInputType.number,
                      style: _fieldStyle,
                      cursorColor: EditorTokens.text,
                      decoration: _decoration('Seed (random)')
                          .copyWith(fillColor: EditorTokens.bg),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _IconBtn(
                    icon: PhosphorIconsRegular.diceFive,
                    onTap: () => setState(() => _seedCtl.text =
                        (DateTime.now().microsecondsSinceEpoch % 4294967296).toString()),
                  ),
                ],
              ),
            ),
        ],
      );

  Widget _generateBar() => Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: EditorTokens.border, width: 0.5)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: EditorTokens.text,
                  foregroundColor: EditorTokens.bg,
                  disabledBackgroundColor: EditorTokens.text,
                  disabledForegroundColor: EditorTokens.bg,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                ),
                onPressed: _busy ? null : _generate,
                icon: _busy
                    ? const TextShimmerWave(
                        'Generating…',
                        style: TextStyle(fontWeight: FontWeight.bold, fontFamily: _font),
                        baseColor: Colors.black45,
                        waveColor: Colors.black,
                      )
                    : const PhosphorIcon(PhosphorIconsRegular.sparkle, size: 18),
                label: _busy
                    ? const SizedBox.shrink()
                    : Text(
                        'Generate · $_credits credits',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: _font),
                      ),
              ),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      padding: EdgeInsets.only(bottom: keyboard),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(top: 8, bottom: 4),
            decoration: BoxDecoration(
              color: EditorTokens.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) {
                final wide = c.maxWidth >= 640;
                final body = wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [_promptField(), const SizedBox(height: 4), _pills()],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              children: [
                                _modelRow(),
                                const SizedBox(height: 10),
                                _advanced(),
                              ],
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _promptField(),
                          const SizedBox(height: 4),
                          _modelRow(),
                          const SizedBox(height: 10),
                          _pills(),
                          const SizedBox(height: 10),
                          _advanced(),
                        ],
                      );

                // Header lives inside the list so dragging it still resizes the sheet.
                return ListView(
                  controller: widget.scrollController,
                  padding: EdgeInsets.zero,
                  children: [
                    _header(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                      child: body,
                    ),
                  ],
                );
              },
            ),
          ),
          _generateBar(),
        ],
      ),
    );
  }
}

// ───────────────────────── Model picker ─────────────────────────

class _ModelPicker extends StatefulWidget {
  const _ModelPicker({required this.models, required this.selectedId});
  final List<AiModelOption> models;
  final String selectedId;

  @override
  State<_ModelPicker> createState() => _ModelPickerState();
}

class _ModelPickerState extends State<_ModelPicker> {
  final _search = TextEditingController();
  String? _provider;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final providers = widget.models.map((m) => m.provider).toSet().toList()..sort();
    final q = _search.text.trim().toLowerCase();
    final filtered = widget.models.where((m) {
      final okProvider = _provider == null || m.provider == _provider;
      final okQuery = q.isEmpty ||
          m.name.toLowerCase().contains(q) ||
          m.provider.toLowerCase().contains(q) ||
          m.description.toLowerCase().contains(q);
      return okProvider && okQuery;
    }).toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, controller) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 8, bottom: 8),
              decoration: BoxDecoration(
                color: EditorTokens.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Search bar, same as the Effects sheet search mode.
            Container(
              height: 46,
              decoration: _hairlineBottom,
              child: Row(
                children: [
                  const SizedBox(width: 14),
                  const PhosphorIcon(PhosphorIconsRegular.magnifyingGlass,
                      color: EditorTokens.muted, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      cursorColor: EditorTokens.text,
                      style: _ts(14),
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: 'Search models',
                        hintStyle: _ts(14, c: EditorTokens.muted),
                      ),
                    ),
                  ),
                  if (_search.text.isNotEmpty)
                    IconButton(
                      icon: const PhosphorIcon(PhosphorIconsRegular.x,
                          color: EditorTokens.text, size: 18),
                      onPressed: () => setState(_search.clear),
                    ),
                ],
              ),
            ),
            // Provider tabs.
            SizedBox(
              height: 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                children: [
                  _UnderlineTab(
                    label: 'All',
                    active: _provider == null,
                    onTap: () => setState(() => _provider = null),
                  ),
                  for (final p in providers)
                    _UnderlineTab(
                      label: p,
                      active: _provider == p,
                      onTap: () => setState(() => _provider = p),
                    ),
                ],
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        'No models match your search',
                        style: _ts(13, c: EditorTokens.muted),
                      ),
                    )
                  : ListView.separated(
                      controller: controller,
                      padding: const EdgeInsets.fromLTRB(14, 6, 14, 16),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final m = filtered[i];
                        return _ModelTile(
                          model: m,
                          selected: m.id == widget.selectedId,
                          onTap: () => Navigator.of(context).pop(m),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModelTile extends StatelessWidget {
  const _ModelTile({required this.model, required this.selected, required this.onTap});
  final AiModelOption model;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: EditorTokens.elevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? EditorTokens.text : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Avatar(model.provider),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(model.name, style: _ts(13, w: FontWeight.w700)),
                      if (model.badge != null) _Badge(model.badge!),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${model.provider} · ${model.description}',
                    style: _ts(11, c: EditorTokens.muted),
                  ),
                  if (model.capabilities.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        for (final c in model.capabilities) _Tag(_capabilityLabels[c]!),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${model.creditsPerUnit}/${model.type == AiMediaType.video ? 's' : 'img'}',
                  style: _ts(11, c: EditorTokens.muted),
                ),
                if (selected) ...[
                  const SizedBox(height: 6),
                  const PhosphorIcon(
                    PhosphorIconsBold.check,
                    size: 14,
                    color: EditorTokens.text,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ModelRow extends StatelessWidget {
  const _ModelRow({required this.model, required this.onTap});
  final AiModelOption model;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: EditorTokens.elevated,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            _Avatar(model.provider, size: 30),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    model.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _ts(13, w: FontWeight.w700),
                  ),
                  Text(
                    model.provider,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _ts(11, c: EditorTokens.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text('Change', style: _ts(11, c: EditorTokens.muted)),
            const SizedBox(width: 4),
            const PhosphorIcon(
              PhosphorIconsRegular.caretRight,
              size: 14,
              color: EditorTokens.muted,
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── Small components ─────────────────────────

class _Avatar extends StatelessWidget {
  const _Avatar(this.provider, {this.size = 36});
  final String provider;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: EditorTokens.bg,
          border: Border.all(color: EditorTokens.border),
        ),
        alignment: Alignment.center,
        child: Text(
          provider.isEmpty ? '?' : provider[0].toUpperCase(),
          style: TextStyle(
            color: EditorTokens.text,
            fontSize: size * 0.4,
            fontWeight: FontWeight.bold,
            fontFamily: _font,
          ),
        ),
      );
}

class _Badge extends StatelessWidget {
  const _Badge(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: EditorTokens.text,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(text, style: _ts(10, w: FontWeight.w700, c: EditorTokens.bg)),
      );
}

class _Tag extends StatelessWidget {
  const _Tag(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: EditorTokens.border),
        ),
        child: Text(text, style: _ts(10, c: EditorTokens.muted)),
      );
}

/// Underline tab, identical to the tag tabs in the Effects top bar.
class _UnderlineTab extends StatelessWidget {
  const _UnderlineTab({
    required this.label,
    required this.active,
    required this.onTap,
    this.icon,
  });
  final String label;
  final bool active;
  final VoidCallback onTap;
  final PhosphorIconData? icon;

  @override
  Widget build(BuildContext context) {
    final color = active ? EditorTokens.text : EditorTokens.muted;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  PhosphorIcon(icon!, size: 16, color: color),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: _ts(14,
                      w: active ? FontWeight.w700 : FontWeight.w500, c: color),
                ),
              ],
            ),
            const SizedBox(height: 4),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 2,
              width: active ? 16 : 0,
              decoration: BoxDecoration(
                color: EditorTokens.text,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PillBody extends StatelessWidget {
  const _PillBody({required this.icon, required this.label});
  final PhosphorIconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: EditorTokens.elevated,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PhosphorIcon(icon, size: 14, color: EditorTokens.text),
            const SizedBox(width: 6),
            Text(label, style: _ts(12, w: FontWeight.w600)),
            const SizedBox(width: 4),
            const PhosphorIcon(
              PhosphorIconsRegular.caretDown,
              size: 11,
              color: EditorTokens.muted,
            ),
          ],
        ),
      );
}

class _Pill<T> extends StatelessWidget {
  const _Pill({
    required this.icon,
    required this.label,
    required this.items,
    required this.labelOf,
    required this.onSelected,
  });
  final PhosphorIconData icon;
  final String label;
  final List<T> items;
  final String Function(T) labelOf;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) => PopupMenuButton<T>(
        tooltip: '',
        color: EditorTokens.elevated,
        onSelected: onSelected,
        itemBuilder: (_) => [
          for (final i in items)
            PopupMenuItem<T>(
              value: i,
              height: 40,
              child: Text(labelOf(i), style: _ts(13)),
            ),
        ],
        child: _PillBody(icon: icon, label: label),
      );
}

class _RefPill extends StatelessWidget {
  const _RefPill({
    required this.path,
    required this.label,
    required this.onPick,
    required this.onClear,
  });
  final String? path;
  final String label;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final has = path != null;
    return GestureDetector(
      onTap: has ? onClear : onPick,
      child: Container(
        height: 34,
        padding: const EdgeInsets.fromLTRB(5, 0, 10, 0),
        decoration: BoxDecoration(
          color: EditorTokens.elevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: has ? EditorTokens.text : Colors.transparent),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: SizedBox(
                width: 24,
                height: 24,
                child: has
                    ? Image.file(File(path!), fit: BoxFit.cover)
                    : const ColoredBox(
                        color: EditorTokens.bg,
                        child: Center(
                          child: PhosphorIcon(
                            PhosphorIconsRegular.plus,
                            size: 12,
                            color: EditorTokens.text,
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 6),
            Text(label, style: _ts(12, w: FontWeight.w600)),
            if (has) ...[
              const SizedBox(width: 6),
              const PhosphorIcon(PhosphorIconsRegular.x, size: 12, color: EditorTokens.muted),
            ],
          ],
        ),
      ),
    );
  }
}

/// Collapsible "Advanced" block (no ExpansionTile borders or dividers).
class _Advanced extends StatefulWidget {
  const _Advanced({required this.children});
  final List<Widget> children;

  @override
  State<_Advanced> createState() => _AdvancedState();
}

class _AdvancedState extends State<_Advanced> {
  bool _open = false;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: EditorTokens.elevated,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _open = !_open),
              child: SizedBox(
                height: 44,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      const PhosphorIcon(PhosphorIconsRegular.slidersHorizontal,
                          size: 16, color: EditorTokens.text),
                      const SizedBox(width: 10),
                      Expanded(child: Text('Advanced', style: _ts(13, w: FontWeight.w700))),
                      AnimatedRotation(
                        turns: _open ? 0.5 : 0,
                        duration: const Duration(milliseconds: 180),
                        child: const PhosphorIcon(PhosphorIconsRegular.caretDown,
                            size: 14, color: EditorTokens.muted),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: _open
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: widget.children,
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      );
}

/// Row layout from the Effects config view: label, slider, value chip.
class _LabeledSlider extends StatelessWidget {
  const _LabeledSlider({
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });
  final String label;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 40,
        child: Row(
          children: [
            SizedBox(
              width: _labelWidth,
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _ts(12, c: EditorTokens.muted),
              ),
            ),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 2,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8, elevation: 2),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                  activeTrackColor: EditorTokens.text,
                  inactiveTrackColor: EditorTokens.border,
                  thumbColor: EditorTokens.text,
                  overlayColor: EditorTokens.text.withValues(alpha: 0.12),
                ),
                child: Slider(
                  value: value.clamp(min, max),
                  min: min,
                  max: max,
                  onChanged: onChanged,
                ),
              ),
            ),
            Container(
              width: 44,
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: EditorTokens.bg,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                valueLabel,
                textAlign: TextAlign.center,
                style: _ts(12, w: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({required this.icon, required this.onTap});
  final PhosphorIconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: EditorTokens.bg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(child: PhosphorIcon(icon, size: 18, color: EditorTokens.text)),
        ),
      );
}