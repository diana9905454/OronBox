import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oronbox/src/core/services/shared_prefs_service.dart';
import 'package:oronbox/src/core/network/github_cdn.dart';
import 'package:oronbox/src/data/community/community_source.dart';

enum WideNavigationRailPosition { bottom, center, split }

const removeBondBeforeSppSettingKey = 'remove_bond_before_spp';
const realtimeActivityNotificationSettingKey = 'realtime_activity_notification';

class CleanSettings {
  const CleanSettings({
    this.exploreEntry = true,
    this.pluginsEntry = true,
    this.homeFeed = true,
    this.explore = true,
    this.inbox = true,
    this.announcements = true,
    this.comments = true,
    this.creator = true,
    this.bandBbsLogin = true,
    this.githubLogin = true,
    this.oronBox = true,
    this.bandBbs = true,
    this.astroBox = true,
    this.huamiAppStore = true,
    this.homeBanner = true,
    this.homeEditorSections = true,
    this.homeFeatured = true,
    this.homeRecommended = true,
    this.homeLatest = true,
  });
  final bool exploreEntry,
      pluginsEntry,
      homeFeed,
      explore,
      inbox,
      announcements,
      comments,
      creator,
      bandBbsLogin,
      githubLogin,
      oronBox,
      bandBbs,
      astroBox,
      huamiAppStore,
      homeBanner,
      homeEditorSections,
      homeFeatured,
      homeRecommended,
      homeLatest;
  bool get exploreEnabled => exploreEntry;
  bool get pluginsEnabled => pluginsEntry;
  bool get homeFeedEnabled => exploreEnabled && homeFeed;
  bool get resourceLibraryEnabled => exploreEnabled && explore;
  bool get inboxEnabled => exploreEnabled && inbox;
  bool get creatorEnabled => exploreEnabled && creator;
  bool get commentsEnabled => resourceLibraryEnabled && comments;
  bool get oronBoxSourceEnabled => resourceLibraryEnabled && oronBox;
  bool get bandBbsSourceEnabled => resourceLibraryEnabled && bandBbs;
  bool get astroBoxSourceEnabled => resourceLibraryEnabled && astroBox;
  bool get huamiAppStoreSourceEnabled =>
      resourceLibraryEnabled && huamiAppStore;
  bool get bandBbsLoginEnabled => bandBbsLogin;
  bool get githubLoginEnabled => bandBbsLoginEnabled && githubLogin;
  bool get announcementsEnabled => announcements;
  bool get hasHomeSection =>
      homeBanner ||
      homeEditorSections ||
      homeFeatured ||
      homeRecommended ||
      homeLatest;
  bool get homeBannerEnabled => homeFeedEnabled && homeBanner;
  bool get homeEditorSectionsEnabled => homeFeedEnabled && homeEditorSections;
  bool get homeFeaturedEnabled => homeFeedEnabled && homeFeatured;
  bool get homeRecommendedEnabled => homeFeedEnabled && homeRecommended;
  bool get homeLatestEnabled => homeFeedEnabled && homeLatest;
  bool get hasResourceSource =>
      oronBoxSourceEnabled ||
      bandBbsSourceEnabled ||
      astroBoxSourceEnabled ||
      huamiAppStoreSourceEnabled;

  // 子项全关时联动关父项
  CleanSettings get normalized {
    final feed = homeFeed && hasHomeSection;
    return copyWith(
      homeFeed: feed,
      exploreEntry: exploreEntry && (feed || explore),
    );
  }

