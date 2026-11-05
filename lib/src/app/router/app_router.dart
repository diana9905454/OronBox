import 'package:oronbox/src/features/settings/pages/app_permissions_page.dart';
import 'package:oronbox/src/features/devices/pages/tools/xiaomi_app_arrangement_page.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:oronbox/src/app/layout/app_navigation_bar.dart';
import 'package:oronbox/src/app/layout/app_scaffold.dart';
import 'package:oronbox/src/app/theme/app_theme.dart';
import 'package:oronbox/src/app/widgets/app_scaffold_messenger.dart';
import 'package:oronbox/src/app/widgets/dialog_helper.dart';
import 'package:oronbox/src/core/providers/app_settings_providers.dart';
import 'package:oronbox/src/data/community/community_source.dart';
import 'package:oronbox/src/data/oronbox/oronbox_home_api.dart';
import 'package:oronbox/src/features/resources/application/resource_catalog_providers.dart';
import 'package:oronbox/src/features/resources/domain/community_resource.dart';
import 'package:oronbox/src/features/devices/pages/apps/device_apps_page.dart';
import 'package:oronbox/src/features/devices/pages/devices_page.dart';
import 'package:oronbox/src/features/devices/pages/firmware/device_firmware_page.dart';
import 'package:oronbox/src/features/devices/pages/info/device_info_page.dart';
import 'package:oronbox/src/features/devices/pages/install/install_local_page.dart';
import 'package:oronbox/src/features/devices/pages/tools/zeppos_more_features_page.dart';
import 'package:oronbox/src/features/settings/pages/labs/voice_assistant_page.dart';
import 'package:oronbox/src/features/settings/pages/labs/feature_lab_page.dart';
import 'package:oronbox/src/features/ai/pages/global_ai_page.dart';
import 'package:oronbox/src/features/devices/pages/tools/zeppos_app_side_debug_page.dart';
import 'package:oronbox/src/features/devices/pages/tools/zeppos_app_settings_page.dart';
import 'package:oronbox/src/features/devices/pages/tools/zeppos_setting_viewer_page.dart';
import 'package:oronbox/src/features/devices/pages/tools/zeppos_music_upload_page.dart';
import 'package:oronbox/src/features/devices/pages/tools/xiaomi_recordings_page.dart';
import 'package:oronbox/src/features/devices/health/pages/xiaomi_health_page.dart';
import 'package:oronbox/src/features/devices/health/pages/xiaomi_health_detail_page.dart';
import 'package:oronbox/src/features/devices/health/pages/xiaomi_health_debug_page.dart';
import 'package:oronbox/src/features/devices/health/pages/xiaomi_health_workout_page.dart';
import 'package:oronbox/src/features/devices/health/health_models.dart';
import 'package:oronbox/src/features/devices/pages/tools/xiaomi_device_feature_pages.dart';
import 'package:oronbox/src/features/devices/pages/tools/zeppos_voice_memos_page.dart';
import 'package:oronbox/src/features/devices/pages/switch/device_switch_page.dart';
import 'package:oronbox/src/features/debug/pages/debug_window_app.dart';
import 'package:oronbox/src/features/oobe/oobe_state.dart';
import 'package:oronbox/src/features/oobe/pages/oobe_page.dart';
import 'package:oronbox/src/features/devices/pages/watchfaces/device_watchfaces_page.dart';
import 'package:oronbox/src/features/devices/providers/pending_shared_device_provider.dart';
import 'package:oronbox/src/features/devices/services/device_share_link.dart';
import 'package:oronbox/src/features/resources/pages/creator/creator_center_page.dart';
import 'package:oronbox/src/features/resources/pages/creator/creator_resource_page.dart';
import 'package:oronbox/src/features/resources/pages/creator/creator_review_status_page.dart';
import 'package:oronbox/src/features/resources/pages/huami_publisher_page.dart';
import 'package:oronbox/src/features/resources/pages/blog_post_page.dart';
import 'package:oronbox/src/features/resources/pages/queue_page.dart';
import 'package:oronbox/src/features/resources/pages/resource_detail_page.dart';
import 'package:oronbox/src/features/resources/pages/resource_collection_page.dart';
import 'package:oronbox/src/features/resources/pages/creator/creator_collection_page.dart';
import 'package:oronbox/src/features/resources/pages/creator/creator_create_wizard.dart';
import 'package:oronbox/src/features/resources/pages/resources_page.dart';
import 'package:oronbox/src/features/settings/pages/acknowledgements_page.dart';
import 'package:oronbox/src/features/settings/pages/about_software_page.dart';
import 'package:oronbox/src/features/settings/pages/settings_page.dart';
import 'package:oronbox/src/features/settings/pages/clean_mode_page.dart';
import 'package:oronbox/src/features/settings/pages/app_data_page.dart';
import 'package:oronbox/src/features/settings/pages/bandbbs_account_page.dart';
import 'package:oronbox/src/features/settings/pages/feedback_page.dart';
import 'package:oronbox/src/features/settings/pages/legal_documents_page.dart';
import 'package:oronbox/src/features/settings/pages/local_server_page.dart';
import 'package:oronbox/src/features/settings/services/oronbox_support_api.dart';
import 'package:oronbox/src/features/plugins/pages/plugin_detail_page.dart';
import 'package:oronbox/src/features/plugins/pages/plugins_page.dart';
import 'package:oronbox/src/features/messages/pages/inbox_page.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/resources',
    observers: [OronBoxDialog.observer],
    redirect: (context, state) {
      final uri = state.uri;
      final onOobe = uri.path == '/oobe';
      if (!isOobeCompleted()) {
        // Until the agreements are accepted and the wizard is finished,
        // everything lands on the OOBE. OAuth callbacks are consumed by
        // DeviceDeepLinkHandler independently of the route.
        return onOobe ? null : '/oobe';
      }
      if (onOobe && uri.queryParameters['replay'] != '1') {
        return '/resources';
      }
      final clean = ref.read(appSettingsProvider).clean;
      if (uri.path == '/inbox' && !clean.inboxEnabled) {
        return clean.exploreEnabled ? '/resources' : '/devices';
      }
      if (uri.path.startsWith('/plugins') && !clean.pluginsEnabled) {
        return clean.exploreEnabled ? '/resources' : '/devices';
      }
      if (uri.path.startsWith('/resources')) {
        if (!clean.exploreEnabled) return '/devices';
        if (uri.path.startsWith('/resources/creator') &&
            !clean.creatorEnabled) {
          return '/resources';
        }
        if (uri.path.startsWith('/resources/comment') &&
            (!clean.commentsEnabled || !clean.resourceLibraryEnabled)) {
          return '/resources';
        }
        if (uri.path.startsWith('/resources/detail') &&
            !clean.resourceLibraryEnabled) {
          return '/resources';
        }
      }
      final device = DeviceShareLink.parse(uri.toString());
      if (device != null) {
        ref.read(pendingSharedDeviceProvider.notifier).set(device);
        return '/devices/switch';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/home', redirect: (context, state) => '/resources'),
      GoRoute(path: '/oobe', builder: (context, state) => const OobePage()),
      GoRoute(
        path: '/debug',
        builder: (context, state) => const DebugWindowPage(embedded: true),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppScaffold(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            observers: [resourceRouteObserver],
            routes: [
              GoRoute(
                path: '/resources',
                builder: (context, state) =>
                    const PrimaryBranchScaffold(child: ResourcesPage()),
                routes: [
                  GoRoute(
                    path: 'comment/:id',
                    builder: (context, state) => CommentThreadPage(
                      commentId: state.pathParameters['id']!,
                    ),
                  ),
                  GoRoute(
                    path: 'detail/:id',
                    pageBuilder: (context, state) {
                      final resource = state.extra as CommunityResource?;
                      late final Widget child;
                      if (resource != null) {
                        child = ResourceDetailPage(
                          resource: resource,
                          targetCommentId:
                              state.uri.queryParameters['comment'] ?? '',
                        );
                      } else {
                        child = ResourceDetailPage(
                          targetCommentId:
                              state.uri.queryParameters['comment'] ?? '',
                          resource: CommunityResource(
                            ref: ResourceRef(
                              source:
                                  communitySourceIdByName(
                                    state.uri.queryParameters['source'] ?? '',
                                  ) ??
                                  ref.read(selectedCommunitySourceProvider),
                              id: state.pathParameters['id']!,
                            ),
                            name: '',
                            type: CommunityResourceType.quickApp,
                            paidType: CommunityPaidType.free,
                            authors: const [],
                            supportedDevices: const {},
                          ),
                        );
                      }
                      return CustomTransitionPage<void>(
                        key: state.pageKey,
                        transitionDuration: const Duration(milliseconds: 320),
                        reverseTransitionDuration: const Duration(
                          milliseconds: 300,
                        ),
                        child: OronBoxScaffoldMessenger(child: child),
                        transitionsBuilder:
                            AppTheme.buildPlatformPageTransition,
                      );
                    },
                  ),
                  GoRoute(
                    path: 'collection/:id',
                    builder: (context, state) => ResourceCollectionPage(
                      collection:
                          state.extra as CommunityResource? ??
                          CommunityResource(
                            ref: ResourceRef(
                              source: CommunitySourceId.oronBox,
                              id: state.pathParameters['id']!,
                            ),
                            name: '',
                            type: CommunityResourceType.quickApp,
                            paidType: CommunityPaidType.free,
                            authors: const [],
                            supportedDevices: const {},
                            isCollection: true,
                          ),
                    ),
                  ),
                  GoRoute(
                    path: 'huami-publisher',
                    builder: (context, state) => HuamiPublisherPage(
                      publisherName: state.uri.queryParameters['name'] ?? '',
                    ),
                  ),
                  GoRoute(
                    path: 'blog/:slug',
                    builder: (context, state) => BlogPostPage(
                      slug: state.pathParameters['slug']!,
                      preview: state.extra is BlogCard
                          ? state.extra! as BlogCard
                          : null,
                    ),
                  ),
                  GoRoute(
                    path: 'creator',
                    pageBuilder: (context, state) => CustomTransitionPage<void>(
                      key: state.pageKey,
                      transitionsBuilder: AppTheme.buildPlatformPageTransition,
                      child: const CreatorCenterPage(),
                    ),
                    routes: [
                      GoRoute(
                        path: 'resources',
                        pageBuilder: (context, state) =>
                            CustomTransitionPage<void>(
                              key: state.pageKey,
                              transitionsBuilder:
                                  AppTheme.buildPlatformPageTransition,
                              child: const CreatorCenterPage(initialTab: 1),
                            ),
                        routes: [
                          GoRoute(
                            path: 'create',
                            builder: (context, state) =>
                                const CreatorCreateWizard(),
                          ),
                          GoRoute(
                            path: ':resourceId',
                            builder: (context, state) => CreatorResourcePage(
                              resourceId: state.pathParameters['resourceId'],
                            ),
                          ),
                        ],
                      ),
                      GoRoute(
                        path: 'reviews',
                        pageBuilder: (context, state) =>
                            CustomTransitionPage<void>(
                              key: state.pageKey,
                              transitionsBuilder:
                                  AppTheme.buildPlatformPageTransition,
                              child: CreatorCenterPage(
                                initialTab: 2,
                                initialReviewFilter:
                                    state.uri.queryParameters['filter'],
                              ),
                            ),
                        routes: [
                          GoRoute(
                            path: ':reviewId',
                            builder: (context, state) =>
                                CreatorReviewStatusPage(
                                  reviewId: state.pathParameters['reviewId']!,
                                ),
                          ),
                        ],
                      ),
                      GoRoute(
                        path: 'collections/new',
                        builder: (context, state) => CreatorCollectionPage(
                          collectionId: 'new',
                          initialName: state.uri.queryParameters['name'] ?? '',
                          initialSummary:
                              state.uri.queryParameters['summary'] ?? '',
                          initialKind:
                              state.uri.queryParameters['kind'] ?? 'quickapp',
                        ),
                      ),
                      GoRoute(
                        path: 'collection/:id',
                        builder: (context, state) => CreatorCollectionPage(
                          collectionId: state.pathParameters['id']!,
                          initialName: state.uri.queryParameters['name'] ?? '',
                          initialSummary:
                              state.uri.queryParameters['summary'] ?? '',
                          initialKind:
                              state.uri.queryParameters['kind'] ?? 'quickapp',
                          revisionId:
                              state.uri.queryParameters['revision'] ??
                              state.uri.queryParameters['revision_id'],
                          item: state.extra is Map<String, Object?>
                              ? state.extra! as Map<String, Object?>
                              : null,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              GoRoute(
                path: '/inbox',
                builder: (context, state) => const InboxPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/devices',
                builder: (context, state) =>
                    const PrimaryBranchScaffold(child: DevicesPage()),
                routes: [
                  GoRoute(
                    path: 'switch',
                    builder: (context, state) => const DeviceSwitchPage(),
                  ),
                  GoRoute(
                    path: 'info',
                    builder: (context, state) => const DeviceInfoPage(),
                  ),
                  GoRoute(
                    path: 'firmware',
                    pageBuilder: (context, state) => CustomTransitionPage<void>(
                      key: state.pageKey,
                      transitionDuration: const Duration(milliseconds: 320),
                      reverseTransitionDuration: const Duration(
                        milliseconds: 300,
                      ),
                      child: const OronBoxScaffoldMessenger(
                        child: DeviceFirmwarePage(),
                      ),
                      transitionsBuilder: AppTheme.buildPlatformPageTransition,
                    ),
                  ),
                  GoRoute(
                    path: 'install/:type',
                    builder: (context, state) {
                      final typeName = state.pathParameters['type']!;
                      final type = InstallType.values.firstWhere(
                        (e) => e.name == typeName,
                        orElse: () => InstallType.app,
                      );
                      return InstallLocalPage(type: type);
                    },
                  ),
                  GoRoute(
                    path: 'apps',
                    builder: (context, state) => const DeviceAppsPage(),
                    routes: [
                      GoRoute(
                        path: 'settings/:appId',
                        redirect: (context, state) =>
                            int.tryParse(state.pathParameters['appId'] ?? '') ==
                                null
                            ? '/devices/apps'
                            : null,
                        pageBuilder: (context, state) {
                          final appId = int.parse(
                            state.pathParameters['appId']!,
                          );
                          final title =
                              state.uri.queryParameters['title'] ??
                              '0x${appId.toRadixString(16).padLeft(8, '0')}';
                          return CustomTransitionPage<void>(
                            key: state.pageKey,
                            transitionDuration: Duration.zero,
                            reverseTransitionDuration: Duration.zero,
                            child: ZeppOsSettingViewerPage(
                              appId: appId,
                              title: title,
                            ),
                            transitionsBuilder: (_, _, _, child) => child,
                          );
                        },
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'watchfaces',
                    builder: (context, state) => const DeviceWatchfacesPage(),
                  ),
                  GoRoute(
                    path: 'velaos-music',
                    builder: (context, state) =>
                        const DeviceMusicUploadPage(xiaomi: true),
                  ),
                  GoRoute(
                    path: 'velaos-recordings',
                    builder: (context, state) => const XiaomiRecordingsPage(),
                  ),
                  GoRoute(
                    path: 'velaos-health',
                    builder: (context, state) => const XiaomiHealthPage(),
                    routes: [
                      GoRoute(
                        path: 'detail',
                        pageBuilder: (context, state) {
                          final args = state.extra;
                          final detailArgs = switch (args) {
                            XiaomiHealthDetailArgs value => value,
                            XiaomiHealthWorkoutRouteArgs value => value.health,
                            _ => null,
                          };
                          final child = detailArgs == null
                              ? const XiaomiHealthPage()
                              : XiaomiHealthDetailPage(args: detailArgs);
                          return CustomTransitionPage<void>(
                            key: state.pageKey,
                            transitionDuration: const Duration(
                              milliseconds: 320,
                            ),
                            reverseTransitionDuration: const Duration(
                              milliseconds: 300,
                            ),
                            child: OronBoxScaffoldMessenger(child: child),
                            transitionsBuilder:
                                AppTheme.buildPlatformPageTransition,
                          );
                        },
                        routes: [
                          GoRoute(
                            path: 'workout/:id',
                            pageBuilder: (context, state) {
                              final extra = state.extra;
                              final preview = switch (extra) {
                                XiaomiHealthWorkoutRouteArgs value =>
                                  value.workout,
                                HealthWorkoutSummary value => value,
                                _ => null,
                              };
                              return CustomTransitionPage<void>(
                                key: state.pageKey,
                                transitionDuration: const Duration(
                                  milliseconds: 320,
                                ),
                                reverseTransitionDuration: const Duration(
                                  milliseconds: 300,
                                ),
                                child: OronBoxScaffoldMessenger(
                                  child: XiaomiHealthWorkoutPage(
                                    workoutId: state.pathParameters['id']!,
                                    preview: preview,
                                    deviceId:
                                        extra is XiaomiHealthWorkoutRouteArgs
                                        ? extra.health.deviceId
                                        : null,
                                  ),
                                ),
                                transitionsBuilder:
                                    AppTheme.buildPlatformPageTransition,
                              );
                            },
                          ),
                        ],
                      ),
                      GoRoute(
                        path: 'debug',
                        pageBuilder: (context, state) =>
                            CustomTransitionPage<void>(
                              key: state.pageKey,
                              transitionDuration: const Duration(
                                milliseconds: 320,
                              ),
                              reverseTransitionDuration: const Duration(
                                milliseconds: 300,
                              ),
                              child: const OronBoxScaffoldMessenger(
                                child: XiaomiHealthDebugPage(),
                              ),
                              transitionsBuilder:
                                  AppTheme.buildPlatformPageTransition,
                            ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'velaos-app-arrangement',
                    builder: (context, state) =>
                        const XiaomiAppArrangementPage(),
                  ),
                  GoRoute(
                    path: 'velaos-app-layout',
                    redirect: (context, state) =>
                        '/devices/velaos-app-arrangement',
                  ),
                  GoRoute(
                    path: 'velaos-app-order',
                    redirect: (context, state) =>
                        '/devices/velaos-app-arrangement',
                  ),
                  GoRoute(
                    path: 'velaos-alarms',
                    builder: (context, state) => const XiaomiAlarmsPage(),
                  ),
                  GoRoute(
                    path: 'velaos-phone-location',
                    redirect: (context, state) => '/settings/permissions',
                  ),
                  GoRoute(
                    path: 'velaos-weather',
                    builder: (context, state) => const XiaomiWeatherPage(),
                  ),
                  GoRoute(
                    path: 'zeppos-more',
                    builder: (context, state) => const ZeppOsMoreFeaturesPage(),
                    routes: [
                      GoRoute(
                        path: 'xiao-ai',
                        redirect: (context, state) =>
                            '/settings/labs/voice-assistant',
                      ),
                      GoRoute(
                        path: 'voice-memos',
                        builder: (context, state) =>
                            const ZeppOsVoiceMemosPage(),
                      ),
                      GoRoute(
                        path: 'music',
                        builder: (context, state) =>
                            const DeviceMusicUploadPage(),
                      ),
                      GoRoute(
                        path: 'app-side',
                        builder: (context, state) =>
                            const ZeppOsAppSideDebugPage(),
                      ),
                      GoRoute(
                        path: 'settings',
                        builder: (context, state) =>
                            const ZeppOsAppSettingsPage(),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/queue',
                builder: (context, state) =>
                    const PrimaryBranchScaffold(child: QueuePage()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/plugins',
                builder: (context, state) => PrimaryBranchScaffold(
                  child: PluginsPage(
                    key: ValueKey(state.uri.queryParameters['plugin'] ?? ''),
                    targetPluginId: state.uri.queryParameters['plugin'] ?? '',
                  ),
                ),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (context, state) =>
                        PluginDetailPage(pluginId: state.pathParameters['id']!),
                    routes: [
                      GoRoute(
                        path: 'page',
                        pageBuilder: (context, state) {
                          final extra = state.extra;
                          final args = extra is PluginUiRouteArgs
                              ? extra
                              : null;
                          return CustomTransitionPage<void>(
                            key: state.pageKey,
                            transitionDuration: const Duration(
                              milliseconds: 320,
                            ),
                            reverseTransitionDuration: const Duration(
                              milliseconds: 300,
                            ),
                            child: OronBoxScaffoldMessenger(
                              child: PluginUiPage(
                                pluginId: state.pathParameters['id']!,
                                preview: args?.nodes,
                                title: args?.title ?? '',
                              ),
                            ),
                            transitionsBuilder:
                                AppTheme.buildPlatformPageTransition,
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) =>
                    const PrimaryBranchScaffold(child: SettingsPage()),
                routes: [
                  for (final category in SettingsCategory.values)
                    GoRoute(
                      path: category.name,
                      builder: (context, state) =>
                          SettingsPage(category: category),
                    ),
                  GoRoute(
                    path: 'data',
                    builder: (context, state) => const AppDataPage(),
                  ),
                  GoRoute(
                    path: 'clean-mode',
                    builder: (context, state) => const CleanModePage(),
                  ),
                  GoRoute(
                    path: 'about',
                    builder: (context, state) => const AboutSoftwarePage(),
                  ),
                  GoRoute(
                    path: 'permissions',
                    builder: (context, state) => const AppPermissionsPage(),
                  ),
                  GoRoute(
                    path: 'legal/:id',
                    builder: (context, state) => LegalDocumentPage(
                      id: state.pathParameters['id']!,
                      title: state.extra?.toString() ?? '',
                    ),
                  ),
                  GoRoute(
                    path: 'logs',
                    builder: (context, state) => const RuntimeLogsPage(),
                  ),
                  GoRoute(
                    path: 'labs',
                    builder: (context, state) => const FeatureLabPage(),
                    routes: [
                      GoRoute(
                        path: 'global-ai',
                        builder: (context, state) => const GlobalAiPage(),
                      ),
                      GoRoute(
                        path: 'voice-assistant',
                        builder: (context, state) => const VoiceAssistantPage(),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'local-server',
                    builder: (context, state) => const LocalServerPage(),
                  ),
                  GoRoute(
                    path: 'bandbbs',
                    builder: (context, state) => const BandBbsAccountPage(),
                  ),
                  GoRoute(
                    path: 'team',
                    redirect: (context, state) => '/settings/about',
                  ),
                  GoRoute(
                    path: 'acknowledgements',
                    builder: (context, state) => const AcknowledgementsPage(),
                  ),
                  GoRoute(
                    path: 'licenses',
                    builder: (context, state) =>
                        const LicensePage(applicationName: 'OronBox'),
                  ),
                  GoRoute(
                    path: 'feedback',
                    builder: (context, state) =>
                        FeedbackPage(target: state.extra as FeedbackTarget?),
                    routes: [
                      GoRoute(
                        path: 'ticket',
                        builder: (context, state) =>
                            state.extra is FeedbackTicket
                            ? FeedbackTicketPage(
                                ticket: state.extra! as FeedbackTicket,
                              )
                            : FeedbackTicketLinkPage(
                                ticketId: state.uri.queryParameters['id'] ?? '',
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
