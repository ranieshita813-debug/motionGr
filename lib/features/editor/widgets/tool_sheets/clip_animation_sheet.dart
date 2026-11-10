import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:provider/provider.dart';
import 'package:flutter_video_editor/core/models/project_model.dart';
import 'package:flutter_video_editor/features/editor/controllers/editor_controller.dart';
import 'package:flutter_video_editor/features/editor/theme/editor_tokens.dart';

const _font = 'Fredoka';
const _tabs = ['In', 'Out'];

class ClipAnimationSheet extends StatefulWidget {
  const ClipAnimationSheet({super.key});

  @override
  State<ClipAnimationSheet> createState() => _ClipAnimationSheetState();
}

class _ClipAnimationSheetState extends State<ClipAnimationSheet> {
  String _searchQuery = '';
  String _selectedTab = 'In';
  bool _searching = false;

  static const List<ClipAnimation> _inAnimations = [
    ClipAnimation.none,
    ClipAnimation.fadeIn,
    ClipAnimation.slideLeft,
    ClipAnimation.slideRight,
    ClipAnimation.zoomIn,
    ClipAnimation.bounce,
    ClipAnimation.spin,
    ClipAnimation.glitch,
    ClipAnimation.rotateIn,
    ClipAnimation.flipHorizontal,
    ClipAnimation.flipVertical,
    ClipAnimation.elasticBounce,
    ClipAnimation.blurFade,
    ClipAnimation.shakeSlide,
    ClipAnimation.zoomRotate,
    ClipAnimation.pulse,
    ClipAnimation.shake,
    ClipAnimation.wipeRight,
    ClipAnimation.wipeLeft,
    ClipAnimation.wipeUp,
    ClipAnimation.wipeDown,
  ];

  static const List<ClipAnimation> _outAnimations = [
    ClipAnimation.none,
    ClipAnimation.fadeOut,
    ClipAnimation.slideLeft,
    ClipAnimation.slideRight,
    ClipAnimation.zoomOut,
    ClipAnimation.spin,
    ClipAnimation.glitch,
    ClipAnimation.flipHorizontal,
    ClipAnimation.flipVertical,
    ClipAnimation.blurFade,
    ClipAnimation.wipeLeft,
    ClipAnimation.wipeRight,
    ClipAnimation.wipeUp,
    ClipAnimation.wipeDown,
    ClipAnimation.fold,
    ClipAnimation.ripple,
  ];

  bool get _isInMode => _selectedTab == 'In';

  List<ClipAnimation> get _filtered {
    final q = _searchQuery.toLowerCase();
    final source = _isInMode ? _inAnimations : _outAnimations;
    return source.where((a) => _animationName(a).toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final editor = context.read<EditorController>();
    final clip = context.select<EditorController, TimelineClip?>((e) => e.selectedClip);

    if (clip == null) {
      return Container(
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        child: const Text(
          'Select a clip to apply animations',
          style: TextStyle(color: EditorTokens.muted, fontSize: 13, fontFamily: _font),
        ),
      );
    }

    final currentAnim = _isInMode ? clip.inAnimation : clip.outAnimation;
    final filtered = _filtered;

    return Column(
      children: [
        _buildTopBar(),
        Expanded(
          child: filtered.isEmpty
              ? const Center(
                  child: Text(
                    'No animations found',
                    style: TextStyle(color: EditorTokens.muted, fontSize: 13, fontFamily: _font),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.78,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final anim = filtered[index];
                    return _AnimationTile(
                      anim: anim,
                      name: _animationName(anim),
                      isSelected: anim == currentAnim,
                      onTap: () => editor.updateSelectedClipAnimation(
                        anim,
                        isInAnimation: _isInMode,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 46,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: EditorTokens.border, width: 0.5)),
      ),
      child: _searching
          ? Row(
              children: [
                const SizedBox(width: 14),
                const PhosphorIcon(PhosphorIconsRegular.magnifyingGlass,
                    color: EditorTokens.muted, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    autofocus: true,
                    onChanged: (v) => setState(() => _searchQuery = v),
                    cursorColor: EditorTokens.text,
                    style: const TextStyle(
                        color: EditorTokens.text, fontSize: 14, fontFamily: _font),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: 'Search animations',
                      hintStyle: TextStyle(
                          color: EditorTokens.muted, fontSize: 14, fontFamily: _font),
                    ),
                  ),
                ),
                IconButton(
                  icon: const PhosphorIcon(PhosphorIconsRegular.x,
                      color: EditorTokens.text, size: 18),
                  onPressed: () => setState(() {
                    _searching = false;
                    _searchQuery = '';
                  }),
                ),
              ],
            )
          : Row(
              children: [
                Expanded(
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    itemCount: _tabs.length,
                    itemBuilder: (_, i) {
                      final tab = _tabs[i];
                      final active = tab == _selectedTab;
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => setState(() => _selectedTab = tab),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                tab,
                                style: TextStyle(
                                  color: active ? EditorTokens.text : EditorTokens.muted,
                                  fontSize: 14,
                                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                                  fontFamily: _font,
                                ),
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
                    },
                  ),
                ),
                IconButton(
                  icon: const PhosphorIcon(PhosphorIconsRegular.magnifyingGlass,
                      color: EditorTokens.text, size: 20),
                  onPressed: () => setState(() => _searching = true),
                ),
              ],
            ),
    );
  }
}

class _AnimationTile extends StatelessWidget {
  const _AnimationTile({
    required this.anim,
    required this.name,
    required this.isSelected,
    required this.onTap,
  });