  CleanSettings copyWith({
    bool? exploreEntry,
    bool? pluginsEntry,
    bool? homeFeed,
    bool? explore,
    bool? inbox,
    bool? announcements,
    bool? comments,
    bool? creator,
    bool? bandBbsLogin,
    bool? githubLogin,
    bool? oronBox,
    bool? bandBbs,
    bool? astroBox,
    bool? huamiAppStore,
    bool? homeBanner,
    bool? homeEditorSections,
    bool? homeFeatured,
    bool? homeRecommended,
    bool? homeLatest,
  }) => CleanSettings(
    exploreEntry: exploreEntry ?? this.exploreEntry,
    pluginsEntry: pluginsEntry ?? this.pluginsEntry,
    homeFeed: homeFeed ?? this.homeFeed,
    explore: explore ?? this.explore,
    inbox: inbox ?? this.inbox,
    announcements: announcements ?? this.announcements,
    comments: comments ?? this.comments,
    creator: creator ?? this.creator,
    bandBbsLogin: bandBbsLogin ?? this.bandBbsLogin,
    githubLogin: githubLogin ?? this.githubLogin,
    oronBox: oronBox ?? this.oronBox,
    bandBbs: bandBbs ?? this.bandBbs,
    astroBox: astroBox ?? this.astroBox,
    huamiAppStore: huamiAppStore ?? this.huamiAppStore,
    homeBanner: homeBanner ?? this.homeBanner,
    homeEditorSections: homeEditorSections ?? this.homeEditorSections,
    homeFeatured: homeFeatured ?? this.homeFeatured,
    homeRecommended: homeRecommended ?? this.homeRecommended,
    homeLatest: homeLatest ?? this.homeLatest,
  );
}

class AppSettings {
  const AppSettings({
    required this.cdn,
    this.effectiveCdn = GitHubCdn.raw,
    required this.communitySource,
    required this.autoInstall,
    required this.disableAutoClean,
    required this.autoReconnect,
    this.autoReconnectOnDisconnect = false,
    required this.wideNavigationRailPosition,
    required this.bandbbsLoadPreviews,
    required this.bandbbsShowAllCategories,
    this.removeBondBeforeSpp = true,
    this.realtimeActivityNotification = true,
    this.checkUpdateOnLaunch = true,
    this.clean = const CleanSettings(),
  });

  final GitHubCdn cdn;
  final GitHubCdn effectiveCdn;
  final CommunitySourceId communitySource;
  final bool autoInstall;
  final bool disableAutoClean;
  final bool autoReconnect;
  final bool autoReconnectOnDisconnect;
  final WideNavigationRailPosition wideNavigationRailPosition;
  final bool bandbbsLoadPreviews;
  final bool bandbbsShowAllCategories;
  final bool removeBondBeforeSpp;
  final bool realtimeActivityNotification;
  final bool checkUpdateOnLaunch;
  final CleanSettings clean;

  AppSettings copyWith({
    GitHubCdn? cdn,
    GitHubCdn? effectiveCdn,
    CommunitySourceId? communitySource,
    bool? autoInstall,
    bool? disableAutoClean,
    bool? autoReconnect,
    bool? autoReconnectOnDisconnect,
    WideNavigationRailPosition? wideNavigationRailPosition,
    bool? bandbbsLoadPreviews,
    bool? checkUpdateOnLaunch,
    bool? bandbbsShowAllCategories,
    bool? removeBondBeforeSpp,
    bool? realtimeActivityNotification,
    CleanSettings? clean,
  }) {
    return AppSettings(
      cdn: cdn ?? this.cdn,
      effectiveCdn: effectiveCdn ?? this.effectiveCdn,
      communitySource: communitySource ?? this.communitySource,
      autoInstall: autoInstall ?? this.autoInstall,
      disableAutoClean: disableAutoClean ?? this.disableAutoClean,
      autoReconnect: autoReconnect ?? this.autoReconnect,
      autoReconnectOnDisconnect:
          autoReconnectOnDisconnect ?? this.autoReconnectOnDisconnect,
      wideNavigationRailPosition:
          wideNavigationRailPosition ?? this.wideNavigationRailPosition,
      bandbbsLoadPreviews: bandbbsLoadPreviews ?? this.bandbbsLoadPreviews,
      bandbbsShowAllCategories:
          bandbbsShowAllCategories ?? this.bandbbsShowAllCategories,
      removeBondBeforeSpp: removeBondBeforeSpp ?? this.removeBondBeforeSpp,
      realtimeActivityNotification:
          realtimeActivityNotification ?? this.realtimeActivityNotification,
      checkUpdateOnLaunch: checkUpdateOnLaunch ?? this.checkUpdateOnLaunch,
      clean: clean ?? this.clean,
    );
  }

