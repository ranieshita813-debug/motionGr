# Audio sheet: integration

Files (put them in `lib/features/editor/audio/`):

| File | Job |
| --- | --- |
| `audio_properties.dart` | Model, preview `gainAt()`, FFmpeg `buildFfmpegFilter()` |
| `audio_sheet.dart` | CapCut-style sheet: waveform + tool panel + tool bar |

## 1) Model + controller

```dart
// clip model
final AudioProperties audioProperties;            // default const AudioProperties()
// toJson:   'audio': audioProperties.toJson()
// fromJson: audioProperties: AudioProperties.fromJson(json['audio'])

// EditorController
void updateAudioProperties(AudioProperties p) {
  final clip = selectedClip;
  if (clip == null) return;
  // replace clip with clip.copyWith(audioProperties: p), push undo, then:
  notifyListeners();
}
```

## 2) Show the sheet

Show it as a bottom panel in the editor layout (not a blocking modal), so the
player stays visible and playable while you adjust.

```dart
AudioSheet(
  durationSeconds: clip.trimmedDurationSeconds,
  waveform: clip.waveformPeaks,        // optional, 0..1
)
```

## 3) Preview

On every player tick (position `t` in seconds of PLAYBACK time):

```dart
final p = clip.audioProperties;
final d = p.playbackSeconds(clip.trimmedDurationSeconds);
player.setVolume(p.gainAt(t, d).clamp(0.0, 1.0));   // fades + volume
player.setSpeed(p.speed);                            // speed
// optional pitch (just_audio): player.setPitch(...) for voice effects
```

Most players cap volume at 1.0. For 101..200% the preview stays at 100%;
export applies the real gain.

Voice effects, noise reduction, enhance voice and normalize are heavy DSP:
they are applied in export. In preview you can show a small "applied on
export" hint, or pre-render a short cached clip.

## 4) Export (FFmpeg)

```dart
final af = clip.audioProperties.buildFfmpegFilter(
  sourceSeconds: clip.trimmedDurationSeconds,
  sampleRate: 44100,
);
// ... -i clip.mp4 ${af != null ? '-af "$af"' : ''} ...
```

Chain order: speed -> voice effect -> noise -> enhance -> normalize ->
volume -> fades. Fade-out start uses the speed-adjusted length.

## 5) Notes

- Waveform: build `waveformPeaks` once per media (e.g. ffmpeg
  `-af astats` or a PCM decode, 1 peak per ~20 ms, normalized to 0..1).
- The waveform strip shows the original level (dim bars) and the result after
  volume and fades (bright bars + white envelope line), so changes are visible
  while dragging.
- Keyframe volume later: store `List<(double t, double gain)>` and replace
  `gainAt`; export with `volume=...:eval=frame` or an `asendcmd` script.