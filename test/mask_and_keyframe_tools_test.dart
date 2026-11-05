import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flutter_video_editor/core/models/project_model.dart';
import 'package:flutter_video_editor/features/editor/controllers/editor_controller.dart';
import 'package:flutter_video_editor/features/editor/widgets/keyframe_controls.dart';
import 'package:flutter_video_editor/features/editor/utils/editor_helpers.dart';
import 'package:flutter_video_editor/features/editor/widgets/tool_panel.dart';
import 'package:flutter_video_editor/features/editor/widgets/tool_sheets/mask.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MaskProperties and mask.dart Tests', () {
    test('MaskProperties supports centerX, centerY, cornerRadius, invert aliases and serialization', () {
      const props = MaskProperties(
        type: MaskType.rectangle,
        centerX: 0.6,
        centerY: 0.4,
        width: 0.8,
        height: 0.5,
        rotation: 0.2,
        cornerRadius: 0.15,
        feather: 15.0,
        invert: true,
      );

      expect(props.centerX, equals(0.6));
      expect(props.positionX, equals(0.6));
      expect(props.centerY, equals(0.4));
      expect(props.positionY, equals(0.4));
      expect(props.cornerRadius, equals(0.15));
      expect(props.invert, isTrue);
      expect(props.isInverted, isTrue);

      final json = props.toJson();
      final fromJson = MaskProperties.fromJson(json);

      expect(fromJson.type, equals(MaskType.rectangle));
      expect(fromJson.centerX, equals(0.6));
      expect(fromJson.centerY, equals(0.4));
      expect(fromJson.cornerRadius, equals(0.15));
      expect(fromJson.invert, isTrue);
    });

    testWidgets('MaskSheet renders full capcut-style mask controls and applies mask to clip', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final controller = EditorController();
      final clip = TimelineClip(
        id: 'clip_1',
        label: 'Video 1',
        start: Duration.zero,
        end: const Duration(seconds: 5),
        clipType: ClipType.video,
      );
      controller.addClip(clip);
      controller.selectClip('clip_1');

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<EditorController>.value(
            value: controller,
            child: const Scaffold(
              body: MaskSheet(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // MaskSheet contains 'Invert' and shape tiles like 'Circle'
      expect(find.text('Invert'), findsOneWidget);
      expect(find.text('None'), findsOneWidget);
      expect(find.text('Circle'), findsOneWidget);

      // Tap 'Circle'
      await tester.tap(find.text('Circle'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 700));

      final updatedClip = controller.selectedClip;
      expect(updatedClip?.maskProperties.type, equals(MaskType.circle));
    });
  });

  group('ToolPanel Keyframe Controls Tests', () {
    testWidgets('ToolPanel renders KeyframeControls for all tools when clip is selected', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final controller = EditorController();
      final clip = TimelineClip(
        id: 'test_clip',
        label: 'Test Clip',
        start: Duration.zero,
        end: const Duration(seconds: 10),
        clipType: ClipType.video,
      );
      controller.addClip(clip);
      controller.selectClip('test_clip');

      // Test across multiple tools: mask, adjust, effects, filters
      final toolsToTest = [
        EditorTool.mask,
        EditorTool.adjust,
        EditorTool.effects,
        EditorTool.filters,
        EditorTool.colorGrading,
      ];

      for (final tool in toolsToTest) {
        await tester.pumpWidget(
          MaterialApp(
            home: ChangeNotifierProvider<EditorController>.value(
              value: controller,
              child: Scaffold(
                body: ToolPanel(
                  tool: tool,
                  onClose: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // KeyframeControls is present in ToolPanel
        expect(find.byType(KeyframeControls), findsOneWidget);

        // Add keyframe tooltip should be available
        expect(find.byTooltip('Add keyframe'), findsOneWidget);
      }
      await tester.pump(const Duration(milliseconds: 700));
    });

    testWidgets('Adding keyframe from ToolPanel updates clip keyframes', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final controller = EditorController();
      final clip = TimelineClip(
        id: 'clip_kf',
        label: 'Clip KF',
        start: Duration.zero,
        end: const Duration(seconds: 10),
        clipType: ClipType.video,
      );
      controller.addClip(clip);
      controller.selectClip('clip_kf');
      seekPlayhead(controller, 2.0);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<EditorController>.value(
            value: controller,
            child: Scaffold(
              body: ToolPanel(
                tool: EditorTool.mask,
                onClose: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(controller.selectedClip!.keyframes.isEmpty, isTrue);

      // Tap 'Add keyframe'
      await tester.tap(find.byTooltip('Add keyframe'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 700));

      expect(controller.selectedClip!.keyframes.isNotEmpty, isTrue);
      expect(find.byTooltip('Remove keyframe'), findsOneWidget);
    });
  });
}