  final ClipAnimation anim;
  final String name;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isNone = anim == ClipAnimation.none;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? EditorTokens.text : Colors.transparent,
                  width: 2,
                ),
              ),
              padding: EdgeInsets.all(isSelected ? 2 : 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: isNone ? EditorTokens.elevated : null,
                    gradient: isNone
                        ? null
                        : LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: _gradientFor(anim),
                          ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PhosphorIcon(
                        _iconFor(anim),
                        color: isNone ? EditorTokens.muted : Colors.white,
                        size: isNone ? 22 : 24,
                      ),
                      if (isSelected && !isNone)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: EditorTokens.text,
                              borderRadius: BorderRadius.only(topLeft: Radius.circular(6)),
                            ),
                            child: const PhosphorIcon(
                              PhosphorIconsBold.check,
                              color: EditorTokens.bg,
                              size: 11,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? EditorTokens.text : EditorTokens.muted,
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              fontFamily: _font,
            ),
          ),
        ],
      ),
    );
  }
}

const Map<ClipAnimation, List<Color>> _gradients = {
  ClipAnimation.fadeIn: [Color(0xFF3A6073), Color(0xFF16222A)],
  ClipAnimation.fadeOut: [Color(0xFF3A6073), Color(0xFF16222A)],
  ClipAnimation.blurFade: [Color(0xFF4568DC), Color(0xFFB06AB3)],
  ClipAnimation.slideLeft: [Color(0xFF11998E), Color(0xFF38EF7D)],
  ClipAnimation.slideRight: [Color(0xFF11998E), Color(0xFF38EF7D)],
  ClipAnimation.wipeLeft: [Color(0xFF136A8A), Color(0xFF267871)],
  ClipAnimation.wipeRight: [Color(0xFF136A8A), Color(0xFF267871)],
  ClipAnimation.wipeUp: [Color(0xFF136A8A), Color(0xFF267871)],
  ClipAnimation.wipeDown: [Color(0xFF136A8A), Color(0xFF267871)],
  ClipAnimation.zoomIn: [Color(0xFF00B4DB), Color(0xFF0083B0)],
  ClipAnimation.zoomOut: [Color(0xFF00B4DB), Color(0xFF0083B0)],
  ClipAnimation.bounce: [Color(0xFFF7971E), Color(0xFFFFD200)],
  ClipAnimation.elasticBounce: [Color(0xFFF7971E), Color(0xFFFFD200)],
  ClipAnimation.elastic: [Color(0xFFF7971E), Color(0xFFFFD200)],
  ClipAnimation.spin: [Color(0xFF833AB4), Color(0xFFFD1D1D)],
  ClipAnimation.rotateIn: [Color(0xFF833AB4), Color(0xFFFD1D1D)],
  ClipAnimation.zoomRotate: [Color(0xFF833AB4), Color(0xFFFD1D1D)],
  ClipAnimation.glitch: [Color(0xFF00E5FF), Color(0xFFFF0055)],
  ClipAnimation.flipHorizontal: [Color(0xFF302B63), Color(0xFF24243E)],
  ClipAnimation.flipVertical: [Color(0xFF302B63), Color(0xFF24243E)],
  ClipAnimation.shakeSlide: [Color(0xFFC94B4C), Color(0xFF4D13D1)],
  ClipAnimation.shake: [Color(0xFFC94B4C), Color(0xFF4D13D1)],
  ClipAnimation.pulse: [Color(0xFFF857A6), Color(0xFFFF5858)],
  ClipAnimation.fold: [Color(0xFF434343), Color(0xFF000000)],
  ClipAnimation.ripple: [Color(0xFF42275A), Color(0xFF734B6D)],
};

