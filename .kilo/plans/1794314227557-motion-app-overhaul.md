# Motion App Overhaul Plan

## Overview
Transform the current "motionGr" video editor into "Motion" with new branding, fixed core features, enhanced effects system, and custom file formats.

---

## 1. App Rebranding: "motionGr" → "Motion"

### Files to Update
| File | Changes |
|------|---------|
| `pubspec.yaml` | `name: motion`, `description: Motion - Professional video editor` |
| `lib/app.dart` | `MaterialApp(title: 'Motion')` |
| `android/app/src/main/AndroidManifest.xml` | `android:label="Motion"` |
| `ios/Runner/Info.plist` | `CFBundleDisplayName: Motion`, `CFBundleName: motion` |
| `lib/features/splash/pages/splash_screen.dart` | Wordmark text "Motion", accent styling |
| `lib/core/services/project_storage_service.dart` | Directory: `Motion_projects` |
| All UI references | Replace "motionGr" → "Motion" |

### Logo Integration
- Use `/assets/logos/logo.svg` as primary logo
- Update `pubspec.yaml` assets to include `assets/logos/`
- Replace text wordmark in splash with logo + "Motion" text
- Generate app icons from `ic_launcher-512.png` / `ic_launcher-1024.png`

---

## 2. Fix Transitions Between Clips

### Problem
Current implementation in `preview.dart:_applyTransition()` only transitions the **outgoing** clip. Real transitions need to **cross-fade/blend between two adjacent clips** (outgoing + incoming).

### Solution
1. **Modify `TimelineClip.transitionType`** to represent transition **between this clip and the next**
2. **Update `Preview` widget** to render both clips during transition window
3. **Add transition rendering logic** that composites outgoing + incoming with blend progress

### Implementation Steps
1. In `project_model.dart`: Keep `transitionType`/`transitionDurationMs` on clip (means "transition to next clip")
2. In `preview.dart`: 
   - Detect when playhead is in transition zone of clip A
   - Render clip A (outgoing) + clip B (incoming) stacked
   - Apply transition effect as blend between the two
3. Add new transition types: `crossfade`, `slide`, `push`, `zoom`, `blur`, `glitch`, `wipe`, `iris`
3. Update `editor_tool_sheets.dart` transition picker UI

---

## 3. Fix Blending System

### Problem
`BlendSheet` UI exists and stores `BlendProperties` on clips, but blending is **not applied during rendering** in `preview.dart`.

### Solution
1. In `preview.dart` clip rendering: wrap clip widget with `BlendMode` application
2. Use `ColorFiltered` + `BlendMode` or `SaveLayer` with `Paint.blendMode`
3. Apply both `blendProperties.type` and `blendProperties.opacity`

### Implementation
```dart
// In preview.dart clip build method:
if (clip.blendProperties.isActive) {
  child = Opacity(
    opacity: clip.blendProperties.opacity,
    child: ColorFiltered(
      colorFilter: ColorFilter.mode(Colors.transparent, flutterBlendMode(clip.blendProperties.type)),
      child: child,
    ),
  );
}
```

---

## 4. Fix Speed Curves

### Problem
`SpeedSheet` has full curve editor UI, but speed curves may not be applied during **playback** or **export**.

### Verification Needed
1. Check `PlaybackController` applies variable speed per frame
2. Check `ExportService` respects `SpeedSettings.points` for curve
3. Ensure `SpeedSettings.interpolate()` is used at render time

### Implementation
1. In `playback_controller.dart`: Sample speed curve at current playhead position
2. In `export_service.dart`: Use speed curve for frame timing during export
3. Add integration tests

---

## 5. Enhanced Effects System

### Current State
- 65 `VideoEffect` enum values (legacy)
- Shader-based effects via `ShaderEffect` / `FxShaders`
- Custom effect import via `CustomEffectImportService`
- Unified registry in `UnifiedEffectRegistry`

### Enhancements
1. **Effect Categories Expansion**
   - Add: AI Effects, Particle, 3D, Audio-Reactive, Style Transfer
   
2. **Full Parameter Customization**
   - Keyframe animation for ALL effect parameters (already supported via `KeyframeAnimation`)
   - Parameter presets per effect
   - Visual parameter curves in UI