  static const String _keyCdn = 'github_cdn';
  static const String _keyEffectiveCdn = 'github_cdn_effective';
  static const String _keyCommunitySource = 'community_source';
  static const String _keyAutoInstall = 'auto_install';
  static const String _keyDisableAutoClean = 'disable_auto_clean';
  static const String _keyAutoReconnect = 'auto_reconnect';
  static const String _keyAutoReconnectOnDisconnect =
      'auto_reconnect_on_disconnect';
  static const String _keyWideNavigationRailPosition =
      'wide_navigation_rail_position';
  static const String _keyBandBbsLoadPreviews = 'bandbbs_load_previews';
  static const String _keyCheckUpdateOnLaunch = 'check_update_on_launch';
  static const String _keyBandBbsShowAllCategories =
      'bandbbs_show_all_categories';

  static AppSettings load() {
    final prefs = SharedPrefsService.instance;
    final cdnRaw = prefs.getString(_keyCdn);
    final cdn = githubCdnByName(cdnRaw ?? '') ?? GitHubCdn.auto;
    final effectiveCdn =
        githubCdnByName(prefs.getString(_keyEffectiveCdn) ?? '') ??
        (cdn == GitHubCdn.auto ? GitHubCdn.raw : cdn);
    final sourceRaw = prefs.getString(_keyCommunitySource);
    final railPositionRaw = prefs.getString(_keyWideNavigationRailPosition);
    return AppSettings(
      cdn: cdn,
      effectiveCdn: effectiveCdn,
      communitySource:
          communitySourceIdByName(sourceRaw ?? '') ?? CommunitySourceId.oronBox,
      autoInstall: prefs.getBool(_keyAutoInstall) ?? true,
      disableAutoClean: prefs.getBool(_keyDisableAutoClean) ?? false,
      autoReconnect: prefs.getBool(_keyAutoReconnect) ?? false,
      autoReconnectOnDisconnect:
          prefs.getBool(_keyAutoReconnectOnDisconnect) ?? false,
      wideNavigationRailPosition: _enumByName(
        WideNavigationRailPosition.values,
        railPositionRaw,
        WideNavigationRailPosition.bottom,
      ),
      bandbbsLoadPreviews: prefs.getBool(_keyBandBbsLoadPreviews) ?? false,
      bandbbsShowAllCategories:
          prefs.getBool(_keyBandBbsShowAllCategories) ?? false,
      removeBondBeforeSpp: prefs.getBool(removeBondBeforeSppSettingKey) ?? true,
      realtimeActivityNotification:
          prefs.getBool(realtimeActivityNotificationSettingKey) ?? true,
      checkUpdateOnLaunch: prefs.getBool(_keyCheckUpdateOnLaunch) ?? true,
      clean: CleanSettings(
        exploreEntry: prefs.getBool('clean_explore_entry') ?? true,
        pluginsEntry: prefs.getBool('clean_plugins_entry') ?? true,
        homeFeed: prefs.getBool('clean_home_feed') ?? true,
        explore: prefs.getBool('clean_explore') ?? true,
        inbox: prefs.getBool('clean_inbox') ?? true,
        announcements: prefs.getBool('clean_announcements') ?? true,
        comments: prefs.getBool('clean_comments') ?? true,
        creator: prefs.getBool('clean_creator') ?? true,
        bandBbsLogin: prefs.getBool('clean_bandbbs_login') ?? true,
        githubLogin: prefs.getBool('clean_github_login') ?? true,
        oronBox: prefs.getBool('clean_source_oronbox') ?? true,
        bandBbs: prefs.getBool('clean_source_bandbbs') ?? true,
        astroBox: prefs.getBool('clean_source_astrobox') ?? true,
        huamiAppStore: prefs.getBool('clean_source_huami_app_store') ?? true,
        homeBanner: prefs.getBool('clean_home_banner') ?? true,
        homeEditorSections: prefs.getBool('clean_home_editor_sections') ?? true,
        homeFeatured: prefs.getBool('clean_home_featured') ?? true,
        homeRecommended: prefs.getBool('clean_home_recommended') ?? true,
        homeLatest: prefs.getBool('clean_home_latest') ?? true,
      ),
    );
  }

