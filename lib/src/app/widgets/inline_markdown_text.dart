import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter/material.dart';

import 'markdown_style_sheet.dart';

class InlineMarkdownText extends StatelessWidget {
  const InlineMarkdownText(this.data, {super.key, this.style});

  final String data;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final base = DefaultTextStyle.of(context).style.merge(style);
    return MarkdownBody(
      data: data,
      softLineBreak: true,
      styleSheet: markdownStyleSheetFromTheme(Theme.of(context)).copyWith(
        p: base,
        blockSpacing: 0,
        pPadding: EdgeInsets.zero,
        code: base.copyWith(fontFamily: 'monospace'),
        listBullet: base,
        codeblockPadding: EdgeInsets.zero,
        codeblockDecoration: const BoxDecoration(),
      ),
    );
  }
}