3. **Effect Stacking & Layering**
   - Multiple effects per clip with z-index
   - Effect blend modes
   - Effect masking support

4. **New UI: Effect Parameter Panel**
   - Expand `effect_parameter_panel.dart` for full keyframe editor
   - Timeline-based parameter curves
   - Copy/paste effect parameter animations

---

## 6. Project File Format: `.mgr`

### Design
```
project.mgr (ZIP archive)
├── project.json          # Project metadata + timeline (current JSON)
├── assets/               # Referenced media files (optional, for portability)
│   ├── video/
│   ├── audio/
│   └── images/
├── thumbnails/           # Generated thumbnails
├── waveforms/            # Audio waveform data
└── manifest.json         # Format version, created/modified dates
```

### Implementation
1. Create `ProjectPackageService` with:
   - `exportProject(Project, File) → Future<void>`
   - `importProject(File) → Future<Project>`
2. Use `archive` package for ZIP handling
3. Support both `.mgr` (full package) and `.json` (legacy) loading
4. Update `ProjectStorageService` to use `.mgr` as primary format
5. Add "Export Project Package" / "Import Project Package" in UI

---

## 7. Effect Package Format: `.emgr`

### Design
```
effect.emgr (ZIP archive)
├── manifest.json         # Effect metadata (id, name, category, author, version)
├── shader.glsl           # GLSL fragment shader source
├── config.json           # Parameter definitions (ShaderParameter[])
├── thumbnail.png         # 256x256 preview
└── preview.mp4           # Optional: demo video
```

### Implementation
1. Extend `CustomEffectImportService`:
   - `exportEffectPackage(ShaderEffect, File) → Future<void>`
   - `importEffectPackage(File) → Future<ShaderEffect>`
2. Register `.emgr` file association on Android/iOS
3. Add "Export Effect Package" in Effects Library
4. Support both folder import (current) and `.emgr` file import

---

## Task Breakdown & Dependencies

| Phase | Tasks | Depends On |
|-------|-------|------------|
| **1. Branding** | 1.1-1.7 | None |
| **2. Transitions** | 2.1-2.4 | 1.1 (project model) |
| **3. Blending** | 3.1-3.2 | 1.1 |
| **4. Speed Curves** | 4.1-4.3 | 1.1 |
| **5. Effects** | 5.1-5.4 | 1.1, 3.1 |
| **6. .mgr Format** | 6.1-6.4 | 1.1 |
| **7. .emgr Format** | 7.1-7.4 | 5.1 |

---

## Validation Plan

### Automated Tests
- Unit tests for project import/export (`.mgr`, `.emgr`)
- Transition rendering tests (golden images)
- Blend mode visual regression tests
- Speed curve interpolation accuracy tests
- Effect parameter keyframe serialization tests

### Manual QA
1. Create project → add clips → apply transitions → verify preview
2. Apply blend modes → verify preview and export
3. Create speed curve → verify playback and export timing
4. Import/export `.mgr` → verify all data preserved
5. Create custom effect → export `.emgr` → import in new app instance
6. Verify app name/logo appears correctly on device home screen

---

## Open Questions

1. **Transition ownership**: Should transition belong to outgoing clip (current) or incoming clip? CapCut puts it on outgoing. Keep current model.

2. **Project package size**: Include media files in `.mgr`? Recommendation: Optional "portable" export includes media; standard export references external paths.

3. **Effect package signing**: Should `.emgr` support digital signatures for marketplace? Defer to future.

4. **Backward compatibility**: Continue supporting `.json` project loading? Yes, keep dual support.

5. **Android/iOS icon generation**: Use existing `ic_launcher-512.png` / `1024.png` with `flutter_launcher_icons`? Yes.

---

## Estimated Effort

| Area | Complexity |
|------|------------|
| Branding | Low |
| Transitions | Medium-High (rendering changes) |
| Blending | Low-Medium |
| Speed Curves | Medium (playback + export) |
| Effects Enhancement | Medium-High |
| .mgr Format | Medium |
| .emgr Format | Low-Medium |

**Total**: ~3-4 weeks for full implementation with testing.