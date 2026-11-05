import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flutter_video_editor/core/models/project_model.dart';
import 'package:flutter_video_editor/features/editor/controllers/editor_controller.dart';
import 'package:flutter_video_editor/features/editor/widgets/editor_toolbar.dart';
import 'package:flutter_video_editor/features/editor/widgets/tool_panel.dart';
import 'package:flutter_video_editor/features/editor/widgets/tool_sheets/music_sheet.dart';
import 'package:flutter_video_editor/features/editor/widgets/tool_sheets/color_grading_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Music and Color Grading Sheet Tests', () {
    test('EditorTool enum contains music and keeps ai as the last item', () {
      expect(EditorTool.values.contains(EditorTool.music), isTrue);
      expect(EditorTool.values.last, equals(EditorTool.ai));
      expect(EditorTool.music.title, equals('Music'));
    });

    test('EditorController addAudioClip and addStickerOverlay work as expected', () {
      final editor = EditorController();
      editor.addAudioClip('/tmp/sample.mp3', title: 'Sample Song', duration: const Duration(seconds: 30));
      expect(editor.project.clips.any((c) => c.clipType == ClipType.audio && c.label == 'Sample Song'), isTrue);

      editor.addStickerOverlay('/tmp/sticker.png');
      expect(editor.project.clips.any((c) => c.sourcePath == '/tmp/sticker.png'), isTrue);
    });

    testWidgets('EditorToolbar renders Music tool when no clip is selected', (WidgetTester tester) async {
      final editor = EditorController();
      String? selectedSheet;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<EditorController>.value(
              value: editor,
              child: EditorToolbar(
                onSelectToolSheet: (sheet) => selectedSheet = sheet,
                onAddMedia: () {},
                onAddOverlay: () {},
              ),
            ),
          ),
        ),
      );

      final musicItem = find.text('Music');
      expect(musicItem, findsOneWidget);

      await tester.tap(musicItem);
      await tester.pumpAndSettle();
      expect(selectedSheet, equals('music'));
    });

    testWidgets('EditorToolbar renders Music tool when audio clip is selected', (WidgetTester tester) async {
      final editor = EditorController();
      final audioClip = TimelineClip(
        id: 'audio_1',
        label: 'My Audio',
        start: Duration.zero,
        end: const Duration(seconds: 10),
        clipType: ClipType.audio,
        layerIndex: 1,
      );
      editor.project.addClip(audioClip);
      editor.selectClip(audioClip.id);

      String? selectedSheet;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<EditorController>.value(
              value: editor,
              child: EditorToolbar(
                onSelectToolSheet: (sheet) => selectedSheet = sheet,
                onAddMedia: () {},
                onAddOverlay: () {},
              ),
            ),
          ),
        ),
      );

      final musicItem = find.text('Music');
      expect(musicItem, findsOneWidget);

      await tester.tap(musicItem);
      await tester.pumpAndSettle();
      expect(selectedSheet, equals('music'));
    });

    testWidgets('EditorTool.music body returns MusicSheet', (WidgetTester tester) async {
      final editor = EditorController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<EditorController>.value(
              value: editor,
              child: EditorTool.music.body,
            ),
          ),
        ),
      );

      expect(find.byType(MusicSheet), findsOneWidget);
    });

    testWidgets('EditorTool.colorGrading body returns ColorGradeSheet', (WidgetTester tester) async {
      final editor = EditorController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<EditorController>.value(
              value: editor,
              child: EditorTool.colorGrading.body,
            ),
          ),
        ),
      );

      expect(find.byType(ColorGradeSheet), findsOneWidget);
    });
  });
}
