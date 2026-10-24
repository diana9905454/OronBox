import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/features/resources/domain/creator_publication_plan.dart';
import 'package:oronbox/src/features/resources/domain/creator_workspace.dart';

void main() {
  test(
    'uses server publication mapping instead of hardcoded category guesses',
    () {
      final plan = buildCreatorPublicationPlan(
        workspace: _workspace(
          artifacts: {
            'artifact': ['device-n67'],
          },
        ),
        devices: const [
          CreatorDevice(
            id: 'device-n67',
            codename: 'n67',
            name: 'Band 9 Pro',
            astroBoxId: 'xmb9p',
          ),
        ],
        bandBbsCategories: const [],
        publicationOptions: const {
          'resource_prefixes': {'quickapp': 912},
          'bandbbs': {
            'n67': {'category_id': 991},
          },
        },
      );
      expect(plan.bandBbsTargets.single.categoryId, 991);
      expect(plan.bandBbsTargets.single.prefixId, 912);
      expect(plan.astroBoxDeviceIds, ['xmb9p']);
    },
  );

  test('maps OronBox devices to BandBBS and AstroBox identities', () {
    final plan = buildCreatorPublicationPlan(
      workspace: _workspace(
        artifacts: {
          'artifact': const ['device-n67'],
        },
      ),
      devices: const [
        CreatorDevice(
          id: 'device-n67',
          codename: 'n67',
          name: 'Xiaomi Smart Band 9 Pro',
          astroBoxId: 'xmb9p',
        ),
      ],
      bandBbsCategories: const [
        {
          'id': 10,
          'title': '穿戴设备',
          'children': [
            {'id': 675, 'title': '小米手环9 Pro', 'children': []},
          ],
        },
      ],
    );

    expect(plan.bandBbsTargets, hasLength(1));
    expect(plan.bandBbsTargets.single.categoryId, 675);
    expect(plan.bandBbsTargets.single.prefixId, 82);
    expect(plan.bandBbsTargets.single.packageId, 'app');
    expect(plan.astroBoxDeviceIds, ['xmb9p']);
    expect(plan.canPublishToBandBbs, isTrue);
  });

  test('fans out one resource to every matched category', () {
    final plan = buildCreatorPublicationPlan(
      workspace: _workspace(
        artifacts: {
          'artifact': const ['n67'],
          'artifact-2': const ['o65'],
        },
      ),
      devices: const [
        CreatorDevice(id: 'n67', codename: 'n67', name: 'Band 9 Pro'),
        CreatorDevice(id: 'o65', codename: 'o65', name: 'REDMI Watch 5'),
      ],
      bandBbsCategories: const [
        {'id': 1, 'title': '小米手环9 Pro', 'children': []},
        {'id': 2, 'title': 'Redmi Watch 5', 'children': []},
      ],
    );

    expect(plan.bandBbsProblem, isNull);
    expect(plan.bandBbsTargets, hasLength(2));
    expect(
      plan.bandBbsTargets.map((target) => target.categoryId),
      containsAll([1, 2]),
    );
    expect(plan.canPublishToBandBbs, isTrue);
  });

  test('maps combined BandBBS categories to every covered device', () {
    for (final codename in const ['o65', 'o65m', 'p65']) {
      final plan = buildCreatorPublicationPlan(
        workspace: _workspace(
          artifacts: {
            'artifact': [codename],
          },
        ),
        devices: [
          CreatorDevice(id: codename, codename: codename, name: codename),
        ],
        bandBbsCategories: const [
          {'id': 101, 'title': '红米手表5/6', 'children': []},
        ],
      );
      expect(plan.bandBbsTargets.single.categoryId, 101, reason: codename);
      expect(plan.canPublishToBandBbs, isTrue, reason: codename);
    }

    final s3 = buildCreatorPublicationPlan(
      workspace: _workspace(
        artifacts: {
          'artifact': const ['n62'],
        },
      ),
      devices: const [
        CreatorDevice(id: 'n62', codename: 'n62', name: 'Xiaomi Watch S3'),
      ],
      bandBbsCategories: const [
        {'id': 102, 'title': 'Xiaomi Watch S3/S4系列', 'children': []},
      ],
    );
    expect(s3.bandBbsTargets.single.categoryId, 102);
  });

  test('maps variant devices to the base-model category', () {
    final plan = buildCreatorPublicationPlan(
      workspace: _workspace(
        artifacts: {
          'artifact': const ['o66nfc'],
        },
      ),
      devices: const [
        CreatorDevice(
          id: 'o66nfc',
          codename: 'o66nfc',
          name: 'Xiaomi Smart Band 10 NFC',
        ),
      ],
      bandBbsCategories: const [
        {
          'id': 19,
          'title': '小米手环',
          'children': [
            {'id': 103, 'title': '小米手环10', 'children': []},
            {'id': 108, 'title': '小米手环10 Pro', 'children': []},
          ],
        },
      ],
    );
    expect(plan.bandBbsTargets.single.categoryId, 103);
    expect(plan.canPublishToBandBbs, isTrue);
  });

  test('does not map variants to a generic family root', () {
    final plan = buildCreatorPublicationPlan(
      workspace: _workspace(
        artifacts: {
          'artifact': const ['o66nfc'],
        },
      ),
      devices: const [
        CreatorDevice(
          id: 'o66nfc',
          codename: 'o66nfc',
          name: 'Xiaomi Smart Band 10 NFC',
        ),
      ],
      bandBbsCategories: const [
        {'id': 19, 'title': '小米手环', 'children': []},
      ],
    );

    expect(plan.bandBbsTargets, isEmpty);
    expect(plan.bandBbsProblem, CreatorBandBbsPlanProblem.unmappedDevices);
    expect(plan.unmappedDeviceNames, ['Xiaomi Smart Band 10 NFC']);
  });

  test('blocks BandBBS when any selected device is unmapped', () {
    final plan = buildCreatorPublicationPlan(
      workspace: _workspace(
        artifacts: {
          'artifact': const ['n67', 'unknown-device'],
        },
      ),
      devices: const [
        CreatorDevice(id: 'n67', codename: 'n67', name: 'Band 9 Pro'),
        CreatorDevice(
          id: 'unknown-device',
          codename: 'unknown-device',
          name: 'Unknown Device',
        ),
      ],
      bandBbsCategories: const [
        {'id': 1, 'title': '小米手环9 Pro', 'children': []},
      ],
    );

    expect(plan.bandBbsTargets, isEmpty);
    expect(plan.bandBbsProblem, CreatorBandBbsPlanProblem.unmappedDevices);
    expect(plan.unmappedDeviceNames, ['Unknown Device']);
    expect(plan.canPublishToBandBbs, isFalse);
  });

  test('rejects multiple artifacts sharing one category', () {
    final plan = buildCreatorPublicationPlan(
      workspace: _workspace(
        artifacts: {
          'artifact': const ['o65'],
          'artifact-2': const ['p65'],
        },
      ),
      devices: const [
        CreatorDevice(id: 'o65', codename: 'o65', name: 'REDMI Watch 5'),
        CreatorDevice(id: 'p65', codename: 'p65', name: 'REDMI Watch 6'),
      ],
      bandBbsCategories: const [
        {'id': 101, 'title': '红米手表5/6', 'children': []},
      ],
    );

    expect(plan.canPublishToBandBbs, isFalse);
    expect(
      plan.bandBbsProblem,
      CreatorBandBbsPlanProblem.sharedCategoryArtifacts,
    );
  });
}

CreatorWorkspace _workspace({required Map<String, List<String>> artifacts}) =>
    CreatorWorkspace(
      resource: const CreatorResource(
        id: 'resource',
        slug: 'resource',
        kind: CreatorResourceKind.quickApp,
      ),
      artifacts: [
        for (final entry in artifacts.entries)
          CreatorArtifact(
            id: entry.key,
            name: '${entry.key}.rpk',
            sha256: '',
            packageId: 'app',
            version: '1',
            devices: entry.value,
          ),
      ],
    );
