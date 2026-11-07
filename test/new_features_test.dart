import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flutter_video_editor/core/models/project_model.dart';
import 'package:flutter_video_editor/features/editor/controllers/editor_controller.dart';
import 'package:flutter_video_editor/features/editor/widgets/editor_toolbar.dart';
import 'package:flutter_video_editor/features/editor/widgets/preview.dart';
import 'package:flutter_video_editor/features/editor/widgets/timeline.dart';
import 'package:flutter_video_editor/features/editor/widgets/tool_panel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('New Feature Requirements Tests', () {
    testWidgets('Long press on clip enables multi selection and updates preview top bar with Group and count', (tester) async {
      final controller = EditorController();
      addTearDown(controller.dispose);
      final c1 = TimelineClip(
        id: 'clip_1',
        label: 'Text 1',
        start: Duration.zero,
        end: const Duration(seconds: 4),
        clipType: ClipType.text,
        layerIndex: 1,
      );
      final c2 = TimelineClip(
        id: 'clip_2',
        label: 'Text 2',
        start: const Duration(seconds: 4),
        end: const Duration(seconds: 8),
        clipType: ClipType.text,
        layerIndex: 1,
      );
      controller.addClip(c1);
      controller.addClip(c2);
      controller.selectClip('clip_1');

      final multiOn = ValueNotifier<bool>(false);
      final multi = ValueNotifier<Set<String>>(<String>{});

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<EditorController>.value(
              value: controller,
              child: SizedBox(
                width: 800,
                height: 600,
                child: Column(
                  children: [
                    Expanded(
                      flex: 1,
                      child: PreviewCanvas(editor: controller),
                    ),
                    Expanded(
                      flex: 1,
                      child: TimelineWidget(
                        editor: controller,
                        multiOn: multiOn,
                        multi: multi,
                        onClearMulti: () {},
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      // Initially only 1 clip selected -> Quality and Export buttons shown
      expect(find.text('Export'), findsOneWidget);
      expect(find.text('HD'), findsOneWidget);

      // Long press on Text 2 to trigger multi-selection
      final clip2Finder = find.text('Text 2');
      expect(clip2Finder, findsOneWidget);
      await tester.longPress(clip2Finder);
      await tester.pump();

      // Multi-selection is now active:
      expect(multiOn.value, isTrue);
      expect(controller.selectedLayerCount, greaterThanOrEqualTo(2));

      // Header hides Export & HD and shows Group & count
      expect(find.text('Export'), findsNothing);
      expect(find.text('HD'), findsNothing);
      expect(find.text('Group'), findsOneWidget);
      expect(find.text('${controller.selectedLayerCount} Selected'), findsOneWidget);

      // Tapping Group combines them into the same group
      await tester.tap(find.text('Group'));
      await tester.pump(const Duration(milliseconds: 700));

      final g1 = controller.project.clips.firstWhere((c) => c.id == 'clip_1').groupId;
      final g2 = controller.project.clips.firstWhere((c) => c.id == 'clip_2').groupId;
      expect(g1, isNotNull);
      expect(g1, equals(g2));
    });

    testWidgets('MaskSheet header contains Element import button and applies element shape mask', (tester) async {
      final controller = EditorController();
      addTearDown(controller.dispose);
      final clip = TimelineClip(
        id: 'clip_mask_test',
        label: 'Video',
        start: Duration.zero,
        end: const Duration(seconds: 4),
        clipType: ClipType.video,
      );
      controller.addClip(clip);
      controller.selectClip('clip_mask_test');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<EditorController>.value(
              value: controller,
              child: ToolPanel(
                tool: EditorTool.mask,
                onClose: () {},
              ),
            ),
          ),
        ),
      );

      // Find the Import Element button in header
      final importBtnFinder = find.byTooltip('Import Element');
      expect(importBtnFinder, findsOneWidget);

      // Tap import element button to open element shapes bottom sheet
      await tester.tap(importBtnFinder);
      await tester.pumpAndSettle();

      expect(find.text('Import Mask from Element'), findsOneWidget);

      // Find Star in bottom sheet and tap it
      final starInSheet = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('Star'),
      );
      expect(starInSheet, findsOneWidget);
      await tester.tap(starInSheet);
      await tester.pumpAndSettle();

      // Mask should now be active with star shape
      expect(controller.selectedClip?.maskProperties.type, equals(MaskType.star));

      // Settle any autosave timers before teardown
      await tester.pump(const Duration(milliseconds: 700));
    });

    test('convertTextClipToSvg converts text clip to svg and adds to elements', () {
      final controller = EditorController();
      addTearDown(controller.dispose);
      final textClip = TimelineClip(
        id: 'txt_test_1',
        label: 'Hello SVG World',
        start: Duration.zero,
        end: const Duration(seconds: 3),
        clipType: ClipType.text,
        textStyle: const TextStyleProperties(
          fontSize: 32,
          textColor: Colors.cyan,
        ),
      );
      controller.addClip(textClip);
      controller.selectClip('txt_test_1');

      final initialClipsCount = controller.project.clips.length;
      controller.convertTextClipToSvg('txt_test_1');

      expect(controller.project.clips.length, equals(initialClipsCount + 1));
      final newElementClip = controller.project.clips.last;
      expect(newElementClip.clipType, equals(ClipType.element));
      expect(newElementClip.label, contains('Hello SVG World'));
      expect(newElementClip.elementProperties.svgPath, isNotNull);
      expect(newElementClip.elementProperties.svgPath, contains('<svg'));
      expect(newElementClip.elementProperties.svgPath, contains('Hello SVG World'));
    });

    testWidgets('EditorToolbar shows To SVG button for text clips', (tester) async {
      final controller = EditorController();
      addTearDown(controller.dispose);
      final textClip = TimelineClip(
        id: 'txt_test_2',
        label: 'Sample Text',
        start: Duration.zero,
        end: const Duration(seconds: 3),
        clipType: ClipType.text,
      );
      controller.addClip(textClip);
      controller.selectClip('txt_test_2');

      await tester.pumpWidget(
        ChangeNotifierProvider<EditorController>.value(
          value: controller,
          child: MaterialApp(
            home: Scaffold(
              body: EditorToolbar(
                onSelectToolSheet: (_) {},
                onAddMedia: () {},
                onAddOverlay: () {},
              ),
            ),
          ),
        ),
      );

      final toSvgFinder = find.text('To SVG');
      expect(toSvgFinder, findsOneWidget);

      await tester.tap(toSvgFinder);
      await tester.pump(const Duration(milliseconds: 700));

      final elementClip = controller.project.clips.firstWhere((c) => c.clipType == ClipType.element);
      expect(elementClip.label, contains('Sample Text'));
    });
  });
}
