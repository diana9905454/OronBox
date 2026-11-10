import 'package:oronbox/src/data/community/description_markdown.dart';

class AstroBoxRepoDescription {
  const AstroBoxRepoDescription({required this.value});

  final String value;
}

AstroBoxRepoDescription normalizeAstroBoxRepoDescription(String raw) {
  return AstroBoxRepoDescription(value: descriptionMarkdown(raw));
}
