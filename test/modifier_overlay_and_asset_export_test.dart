import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_video_editor/core/models/project_model.dart';
import 'package:flutter_video_editor/features/editor/controllers/editor_controller.dart';
import 'package:flutter_video_editor/features/editor/controllers/track_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Modifier Overlay & Asset Export Unit Tests', () {
    test('TimelineClip.isModifier correctly identifies modifier tracks', () {
      final adjClip = TimelineClip(
        id: 'adj_123',
        label: 'Adjustment',
        start: Duration.zero,
        end: const Duration(seconds: 5),
        clipType: ClipType.overlay,
        layerIndex: -2,
      );

      final fxClip = TimelineClip(
        id: 'fx_123',
        label: 'Effect',
        start: Duration.zero,
        end: const Duration(seconds: 5),
        clipType: ClipType.overlay,
        layerIndex: -3,
      );

      final videoClip = TimelineClip(
        id: 'v_1',
        label: 'Main Video',
        start: Duration.zero,
        end: const Duration(seconds: 5),
        clipType: ClipType.video,
        layerIndex: 0,
      );

      final overlayVideo = TimelineClip(
        id: 'v_overlay',
        label: 'PIP Video',
        start: Duration.zero,
        end: const Duration(seconds: 5),
        clipType: ClipType.video,
        layerIndex: 1,
      );

      final textClip = TimelineClip(
        id: 'txt_1',
        label: 'Text Overlay',
        start: Duration.zero,
        end: const Duration(seconds: 5),
        clipType: ClipType.text,
        layerIndex: 1,
      );

      expect(adjClip.isModifier, isTrue);
      expect(fxClip.isModifier, isTrue);
      expect(videoClip.isModifier, isFalse);
      expect(overlayVideo.isModifier, isFalse);
      expect(textClip.isModifier, isFalse);
    });

    test('TrackController.isOverlay returns false for modifier tracks', () {
      final trackCtrl = TrackController();

      final adjClip = TimelineClip(
        id: 'adj_123',
        label: 'Adjustment',
        start: Duration.zero,
        end: const Duration(seconds: 5),
        clipType: ClipType.overlay,
        layerIndex: -2,
      );

      final fxClip = TimelineClip(
        id: 'fx_123',
        label: 'Effect',
        start: Duration.zero,
        end: const Duration(seconds: 5),
        clipType: ClipType.overlay,
        layerIndex: -3,
      );

      final textClip = TimelineClip(
        id: 'txt_1',
        label: 'Hello World',
        start: Duration.zero,
        end: const Duration(seconds: 5),
        clipType: ClipType.text,
        layerIndex: 1,
      );

      expect(trackCtrl.isOverlay(adjClip), isFalse);
      expect(trackCtrl.isOverlay(fxClip), isFalse);
      expect(trackCtrl.isOverlay(textClip), isTrue);
    });

    test('EditorController addEffectClip and updateColorGrading create modifier clips that are not overlays', () {
      final project = Project(
        id: 'proj_test',
        name: 'Test Project',
        clips: [
          TimelineClip(
            id: 'v_1',
            label: 'Video 1',
            start: Duration.zero,
            end: const Duration(seconds: 10),
            clipType: ClipType.video,
          ),
        ],
      );

      final editor = EditorController();
      editor.loadProject(project);
      editor.selectClip('v_1');

      editor.updateColorGrading(const ColorGradingSettings(brightness: 0.2));
      expect(editor.project.clips.length, equals(2));

      final adjClip = editor.project.clips.firstWhere((c) => c.label == 'Adjustment');
      expect(adjClip.isModifier, isTrue);

      editor.applyEffect(VideoEffect.vhs);
      expect(editor.project.clips.length, equals(3));

      final fxClip = editor.project.clips.firstWhere((c) => c.label == 'Effect');
      expect(fxClip.isModifier, isTrue);
    });

    test('Project default thumbnail is empty string instead of non-existent placeholder', () {
      final project = Project(id: 'p_1', name: 'New Project');
      expect(project.thumbnail, equals(''));
      expect(project.thumbnail.contains('placeholder.png'), isFalse);
    });
  });
}
