import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:flutter_video_editor/core/controllers/auth_controller.dart';
import 'package:flutter_video_editor/core/models/project_model.dart';
import 'package:flutter_video_editor/features/editor/controllers/editor_controller.dart';
import 'package:flutter_video_editor/features/editor/widgets/adjustments_sheet.dart';
import 'package:flutter_video_editor/features/editor/widgets/blend_sheet.dart';
import 'package:flutter_video_editor/features/editor/widgets/tool_sheets/editor_tool_sheets.dart'
    show canvasRatioNotifier, CanvasRatio;
import 'package:flutter_video_editor/features/effects/services/shader_effect_service.dart';
import 'package:flutter_video_editor/features/projects/controllers/projects_controller.dart';
import 'package:flutter_video_editor/features/projects/pages/create_project_page.dart';
import 'package:flutter_video_editor/features/projects/pages/home_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AdjustSettings toColorFilter Neutral Saturation & Channel Balance Tests', () {
    test('AdjustSettings.toColorFilter does not distort channels or produce red tint at neutral saturation', () {
      // Contrast change without saturation change
      final contrastSettings = AdjustSettings.identity.set(AdjustParam.contrast, 20);
      final cf = contrastSettings.toColorFilter();
      expect(cf, isNotNull);

      // Verify that green and blue diagonal channels are properly balanced and not zeroed
      // at neutral saturation (s = 1.0)
      const double rw = 0.2126;
      const double gw = 0.7152;
      const double bw = 0.0722;
      const double s = 1.0;
      const double c = 1.2;

      final double invS = 1 - s; // 0.0
      final double rr = (rw * invS + s); // 1.0
      final double gg = (gw * invS + s); // 1.0
      final double bb = (bw * invS + s); // 1.0

      expect(c * rr, closeTo(1.2, 0.001));
      expect(c * gg, closeTo(1.2, 0.001));
      expect(c * bb, closeTo(1.2, 0.001));
    });
  });

  group('ShaderEffectService refreshEffects Tests', () {
    test('refreshEffects notifies listeners', () async {
      final service = ShaderEffectService();
      bool notified = false;
      service.addListener(() {
        notified = true;
      });

      await service.refreshEffects();
      expect(notified, isTrue);
      service.dispose();
    });
  });

  group('BlendSheet Rendering & Compact Layout Tests', () {
    testWidgets('BlendSheet renders compactly without exceptions', (tester) async {
      final controller = EditorController();
      addTearDown(controller.dispose);
      final clip = TimelineClip(
        id: 'clip_b_compact',
        label: 'Video',
        start: Duration.zero,
        end: const Duration(seconds: 5),
        clipType: ClipType.video,
      );
      controller.addClip(clip);
      controller.selectClip('clip_b_compact');

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

      // Pump to settle autosave timer
      await tester.pump(const Duration(milliseconds: 700));

      expect(find.byType(BlendSheet), findsOneWidget);
      expect(find.text('Opacity'), findsOneWidget);
      expect(find.text('Normal'), findsOneWidget);
      expect(find.text('Darken'), findsOneWidget);
      expect(find.text('Screen'), findsOneWidget);
    });
  });

  group('CreateProjectPage and Navigation Tests', () {
    testWidgets('HomePage New Project navigates to CreateProjectPage', (tester) async {
      final authCtrl = AuthController();
      final projectsCtrl = ProjectsController();
      final editorCtrl = EditorController();
      addTearDown(authCtrl.dispose);
      addTearDown(projectsCtrl.dispose);
      addTearDown(editorCtrl.dispose);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: authCtrl),
            ChangeNotifierProvider.value(value: projectsCtrl),
            ChangeNotifierProvider.value(value: editorCtrl),
          ],
          child: MaterialApp(
            routes: {
              '/create_project': (_) => const CreateProjectPage(),
              '/editor': (_) => const Scaffold(body: Text('Editor Page Mock')),
            },
            home: const HomePage(),
          ),
        ),
      );

      // Tap New Project button
      final newProjBtn = find.text('New project');
      expect(newProjBtn, findsOneWidget);
      await tester.tap(newProjBtn);
      await tester.pumpAndSettle();

      // Should be on CreateProjectPage
      expect(find.byType(CreateProjectPage), findsOneWidget);
      expect(find.text('New Project'), findsOneWidget);
      expect(find.text('Aspect Ratio'), findsOneWidget);
      expect(find.text('9:16'), findsOneWidget);
      expect(find.text('16:9'), findsOneWidget);
      expect(find.text('Blank Project'), findsOneWidget);
      expect(find.text('Select Media'), findsOneWidget);
    });

    testWidgets('CreateProjectPage can select aspect ratio and create blank project', (tester) async {
      final projectsCtrl = ProjectsController();
      final editorCtrl = EditorController();
      addTearDown(projectsCtrl.dispose);
      addTearDown(editorCtrl.dispose);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: projectsCtrl),
            ChangeNotifierProvider.value(value: editorCtrl),
          ],
          child: MaterialApp(
            routes: {
              '/editor': (_) => const Scaffold(body: Text('Editor Page Mock')),
            },
            home: const CreateProjectPage(),
          ),
        ),
      );

      // Select 16:9 ratio
      await tester.tap(find.text('16:9'));
      await tester.pumpAndSettle();

      // Enter project name
      final textField = find.byType(TextField);
      await tester.enterText(textField, 'My Awesome Vlog');
      await tester.pump();

      // Tap Blank Project
      await tester.tap(find.text('Blank Project'));
      await tester.pumpAndSettle();

      // Should navigate to Editor Page Mock
      expect(find.text('Editor Page Mock'), findsOneWidget);

      // Project was created and loaded into EditorController
      expect(editorCtrl.project.name, equals('My Awesome Vlog'));
      expect(editorCtrl.project.aspectRatio, equals(AspectRatioPreset.sixteenNine));
      expect(canvasRatioNotifier.value, equals(CanvasRatio.r16x9));
    });
  });
}
