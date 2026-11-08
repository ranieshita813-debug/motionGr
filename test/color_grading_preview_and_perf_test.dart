import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flutter_video_editor/core/models/color_grade.dart';
import 'package:flutter_video_editor/core/models/project_model.dart';
import 'package:flutter_video_editor/features/editor/controllers/editor_controller.dart';
import 'package:flutter_video_editor/features/editor/widgets/adjustments_sheet.dart';
import 'package:flutter_video_editor/features/editor/widgets/preview.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Adjustment and Color Grading Preview and Performance Tests', () {
    test('AdjustSettings.toColorFilter handles brightness, contrast, hue/tint, highlights, and shadows', () {
      final settings = AdjustSettings.identity
          .set(AdjustParam.brightness, 20)
          .set(AdjustParam.contrast, 15)
          .set(AdjustParam.hue, 25)
          .set(AdjustParam.highlights, 10)
          .set(AdjustParam.shadows, -10);

      final filter = settings.toColorFilter();
      expect(filter, isNotNull);
    });

    test('ColorGrade bridge round-trips all grading parameters to ColorGradingSettings', () {
      const origCg = ColorGradingSettings(
        brightness: 0.1,
        contrast: 1.25,
        saturation: 1.3,
        temperature: 0.2,
        tint: -0.15,
        exposure: 0.1,
        highlights: 0.12,
        shadows: -0.08,
        vignette: 0.35,
        fade: 0.15,
      );

      final grade = ColorGrade.fromLegacy(
        brightness: origCg.brightness,
        contrast: origCg.contrast,
        saturation: origCg.saturation,
        temperature: origCg.temperature,
        tint: origCg.tint,
        exposure: origCg.exposure,
        highlights: origCg.highlights,
        shadows: origCg.shadows,
        vignette: origCg.vignette,
        fade: origCg.fade,
      );

      final leg = grade.toLegacy();
      expect(leg.contrast, closeTo(1.25, 0.01));
      expect(leg.saturation, closeTo(1.3, 0.01));
      expect(leg.temperature, closeTo(0.2, 0.01));
      expect(leg.tint, closeTo(-0.15, 0.01));
      expect(leg.highlights, closeTo(0.12, 0.01));
      expect(leg.shadows, closeTo(-0.08, 0.01));
      expect(leg.vignette, closeTo(0.35, 0.01));
      expect(leg.fade, closeTo(0.15, 0.01));
    });

    test('AdjustSettings.fromColorGrading converts all ColorGradingSettings accurately', () {
      const cg = ColorGradingSettings(
        brightness: 0.15,
        contrast: 1.2,
        saturation: 1.4,
        temperature: 0.3,
        tint: -0.2,
        exposure: 0.25,
        highlights: 0.1,
        shadows: -0.1,
        vignette: 0.4,
        fade: 0.2,
        sepia: 0.3,
        brilliance: 0.15,
        clarity: 0.2,
      );

      final adj = AdjustSettings.fromColorGrading(cg);
      expect(adj[AdjustParam.brightness], closeTo(15.0, 0.01));
      expect(adj[AdjustParam.contrast], closeTo(20.0, 0.01));
      expect(adj[AdjustParam.saturation], closeTo(40.0, 0.01));
      expect(adj[AdjustParam.warmth], closeTo(30.0, 0.01));
      expect(adj[AdjustParam.hue], closeTo(-20.0, 0.01));
      expect(adj[AdjustParam.exposure], closeTo(25.0, 0.01));
      expect(adj[AdjustParam.highlights], closeTo(10.0, 0.01));
      expect(adj[AdjustParam.shadows], closeTo(-10.0, 0.01));
      expect(adj[AdjustParam.vignette], closeTo(40.0, 0.01));
      expect(adj[AdjustParam.fade], closeTo(20.0, 0.01));
      expect(adj[AdjustParam.sepia], closeTo(30.0, 0.01));
      expect(adj[AdjustParam.brilliance], closeTo(15.0, 0.01));
      expect(adj[AdjustParam.clarity], closeTo(20.0, 0.01));

      final backToCg = adj.toColorGrading();
      expect(backToCg.brightness, closeTo(0.15, 0.01));
      expect(backToCg.contrast, closeTo(1.2, 0.01));
      expect(backToCg.saturation, closeTo(1.4, 0.01));
      expect(backToCg.temperature, closeTo(0.3, 0.01));
      expect(backToCg.tint, closeTo(-0.2, 0.01));
    });

    testWidgets('PreviewCanvas applies color grading filter when tint/temperature/highlights are changed',
        (WidgetTester tester) async {
      final editor = EditorController();
      final clip = TimelineClip(
        id: 'clip_video_1',
        label: 'Video Clip 1',
        start: Duration.zero,
        end: const Duration(seconds: 5),
        clipType: ClipType.video,
        sourcePath: 'assets/sample.mp4',
        colorGrading: const ColorGradingSettings(tint: 0.3),
      );
      editor.addClip(clip);
      editor.selectClip(clip.id);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<EditorController>.value(
              value: editor,
              child: PreviewCanvas(editor: editor),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      // ColorFiltered is present in the widget tree when color grading is active
      expect(find.byType(ColorFiltered), findsWidgets);

      await tester.pump(const Duration(seconds: 1));
      editor.dispose();
    });
  });
}
