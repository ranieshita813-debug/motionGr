# Mask tool: integration

Files (put them in `lib/features/editor/mask/`):

| File | Job |
| --- | --- |
| `mask_geometry.dart` | Shared geometry, `MaskXform`, `maskSigma`, `MaskPropsX` extension |
| `masked_layer.dart` | `MaskedLayer` (real mask on the video), `renderMaskMatte`, `writeMaskPng` (export) |
| `mask_handles_overlay.dart` | Transparent handles over the main player |
| `mask_sheet.dart` | Bottom bar only (no own preview) |

Delete the old `_MaskCanvas`, `_CanvasPainter`, `_G`, `_MaskXform` from the old file.

## 1) EditorController

```dart
bool _isMaskEditing = false;
bool get isMaskEditing => _isMaskEditing;

void setMaskEditing(bool v) {
  if (_isMaskEditing == v) return;
  _isMaskEditing = v;
  notifyListeners();
}
```

`updateMaskProperties(MaskProperties)` must call `notifyListeners()`.
Passing `const MaskProperties()` (type = `MaskType.none`) is what "None" uses to remove the mask.

## 2) Main player

Wrap the real video widget. Keep `MaskedLayer` INSIDE the clip's own
scale/position `Transform`, so the mask moves with the clip (like CapCut).

```dart
final editor = context.watch<EditorController>();
final clip = editor.selectedClip;

Stack(
  fit: StackFit.expand,
  children: [
    Transform(
      transform: clipTransform,                    // your existing clip transform
      child: RepaintBoundary(
        child: MaskedLayer.fromProps(
          props: clip?.maskProperties,
          child: YourVideoWidget(),                // VideoPlayer / Texture ...
        ),
      ),
    ),
    if (editor.isMaskEditing)
      const Positioned.fill(child: MaskHandlesOverlay()),
  ],
)
```

Important: `Positioned.fill` must have exactly the same size as the video frame,
not the whole screen. If your video is letterboxed, put the Stack inside the
`AspectRatio` that sizes the video.

For clips that are NOT selected, pass their own `clip.maskProperties` to
`MaskedLayer.fromProps` too, so masks are visible while playing/scrubbing.

## 3) Open the sheet

```dart
showModalBottomSheet(
  context: context,
  isScrollControlled: false,
  backgroundColor: Colors.transparent,
  barrierColor: Colors.transparent,     // keep the player visible and touchable
  builder: (_) => const MaskSheet(),
);
```

If you use `showModalBottomSheet`, the barrier blocks touches on the player.
Better: show `MaskSheet` as a bottom panel inside your editor layout (below the
player) while `isMaskEditing` is true, instead of a modal sheet.

## 4) Export (FFmpeg)

Use the same matte as the preview:

```dart
final png = await writeMaskPng(
  props: clip.maskProperties,
  videoSize: Size(videoWidth, videoHeight),   // real pixels
  path: '$tmp/mask_${clip.id}.png',
);
```

Then in the filter graph (white = visible, invert/feather already baked in):

```
-i clip.mp4 -i mask_<id>.png
-filter_complex "[1:v]format=gray[m];[0:v]format=rgba[c];[c][m]alphamerge[masked];[base][masked]overlay=x:y[out]"
```

Feather is baked into the PNG with `maskSigma(feather, videoWidth)`, the same
function the player uses, so preview and export match.

## 5) Notes

- Why `ShaderMask` and not `canvas.saveLayer`: `video_player` draws through a
  `Texture` layer. A manual `saveLayer` does not affect it; `ShaderMask` does.
- `ShaderMask` uses `BlendMode.dstIn`: visible = child * matte alpha.
- Keyframes: make `MaskProperties` keyframable (centerX/Y, width/height,
  rotation, feather). Interpolate to a `MaskXform` per frame and pass it to
  `MaskedLayer` and the export matte.
- Requires Flutter 3.7+ (`Picture.toImageSync`) and `Color.withValues`
  (Flutter 3.27+, already used in your code).