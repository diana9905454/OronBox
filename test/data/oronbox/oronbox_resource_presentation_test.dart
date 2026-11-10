import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/data/community/community_source.dart';
import 'package:oronbox/src/data/oronbox/oronbox_resource_provider.dart';
import 'package:oronbox/src/features/resources/domain/community_resource.dart';
import 'package:oronbox/src/features/resources/domain/resource_catalog.dart';
import 'package:oronbox/src/features/resources/pages/resource_detail_page.dart';

void main() {
  test('reads the full body independently of the searchable summary', () async {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.resolve(
            Response<Object?>(
              requestOptions: options,
              statusCode: 200,
              data: {
                'id': 'body-test',
                'name': 'Body',
                'kind': 'watchface',
                'summary': 'short keywords',
                'description': '# Full body',
                'description_format': 'markdown',
              },
            ),
          );
        },
      ),
    );
    final detail = await OronBoxResourceCatalog(dio: dio).getDetail(
      const ResourceRef(source: CommunitySourceId.oronBox, id: 'body-test'),
    );
    expect(detail.summary, 'short keywords');
    expect(detail.content.value, '# Full body');
    expect(detail.content.format, ResourceContentFormat.markdown);
  });

  test(
    'preserves collection kind and representative media from the public API',
    () async {
      final digest = List.filled(64, 'c').join();
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.resolve(
              Response<Object?>(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'id': 'collection',
                  'name': 'Watch collection',
                  'summary': 'A collection of watchfaces',
                  'owner': 'creator',
                  'kind': 'watchface',
                  'representative_resource_id': 'watchface-resource',
                  'representative': {
                    'id': 'watchface-resource',
                    'name': 'Representative watchface',
                    'kind': 'watchface',
                    'paid_type': 'force_paid',
                    'icon_sha256': digest,
                  },
                  'resource_count': 2,
                  'resources': [
                    {
                      'id': 'other-resource',
                      'name': 'Other resource',
                      'kind': 'watchface',
                    },
                  ],
                },
              ),
            );
          },
        ),
      );

      final detail = await OronBoxResourceCatalog(dio: dio)
          .getCollection('collection');

      expect(detail.type, CommunityResourceType.watchface);
      expect(detail.resourceCount, 2);
      expect(detail.representative?.ref.id, 'watchface-resource');
      expect(detail.representative?.paidType, CommunityPaidType.forcePaid);
      expect(detail.representative?.iconUrl?.pathSegments.last, digest);
    },
  );

  test('maps the OronBox owner BandBBS avatar from the public API', () async {
    final digest = List.filled(64, 'b').join();
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          expect(options.queryParameters['attributes'], 'original,template');
          handler.resolve(
            Response<Object?>(
              requestOptions: options,
              statusCode: 200,
              data: {
                'resources': [
                  {
                    'id': 'resource',
                    'name': 'Resource',
                    'kind': 'quickapp',
                    'owner': 'creator',
                    'owner_bandbbs_user_id': 12345,
                    'owner_avatar_url': 'https://bandbbs.example/avatar.png',
                    'devices': <String>[],
                    'attributes': ['original', 'template'],
                    'icon_sha256': digest,
                  },
                ],
                'total': 1,
              },
            ),
          );
        },
      ),
    );

    final page = await OronBoxResourceCatalog(dio: dio).getPage(
      const CommunityResourceQuery(
        page: 0,
        pageSize: 30,
        selectedAttributes: {'original', 'template'},
      ),
    );

    expect(page.items.single.authors.single.name, 'creator');
    expect(
      page.items.single.authors.single.avatarUrl,
      Uri.parse('https://bandbbs.example/avatar.png'),
    );
    expect(page.items.single.iconUrl?.queryParameters['line'], 'local');
    expect(page.items.single.tags, ['original', 'template']);
  });

  test('uses the icon as the default cover instead of a preview', () async {
    final iconDigest = List.filled(64, 'i').join();
    final previewDigest = List.filled(64, 'p').join();
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.resolve(
            Response<Object?>(
              requestOptions: options,
              statusCode: 200,
              data: {
                'resources': [
                  {
                    'id': 'resource',
                    'name': 'Resource',
                    'kind': 'quickapp',
                    'icon_sha256': iconDigest,
                    'preview_sha256': previewDigest,
                  },
                ],
                'total': 1,
              },
            ),
          );
        },
      ),
    );

    final item = (await OronBoxResourceCatalog(
      dio: dio,
    ).getPage(const CommunityResourceQuery(page: 0, pageSize: 1))).items.single;

    expect(item.coverUrl, item.iconUrl);
    expect(item.coverUrl?.pathSegments.last, iconDigest);
  });

  test(
    'falls back to the local blob line when R2 size probing fails',
    () async {
      final requestedLines = <String>[];
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            final line = options.uri.queryParameters['line'] ?? '';
            requestedLines.add(line);
            if (line == 'r2') {
              handler.reject(
                DioException(
                  requestOptions: options,
                  type: DioExceptionType.badResponse,
                  response: Response<Object?>(
                    requestOptions: options,
                    statusCode: 503,
                  ),
                ),
              );
              return;
            }
            handler.resolve(
              Response<Object?>(
                requestOptions: options,
                statusCode: 200,
                headers: Headers.fromMap({
                  Headers.contentLengthHeader: ['1234'],
                }),
              ),
            );
          },
        ),
      );

      final size = await OronBoxResourceCatalog(dio: dio).probeDownloadSize(
        CommunityResourceFile(
          id: 'artifact',
          fileName: 'app.rpk',
          version: '1.0.0',
          downloadUrl: Uri.parse(
            'https://ob-api.example/api/v1/blobs/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          ),
        ),
      );

      expect(size, 1234);
      expect(requestedLines, ['r2', 'local']);
    },
  );

  test('uses the R2 blob line when size probing succeeds', () async {
    final requestedLines = <String>[];
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final line = options.uri.queryParameters['line'] ?? '';
          requestedLines.add(line);
          handler.resolve(
            Response<Object?>(
              requestOptions: options,
              statusCode: 200,
              headers: Headers.fromMap({
                Headers.contentLengthHeader: ['5678'],
              }),
            ),
          );
        },
      ),
    );

    final size = await OronBoxResourceCatalog(dio: dio).probeDownloadSize(
      CommunityResourceFile(
        id: 'artifact',
        fileName: 'app.rpk',
        version: '1.0.0',
        downloadUrl: Uri.parse(
          'https://ob-api.example/api/v1/blobs/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
        ),
      ),
    );

    expect(size, 5678);
    expect(requestedLines, ['r2']);
  });

  test('parses preview media using the server sha256 field', () {
    final digest = List.filled(64, 'a').join();
    final images = parseOronBoxPreviewImages([
      {'role': 'preview', 'sha256': digest, 'width': 1200, 'height': 800},
    ], blobUri: (value) => Uri.parse('https://example.test/$value'));

    expect(images, hasLength(1));
    expect(images.single.url.pathSegments.last, digest);
    expect(images.single.width, 1200);
    expect(images.single.height, 800);
  });

  test('passes paid visibility filters to the OronBox API', () async {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          expect(options.queryParameters['hide_paid'], '1');
          expect(options.queryParameters['hide_force_paid'], '1');
          expect(options.queryParameters['seed'], 987654);
          handler.resolve(
            Response<Object?>(
              requestOptions: options,
              statusCode: 200,
              data: {'resources': <Object?>[], 'total': 0},
            ),
          );
        },
      ),
    );

    await OronBoxResourceCatalog(dio: dio).getPage(
      const CommunityResourceQuery(
        hidePaid: true,
        hideForcePaid: true,
        seed: 987654,
      ),
    );
  });

  test('uses the stable paid type wire values', () {
    expect(communityPaidTypeToWire(CommunityPaidType.forcePaid), 'force_paid');
    expect(
      communityPaidTypeFromWire('force_paid'),
      CommunityPaidType.forcePaid,
    );
    expect(communityPaidTypeFromWire('unrecognized'), CommunityPaidType.free);
  });

  test('expands one artifact into one install choice per bound device', () {
    const file = CommunityResourceFile(
      id: 'artifact',
      fileName: 'app.rpk',
      version: '1.0.0',
      supportedDevices: {'n66', 'n67'},
    );
    const detail = CommunityResourceDetail(
      ref: ResourceRef(source: CommunitySourceId.oronBox, id: 'resource'),
      name: 'Resource',
      type: CommunityResourceType.quickApp,
      paidType: CommunityPaidType.free,
      authors: [],
      supportedDevices: {'n66', 'n67'},
      content: CommunityResourceContent(
        format: ResourceContentFormat.plainText,
        value: '',
      ),
      files: [file],
    );

    final choices = buildResourceInstallChoices(detail);

    expect(choices, hasLength(2));
    expect(choices.map((choice) => choice.codename), {'n66', 'n67'});
    expect(choices.every((choice) => !choice.label.contains('/')), isTrue);
  });

  test('keeps Huami App Store numeric device sources installable', () {
    const file = CommunityResourceFile(
      id: 'app:1.0.0',
      fileName: 'app.zpk',
      version: '1.0.0',
      supportedDevices: {'8519936'},
    );
    const detail = CommunityResourceDetail(
      ref: ResourceRef(
        source: CommunitySourceId.huamiAppStore,
        id: '8519936:app',
      ),
      name: 'Huami app',
      type: CommunityResourceType.miniprogram,
      paidType: CommunityPaidType.free,
      authors: [],
      supportedDevices: {'8519936'},
      content: CommunityResourceContent(
        format: ResourceContentFormat.plainText,
        value: '',
      ),
      files: [file],
      canDownload: true,
    );

    final choices = buildResourceInstallChoices(detail);

    expect(choices, hasLength(1));
    expect(choices.single.file, same(file));
    expect(choices.single.codename, isEmpty);
    expect(
      preferredResourceInstallChoice(detail, choices, 'any-current-device'),
      same(choices.single),
    );
  });
  test('BandBBS installation ignores cached inferred device metadata', () {
    const detail = CommunityResourceDetail(
      ref: ResourceRef(source: CommunitySourceId.bandbbs, id: 'resource'),
      name: 'Resource',
      type: CommunityResourceType.quickApp,
      paidType: CommunityPaidType.free,
      authors: [],
      supportedDevices: {'n66'},
      content: CommunityResourceContent(
        format: ResourceContentFormat.plainText,
        value: '',
      ),
      files: [
        CommunityResourceFile(
          id: 'file',
          fileName: 'n66.rpk',
          version: '1',
          supportedDevices: {'n66'},
        ),
      ],
    );
    final choices = buildResourceInstallChoices(detail);
    expect(choices, hasLength(1));
    expect(choices.single.codename, isEmpty);
    expect(
      preferredResourceInstallChoice(detail, choices, 'n67'),
      same(choices.single),
    );
  });
}
