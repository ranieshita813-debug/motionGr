import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flutter_video_editor/core/models/project_model.dart';
import 'package:flutter_video_editor/core/services/tracking/native_tracker.dart';
import 'package:flutter_video_editor/features/editor/controllers/editor_controller.dart';
import 'package:flutter_video_editor/features/editor/widgets/editor_toolbar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Object Tracking Toolbar & State Tests', () {
    testWidgets('EditorToolbar shows Tracking tool for text clip', (tester) async {
      final editor = EditorController();
      final textClip = TimelineClip(
        id: 'c_text',
        label: 'My Text',
        start: Duration.zero,
        end: const Duration(seconds: 5),
        clipType: ClipType.text,
      );
      editor.addClip(textClip);
      editor.selectClip(textClip.id);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<EditorController>.value(
              value: editor,
              child: EditorToolbar(
                onSelectToolSheet: (_) {},
                onAddMedia: () {},
                onAddOverlay: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('Tracking'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(milliseconds: 700));
    });

    testWidgets('EditorToolbar shows Tracking tool for element clip', (tester) async {
      final editor = EditorController();
      final elClip = TimelineClip(
        id: 'c_element',
        label: 'Shape',
        start: Duration.zero,
        end: const Duration(seconds: 5),
        clipType: ClipType.element,
      );
      editor.addClip(elClip);
      editor.selectClip(elClip.id);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<EditorController>.value(
              value: editor,
              child: EditorToolbar(
                onSelectToolSheet: (_) {},
                onAddMedia: () {},
                onAddOverlay: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('Tracking'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(milliseconds: 700));
    });

    testWidgets('EditorToolbar shows Tracking tool for sticker clip', (tester) async {
      final editor = EditorController();
      final stickerClip = TimelineClip(
        id: 'c_sticker',
        label: 'Emoji',
        start: Duration.zero,
        end: const Duration(seconds: 5),
        clipType: ClipType.sticker,
      );
      editor.addClip(stickerClip);
      editor.selectClip(stickerClip.id);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<EditorController>.value(
              value: editor,
              child: EditorToolbar(
                onSelectToolSheet: (_) {},
                onAddMedia: () {},
                onAddOverlay: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('Tracking'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(milliseconds: 700));
    });

    testWidgets('EditorToolbar does NOT show Tracking tool for video or audio clips or unselected', (tester) async {
      final editor = EditorController();

      // No clip selected
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<EditorController>.value(
              value: editor,
              child: EditorToolbar(
                onSelectToolSheet: (_) {},
                onAddMedia: () {},
                onAddOverlay: () {},
              ),
            ),
          ),
        ),
      );
      expect(find.text('Tracking'), findsNothing);

      // Video clip selected
      final vidClip = TimelineClip(
        id: 'c_vid',
        label: 'Main Video',
        start: Duration.zero,
        end: const Duration(seconds: 5),
        clipType: ClipType.video,
      );
      editor.addClip(vidClip);
      editor.selectClip(vidClip.id);
      await tester.pump();

      expect(find.text('Tracking'), findsNothing);
      await tester.pumpAndSettle(const Duration(milliseconds: 700));
    });

    test('Tracking pointer mode toggle and progress execution in EditorController', () async {
      final editor = EditorController();
      final textClip = TimelineClip(
        id: 'txt_1',
        label: 'Hello',
        start: Duration.zero,
        end: const Duration(seconds: 4),
        clipType: ClipType.text,
      );
      editor.addClip(textClip);
      editor.selectClip(textClip.id);

      expect(editor.isTrackingPointerMode, isFalse);
      editor.startTrackingPointerMode();
      expect(editor.isTrackingPointerMode, isTrue);

      editor.updateTrackingTargetPoint(const Offset(0.35, 0.45));
      expect(editor.trackingTargetPoint.dx, closeTo(0.35, 0.001));
      expect(editor.trackingTargetPoint.dy, closeTo(0.45, 0.001));

      // Run tracking
      final future = editor.runTrackingForSelectedClip();
      expect(editor.isTrackingRunning, isTrue);
      await future;
      expect(editor.isTrackingRunning, isFalse);

      final updatedClip = editor.selectedClip!;
      expect(updatedClip.trackingData.isEnabled, isTrue);
      expect(updatedClip.trackingData.points, isNotEmpty);
    });

    test('TrackingData serialization and pointAt interpolation', () {
      const tracking = TrackingData(
        isEnabled: true,
        targetName: 'Item',
        rect: Rect.fromLTWH(0.2, 0.2, 0.2, 0.2),
        smoothness: 0.5,
        points: [
          {'t': 0.0, 'cx': 0.2, 'cy': 0.3, 'w': 0.1, 'h': 0.1, 'found': true},
          {'t': 2.0, 'cx': 0.4, 'cy': 0.5, 'w': 0.1, 'h': 0.1, 'found': true},
        ],
      );

      final json = tracking.toJson();
      final recovered = TrackingData.fromJson(json);

      expect(recovered.isEnabled, isTrue);
      expect(recovered.points.length, equals(2));

      final pts = recovered.points.map((p) => TrackPoint.fromMap(p)).toList();
      final midPoint = pointAt(pts, 1.0);
      expect(midPoint, isNotNull);
      expect(midPoint!.cx, closeTo(0.3, 0.01));
      expect(midPoint.cy, closeTo(0.4, 0.01));
    });
  });
}
