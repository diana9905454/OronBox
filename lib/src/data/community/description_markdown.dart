import 'package:html/parser.dart' as html;
import 'package:html2md/html2md.dart' as html2md;

String descriptionMarkdown(String source, {Uri? baseUri}) {
  final fragment = html.parseFragment(source);
  if (fragment.children.isEmpty) return source;
  for (final element in fragment.querySelectorAll(
    'script, style, iframe, form, input, button',
  )) {
    element.remove();
  }
  for (final element in fragment.querySelectorAll('[href], [src]')) {
    for (final attribute in ['href', 'src']) {
      final value = element.attributes[attribute];
      if (value == null) continue;
      final uri = Uri.tryParse(value);
      final resolved = uri == null ? null : (baseUri?.resolveUri(uri) ?? uri);
      if (resolved == null ||
          (resolved.hasScheme &&
              resolved.scheme != 'https' &&
              resolved.scheme != 'http')) {
        element.attributes.remove(attribute);
      } else {
        element.attributes[attribute] = resolved.toString();
      }
    }
  }
  for (final element in fragment.querySelectorAll('span[style]')) {
    if (RegExp(r'font-weight\s*:\s*(?:bold|[6-9]00)')
        .hasMatch(element.attributes['style']!.toLowerCase())) {
      element.innerHtml = '<strong>${element.innerHtml}</strong>';
    }
  }
  return html2md.convert(fragment.outerHtml).trim();
}