  static const defaults = AppSettings(
    cdn: GitHubCdn.auto,
    effectiveCdn: GitHubCdn.raw,
    communitySource: CommunitySourceId.oronBox,
    autoInstall: true,
    disableAutoClean: false,
    autoReconnect: false,
    autoReconnectOnDisconnect: false,
    wideNavigationRailPosition: WideNavigationRailPosition.bottom,
    bandbbsLoadPreviews: false,
    bandbbsShowAllCategories: false,
    removeBondBeforeSpp: true,
    realtimeActivityNotification: true,
  );

  Future<void> save() async {
    final prefs = SharedPrefsService.instance;
    await prefs.setString(_keyCdn, cdn.name);
    await prefs.setString(_keyEffectiveCdn, effectiveCdn.name);
    await prefs.setString(_keyCommunitySource, communitySource.storageKey);
    await prefs.setBool(_keyAutoInstall, autoInstall);
    await prefs.setBool(_keyDisableAutoClean, disableAutoClean);
    await prefs.setBool(_keyAutoReconnect, autoReconnect);
    await prefs.setBool(
      _keyAutoReconnectOnDisconnect,
      autoReconnectOnDisconnect,
    );
    await prefs.setString(
      _keyWideNavigationRailPosition,
      wideNavigationRailPosition.name,
    );
    await prefs.setBool(_keyBandBbsLoadPreviews, bandbbsLoadPreviews);
    await prefs.setBool(_keyBandBbsShowAllCategories, bandbbsShowAllCategories);
    await prefs.setBool(removeBondBeforeSppSettingKey, removeBondBeforeSpp);
    await prefs.setBool(
      realtimeActivityNotificationSettingKey,
      realtimeActivityNotification,
    );
    await prefs.setBool(_keyCheckUpdateOnLaunch, checkUpdateOnLaunch);
    await prefs.setBool('clean_explore_entry', clean.exploreEntry);
    await prefs.setBool('clean_plugins_entry', clean.pluginsEntry);
    await prefs.setBool('clean_home_feed', clean.homeFeed);
    await prefs.setBool('clean_explore', clean.explore);
    await prefs.setBool('clean_inbox', clean.inbox);
    await prefs.setBool('clean_announcements', clean.announcements);
    await prefs.setBool('clean_comments', clean.comments);
    await prefs.setBool('clean_creator', clean.creator);
    await prefs.setBool('clean_bandbbs_login', clean.bandBbsLogin);
    await prefs.setBool('clean_github_login', clean.githubLogin);
    await prefs.setBool('clean_source_oronbox', clean.oronBox);
    await prefs.setBool('clean_source_bandbbs', clean.bandBbs);
    await prefs.setBool('clean_source_astrobox', clean.astroBox);
    await prefs.setBool('clean_source_huami_app_store', clean.huamiAppStore);
    await prefs.setBool('clean_home_banner', clean.homeBanner);
    await prefs.setBool('clean_home_editor_sections', clean.homeEditorSections);
    await prefs.setBool('clean_home_featured', clean.homeFeatured);
    await prefs.setBool('clean_home_recommended', clean.homeRecommended);
    await prefs.setBool('clean_home_latest', clean.homeLatest);
  }

  static T _enumByName<T extends Enum>(
    Iterable<T> values,
    String? name,
    T fallback,
  ) {
    if (name == null) return fallback;
    for (final value in values) {
      if (value.name == name) return value;
    }
    return fallback;
  }
}

