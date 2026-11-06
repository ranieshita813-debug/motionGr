import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flutter_video_editor/core/models/project_model.dart';
import 'package:flutter_video_editor/features/editor/controllers/editor_controller.dart';
import 'package:flutter_video_editor/features/editor/widgets/keyframe_controls.dart';
import 'package:flutter_video_editor/features/editor/utils/editor_helpers.dart';
import 'package:flutter_video_editor/core/theme/app_theme.dart';
import 'package:flutter_video_editor/features/editor/pages/editor_page.dart';
import 'package:flutter_video_editor/features/editor/widgets/timeline.dart';
import 'package:flutter_video_editor/features/editor/widgets/transport.dart';
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

    test('AppTheme defaults to HelveticaNeue font', () {
      expect(AppTheme.defaultFontFamily, equals('HelveticaNeue'));
      expect(AppTheme.darkTheme.textTheme.bodyLarge?.fontFamily, equals('HelveticaNeue'));
      expect(AppTheme.darkTheme.textTheme.headlineMedium?.fontFamily, equals('HelveticaNeue'));
    });

    testWidgets('EditorPage keeps TransportBar and TimelineWidget visible when Mask tool is active', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844); // mobile phone screen
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final controller = EditorController();
      final clip = TimelineClip(
        id: 'clip_mobile',
        label: 'Video',
        start: Duration.zero,
        end: const Duration(seconds: 10),
        clipType: ClipType.video,
      );
      controller.addClip(clip);
      controller.selectClip('clip_mobile');

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: ChangeNotifierProvider<EditorController>.value(
            value: controller,
            child: const Scaffold(
              body: EditorPage(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially timeline and transport bar are visible
      expect(find.byType(TransportBar), findsOneWidget);
      expect(find.byType(TimelineWidget), findsOneWidget);

      // Scroll and open Mask tool
      await tester.scrollUntilVisible(
        find.text('Mask'),
        100.0,
        scrollable: find.descendant(of: find.byType(EditorPage), matching: find.byType(Scrollable)).last,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Mask'));
      await tester.pumpAndSettle();

      // MaskSheet is open
      expect(find.byType(MaskSheet), findsOneWidget);

      // Crucial: Video TransportBar and TimelineWidget must remain visible!
      expect(find.byType(TransportBar), findsOneWidget);
      expect(find.byType(TimelineWidget), findsOneWidget);
    });
  });

  group('ToolPanel Keyframe Controls Tests', () {
    testWidgets('ToolPanel does not duplicate KeyframeControls when clip is selected', (WidgetTester tester) async {
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

        // KeyframeControls is NOT in ToolPanel header to avoid duplicates
        expect(find.byType(KeyframeControls), findsNothing);
      }
      await tester.pump(const Duration(milliseconds: 700));
    });

    test('Mask keyframes interpolation and updateMaskProperties with keyframes', () {
      final controller = EditorController();
      final clip = TimelineClip(
        id: 'clip_mask_kf',
        label: 'Mask KF Test',
        start: Duration.zero,
        end: const Duration(seconds: 10),
        clipType: ClipType.video,
        maskProperties: const MaskProperties(
          type: MaskType.circle,
          centerX: 0.2,
          centerY: 0.2,
          width: 0.3,
          height: 0.3,
          rotation: 0.0,
          feather: 0.0,
        ),
      );
      controller.addClip(clip);
      controller.selectClip('clip_mask_kf');

      // Add keyframe at 1.0s (start)
      seekPlayhead(controller, 1.0);
      controller.addKeyframeAtPlayhead();

      expect(
        controller.selectedClip!.keyframes.any((k) => k.property == KeyframeProperty.maskX),
        isTrue,
      );

      // Seek to 5.0s and modify mask properties via updateMaskProperties
      seekPlayhead(controller, 5.0);
      controller.updateMaskProperties(
        const MaskProperties(
          type: MaskType.circle,
          centerX: 0.8,
          centerY: 0.6,
          width: 0.7,
          height: 0.7,
          rotation: 1.5,
          feather: 20.0,
        ),
      );

      final updatedClip = controller.selectedClip!;
      final maskXKfs = updatedClip.keyframes.where((k) => k.property == KeyframeProperty.maskX).toList();
      expect(maskXKfs.length, greaterThanOrEqualTo(2));

      // Test interpolation at 1.0s
      final maskAt1s = getInterpolatedMaskProperties(updatedClip, const Duration(seconds: 1));
      expect(maskAt1s.centerX, closeTo(0.2, 0.05));
      expect(maskAt1s.centerY, closeTo(0.2, 0.05));

      // Test interpolation at 3.0s (halfway between 1s and 5s: 0.2 -> 0.8 => 0.5)
      final maskAt3s = getInterpolatedMaskProperties(updatedClip, const Duration(seconds: 3));
      expect(maskAt3s.centerX, closeTo(0.5, 0.05));
      expect(maskAt3s.centerY, closeTo(0.4, 0.05));
      expect(maskAt3s.feather, closeTo(10.0, 0.05));

      // Test interpolation at 5.0s
      final maskAt5s = getInterpolatedMaskProperties(updatedClip, const Duration(seconds: 5));
      expect(maskAt5s.centerX, closeTo(0.8, 0.05));
      expect(maskAt5s.centerY, closeTo(0.6, 0.05));
      expect(maskAt5s.feather, closeTo(20.0, 0.05));
    });
  });
}
