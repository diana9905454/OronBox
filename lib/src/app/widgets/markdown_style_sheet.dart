import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:material_ui/material_ui.dart';

/// Builds the markdown package's stylesheet from the application's Material UI
/// theme without converting the theme through the legacy Flutter Material API.
MarkdownStyleSheet markdownStyleSheetFromTheme(ThemeData theme) {
  final textColor = theme.colorScheme.onSurface;
  final body = (theme.textTheme.bodyMedium ?? const TextStyle()).copyWith(
    color: textColor,
  );
  final bodySize = body.fontSize ?? 14;
  final code = body.copyWith(
    backgroundColor: theme.cardTheme.color,
    fontFamily: 'monospace',
    fontSize: bodySize * 0.85,
  );

  return MarkdownStyleSheet(
    a: TextStyle(color: theme.colorScheme.primary),
    p: body,
    pPadding: EdgeInsets.zero,
    code: code,
    h1: theme.textTheme.headlineSmall?.copyWith(color: textColor),
    h1Padding: EdgeInsets.zero,
    h2: theme.textTheme.titleLarge?.copyWith(color: textColor),
    h2Padding: EdgeInsets.zero,
    h3: theme.textTheme.titleMedium?.copyWith(color: textColor),
    h3Padding: EdgeInsets.zero,
    h4: theme.textTheme.bodyLarge?.copyWith(color: textColor),
    h4Padding: EdgeInsets.zero,
    h5: theme.textTheme.bodyLarge?.copyWith(color: textColor),
    h5Padding: EdgeInsets.zero,
    h6: theme.textTheme.bodyLarge?.copyWith(color: textColor),
    h6Padding: EdgeInsets.zero,
    em: TextStyle(color: textColor, fontStyle: FontStyle.italic),
    strong: TextStyle(color: textColor, fontWeight: FontWeight.bold),
    del: TextStyle(color: textColor, decoration: TextDecoration.lineThrough),
    blockquote: body,
    img: body,
    checkbox: body.copyWith(color: theme.primaryColor),
    blockSpacing: 8,
    listIndent: 24,
    listBullet: body,
    listBulletPadding: const EdgeInsets.only(right: 4),
    tableHead: TextStyle(color: textColor, fontWeight: FontWeight.w600),
    tableBody: body,
    tableHeadAlign: TextAlign.center,
    tablePadding: const EdgeInsets.only(bottom: 4),
    tableBorder: TableBorder.all(color: theme.dividerColor),
    tableColumnWidth: const FlexColumnWidth(),
    tableCellsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
    tableCellsDecoration: const BoxDecoration(),
    blockquotePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    blockquoteDecoration: BoxDecoration(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(3),
      border: Border(
        left: BorderSide(color: theme.colorScheme.primary, width: 3),
      ),
    ),
    codeblockPadding: const EdgeInsets.all(8),
    codeblockDecoration: BoxDecoration(
      color: theme.cardTheme.color,
      borderRadius: BorderRadius.circular(2),
    ),
    horizontalRuleDecoration: BoxDecoration(
      border: Border(top: BorderSide(width: 5, color: theme.dividerColor)),
    ),
  );
}
