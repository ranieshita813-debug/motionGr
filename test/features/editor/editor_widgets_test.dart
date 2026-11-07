import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flutter_video_editor/core/models/project_model.dart';
import 'package:flutter_video_editor/features/editor/controllers/editor_controller.dart';
import 'package:flutter_video_editor/features/editor/widgets/timeline.dart';
import 'package:flutter_video_editor/features/editor/widgets/preview.dart';
import 'package:flutter_video_editor/features/editor/widgets/tool_panel.dart';
import 'package:flutter_video_editor/features/editor/widgets/adjustments_sheet.dart';
import 'package:flutter_video_editor/features/editor/widgets/tool_sheets/editor_tool_sheets.dart';
import 'package:flutter_video_editor/features/editor/widgets/tool_sheets/elements_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late EditorController editor;

  setUp(() {
    canvasColorNotifier.value = Colors.black;
    editor = EditorController();
    final project = Project(
      id: 'proj_test',
      name: 'Test Project',
      clips: <TimelineClip>[
        TimelineClip(
          id: 'v1',
          label: 'Video 1',
          start: Duration.zero,
          end: const Duration(seconds: 5),
          clipType: ClipType.video,
          layerIndex: 0,
        ),
      ],
    );
    editor.loadProject(project);
  });

  group('Editor Widgets & Canvas Background Tests', () {
    testWidgets('TimelineWidget does not render blank lane placeholders (Add text, Add audio, etc)', (WidgetTester tester) async {
      final multiOn = ValueNotifier<bool>(false);
      final multi = ValueNotifier<Set<String>>(<String>{});

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<EditorController>.value(
              value: editor,
              child: TimelineWidget(
                editor: editor,
                multiOn: multiOn,
                multi: multi,
                onClearMulti: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify that placeholder tracks are not rendered
      expect(find.text('Add text'), findsNothing);
      expect(find.text('Add sticker'), findsNothing);
      expect(find.text('Add audio'), findsNothing);
    });

    testWidgets('canvasColorNotifier updates canvas background in PreviewCanvas', (WidgetTester tester) async {
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
      await tester.pumpAndSettle();

      // Default canvas color is black
      expect(canvasColorNotifier.value, equals(Colors.black));

      // Change canvas color to Teal
      canvasColorNotifier.value = const Color(0xFF00C4D6);
      await tester.pumpAndSettle();

      // Find DecoratedBox inside canvasColorBox with new color
      final decoratedBoxFinder = find.descendant(
        of: find.byKey(const ValueKey('canvasColorBox')),
        matching: find.byType(DecoratedBox),
      ).first;
      final DecoratedBox decoratedBox = tester.widget<DecoratedBox>(decoratedBoxFinder);
      final BoxDecoration decoration = decoratedBox.decoration as BoxDecoration;
      expect(decoration.color, equals(const Color(0xFF00C4D6)));

      // Set canvas color to transparent
      canvasColorNotifier.value = Colors.transparent;
      await tester.pumpAndSettle();
      final DecoratedBox transparentDecoratedBox = tester.widget<DecoratedBox>(decoratedBoxFinder);
      final BoxDecoration transparentDecoration = transparentDecoratedBox.decoration as BoxDecoration;
      expect(transparentDecoration.color, isNull);
    });

    testWidgets('ToolPanel with EditorTool.adjust renders without duplicate footers', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<EditorController>.value(
              value: editor,
              child: ToolPanel(
                tool: EditorTool.adjust,
                onClose: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // AdjustSheet should be present
      expect(find.byType(AdjustSheet), findsOneWidget);

      // Check that only ONE ToolPanel footer title "Adjust" is rendered in ToolPanel header/footer
      final adjustTextFinder = find.text('Adjust');
      expect(adjustTextFinder, findsNWidgets(2)); // Header title and Footer title in ToolPanel

      // Verify "Reset all" and "Hold to compare" actions exist inside AdjustSheet
      expect(find.byIcon(Icons.compare_rounded), findsOneWidget);
    });

    testWidgets('ToolPanel with EditorTool.elements renders without duplicate headers', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<EditorController>.value(
              value: editor,
              child: ToolPanel(
                tool: EditorTool.elements,
                onClose: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // ElementsSheet should be present
      expect(find.byType(ElementsSheet), findsOneWidget);

      // Verify that "Elements" text appears exactly twice (ToolPanel header and ToolPanel footer)
      expect(find.text('Elements'), findsNWidgets(2));

      // Verify no duplicate close arrow icon (Icons.keyboard_arrow_down_rounded) from old internal header
      expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsNothing);
    });

    testWidgets('PreviewCanvas renders with non-zero dimensions and displays media and overlays', (WidgetTester tester) async {
      final customEditor = EditorController();
      addTearDown(customEditor.dispose);
      customEditor.addTextOverlay('Preview Sample Text');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<EditorController>.value(
              value: customEditor,
              child: SizedBox(
                width: 400,
                height: 300,
                child: PreviewCanvas(editor: customEditor),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Verify canvas rendered size is non-zero
      final canvasBoxFinder = find.byKey(const ValueKey('canvasColorBox'));
      expect(canvasBoxFinder, findsOneWidget);
      final RenderBox renderBox = tester.renderObject(canvasBoxFinder) as RenderBox;
      expect(renderBox.size.width, greaterThan(0));
      expect(renderBox.size.height, greaterThan(0));

      // Verify the text overlay is rendered with non-zero dimensions
      final textFinder = find.text('Preview Sample Text');
      expect(textFinder, findsOneWidget);
      final RenderBox textRenderBox = tester.renderObject(textFinder) as RenderBox;
      expect(textRenderBox.size.width, greaterThan(0));
      expect(textRenderBox.size.height, greaterThan(0));

      // Let autosave timer settle
      await tester.pump(const Duration(milliseconds: 700));
    });
  });
}
