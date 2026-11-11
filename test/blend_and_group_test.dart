import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flutter_video_editor/core/models/project_model.dart';
import 'package:flutter_video_editor/features/editor/controllers/editor_controller.dart';
import 'package:flutter_video_editor/features/editor/widgets/editor_toolbar.dart';
import 'package:flutter_video_editor/features/editor/widgets/blend_sheet.dart';
import 'package:flutter_video_editor/features/editor/widgets/tool_panel.dart';
import 'package:flutter_video_editor/features/editor/widgets/transport.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Blend Model and Controller Tests', () {
    test('BlendProperties serialization and deserialization', () {
      const props = BlendProperties(
        type: BlendType.screen,
        opacity: 0.85,
      );
      final json = props.toJson();
      final fromJson = BlendProperties.fromJson(json);

      expect(fromJson.type, equals(BlendType.screen));
      expect(fromJson.opacity, closeTo(0.85, 0.001));
      expect(fromJson.isActive, isTrue);
    });

    test('TimelineClip retains and updates blend properties and groupId', () {
      final clip = TimelineClip(
        id: 'clip_b1',
        label: 'Video 1',
        start: Duration.zero,
        end: const Duration(seconds: 4),
        clipType: ClipType.video,
        blendProperties: const BlendProperties(type: BlendType.multiply, opacity: 0.7),
        groupId: 'group_test',
      );

      final json = clip.toJson();
      final restored = TimelineClip.fromJson(json);

      expect(restored.blendProperties.type, equals(BlendType.multiply));
      expect(restored.blendProperties.opacity, closeTo(0.7, 0.001));
      expect(restored.groupId, equals('group_test'));
    });

    test('EditorController updateBlendProperties updates selected clip', () {
      final controller = EditorController();
      addTearDown(controller.dispose);
      final clip = TimelineClip(
        id: 'clip_b2',
        label: 'Video 2',
        start: Duration.zero,
        end: const Duration(seconds: 4),
        clipType: ClipType.video,
      );
      controller.addClip(clip);
      controller.selectClip('clip_b2');

      controller.updateBlendProperties(const BlendProperties(type: BlendType.overlay, opacity: 0.6));
      expect(controller.selectedClip?.blendProperties.type, equals(BlendType.overlay));
      expect(controller.selectedClip?.blendProperties.opacity, closeTo(0.6, 0.001));
    });
  });

  group('Toolbar Blend Tool Tests', () {
    testWidgets('EditorToolbar shows Blend tool for video/image clip', (tester) async {
      final controller = EditorController();
      addTearDown(controller.dispose);
      final clip = TimelineClip(
        id: 'v_clip',
        label: 'Video',
        start: Duration.zero,
        end: const Duration(seconds: 5),
        clipType: ClipType.video,
      );
      controller.addClip(clip);
      controller.selectClip('v_clip');

      String? openedSheet;
      await tester.pumpWidget(
        ChangeNotifierProvider<EditorController>.value(
          value: controller,
          child: MaterialApp(
            home: Scaffold(
              body: EditorToolbar(
                onSelectToolSheet: (sheet) => openedSheet = sheet,
                onAddMedia: () {},
                onAddOverlay: () {},
              ),
            ),
          ),
        ),
      );

      final blendFinder = find.text('Blend');
      expect(blendFinder, findsOneWidget);
      await tester.tap(blendFinder);
      await tester.pump(const Duration(milliseconds: 700));
      expect(openedSheet, equals('blend'));
    });

    testWidgets('BlendSheet renders and updates blend mode', (tester) async {
      final controller = EditorController();
      addTearDown(controller.dispose);
      final clip = TimelineClip(
        id: 'v_clip_sheet',
        label: 'Video',
        start: Duration.zero,
        end: const Duration(seconds: 5),
        clipType: ClipType.video,
      );
      controller.addClip(clip);
      controller.selectClip('v_clip_sheet');

      await tester.pumpWidget(
        ChangeNotifierProvider<EditorController>.value(
          value: controller,
          child: const MaterialApp(
            home: Scaffold(
              body: BlendSheet(),
            ),
          ),
        ),
      );

      expect(find.text('Opacity'), findsOneWidget);
      expect(find.text('Normal'), findsOneWidget);
      expect(find.text('Darken'), findsOneWidget);

      await tester.tap(find.text('Darken'));
      await tester.pump(const Duration(milliseconds: 700));
      expect(controller.selectedClip?.blendProperties.type, equals(BlendType.darken));
    });

    test('EditorTool.blend builds BlendSheet widget', () {
      final widget = EditorTool.blend.buildBody(() {});
      expect(widget, isA<BlendSheet>());
    });
  });

  group('Multi-Layer Selection and Transport Bar Group Button Tests', () {
    testWidgets('TransportBar displays More button and provides Group and Ungroup actions', (tester) async {
      final controller = EditorController();
      addTearDown(controller.dispose);
      final c1 = TimelineClip(
        id: 'c1',
        label: 'Clip 1',
        start: Duration.zero,
        end: const Duration(seconds: 3),
        clipType: ClipType.video,
      );
      final c2 = TimelineClip(
        id: 'c2',
        label: 'Clip 2',
        start: Duration.zero,
        end: const Duration(seconds: 3),
        clipType: ClipType.image,
      );
      controller.addClip(c1);
      controller.addClip(c2);

      await tester.pumpWidget(
        ChangeNotifierProvider<EditorController>.value(
          value: controller,
          child: MaterialApp(
            home: Scaffold(
              body: TransportBar(editor: controller),
            ),
          ),
        ),
      );

      // Group button is removed from main TransportBar
      expect(find.byTooltip('Group'), findsNothing);

      // More button is present at the right
      expect(find.byTooltip('More'), findsOneWidget);

      // Select multiple layers
      controller.setMultiSelectedClips(['c1', 'c2']);
      await tester.pump();

      // Open More menu
      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();

      expect(find.text('Group selected clips'), findsOneWidget);
      await tester.tap(find.text('Group selected clips'));
      await tester.pumpAndSettle();

      // Both clips should now have the same groupId assigned
      final group1 = controller.project.clips.firstWhere((c) => c.id == 'c1').groupId;
      final group2 = controller.project.clips.firstWhere((c) => c.id == 'c2').groupId;
      expect(group1, isNotNull);
      expect(group1, equals(group2));

      // Now ungroup clips
      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      expect(find.text('Ungroup clips'), findsOneWidget);
      await tester.tap(find.text('Ungroup clips'));
      await tester.pumpAndSettle();

      expect(controller.project.clips.firstWhere((c) => c.id == 'c1').groupId, isNull);
      expect(controller.project.clips.firstWhere((c) => c.id == 'c2').groupId, isNull);

      await tester.pump(const Duration(milliseconds: 700));
    });
  });
}
