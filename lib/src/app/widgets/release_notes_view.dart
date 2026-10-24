import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:material_ui/material_ui.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:html2md/html2md.dart' as html2md;

import 'markdown_style_sheet.dart';

class ReleaseNotesView extends StatelessWidget {
  const ReleaseNotesView({super.key, required this.data});

  final String data;

  @override
  Widget build(BuildContext context) {
    if (data.trim().isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final body = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      height: 1.45,
    );
    TextStyle? heading(TextStyle? style) =>
        style?.copyWith(fontWeight: FontWeight.w700);
    final smallHeading = heading(theme.textTheme.titleSmall);
    final bullet = TextPainter(
      text: TextSpan(text: '• ', style: body),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final bulletWidth = bullet.width;
    bullet.dispose();
    final sheet = markdownStyleSheetFromTheme(theme).copyWith(
      p: body,
      h1: heading(theme.textTheme.titleLarge),
      h2: heading(theme.textTheme.titleMedium),
      h3: smallHeading,
      h4: smallHeading,
      h5: smallHeading,
      h6: smallHeading,
      blockSpacing: 10,
      listBullet: body,
      listIndent: bulletWidth,
      listBulletPadding: EdgeInsets.zero,
      code: theme.textTheme.bodySmall?.copyWith(
        fontFamily: 'monospace',
        height: 1.4,
      ),
      codeblockPadding: EdgeInsets.zero,
      codeblockDecoration: const BoxDecoration(),
    );
    final listBuilder = _ReleaseNotesListBuilder(sheet);
    return MarkdownBody(
      data: data,
      selectable: true,
      softLineBreak: true,
      styleSheet: sheet,
      builders: {
        'ul': listBuilder,
        'ol': listBuilder,
        'hr': _ReleaseNotesDividerBuilder(),
      },
    );
  }
}

// Keep list rows contiguous while retaining the 10px gap between top-level blocks.
class _ReleaseNotesListBuilder extends MarkdownElementBuilder {
  _ReleaseNotesListBuilder(this.sheet);

  final MarkdownStyleSheet sheet;

  @override
  Widget visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final ordered = element.tag == 'ol';
    final count = element.children?.whereType<md.Element>().length ?? 1;
    final marker = TextPainter(
      text: TextSpan(text: ordered ? '$count. ' : '• ', style: sheet.p),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final markerWidth = marker.width;
    marker.dispose();
    return MarkdownBody(
      data: html2md.convert(md.renderToHtml([element])),
      selectable: true,
      softLineBreak: true,
      styleSheet: sheet.copyWith(blockSpacing: 0, listIndent: markerWidth),
      bulletBuilder: (parameters) => Text(
        parameters.style == BulletStyle.orderedList
            ? '${parameters.index + 1}. '
            : '• ',
        style: sheet.listBullet,
      ),
    );
  }
}

class _ReleaseNotesDividerBuilder extends MarkdownElementBuilder {
  @override
  Widget visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) => const Divider();
}