List<Color> _gradientFor(ClipAnimation anim) =>
    _gradients[anim] ?? const [Color(0xFF2A2A30), Color(0xFF1B1B20)];

String _animationName(ClipAnimation anim) {
  switch (anim) {
    case ClipAnimation.none:
      return 'None';
    case ClipAnimation.fadeIn:
      return 'Fade In';
    case ClipAnimation.fadeOut:
      return 'Fade Out';
    case ClipAnimation.slideLeft:
      return 'Slide Left';
    case ClipAnimation.slideRight:
      return 'Slide Right';
    case ClipAnimation.zoomIn:
      return 'Zoom In';
    case ClipAnimation.zoomOut:
      return 'Zoom Out';
    case ClipAnimation.bounce:
      return 'Bounce';
    case ClipAnimation.spin:
      return 'Spin';
    case ClipAnimation.glitch:
      return 'Glitch';
    case ClipAnimation.rotateIn:
      return 'Rotate In';
    case ClipAnimation.flipHorizontal:
      return 'Flip H';
    case ClipAnimation.flipVertical:
      return 'Flip V';
    case ClipAnimation.elasticBounce:
      return 'Elastic';
    case ClipAnimation.blurFade:
      return 'Blur Fade';
    case ClipAnimation.shakeSlide:
      return 'Shake Slide';
    case ClipAnimation.zoomRotate:
      return 'Zoom Rotate';
    case ClipAnimation.shake:
      return 'Shake';
    case ClipAnimation.pulse:
      return 'Pulse';
    case ClipAnimation.elastic:
      return 'Elastic Loop';
    case ClipAnimation.wipeRight:
      return 'Wipe Right';
    case ClipAnimation.wipeLeft:
      return 'Wipe Left';
    case ClipAnimation.wipeUp:
      return 'Wipe Up';
    case ClipAnimation.wipeDown:
      return 'Wipe Down';
    case ClipAnimation.fold:
      return 'Fold';
    case ClipAnimation.ripple:
      return 'Ripple';
    default:
      return anim.name;
  }
}

PhosphorIconData _iconFor(ClipAnimation anim) {
  switch (anim) {
    case ClipAnimation.none:
      return PhosphorIconsRegular.prohibit;
    case ClipAnimation.fadeIn:
    case ClipAnimation.fadeOut:
    case ClipAnimation.blurFade:
      return PhosphorIconsRegular.circle;
    case ClipAnimation.slideLeft:
    case ClipAnimation.wipeLeft:
      return PhosphorIconsRegular.arrowLeft;
    case ClipAnimation.slideRight:
    case ClipAnimation.wipeRight:
      return PhosphorIconsRegular.arrowRight;
    case ClipAnimation.wipeUp:
      return PhosphorIconsRegular.arrowUp;
    case ClipAnimation.wipeDown:
      return PhosphorIconsRegular.arrowDown;
    case ClipAnimation.zoomIn:
      return PhosphorIconsRegular.magnifyingGlassPlus;
    case ClipAnimation.zoomOut:
      return PhosphorIconsRegular.magnifyingGlassMinus;
    case ClipAnimation.bounce:
    case ClipAnimation.elasticBounce:
    case ClipAnimation.elastic:
      return PhosphorIconsRegular.play;
    case ClipAnimation.spin:
    case ClipAnimation.rotateIn:
    case ClipAnimation.zoomRotate:
      return PhosphorIconsRegular.arrowsClockwise;
    case ClipAnimation.glitch:
      return PhosphorIconsRegular.magicWand;
    case ClipAnimation.flipHorizontal:
    case ClipAnimation.flipVertical:
      return PhosphorIconsRegular.repeat;
    case ClipAnimation.shakeSlide:
    case ClipAnimation.shake:
      return PhosphorIconsRegular.sliders;
    case ClipAnimation.pulse:
      return PhosphorIconsRegular.heartbeat;
    case ClipAnimation.fold:
      return PhosphorIconsRegular.bookOpen;
    case ClipAnimation.ripple:
      return PhosphorIconsRegular.waves;
    default:
      return PhosphorIconsRegular.sparkle;
  }
}