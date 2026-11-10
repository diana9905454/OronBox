import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/features/resources/domain/creator_external_binding.dart';

void main() {
  test('reads canonical and historical BandBBS bindings', () {
    final canonical = parseCreatorBandBbsBinding('{"12":"345"}');
    expect(canonical.single.categoryId, '12');
    expect(canonical.single.resourceId, '345');

    final historical = parseCreatorBandBbsBinding(
      '{"13":{"resource_id":"678","url":"https://example.com/678"}}',
    );
    expect(historical.single.categoryId, '13');
    expect(historical.single.resourceId, '678');
    expect(historical.single.url, 'https://example.com/678');
  });

  test('reads partial and completed publication URLs without assuming object values', () {
    expect(
      creatorPublicationLinkUrls({
        'target': 'bandbbs',
        'status_detail': {
          'resources': {
            '13': '678',
            '12': {
              'resource_id': '345',
              'url': 'https://www.bandbbs.cn/resources/345/',
            },
          },
        },
        'external_url': 'https://www.bandbbs.cn/resources/345/',
      }),
      [
        'https://www.bandbbs.cn/resources/345/',
        'https://www.bandbbs.cn/resources/678/',
      ],
    );
    expect(
      creatorPublicationLinkUrls({
        'target': 'bandbbs',
        'status_detail': {
          'completed_categories': {
            '12': {'resource_id': '345'},
          },
        },
      }),
      ['https://www.bandbbs.cn/resources/345/'],
    );
    expect(
      creatorPublicationLinkUrls({
        'target': 'astrobox',
        'external_url': 'https://github.com/example/catalog/pull/1',
      }),
      ['https://github.com/example/catalog/pull/1'],
    );
  });
  test('rejects unsafe links and resolves canonical numeric binding IDs', () {
    expect(
      parseCreatorBandBbsBinding({'12': '345'}).single.resolvedUrl,
      'https://www.bandbbs.cn/resources/345/',
    );
    expect(
      creatorPublicationLinkUrls({'external_url': 'javascript:alert(1)'}),
      isEmpty,
    );
    expect(
      parseCreatorBandBbsBinding({
        '12': {'resource_id': 'invalid', 'url': 'javascript:alert(1)'},
      }).single.resolvedUrl,
      isEmpty,
    );
  });
}
