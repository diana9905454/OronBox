import 'package:oronbox/src/features/resources/domain/resource_catalog.dart';

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:oronbox/src/core/services/shared_prefs_service.dart';
import 'package:oronbox/src/data/bandbbs/bandbbs_resource_provider.dart';
import 'package:oronbox/src/features/accounts/services/bandbbs_auth_service.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    FlutterSecureStorage.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => '/tmp/oronbox-token-test',
        );
    SharedPreferences.setMockInitialValues({
      'bandbbs.oauth.token': jsonEncode({
        'access_token': 'test-token',
        'refresh_token': 'test-refresh-token',
        'token_type': 'bearer',
        'expires_at': DateTime.utc(2099).toIso8601String(),
        'scope': '',
      }),
    });
    await SharedPrefsService.instance.init();
  });

  test('does not infer devices from category names or filenames', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final dio = Dio();
    addTearDown(dio.close);
    final resource = {
      'resource_id': 42,
      'title': 'Device resource',
      'prefix_id': 81,
      'Category': {'title': 'Xiaomi Smart Band 9'},
      'current_files': [
        {'id': 1, 'filename': 'n66.rpk'},
      ],
    };
    final paths = <String>[];
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          paths.add(options.path);
          handler.resolve(
            Response<Object?>(
              requestOptions: options,
              statusCode: 200,
              data: options.path.endsWith('/42')
                  ? {'resource': resource}
                  : {
                      'resources': [resource],
                    },
            ),
          );
        },
      ),
    );
    final catalog = BandBbsCatalog(
      dio: dio,
      auth: container.read(bandBbsAuthProvider.notifier),
    );
    final page = await catalog.getPage(
      const CommunityResourceQuery(selectedDevices: {'n67'}),
    );
    expect(page.items, hasLength(1));
    expect(page.items.single.supportedDevices, isEmpty);
    final detail = await catalog.getDetail(page.items.single.ref);
    expect(detail.supportedDevices, isEmpty);
    expect(detail.files.single.supportedDevices, isEmpty);
    expect(paths.any((path) => path.contains('categor')), isFalse);
  });

  test('test category follows the standard default-hidden behavior', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final auth = container.read(bandBbsAuthProvider.notifier);

    final defaultTree = await BandBbsCatalog(
      dio: _categoryDio(),
      auth: auth,
    ).getCategoryTree();
    final fullTree = await BandBbsCatalog(
      dio: _categoryDio(),
      auth: auth,
      showAllCategories: true,
    ).getCategoryTree();

    expect(defaultTree.map((node) => node.title), ['红米手表5/6']);
    expect(fullTree.map((node) => node.title), ['测试区', '红米手表5/6']);
  });
}

Dio _categoryDio() {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) => handler.resolve(
        Response<Object?>(
          requestOptions: options,
          statusCode: 200,
          data: {
            'categories_flat': [
              {
                'depth': 0,
                'category': {
                  'resource_category_id': 104,
                  'title': '测试区',
                  'resource_count': 1,
                  'parent_category_id': 0,
                },
              },
              {
                'depth': 0,
                'category': {
                  'resource_category_id': 101,
                  'title': '红米手表5/6',
                  'resource_count': 1,
                  'parent_category_id': 0,
                },
              },
            ],
          },
        ),
      ),
    ),
  );
  return dio;
}
