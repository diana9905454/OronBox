import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/data/oronbox/oronbox_home_api.dart';

void main() {
  test('published blogs are included without an editor section', () async {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final data = options.path.contains('/api/v1/blog')
              ? {
                  'posts': [
                    {
                      'slug': 'release-notes',
                      'type': 'announcement',
                      'title': 'Release notes',
                      'subtitle': '',
                      'author': 'OronBox',
                    },
                  ],
                }
              : {
                  'banners': <Object?>[],
                  'sections': <Object?>[],
                  'resource_feed': {
                    'featured': <Object?>[],
                    'recommended': [
                      {
                        'id': 'resource-1',
                        'name': 'Recommended resource',
                        'kind': 'quickapp',
                        'paid_type': 'free',
                        'published_at': '2026-08-18T08:00:00Z',
                        'updated_at': '2026-08-18T09:00:00Z',
                        'devices': <Object?>[],
                        'attributes': <Object?>[],
                      },
                    ],
                    'latest': <Object?>[],
                  },
                };
          handler.resolve(
            Response<Object?>(
              requestOptions: options,
              statusCode: 200,
              data: data,
            ),
          );
        },
      ),
    );

    final feed = await OronBoxHomeApi(dio: dio).fetchHome();

    expect(feed.blogs.single.slug, 'release-notes');
    expect(feed.resourceFeed.available, isTrue);
    expect(feed.resourceFeed.recommended.single.name, 'Recommended resource');
    expect(
      feed.resourceFeed.recommended.single.updatedAt,
      DateTime.utc(2026, 8, 18, 8),
    );
    expect(feed.isEmpty, isFalse);
  });

  test('blog failures do not hide the resource feed', () async {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path.contains('/api/v1/blog')) {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.connectionError,
              ),
            );
            return;
          }
          handler.resolve(
            Response<Object?>(
              requestOptions: options,
              statusCode: 200,
              data: {
                'banners': <Object?>[],
                'sections': <Object?>[],
                'resource_feed': {
                  'featured': <Object?>[],
                  'recommended': [
                    {
                      'id': 'resource-1',
                      'name': 'Recommended resource',
                      'kind': 'quickapp',
                      'paid_type': 'free',
                      'devices': <Object?>[],
                      'attributes': <Object?>[],
                    },
                  ],
                  'latest': <Object?>[],
                },
              },
            ),
          );
        },
      ),
    );

    final feed = await OronBoxHomeApi(dio: dio).fetchHome();

    expect(feed.blogs, isEmpty);
    expect(feed.resourceFeed.recommended.single.name, 'Recommended resource');
  });

  test('explicitly available aggregate resource feed may be empty', () async {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.resolve(
            Response<Object?>(
              requestOptions: options,
              statusCode: 200,
              data: options.path.contains('/api/v1/blog')
                  ? {'posts': <Object?>[]}
                  : {
                      'banners': <Object?>[],
                      'sections': <Object?>[],
                      'resource_feed': {
                        'featured': <Object?>[],
                        'recommended': <Object?>[],
                        'latest': <Object?>[],
                      },
                      'resource_feed_available': true,
                    },
            ),
          );
        },
      ),
    );

    final feed = await OronBoxHomeApi(dio: dio).fetchHome(seed: 1);

    expect(feed.resourceFeed.available, isTrue);
  });

  test('unavailable aggregate resource feed keeps legacy fallback', () async {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.resolve(
            Response<Object?>(
              requestOptions: options,
              statusCode: 200,
              data: options.path.contains('/api/v1/blog')
                  ? {'posts': <Object?>[]}
                  : {
                      'banners': <Object?>[],
                      'sections': <Object?>[],
                      'resource_feed': {
                        'featured': <Object?>[],
                        'recommended': <Object?>[],
                        'latest': <Object?>[],
                      },
                      'resource_feed_available': false,
                    },
            ),
          );
        },
      ),
    );

    final feed = await OronBoxHomeApi(dio: dio).fetchHome(seed: 1);

    expect(feed.resourceFeed.available, isFalse);
  });
}
