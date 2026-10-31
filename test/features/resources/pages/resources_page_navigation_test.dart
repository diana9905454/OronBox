import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/app_localizations_delegates.dart';
import 'package:oronbox/src/app/layout/app_navigation_bar.dart';
import 'package:oronbox/src/app/theme/app_theme.dart';
import 'package:oronbox/src/app/widgets/app_scaffold_messenger.dart';
import 'package:oronbox/src/core/network/github_cdn.dart';
import 'package:oronbox/src/core/providers/app_settings_providers.dart';
import 'package:oronbox/src/core/services/shared_prefs_service.dart';
import 'package:oronbox/src/data/community/community_source.dart';
import 'package:oronbox/src/data/oronbox/oronbox_home_api.dart';
import 'package:oronbox/src/features/accounts/application/host_accounts.dart';
import 'package:oronbox/src/features/resources/application/oronbox_resource_attributes.dart';
import 'package:oronbox/src/features/resources/controllers/resource_filter_controller.dart';
import 'package:oronbox/src/features/resources/domain/community_resource.dart';
import 'package:oronbox/src/features/resources/pages/resources_page.dart';
import 'package:oronbox/src/features/resources/application/home_providers.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await SharedPrefsService.instance.init();
  });

  testWidgets('resource home remains tappable after returning from detail', (
    tester,
  ) async {
    final first = _resource('first');
    final second = _resource('second');
    final router = GoRouter(
      initialLocation: '/resources',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (_, _, navigationShell) => navigationShell,
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/resources',
                  builder: (_, _) =>
                      const PrimaryBranchScaffold(child: ResourcesPage()),
                  routes: [
                    GoRoute(
                      path: 'detail/:id',
                      pageBuilder: (_, state) => CustomTransitionPage<void>(
                        key: state.pageKey,
                        transitionDuration: const Duration(milliseconds: 320),
                        reverseTransitionDuration: const Duration(
                          milliseconds: 300,
                        ),
                        child: OronBoxScaffoldMessenger(
                          child: Scaffold(
                            body: Text('detail:${state.pathParameters['id']}'),
                          ),
                        ),
                        transitionsBuilder:
                            AppTheme.buildPlatformPageTransition,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/other',
                  builder: (_, _) => const Scaffold(body: Text('other')),
                ),
              ],
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    final settings = AppSettings(
      cdn: GitHubCdn.raw,
      communitySource: CommunitySourceId.oronBox,
      autoInstall: true,
      disableAutoClean: false,
      autoReconnect: false,
      wideNavigationRailPosition: WideNavigationRailPosition.bottom,
      bandbbsLoadPreviews: false,
      bandbbsShowAllCategories: false,
      clean: const CleanSettings(
        homeFeed: true,
        homeLatest: true,
        homeRecommended: false,
        homeFeatured: false,
        homeBanner: false,
        homeEditorSections: false,
        explore: true,
        exploreEntry: true,
        creator: false,
      ),
    );
    final feed = HomeFeed(
      banners: const [],
      blogs: const [],
      sections: const [],
      resourceFeed: HomeResourceFeed(
        featured: const [],
        recommended: const [],
        latest: [first, second],
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appSettingsProvider.overrideWith(
            () => _FixedSettingsNotifier(settings),
          ),
          resourceModeControllerProvider.overrideWith(_HomeModeController.new),
          homeFeedProvider.overrideWith((ref) async => feed),
          oronBoxResourceAttributesProvider.overrideWith(
            (ref) async => const [],
          ),
          hostAccountsProvider.overrideWith(_SignedOutHost.new),
        ],
        child: MaterialApp.router(
          locale: const Locale('zh'),
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('first'));
    await tester.pumpAndSettle();
    expect(find.text('detail:first'), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('first'), findsOneWidget);

    await tester.tap(find.text('second'));
    await tester.pumpAndSettle();
    expect(find.text('detail:second'), findsOneWidget);
  });
}

CommunityResource _resource(String id) => CommunityResource(
  ref: ResourceRef(source: CommunitySourceId.oronBox, id: id),
  name: id,
  type: CommunityResourceType.quickApp,
  paidType: CommunityPaidType.free,
  authors: const [],
  supportedDevices: const {},
);

class _FixedSettingsNotifier extends LocalAppSettingsNotifier {
  _FixedSettingsNotifier(this._settings);

  final AppSettings _settings;

  @override
  AppSettings build() => _settings;
}

class _HomeModeController extends ResourceModeController {
  @override
  ResourceMode build() => ResourceMode.home;
}

class _SignedOutHost extends HostAccountsNotifier {
  @override
  HostAccountsState build() => const HostAccountsState();
}