abstract class AppSettingsNotifier extends Notifier<AppSettings> {
  Future<void> setCdn(GitHubCdn cdn);
  Future<void> setEffectiveCdn(GitHubCdn cdn);
  Future<void> setCommunitySource(CommunitySourceId source);
  Future<void> setAutoInstall(bool value);
  Future<void> setDisableAutoClean(bool value);
  Future<void> setAutoReconnect(bool value);
  Future<void> setAutoReconnectOnDisconnect(bool value);
  Future<void> setWideNavigationRailPosition(WideNavigationRailPosition value);
  Future<void> setBandBbsLoadPreviews(bool value);
  Future<void> setBandBbsShowAllCategories(bool value);
  Future<void> setRemoveBondBeforeSpp(bool value);
  Future<void> setRealtimeActivityNotification(bool value);
  Future<void> setCheckUpdateOnLaunch(bool value);
  Future<void> setClean(CleanSettings value);
}

const xmsDeveloperSkipSignatureKey = 'xmsDeveloperSkipSignature';

class XmsDeveloperModeNotifier extends Notifier<bool> {
  @override
  bool build() =>
      SharedPrefsService.instance.getBool(xmsDeveloperSkipSignatureKey) ??
      false;

  Future<void> setEnabled(bool value) async {
    state = value;
    await SharedPrefsService.instance.setBool(
      xmsDeveloperSkipSignatureKey,
      value,
    );
  }
}

final xmsDeveloperModeProvider =
    NotifierProvider<XmsDeveloperModeNotifier, bool>(
      XmsDeveloperModeNotifier.new,
    );

class LocalAppSettingsNotifier extends AppSettingsNotifier {
  @override
  AppSettings build() => AppSettings.load();

  @override
  Future<void> setCdn(GitHubCdn cdn) async {
    state = state.copyWith(
      cdn: cdn,
      effectiveCdn: cdn == GitHubCdn.auto ? state.effectiveCdn : cdn,
    );
    await state.save();
  }

  @override
  Future<void> setEffectiveCdn(GitHubCdn cdn) async {
    state = state.copyWith(effectiveCdn: cdn);
    await state.save();
  }

  @override
  Future<void> setCommunitySource(CommunitySourceId source) async {
    state = state.copyWith(communitySource: source);
    await state.save();
  }

  @override
  Future<void> setAutoInstall(bool value) async {
    state = state.copyWith(autoInstall: value);
    await state.save();
  }

  @override
  Future<void> setDisableAutoClean(bool value) async {
    state = state.copyWith(disableAutoClean: value);
    await state.save();
  }

  @override
  Future<void> setAutoReconnect(bool value) async {
    state = state.copyWith(autoReconnect: value);
    await state.save();
  }

  @override
  Future<void> setAutoReconnectOnDisconnect(bool value) async {
    state = state.copyWith(autoReconnectOnDisconnect: value);
    await state.save();
  }

  @override
  Future<void> setWideNavigationRailPosition(
    WideNavigationRailPosition value,
  ) async {
    state = state.copyWith(wideNavigationRailPosition: value);
    await state.save();
  }

  @override
  Future<void> setBandBbsLoadPreviews(bool value) async {
    state = state.copyWith(bandbbsLoadPreviews: value);
    await state.save();
  }

  @override
  Future<void> setBandBbsShowAllCategories(bool value) async {
    state = state.copyWith(bandbbsShowAllCategories: value);
    await state.save();
  }

  @override
  Future<void> setRemoveBondBeforeSpp(bool value) async {
    state = state.copyWith(removeBondBeforeSpp: value);
    await state.save();
  }

  @override
  Future<void> setRealtimeActivityNotification(bool value) async {
    state = state.copyWith(realtimeActivityNotification: value);
    await state.save();
  }

  @override
  Future<void> setCheckUpdateOnLaunch(bool value) async {
    state = state.copyWith(checkUpdateOnLaunch: value);
    await state.save();
  }

  @override
  Future<void> setClean(CleanSettings value) async {
    state = state.copyWith(clean: value.normalized);
    await state.save();
  }
}

final appSettingsProvider = NotifierProvider<AppSettingsNotifier, AppSettings>(
  LocalAppSettingsNotifier.new,
);
