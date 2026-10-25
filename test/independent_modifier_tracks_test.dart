import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_video_editor/core/models/project_model.dart';
import 'package:flutter_video_editor/features/editor/controllers/editor_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Independent Modifier Tracks (Adjustment/Filter/Effect) Tests', () {
    late EditorController controller;
    late TimelineClip videoClip1;
    late TimelineClip videoClip2;

    setUp(() {
      controller = EditorController();
      videoClip1 = TimelineClip(
        id: 'video_1',
        label: 'Video 1',
        start: Duration.zero,
        end: const Duration(seconds: 5),
        clipType: ClipType.video,
        sourcePath: 'assets/sample1.mp4',
      );
      videoClip2 = TimelineClip(
        id: 'video_2',
        label: 'Video 2',
        start: const Duration(seconds: 5),
        end: const Duration(seconds: 10),
        clipType: ClipType.video,
        sourcePath: 'assets/sample2.mp4',
      );
      controller.addClip(videoClip1);
      controller.addClip(videoClip2);
    });

    test('Creating an Adjustment clip creates an independent overlay clip', () {
      controller.selectClip('video_1');
      controller.updateColorGrading(const ColorGradingSettings(brightness: 0.5));

      final adjClips = controller.clips.where((c) => c.label == 'Adjustment' || c.id.startsWith('adj_')).toList();
      expect(adjClips, isNotEmpty);
      final adj = adjClips.first;

      expect(adj.colorGrading.brightness, equals(0.5));
      expect(adj.start, equals(Duration.zero));
      expect(adj.end, equals(const Duration(seconds: 5)));

      // Main video clips remain unchanged in count and duration
      final videoClips = controller.clips.where((c) => c.clipType == ClipType.video).toList();
      expect(videoClips.length, equals(2));
      expect(videoClips.first.duration, equals(const Duration(seconds: 5)));
    });

    test('Splitting an Adjustment clip splits ONLY the Adjustment clip and NOT the video clip', () {
      controller.selectClip('video_1');
      controller.updateColorGrading(const ColorGradingSettings(brightness: 0.5));

      final adjClips = controller.clips.where((c) => c.label == 'Adjustment' || c.id.startsWith('adj_')).toList();
      final adj = adjClips.first;

      controller.selectClip(adj.id);
      controller.setPlayhead(const Duration(seconds: 2));
      controller.splitSelectedClip();

      // Video clips remain 2
      final videoClips = controller.clips.where((c) => c.clipType == ClipType.video).toList();
      expect(videoClips.length, equals(2));
      expect(videoClips[0].duration, equals(const Duration(seconds: 5)));
      expect(videoClips[1].duration, equals(const Duration(seconds: 5)));

      // Adjustment clips split into 2 parts
      final newAdjClips = controller.clips.where((c) => c.label.contains('Adjustment') || c.id.contains('adj_')).toList();
      expect(newAdjClips.length, equals(2));
      expect(newAdjClips[0].duration, equals(const Duration(seconds: 2)));
      expect(newAdjClips[1].duration, equals(const Duration(seconds: 3)));
    });

    test('Trimming and lengthening Adjustment clip does NOT alter main video clip duration', () {
      controller.selectClip('video_1');
      controller.updateColorGrading(const ColorGradingSettings(contrast: 1.5));

      final adj = controller.clips.firstWhere((c) => c.label == 'Adjustment' || c.id.startsWith('adj_'));
      controller.selectClip(adj.id);

      // Extend adjustment clip to cover both video 1 and video 2 (0s to 8s)
      controller.trimSelectedClip(Duration.zero, const Duration(seconds: 8));

      final updatedAdj = controller.clips.firstWhere((c) => c.id == adj.id);
      expect(updatedAdj.start, equals(Duration.zero));
      expect(updatedAdj.end, equals(const Duration(seconds: 8)));

      // Video clips remain untouched
      final v1 = controller.clips.firstWhere((c) => c.id == 'video_1');
      final v2 = controller.clips.firstWhere((c) => c.id == 'video_2');
      expect(v1.duration, equals(const Duration(seconds: 5)));
      expect(v2.duration, equals(const Duration(seconds: 5)));
    });

    test('Deleting an Adjustment clip removes only the Adjustment clip', () {
      controller.selectClip('video_1');
      controller.updateColorGrading(const ColorGradingSettings(saturation: 1.2));

      final adj = controller.clips.firstWhere((c) => c.label == 'Adjustment' || c.id.startsWith('adj_'));
      controller.selectClip(adj.id);
      controller.deleteSelectedClip();

      expect(controller.clips.any((c) => c.id == adj.id), isFalse);
      expect(controller.clips.where((c) => c.clipType == ClipType.video).length, equals(2));
    });
  });
}
