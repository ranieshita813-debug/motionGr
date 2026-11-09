/// Re-exports all enums from project_model.dart to avoid duplicate definitions.
/// Import this file where legacy enum references are needed.
library clip_enums;

export 'package:flutter_video_editor/core/models/project_model.dart'
    show
    ClipType,
    VideoEffect,
    TextAnimationStyle,
    ClipAnimation,
    ElementShape,
    MaskType,
    KeyframeProperty,
    CurveType,
    BlendType;
