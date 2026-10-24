import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/data/astrobox/astrobox_repo_description.dart';
import 'package:oronbox/src/data/community/description_markdown.dart';

void main() {
  test('converts HTML formatting without losing paragraphs and links', () {
    final result = normalizeAstroBoxRepoDescription(
      '<p>First<br/><span style="font-weight: 700">bold</span></p>'
      '<p><a href="https://example.com">Link</a></p>',
    );
    expect(result.value, contains('**bold**'));
    expect(result.value, contains('[Link](https://example.com)'));
    expect(result.value, contains('\n\n'));
    expect(result.value, isNot(contains('<span')));
  });

  test('preserves existing Markdown', () {
    expect(
      normalizeAstroBoxRepoDescription('**bold** & text').value,
      '**bold** & text',
    );
  });

  test('resolves forum assets and removes executable content', () {
    final result = descriptionMarkdown(
      '<script>secret</script><p><img src="/a.png">'
      '<a href="javascript:alert(1)">unsafe</a></p>',
      baseUri: Uri.parse('https://www.bandbbs.cn/'),
    );
    expect(result, contains('https://www.bandbbs.cn/a.png'));
    expect(result, isNot(contains('secret')));
    expect(result, isNot(contains('javascript:')));
  });
}
