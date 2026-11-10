import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/app/widgets/release_notes_view.dart';
import 'package:oronbox/src/app/widgets/inline_markdown_text.dart';

void main() {
  testWidgets('release notes retain typography and block spacing', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ReleaseNotesView(data: 'First\n\nSecond')),
      ),
    );
    final first = find.text('First', findRichText: true);
    final second = find.text('Second', findRichText: true);
    expect(tester.getTopLeft(second).dy - tester.getBottomLeft(first).dy, 10);
    final markdown = tester.widget<MarkdownBody>(find.byType(MarkdownBody));
    expect(markdown.styleSheet!.p!.height, 1.45);
    expect(markdown.styleSheet!.code!.height, 1.4);
    expect(markdown.styleSheet!.codeblockPadding, EdgeInsets.zero);
    expect(tester.getTopLeft(first), Offset.zero);
  });

  testWidgets('message Markdown preserves inherited size and outer bounds', (
    tester,
  ) async {
    const style = TextStyle(fontSize: 13, height: 1.3);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DefaultTextStyle(
            style: style,
            child: InlineMarkdownText('**bold** and `code`'),
          ),
        ),
      ),
    );
    final markdown = tester.widget<MarkdownBody>(find.byType(MarkdownBody));
    expect(markdown.styleSheet!.p!.fontSize, 13);
    expect(markdown.styleSheet!.p!.height, 1.3);
    expect(markdown.styleSheet!.blockSpacing, 0);
    final text = find.byWidgetPredicate(
      (widget) =>
          widget is Text && widget.textSpan?.toPlainText() == 'bold and code',
    );
    expect(text, findsOneWidget);
    expect(tester.getTopLeft(text), Offset.zero);
  });
}
