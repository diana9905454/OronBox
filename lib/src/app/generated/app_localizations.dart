import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ja'),
    Locale('ru'),
    Locale('zh'),
    Locale('zh', 'TW'),
  ];

  /// No description provided for @homeTab.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get homeTab;

  /// No description provided for @exploreTab.
  ///
  /// In en, this message translates to:
  /// **'Explore'**
  String get exploreTab;

  /// No description provided for @devicesTab.
  ///
  /// In en, this message translates to:
  /// **'Devices'**
  String get devicesTab;

  /// No description provided for @pluginsTab.
  ///
  /// In en, this message translates to:
  /// **'Plugins'**
  String get pluginsTab;

  /// No description provided for @pluginImport.
  ///
  /// In en, this message translates to:
  /// **'Import plugin'**
  String get pluginImport;

  /// No description provided for @pluginInstalled.
  ///
  /// In en, this message translates to:
  /// **'Installed'**
  String get pluginInstalled;

  /// No description provided for @pluginMarket.
  ///
  /// In en, this message translates to:
  /// **'Plugin market'**
  String get pluginMarket;

  /// No description provided for @pluginMarketUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The plugin market is not available yet'**
  String get pluginMarketUnavailable;

  /// No description provided for @pluginEmpty.
  ///
  /// In en, this message translates to:
  /// **'No plugins installed'**
  String get pluginEmpty;

  /// No description provided for @pluginSelectHint.
  ///
  /// In en, this message translates to:
  /// **'Select a plugin to view its features'**
  String get pluginSelectHint;

  /// No description provided for @pluginFeatures.
  ///
  /// In en, this message translates to:
  /// **'Features'**
  String get pluginFeatures;

  /// No description provided for @pluginDetails.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get pluginDetails;

  /// No description provided for @pluginNoFeatures.
  ///
  /// In en, this message translates to:
  /// **'This plugin has no available features'**
  String get pluginNoFeatures;

  /// No description provided for @pluginAuthor.
  ///
  /// In en, this message translates to:
  /// **'Author'**
  String get pluginAuthor;

  /// No description provided for @pluginVersion.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get pluginVersion;

  /// No description provided for @pluginApiLevel.
  ///
  /// In en, this message translates to:
  /// **'API level'**
  String get pluginApiLevel;

  /// No description provided for @pluginWebsite.
  ///
  /// In en, this message translates to:
  /// **'Website'**
  String get pluginWebsite;

  /// No description provided for @pluginPermissions.
  ///
  /// In en, this message translates to:
  /// **'Permissions'**
  String get pluginPermissions;

  /// No description provided for @pluginInstallConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm plugin installation'**
  String get pluginInstallConfirmTitle;

  /// No description provided for @pluginUpdateConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm plugin update'**
  String get pluginUpdateConfirmTitle;

  /// No description provided for @pluginDeclaredPermissions.
  ///
  /// In en, this message translates to:
  /// **'This plugin declares the following permissions:'**
  String get pluginDeclaredPermissions;

  /// No description provided for @pluginNoPermissions.
  ///
  /// In en, this message translates to:
  /// **'No permissions declared'**
  String get pluginNoPermissions;

  /// No description provided for @pluginUpToDate.
  ///
  /// In en, this message translates to:
  /// **'Installed and up to date'**
  String get pluginUpToDate;

  /// No description provided for @pluginUninstallTitle.
  ///
  /// In en, this message translates to:
  /// **'Uninstall plugin'**
  String get pluginUninstallTitle;

  /// No description provided for @pluginUninstallMessage.
  ///
  /// In en, this message translates to:
  /// **'The plugin\'s data will also be removed'**
  String get pluginUninstallMessage;

  /// No description provided for @pluginUpload.
  ///
  /// In en, this message translates to:
  /// **'Upload plugin'**
  String get pluginUpload;

  /// No description provided for @pluginPublishTitle.
  ///
  /// In en, this message translates to:
  /// **'Publish plugin'**
  String get pluginPublishTitle;

  /// No description provided for @pluginPublishNew.
  ///
  /// In en, this message translates to:
  /// **'Will be published as a new plugin'**
  String get pluginPublishNew;

  /// No description provided for @pluginPublishUpdate.
  ///
  /// In en, this message translates to:
  /// **'Will update the published plugin with the same ID'**
  String get pluginPublishUpdate;

  /// No description provided for @pluginTakedown.
  ///
  /// In en, this message translates to:
  /// **'Take down'**
  String get pluginTakedown;

  /// No description provided for @pluginTakedownConfirm.
  ///
  /// In en, this message translates to:
  /// **'The plugin will be permanently removed from the market'**
  String get pluginTakedownConfirm;

  /// No description provided for @pluginLoginRequired.
  ///
  /// In en, this message translates to:
  /// **'Sign in to upload plugins'**
  String get pluginLoginRequired;

  /// No description provided for @pluginSubmittedForReview.
  ///
  /// In en, this message translates to:
  /// **'Submitted for review. It will be listed once approved'**
  String get pluginSubmittedForReview;

  /// No description provided for @pluginStatePending.
  ///
  /// In en, this message translates to:
  /// **'Pending review'**
  String get pluginStatePending;

  /// No description provided for @pluginStateRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get pluginStateRejected;

  /// No description provided for @pluginStateDelisted.
  ///
  /// In en, this message translates to:
  /// **'Delisted'**
  String get pluginStateDelisted;

  /// No description provided for @pluginLegacyWarningTitle.
  ///
  /// In en, this message translates to:
  /// **'Legacy plugin'**
  String get pluginLegacyWarningTitle;

  /// No description provided for @pluginLegacyWarningMessage.
  ///
  /// In en, this message translates to:
  /// **'This is an AstroBox v1 plugin. OronBox will try to run it in compatibility mode, but issues may occur.\nCheck for an updated native OronBox plugin, or ask the author to adapt it'**
  String get pluginLegacyWarningMessage;

  /// No description provided for @settingsTab.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTab;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @resourceListView.
  ///
  /// In en, this message translates to:
  /// **'List view'**
  String get resourceListView;

  /// No description provided for @resourceGridView.
  ///
  /// In en, this message translates to:
  /// **'Card view'**
  String get resourceGridView;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @refreshing.
  ///
  /// In en, this message translates to:
  /// **'Refreshing'**
  String get refreshing;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @newlyPublished.
  ///
  /// In en, this message translates to:
  /// **'Newly published'**
  String get newlyPublished;

  /// No description provided for @resourceLibrary.
  ///
  /// In en, this message translates to:
  /// **'Resource library'**
  String get resourceLibrary;

  /// No description provided for @resourceDetails.
  ///
  /// In en, this message translates to:
  /// **'Resource details'**
  String get resourceDetails;

  /// No description provided for @resourceCollectionDetails.
  ///
  /// In en, this message translates to:
  /// **'Collection details'**
  String get resourceCollectionDetails;

  /// No description provided for @resourceArticleDetails.
  ///
  /// In en, this message translates to:
  /// **'Article details'**
  String get resourceArticleDetails;

  /// No description provided for @creatorCenter.
  ///
  /// In en, this message translates to:
  /// **'Creator center'**
  String get creatorCenter;

  /// No description provided for @creatorNewResource.
  ///
  /// In en, this message translates to:
  /// **'New resource'**
  String get creatorNewResource;

  /// No description provided for @creatorResourceName.
  ///
  /// In en, this message translates to:
  /// **'Resource name'**
  String get creatorResourceName;

  /// No description provided for @creatorResourceSummary.
  ///
  /// In en, this message translates to:
  /// **'Resource summary'**
  String get creatorResourceSummary;

  /// No description provided for @creatorResourceMetadataRequired.
  ///
  /// In en, this message translates to:
  /// **'Resource name and summary are required'**
  String get creatorResourceMetadataRequired;

  /// No description provided for @creatorSubmitValidationFailed.
  ///
  /// In en, this message translates to:
  /// **'Please fix the following before submitting'**
  String get creatorSubmitValidationFailed;

  /// No description provided for @creatorPaidType.
  ///
  /// In en, this message translates to:
  /// **'Payment type'**
  String get creatorPaidType;

  /// No description provided for @creatorSaveDraft.
  ///
  /// In en, this message translates to:
  /// **'Save draft'**
  String get creatorSaveDraft;

  /// No description provided for @creatorAddArtifact.
  ///
  /// In en, this message translates to:
  /// **'Add resource file'**
  String get creatorAddArtifact;

  /// No description provided for @creatorBindDevices.
  ///
  /// In en, this message translates to:
  /// **'Bind devices'**
  String get creatorBindDevices;

  /// No description provided for @creatorDeleteResource.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get creatorDeleteResource;

  /// No description provided for @creatorIconCover.
  ///
  /// In en, this message translates to:
  /// **'Icon & cover'**
  String get creatorIconCover;

  /// No description provided for @creatorInvalidImage.
  ///
  /// In en, this message translates to:
  /// **'Unable to decode this image; use PNG/JPEG/WebP'**
  String get creatorInvalidImage;

  /// No description provided for @creatorInvalidPackage.
  ///
  /// In en, this message translates to:
  /// **'This file is not a Vela quick app or watchface'**
  String get creatorInvalidPackage;

  /// No description provided for @creatorPublishPreparing.
  ///
  /// In en, this message translates to:
  /// **'Processing file {done}/{total}'**
  String creatorPublishPreparing(Object done, Object total);

  /// No description provided for @creatorPublishUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading {percent}%'**
  String creatorPublishUploading(Object percent);

  /// No description provided for @creatorPublishServer.
  ///
  /// In en, this message translates to:
  /// **'Server is processing…'**
  String get creatorPublishServer;

  /// No description provided for @creatorAstroBoxItemId.
  ///
  /// In en, this message translates to:
  /// **'Item ID'**
  String get creatorAstroBoxItemId;

  /// No description provided for @creatorAstroBoxRepository.
  ///
  /// In en, this message translates to:
  /// **'Repository name'**
  String get creatorAstroBoxRepository;

  /// No description provided for @creatorAstroBoxTags.
  ///
  /// In en, this message translates to:
  /// **'Tags (comma separated)'**
  String get creatorAstroBoxTags;

  /// No description provided for @creatorAstroBoxAuthor.
  ///
  /// In en, this message translates to:
  /// **'Author (must match your AstroBox username)'**
  String get creatorAstroBoxAuthor;

  /// No description provided for @creatorAstroBoxBindAccount.
  ///
  /// In en, this message translates to:
  /// **'Bind AstroBox account'**
  String get creatorAstroBoxBindAccount;

  /// No description provided for @replace.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get replace;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @creatorSubmitReview.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get creatorSubmitReview;

  /// No description provided for @creatorArchiveAction.
  ///
  /// In en, this message translates to:
  /// **'Delist'**
  String get creatorArchiveAction;

  /// No description provided for @creatorArchiveConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delisting hides this resource from the store. You can restore it anytime.'**
  String get creatorArchiveConfirm;

  /// No description provided for @creatorRestoreAction.
  ///
  /// In en, this message translates to:
  /// **'Relist'**
  String get creatorRestoreAction;

  /// No description provided for @creatorDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'This draft resource will be permanently deleted.'**
  String get creatorDeleteConfirm;

  /// No description provided for @creatorDeletePublishedConfirm.
  ///
  /// In en, this message translates to:
  /// **'Permanently deletes the OronBox resource and the corresponding BandBBS resources. This cannot be undone. Content already published on AstroBox is not affected; contact the AstroBox-Repo maintainers to delist it.'**
  String get creatorDeletePublishedConfirm;

  /// No description provided for @creatorArtifactCount.
  ///
  /// In en, this message translates to:
  /// **'{count} packages'**
  String creatorArtifactCount(Object count);

  /// No description provided for @creatorKindMismatchMessage.
  ///
  /// In en, this message translates to:
  /// **'This file looks like a {detected}, but this resource is a {expected}. You can keep it, but please confirm before submitting for review.'**
  String creatorKindMismatchMessage(Object detected, Object expected);

  /// No description provided for @creatorDeviceMoveBlocked.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" has only this device bound and cannot be moved'**
  String creatorDeviceMoveBlocked(Object name);

  /// No description provided for @creatorSelectDevices.
  ///
  /// In en, this message translates to:
  /// **'Select supported devices'**
  String get creatorSelectDevices;

  /// No description provided for @creatorSelectedDeviceCount.
  ///
  /// In en, this message translates to:
  /// **'{count} devices selected'**
  String creatorSelectedDeviceCount(Object count);

  /// No description provided for @creatorNoDevicesSelected.
  ///
  /// In en, this message translates to:
  /// **'No devices selected'**
  String get creatorNoDevicesSelected;

  /// No description provided for @creatorDeviceSelectionDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get creatorDeviceSelectionDone;

  /// No description provided for @creatorAtLeastOneDevice.
  ///
  /// In en, this message translates to:
  /// **'Each resource file must bind at least one device'**
  String get creatorAtLeastOneDevice;

  /// No description provided for @resourceAstroBoxEncryptedTitle.
  ///
  /// In en, this message translates to:
  /// **'OronBox cannot process this AstroBox resource'**
  String get resourceAstroBoxEncryptedTitle;

  /// No description provided for @resourceAstroBoxEncryptedMessage.
  ///
  /// In en, this message translates to:
  /// **'This resource uses AstroBox Creator Console\'s private encrypted upload. OronBox cannot decrypt, download, or install it. Please open it with AstroBox instead.'**
  String get resourceAstroBoxEncryptedMessage;

  /// No description provided for @resourceAstroBoxEncryptedAction.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get resourceAstroBoxEncryptedAction;

  /// No description provided for @filter.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get filter;

  /// No description provided for @resourceTypeFilter.
  ///
  /// In en, this message translates to:
  /// **'Resource type'**
  String get resourceTypeFilter;

  /// No description provided for @resourceCompatibleDevicesFilter.
  ///
  /// In en, this message translates to:
  /// **'Compatible devices'**
  String get resourceCompatibleDevicesFilter;

  /// No description provided for @currentDevice.
  ///
  /// In en, this message translates to:
  /// **'Current device'**
  String get currentDevice;

  /// No description provided for @currentWatchface.
  ///
  /// In en, this message translates to:
  /// **'Current watchface'**
  String get currentWatchface;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @watchfaces.
  ///
  /// In en, this message translates to:
  /// **'Watchface'**
  String get watchfaces;

  /// No description provided for @module.
  ///
  /// In en, this message translates to:
  /// **'Module'**
  String get module;

  /// No description provided for @quickApps.
  ///
  /// In en, this message translates to:
  /// **'Quickapps'**
  String get quickApps;

  /// No description provided for @firmwareTools.
  ///
  /// In en, this message translates to:
  /// **'Firmware / Tools'**
  String get firmwareTools;

  /// No description provided for @oronBox.
  ///
  /// In en, this message translates to:
  /// **'OronBox'**
  String get oronBox;

  /// No description provided for @bandbbs.
  ///
  /// In en, this message translates to:
  /// **'BandBBS'**
  String get bandbbs;

  /// No description provided for @astroBox.
  ///
  /// In en, this message translates to:
  /// **'AstroBox'**
  String get astroBox;

  /// No description provided for @local.
  ///
  /// In en, this message translates to:
  /// **'Local'**
  String get local;

  /// No description provided for @install.
  ///
  /// In en, this message translates to:
  /// **'Install'**
  String get install;

  /// No description provided for @update.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get update;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @supportedDevices.
  ///
  /// In en, this message translates to:
  /// **'Supported devices'**
  String get supportedDevices;

  /// No description provided for @downloads.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get downloads;

  /// No description provided for @downloadTimes.
  ///
  /// In en, this message translates to:
  /// **'{count} downloads'**
  String downloadTimes(int count);

  /// No description provided for @changelog.
  ///
  /// In en, this message translates to:
  /// **'Changelog'**
  String get changelog;

  /// No description provided for @changelogUnavailable.
  ///
  /// In en, this message translates to:
  /// **'No changelog yet'**
  String get changelogUnavailable;

  /// No description provided for @notFound.
  ///
  /// In en, this message translates to:
  /// **'Not found'**
  String get notFound;

  /// No description provided for @downloadStarted.
  ///
  /// In en, this message translates to:
  /// **'Download started'**
  String get downloadStarted;

  /// No description provided for @compatible.
  ///
  /// In en, this message translates to:
  /// **'Compatible with'**
  String get compatible;

  /// No description provided for @incompatible.
  ///
  /// In en, this message translates to:
  /// **'Incompatible with'**
  String get incompatible;

  /// No description provided for @incompatibleSuffix.
  ///
  /// In en, this message translates to:
  /// **''**
  String get incompatibleSuffix;

  /// No description provided for @myResources.
  ///
  /// In en, this message translates to:
  /// **'My resources'**
  String get myResources;

  /// No description provided for @drafts.
  ///
  /// In en, this message translates to:
  /// **'Drafts'**
  String get drafts;

  /// No description provided for @pendingReview.
  ///
  /// In en, this message translates to:
  /// **'Pending review'**
  String get pendingReview;

  /// No description provided for @published.
  ///
  /// In en, this message translates to:
  /// **'Published'**
  String get published;

  /// No description provided for @creatorStateSuspended.
  ///
  /// In en, this message translates to:
  /// **'Delisted'**
  String get creatorStateSuspended;

  /// No description provided for @creatorStateFrozen.
  ///
  /// In en, this message translates to:
  /// **'Frozen'**
  String get creatorStateFrozen;

  /// No description provided for @creatorSuspendedByOwnerNotice.
  ///
  /// In en, this message translates to:
  /// **'The resource is delisted. Keep editing and resubmit for review, or restore it directly'**
  String get creatorSuspendedByOwnerNotice;

  /// No description provided for @creatorSuspendedByAdminNotice.
  ///
  /// In en, this message translates to:
  /// **'An administrator delisted this resource. Edit and resubmit for review; it is restored once approved'**
  String get creatorSuspendedByAdminNotice;

  /// No description provided for @creatorFrozenNotice.
  ///
  /// In en, this message translates to:
  /// **'An administrator froze this resource. It can no longer be edited and only an administrator can lift the freeze'**
  String get creatorFrozenNotice;

  /// No description provided for @creatorModerationReason.
  ///
  /// In en, this message translates to:
  /// **'Reason: {reason}'**
  String creatorModerationReason(Object reason);

  /// No description provided for @creatorBannedTitle.
  ///
  /// In en, this message translates to:
  /// **'Account banned'**
  String get creatorBannedTitle;

  /// No description provided for @creatorBannedDescription.
  ///
  /// In en, this message translates to:
  /// **'Your account was banned by an administrator and the creator center is unavailable. Contact the team through a support ticket if you believe this is a mistake'**
  String get creatorBannedDescription;

  /// No description provided for @creatorFrozenTitle.
  ///
  /// In en, this message translates to:
  /// **'Creator capability frozen'**
  String get creatorFrozenTitle;

  /// No description provided for @creatorFrozenDescription.
  ///
  /// In en, this message translates to:
  /// **'An administrator froze your creator capability, so you cannot submit or manage resources for now. The rest of your account is unaffected'**
  String get creatorFrozenDescription;

  /// No description provided for @creatorBandBbsNoDevices.
  ///
  /// In en, this message translates to:
  /// **'Select supported devices for the resource file first'**
  String get creatorBandBbsNoDevices;

  /// No description provided for @creatorBandBbsUnmappedDevices.
  ///
  /// In en, this message translates to:
  /// **'No BandBBS category could be resolved for: {devices}'**
  String creatorBandBbsUnmappedDevices(Object devices);

  /// No description provided for @creatorBandBbsSharedCategory.
  ///
  /// In en, this message translates to:
  /// **'Devices in the same BandBBS category are bound to multiple packages. Bind one package per category'**
  String get creatorBandBbsSharedCategory;

  /// No description provided for @creatorBandBbsUnresolved.
  ///
  /// In en, this message translates to:
  /// **'Unable to resolve a BandBBS category'**
  String get creatorBandBbsUnresolved;

  /// No description provided for @creatorOptionalIcon.
  ///
  /// In en, this message translates to:
  /// **'Icon (optional, 1:1)'**
  String get creatorOptionalIcon;

  /// No description provided for @creatorOptionalCover.
  ///
  /// In en, this message translates to:
  /// **'Cover (optional, 3:2)'**
  String get creatorOptionalCover;

  /// No description provided for @creatorRequiredIcon.
  ///
  /// In en, this message translates to:
  /// **'Icon (required for AstroBox, 1:1)'**
  String get creatorRequiredIcon;

  /// No description provided for @creatorRequiredCover.
  ///
  /// In en, this message translates to:
  /// **'Cover (required for AstroBox, 3:2)'**
  String get creatorRequiredCover;

  /// No description provided for @creatorIconShapeHint.
  ///
  /// In en, this message translates to:
  /// **'The icon is not square and may look wrong in AstroBox'**
  String get creatorIconShapeHint;

  /// No description provided for @creatorCoverShapeHint.
  ///
  /// In en, this message translates to:
  /// **'The cover is not 3:2 and may look wrong in AstroBox'**
  String get creatorCoverShapeHint;

  /// No description provided for @creatorTermsBandBbs.
  ///
  /// In en, this message translates to:
  /// **'BandBBS community terms and rules'**
  String get creatorTermsBandBbs;

  /// No description provided for @creatorTermsAstroBox.
  ///
  /// In en, this message translates to:
  /// **'AstroBox-Repo submission standards'**
  String get creatorTermsAstroBox;

  /// No description provided for @creatorTermsAccept.
  ///
  /// In en, this message translates to:
  /// **'I have read and accept the publishing agreements above'**
  String get creatorTermsAccept;

  /// No description provided for @creatorTermsContinue.
  ///
  /// In en, this message translates to:
  /// **'Enter Creator Center'**
  String get creatorTermsContinue;

  /// No description provided for @agree.
  ///
  /// In en, this message translates to:
  /// **'Agree'**
  String get agree;

  /// No description provided for @creatorRulesAccept.
  ///
  /// In en, this message translates to:
  /// **'I have read and agree to the review rules above'**
  String get creatorRulesAccept;

  /// No description provided for @creatorBandBbsTermsNotice.
  ///
  /// In en, this message translates to:
  /// **'After OronBox review, this resource is published directly to the matching BandBBS categories. Deleting the OronBox resource also deletes the corresponding BandBBS resources.'**
  String get creatorBandBbsTermsNotice;

  /// No description provided for @creatorBandBbsLimitsNotice.
  ///
  /// In en, this message translates to:
  /// **'One-click publishing to BandBBS has the following limitations, which must be fixed manually after publishing:\n1. BandBBS provides no API to upload the resource icon, so the icon will appear blank on BandBBS; please update it manually on the BandBBS site\n2. BandBBS provides no API for discussion-forum tags, so the resource\'s forum attributes will not be set, which may get the resource removed; please set the correct forum manually on the BandBBS site'**
  String get creatorBandBbsLimitsNotice;

  /// No description provided for @creatorAstroBoxTermsNotice.
  ///
  /// In en, this message translates to:
  /// **'After OronBox review, a resource repository is created and a PR is submitted to the official AstroBox repository, reviewed independently by AstroBox maintainers. To delist after publication, contact the AstroBox-Repo maintainers.'**
  String get creatorAstroBoxTermsNotice;

  /// No description provided for @creatorAstroBoxReviewNotice.
  ///
  /// In en, this message translates to:
  /// **'Resources published to AstroBox must meet the review requirements:\n1. The resource must not contain obscene, politically sensitive or otherwise illegal content\n2. The resource quality must not be too low, e.g. a watchface made by merely swapping a template, or an overly simple quickapp\n3. The cover should be attractive and aesthetically pleasing, with a 3:2 ratio (recommended 1200x800); icon recommended 192x192\n4. The resource must run its basic functions properly on supported devices\n5. Uploading others\' resources without authorization is forbidden\n6. When using well-known IP assets, the preview must include a copyright notice image (stating the assets are unrelated to AstroBox and Xiaomi)'**
  String get creatorAstroBoxReviewNotice;

  /// No description provided for @failed.
  ///
  /// In en, this message translates to:
  /// **'Failed / Needs action'**
  String get failed;

  /// No description provided for @basicInfo.
  ///
  /// In en, this message translates to:
  /// **'Basic info'**
  String get basicInfo;

  /// No description provided for @packageFiles.
  ///
  /// In en, this message translates to:
  /// **'Resource files'**
  String get packageFiles;

  /// No description provided for @publishTargets.
  ///
  /// In en, this message translates to:
  /// **'Publish targets'**
  String get publishTargets;

  /// No description provided for @scan.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get scan;

  /// No description provided for @logs.
  ///
  /// In en, this message translates to:
  /// **'Logs'**
  String get logs;

  /// No description provided for @pairedDevices.
  ///
  /// In en, this message translates to:
  /// **'Paired devices'**
  String get pairedDevices;

  /// No description provided for @apps.
  ///
  /// In en, this message translates to:
  /// **'Apps'**
  String get apps;

  /// No description provided for @deviceAppCount.
  ///
  /// In en, this message translates to:
  /// **'App count'**
  String get deviceAppCount;

  /// No description provided for @deviceWatchfaceCount.
  ///
  /// In en, this message translates to:
  /// **'Watchface count'**
  String get deviceWatchfaceCount;

  /// No description provided for @connection.
  ///
  /// In en, this message translates to:
  /// **'Connection'**
  String get connection;

  /// No description provided for @protocol.
  ///
  /// In en, this message translates to:
  /// **'Protocol'**
  String get protocol;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @errorBluetoothUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth is not available. Check that Bluetooth is enabled and OronBox has permission to use it'**
  String get errorBluetoothUnavailable;

  /// No description provided for @errorBluetoothConnectFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection failed. Check Bluetooth permission, keep the device nearby and not in use, enable Connect new phone on the device, then try again'**
  String get errorBluetoothConnectFailed;

  /// No description provided for @errorBluetoothDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth disconnected. Reconnect the device and try again'**
  String get errorBluetoothDisconnected;

  /// No description provided for @errorOperationTimeout.
  ///
  /// In en, this message translates to:
  /// **'Operation timed out. Make sure the device is still nearby and try again'**
  String get errorOperationTimeout;

  /// No description provided for @errorDeviceNotReady.
  ///
  /// In en, this message translates to:
  /// **'Device is not ready. Connect and authenticate the device first'**
  String get errorDeviceNotReady;

  /// No description provided for @errorBleCharacteristicsMissing.
  ///
  /// In en, this message translates to:
  /// **'Required BLE channels were not found. Reconnect the device or check whether it supports this feature'**
  String get errorBleCharacteristicsMissing;

  /// No description provided for @errorWebSerialUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This browser does not support Web Serial. Use Chrome, Edge, or another Web Serial compatible browser'**
  String get errorWebSerialUnavailable;

  /// No description provided for @errorAccountPasswordIncorrect.
  ///
  /// In en, this message translates to:
  /// **'Xiaomi account username or password is incorrect'**
  String get errorAccountPasswordIncorrect;

  /// No description provided for @errorAccountTwoFactorIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Xiaomi account two-factor verification was not completed. Sign in again'**
  String get errorAccountTwoFactorIncomplete;

  /// No description provided for @errorXiaomiAccountSessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Your Xiaomi account session has expired. Sign in again'**
  String get errorXiaomiAccountSessionExpired;

  /// No description provided for @errorOronBoxSessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Your OronBox session has expired. Sign in to BandBBS again'**
  String get errorOronBoxSessionExpired;

  /// No description provided for @errorNetworkUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unable to reach the service. Check your network and try again'**
  String get errorNetworkUnavailable;

  /// No description provided for @errorServiceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The service is temporarily unavailable. Try again later'**
  String get errorServiceUnavailable;

  /// No description provided for @errorPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'You do not have permission to perform this operation'**
  String get errorPermissionDenied;

  /// No description provided for @errorContentNotFound.
  ///
  /// In en, this message translates to:
  /// **'The requested content no longer exists or is unavailable'**
  String get errorContentNotFound;

  /// No description provided for @errorRequestConflict.
  ///
  /// In en, this message translates to:
  /// **'The content has changed. Refresh it and try again'**
  String get errorRequestConflict;

  /// No description provided for @errorCoinBalanceInsufficient.
  ///
  /// In en, this message translates to:
  /// **'You do not have enough coins'**
  String get errorCoinBalanceInsufficient;

  /// No description provided for @errorCoinResourceLimit.
  ///
  /// In en, this message translates to:
  /// **'You can give at most 2 coins to this resource'**
  String get errorCoinResourceLimit;

  /// No description provided for @errorCoinOwnResource.
  ///
  /// In en, this message translates to:
  /// **'You cannot coin your own resource'**
  String get errorCoinOwnResource;

  /// No description provided for @errorCoinVotingFrozen.
  ///
  /// In en, this message translates to:
  /// **'Coin voting is currently frozen'**
  String get errorCoinVotingFrozen;

  /// No description provided for @errorCoinAccountTooNew.
  ///
  /// In en, this message translates to:
  /// **'Your account must be at least 24 hours old to give coins'**
  String get errorCoinAccountTooNew;

  /// No description provided for @errorCoinOperationFailed.
  ///
  /// In en, this message translates to:
  /// **'The coin could not be sent. Try again'**
  String get errorCoinOperationFailed;

  /// No description provided for @errorCoinStatusUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Coin status is unavailable. Tap to retry'**
  String get errorCoinStatusUnavailable;

  /// No description provided for @errorOperationFailed.
  ///
  /// In en, this message translates to:
  /// **'The operation failed. Try again'**
  String get errorOperationFailed;

  /// No description provided for @errorUnknown.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Try again'**
  String get errorUnknown;

  /// No description provided for @errorDownloadQuotaExceeded.
  ///
  /// In en, this message translates to:
  /// **'Today\'s download limit has been reached'**
  String get errorDownloadQuotaExceeded;

  /// No description provided for @errorGitHubNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'GitHub publishing is not configured'**
  String get errorGitHubNotConfigured;

  /// No description provided for @errorRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many requests. Wait a moment and try again'**
  String get errorRateLimited;

  /// No description provided for @errorFileTooLarge.
  ///
  /// In en, this message translates to:
  /// **'The selected file is too large'**
  String get errorFileTooLarge;

  /// No description provided for @errorInvalidRequest.
  ///
  /// In en, this message translates to:
  /// **'Some submitted information is invalid. Check it and try again'**
  String get errorInvalidRequest;

  /// No description provided for @errorOperationCancelled.
  ///
  /// In en, this message translates to:
  /// **'Operation cancelled'**
  String get errorOperationCancelled;

  /// No description provided for @errorUnsupportedFileType.
  ///
  /// In en, this message translates to:
  /// **'Unsupported or unrecognized file type'**
  String get errorUnsupportedFileType;

  /// No description provided for @errorCertificateVerificationFailed.
  ///
  /// In en, this message translates to:
  /// **'Certificate verification failed. If you are using a proxy, disable HTTPS interception for this app or make sure its certificate is trusted'**
  String get errorCertificateVerificationFailed;

  /// No description provided for @errorUnknownWithDetail.
  ///
  /// In en, this message translates to:
  /// **'Operation failed: {detail}'**
  String errorUnknownWithDetail(Object detail);

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @resources.
  ///
  /// In en, this message translates to:
  /// **'Resources'**
  String get resources;

  /// No description provided for @communitySourceAstroBoxRepo.
  ///
  /// In en, this message translates to:
  /// **'AstroBox'**
  String get communitySourceAstroBoxRepo;

  /// No description provided for @communitySourceBandBbs.
  ///
  /// In en, this message translates to:
  /// **'BandBBS Community'**
  String get communitySourceBandBbs;

  /// No description provided for @communitySourceHuamiAppStore.
  ///
  /// In en, this message translates to:
  /// **'Amazfit App Store'**
  String get communitySourceHuamiAppStore;

  /// No description provided for @devices.
  ///
  /// In en, this message translates to:
  /// **'Devices'**
  String get devices;

  /// No description provided for @creatorCompatibleDeviceCount.
  ///
  /// In en, this message translates to:
  /// **'{count} devices'**
  String creatorCompatibleDeviceCount(int count);

  /// No description provided for @categories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get categories;

  /// No description provided for @advanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get advanced;

  /// No description provided for @openSourceLicenses.
  ///
  /// In en, this message translates to:
  /// **'Open source licenses'**
  String get openSourceLicenses;

  /// No description provided for @acknowledgements.
  ///
  /// In en, this message translates to:
  /// **'Special Acknowledgements'**
  String get acknowledgements;

  /// No description provided for @deviceNotConnected.
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get deviceNotConnected;

  /// No description provided for @deviceConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get deviceConnected;

  /// No description provided for @deviceDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get deviceDisconnected;

  /// No description provided for @deviceReconnect.
  ///
  /// In en, this message translates to:
  /// **'Reconnect'**
  String get deviceReconnect;

  /// No description provided for @deviceConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get deviceConnect;

  /// No description provided for @deviceSwitch.
  ///
  /// In en, this message translates to:
  /// **'Switch'**
  String get deviceSwitch;

  /// No description provided for @deviceSyncTime.
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get deviceSyncTime;

  /// No description provided for @deviceCharging.
  ///
  /// In en, this message translates to:
  /// **'Charging'**
  String get deviceCharging;

  /// No description provided for @deviceLastChargedNow.
  ///
  /// In en, this message translates to:
  /// **'Charged just now'**
  String get deviceLastChargedNow;

  /// No description provided for @deviceLastChargedMinutes.
  ///
  /// In en, this message translates to:
  /// **'Charged {count} min ago'**
  String deviceLastChargedMinutes(int count);

  /// No description provided for @deviceLastChargedHours.
  ///
  /// In en, this message translates to:
  /// **'Charged {count} hr ago'**
  String deviceLastChargedHours(int count);

  /// No description provided for @deviceLastChargedDays.
  ///
  /// In en, this message translates to:
  /// **'Charged {count} days ago'**
  String deviceLastChargedDays(int count);

  /// No description provided for @deviceFeaturesInstallApp.
  ///
  /// In en, this message translates to:
  /// **'Install app'**
  String get deviceFeaturesInstallApp;

  /// No description provided for @deviceFeaturesInstallWatchface.
  ///
  /// In en, this message translates to:
  /// **'Install watchface'**
  String get deviceFeaturesInstallWatchface;

  /// No description provided for @deviceFeaturesInstallFirmware.
  ///
  /// In en, this message translates to:
  /// **'Firmware update'**
  String get deviceFeaturesInstallFirmware;

  /// No description provided for @deviceFeaturesInstallFirmwareDesc.
  ///
  /// In en, this message translates to:
  /// **'Check for device updates or install local firmware'**
  String get deviceFeaturesInstallFirmwareDesc;

  /// No description provided for @firmwareCheckingUpdates.
  ///
  /// In en, this message translates to:
  /// **'Checking for firmware updates'**
  String get firmwareCheckingUpdates;

  /// No description provided for @firmwareNoUpdatesFound.
  ///
  /// In en, this message translates to:
  /// **'No newer firmware was found for this device'**
  String get firmwareNoUpdatesFound;

  /// No description provided for @firmwareSourceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'An online firmware source is not yet available for this device type'**
  String get firmwareSourceUnavailable;

  /// No description provided for @firmwareVersionUnknown.
  ///
  /// In en, this message translates to:
  /// **'Current firmware version unavailable'**
  String get firmwareVersionUnknown;

  /// No description provided for @firmwareCurrentVersion.
  ///
  /// In en, this message translates to:
  /// **'Current version'**
  String get firmwareCurrentVersion;

  /// No description provided for @firmwareLatestRelease.
  ///
  /// In en, this message translates to:
  /// **'Latest firmware'**
  String get firmwareLatestRelease;

  /// No description provided for @firmwareHistoricalReleases.
  ///
  /// In en, this message translates to:
  /// **'Historical firmware'**
  String get firmwareHistoricalReleases;

  /// No description provided for @firmwareUpToDate.
  ///
  /// In en, this message translates to:
  /// **'Your firmware is up to date'**
  String get firmwareUpToDate;

  /// No description provided for @firmwareUpdateAvailable.
  ///
  /// In en, this message translates to:
  /// **'An update is available'**
  String get firmwareUpdateAvailable;

  /// No description provided for @firmwareDownloadLatestFull.
  ///
  /// In en, this message translates to:
  /// **'Download latest full package'**
  String get firmwareDownloadLatestFull;

  /// No description provided for @firmwareUpdateNow.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get firmwareUpdateNow;

  /// No description provided for @firmwareReleaseNotes.
  ///
  /// In en, this message translates to:
  /// **'Release notes'**
  String get firmwareReleaseNotes;

  /// No description provided for @firmwareReleaseNotesUnavailable.
  ///
  /// In en, this message translates to:
  /// **'No release notes available'**
  String get firmwareReleaseNotesUnavailable;

  /// No description provided for @download.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get download;

  /// No description provided for @downloadTaskAdded.
  ///
  /// In en, this message translates to:
  /// **'Added to the download queue'**
  String get downloadTaskAdded;

  /// No description provided for @zeppOsMoreFeatures.
  ///
  /// In en, this message translates to:
  /// **'Special features'**
  String get zeppOsMoreFeatures;

  /// No description provided for @zeppOsMoreFeaturesDescription.
  ///
  /// In en, this message translates to:
  /// **'Manage additional features for Zepp OS devices'**
  String get zeppOsMoreFeaturesDescription;

  /// No description provided for @zeppOsDeviceFeaturesSection.
  ///
  /// In en, this message translates to:
  /// **'Device features'**
  String get zeppOsDeviceFeaturesSection;

  /// No description provided for @zeppOsAppsAndDevelopmentSection.
  ///
  /// In en, this message translates to:
  /// **'Apps and development'**
  String get zeppOsAppsAndDevelopmentSection;

  /// No description provided for @zeppOsAssistant.
  ///
  /// In en, this message translates to:
  /// **'Voice lab'**
  String get zeppOsAssistant;

  /// No description provided for @zeppOsAssistantDescription.
  ///
  /// In en, this message translates to:
  /// **'Capture, monitor, and reply to watch voice assistant sessions'**
  String get zeppOsAssistantDescription;

  /// No description provided for @zeppOsScreenMirror.
  ///
  /// In en, this message translates to:
  /// **'Screen mirroring'**
  String get zeppOsScreenMirror;

  /// No description provided for @zeppOsScreenMirrorDescription.
  ///
  /// In en, this message translates to:
  /// **'View the watch screen on this device'**
  String get zeppOsScreenMirrorDescription;

  /// No description provided for @zeppOsScreenMirrorSemantics.
  ///
  /// In en, this message translates to:
  /// **'Zepp OS watch screen mirror'**
  String get zeppOsScreenMirrorSemantics;

  /// No description provided for @zeppOsScreenMirrorUnsupported.
  ///
  /// In en, this message translates to:
  /// **'This screen format cannot be displayed: {error}'**
  String zeppOsScreenMirrorUnsupported(Object error);

  /// No description provided for @expand.
  ///
  /// In en, this message translates to:
  /// **'Expand'**
  String get expand;

  /// No description provided for @collapse.
  ///
  /// In en, this message translates to:
  /// **'Collapse'**
  String get collapse;

  /// No description provided for @voiceLabTitle.
  ///
  /// In en, this message translates to:
  /// **'Voice lab'**
  String get voiceLabTitle;

  /// No description provided for @voiceLabXiaoAi.
  ///
  /// In en, this message translates to:
  /// **'XiaoAI'**
  String get voiceLabXiaoAi;

  /// No description provided for @voiceLabReceivingAudio.
  ///
  /// In en, this message translates to:
  /// **'Receiving audio from the watch'**
  String get voiceLabReceivingAudio;

  /// No description provided for @voiceLabWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for a voice session'**
  String get voiceLabWaiting;

  /// No description provided for @voiceLabContinuousCapture.
  ///
  /// In en, this message translates to:
  /// **'Continuous capture'**
  String get voiceLabContinuousCapture;

  /// No description provided for @voiceLabContinuousCaptureDescription.
  ///
  /// In en, this message translates to:
  /// **'Request the next recording when the current one ends'**
  String get voiceLabContinuousCaptureDescription;

  /// No description provided for @voiceLabDisableMonitoring.
  ///
  /// In en, this message translates to:
  /// **'Disable live monitoring'**
  String get voiceLabDisableMonitoring;

  /// No description provided for @voiceLabEnableMonitoring.
  ///
  /// In en, this message translates to:
  /// **'Enable live monitoring'**
  String get voiceLabEnableMonitoring;

  /// No description provided for @voiceLabReplyLabel.
  ///
  /// In en, this message translates to:
  /// **'Reply sent to the watch'**
  String get voiceLabReplyLabel;

  /// No description provided for @voiceLabReplyHint.
  ///
  /// In en, this message translates to:
  /// **'Enter a reply'**
  String get voiceLabReplyHint;

  /// No description provided for @voiceLabReplyQueued.
  ///
  /// In en, this message translates to:
  /// **'Reply queued until the current recording ends'**
  String get voiceLabReplyQueued;

  /// No description provided for @voiceLabReplySent.
  ///
  /// In en, this message translates to:
  /// **'Reply sent to the watch'**
  String get voiceLabReplySent;

  /// No description provided for @voiceLabCapturedData.
  ///
  /// In en, this message translates to:
  /// **'Captured data'**
  String get voiceLabCapturedData;

  /// No description provided for @voiceLabDecoder.
  ///
  /// In en, this message translates to:
  /// **'Decoder'**
  String get voiceLabDecoder;

  /// No description provided for @voiceLabOpusFrames.
  ///
  /// In en, this message translates to:
  /// **'Opus frames'**
  String get voiceLabOpusFrames;

  /// No description provided for @voiceLabDataSize.
  ///
  /// In en, this message translates to:
  /// **'Data size'**
  String get voiceLabDataSize;

  /// No description provided for @voiceLabPcmSamples.
  ///
  /// In en, this message translates to:
  /// **'PCM samples'**
  String get voiceLabPcmSamples;

  /// No description provided for @voiceLabExportOpus.
  ///
  /// In en, this message translates to:
  /// **'Export Opus'**
  String get voiceLabExportOpus;

  /// No description provided for @voiceLabExportWav.
  ///
  /// In en, this message translates to:
  /// **'Export WAV'**
  String get voiceLabExportWav;

  /// No description provided for @voiceLabClearCapture.
  ///
  /// In en, this message translates to:
  /// **'Clear captured data'**
  String get voiceLabClearCapture;

  /// No description provided for @voiceLabSaveRecording.
  ///
  /// In en, this message translates to:
  /// **'Save voice recording'**
  String get voiceLabSaveRecording;

  /// No description provided for @voiceLabSaveOpus.
  ///
  /// In en, this message translates to:
  /// **'Save Opus audio'**
  String get voiceLabSaveOpus;

  /// No description provided for @voiceLabAudioProcessingFailedPrefix.
  ///
  /// In en, this message translates to:
  /// **'Audio processing failed'**
  String get voiceLabAudioProcessingFailedPrefix;

  /// No description provided for @voiceLabAudioProcessingFailed.
  ///
  /// In en, this message translates to:
  /// **'Audio processing failed: {error}'**
  String voiceLabAudioProcessingFailed(Object error);

  /// No description provided for @voiceLabContinuousCaptureFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not configure continuous capture: {error}'**
  String voiceLabContinuousCaptureFailed(Object error);

  /// No description provided for @voiceLabAssistantSwitchFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not switch voice assistant: {error}'**
  String voiceLabAssistantSwitchFailed(Object error);

  /// No description provided for @voiceLabExportWavFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not export WAV: {error}'**
  String voiceLabExportWavFailed(Object error);

  /// No description provided for @voiceLabExportOpusFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not export Opus: {error}'**
  String voiceLabExportOpusFailed(Object error);

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @sendFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not send: {error}'**
  String sendFailed(Object error);

  /// No description provided for @ready.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get ready;

  /// No description provided for @initializing.
  ///
  /// In en, this message translates to:
  /// **'Initializing'**
  String get initializing;

  /// No description provided for @zeppOsMapSelectPackage.
  ///
  /// In en, this message translates to:
  /// **'Select a Zepp OS map package'**
  String get zeppOsMapSelectPackage;

  /// No description provided for @zeppOsMapReadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not read the map package'**
  String get zeppOsMapReadFailed;

  /// No description provided for @zeppOsMapTransferTitle.
  ///
  /// In en, this message translates to:
  /// **'Transfer offline map'**
  String get zeppOsMapTransferTitle;

  /// No description provided for @zeppOsMapGarminDetected.
  ///
  /// In en, this message translates to:
  /// **'{fileName}\nDetected a single-file Garmin IMG map: {mapName}'**
  String zeppOsMapGarminDetected(Object fileName, Object mapName);

  /// No description provided for @zeppOsMapGarminNoPreview.
  ///
  /// In en, this message translates to:
  /// **'This map does not contain a Zepp OS 11/x/y tile tree. The original IMG will be transferred as a single-file map package, so a coverage preview is unavailable.'**
  String get zeppOsMapGarminNoPreview;

  /// No description provided for @zeppOsMapTileSummary.
  ///
  /// In en, this message translates to:
  /// **'{fileName} · {count} tiles\nThe preview shows package coverage, not the Garmin IMG rendering on the watch.'**
  String zeppOsMapTileSummary(Object fileName, Object count);

  /// No description provided for @zeppOsMapStartTransfer.
  ///
  /// In en, this message translates to:
  /// **'Start transfer'**
  String get zeppOsMapStartTransfer;

  /// No description provided for @zeppOsMapTransferringBluetooth.
  ///
  /// In en, this message translates to:
  /// **'Transferring over Bluetooth'**
  String get zeppOsMapTransferringBluetooth;

  /// No description provided for @zeppOsMapTransferComplete.
  ///
  /// In en, this message translates to:
  /// **'Offline map transfer complete'**
  String get zeppOsMapTransferComplete;

  /// No description provided for @zeppOsMapConversionFailed.
  ///
  /// In en, this message translates to:
  /// **'Map could not be converted safely'**
  String get zeppOsMapConversionFailed;

  /// No description provided for @zeppOsMapBtClassicHint.
  ///
  /// In en, this message translates to:
  /// **'BT Classic bulk transfer is active. After transfer starts, confirm the installation on the watch.'**
  String get zeppOsMapBtClassicHint;

  /// No description provided for @zeppOsMapBleHint.
  ///
  /// In en, this message translates to:
  /// **'BLE supports map packages up to 2 MB. Switch to BT Classic before transferring a larger map. After transfer starts, confirm the installation on the watch.'**
  String get zeppOsMapBleHint;

  /// No description provided for @zeppOsMapPreviewTooLarge.
  ///
  /// In en, this message translates to:
  /// **'The map area is too large to preview in full'**
  String get zeppOsMapPreviewTooLarge;

  /// No description provided for @zeppOsSettingPageLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load the settings page: {error}'**
  String zeppOsSettingPageLoadFailed(Object error);

  /// No description provided for @zeppOsAppCompatibilitySaved.
  ///
  /// In en, this message translates to:
  /// **'Compatibility files saved for {appId}'**
  String zeppOsAppCompatibilitySaved(Object appId);

  /// No description provided for @zeppOsAppStorageSaved.
  ///
  /// In en, this message translates to:
  /// **'settingsStorage saved for {appId}'**
  String zeppOsAppStorageSaved(Object appId);

  /// No description provided for @zeppOsAppSupplementFiles.
  ///
  /// In en, this message translates to:
  /// **'Add app-side or setting files'**
  String get zeppOsAppSupplementFiles;

  /// No description provided for @zeppOsAppSupplementCompatibility.
  ///
  /// In en, this message translates to:
  /// **'Add mini-app compatibility files'**
  String get zeppOsAppSupplementCompatibility;

  /// No description provided for @zeppOsAppReplaceCompatibility.
  ///
  /// In en, this message translates to:
  /// **'Add or replace compatibility files'**
  String get zeppOsAppReplaceCompatibility;

  /// No description provided for @zeppOsAppSideAvailable.
  ///
  /// In en, this message translates to:
  /// **'app-side ✓'**
  String get zeppOsAppSideAvailable;

  /// No description provided for @zeppOsAppSideMissing.
  ///
  /// In en, this message translates to:
  /// **'app-side missing'**
  String get zeppOsAppSideMissing;

  /// No description provided for @zeppOsSettingAvailable.
  ///
  /// In en, this message translates to:
  /// **'setting ✓'**
  String get zeppOsSettingAvailable;

  /// No description provided for @zeppOsSettingMissing.
  ///
  /// In en, this message translates to:
  /// **'setting missing'**
  String get zeppOsSettingMissing;

  /// No description provided for @zeppOsAppEditStorage.
  ///
  /// In en, this message translates to:
  /// **'Edit settingsStorage'**
  String get zeppOsAppEditStorage;

  /// No description provided for @zeppOsStorageKeyRequired.
  ///
  /// In en, this message translates to:
  /// **'Key is required'**
  String get zeppOsStorageKeyRequired;

  /// No description provided for @zeppOsStorageDuplicateKey.
  ///
  /// In en, this message translates to:
  /// **'Duplicate key: {key}'**
  String zeppOsStorageDuplicateKey(Object key);

  /// No description provided for @zeppOsStorageDescription.
  ///
  /// In en, this message translates to:
  /// **'This data is shared by the setting page and app-side, and is stored as strings according to the Zepp OS specification.'**
  String get zeppOsStorageDescription;

  /// No description provided for @zeppOsStorageEmpty.
  ///
  /// In en, this message translates to:
  /// **'No stored entries'**
  String get zeppOsStorageEmpty;

  /// No description provided for @zeppOsStorageKey.
  ///
  /// In en, this message translates to:
  /// **'Key'**
  String get zeppOsStorageKey;

  /// No description provided for @zeppOsStorageValue.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get zeppOsStorageValue;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @selectedFileReadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not read the selected file'**
  String get selectedFileReadFailed;

  /// No description provided for @zeppOsAppInvalidHexId.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid hexadecimal App ID'**
  String get zeppOsAppInvalidHexId;

  /// No description provided for @zeppOsAppSelectCompatibilityFile.
  ///
  /// In en, this message translates to:
  /// **'Select at least one app-side.js or setting.js file'**
  String get zeppOsAppSelectCompatibilityFile;

  /// No description provided for @zeppOsAppHexId.
  ///
  /// In en, this message translates to:
  /// **'App ID (hexadecimal)'**
  String get zeppOsAppHexId;

  /// No description provided for @optionalDisplayName.
  ///
  /// In en, this message translates to:
  /// **'Display name (optional)'**
  String get optionalDisplayName;

  /// No description provided for @zeppOsAppSideUnchanged.
  ///
  /// In en, this message translates to:
  /// **'Keep existing app-side'**
  String get zeppOsAppSideUnchanged;

  /// No description provided for @zeppOsSettingUnchanged.
  ///
  /// In en, this message translates to:
  /// **'Keep existing setting'**
  String get zeppOsSettingUnchanged;

  /// No description provided for @selectFile.
  ///
  /// In en, this message translates to:
  /// **'Select file'**
  String get selectFile;

  /// No description provided for @zeppOsAppCompatibilityOverwriteHint.
  ///
  /// In en, this message translates to:
  /// **'Saving replaces compatibility files with the same name for this App ID, but does not modify the mini app on the watch.'**
  String get zeppOsAppCompatibilityOverwriteHint;

  /// No description provided for @zeppOsDebugRefreshFailed.
  ///
  /// In en, this message translates to:
  /// **'Automatic refresh failed: {error}'**
  String zeppOsDebugRefreshFailed(Object error);

  /// No description provided for @zeppOsDebugInvalidHex.
  ///
  /// In en, this message translates to:
  /// **'HEX must contain complete bytes separated by spaces, line breaks, 0x, commas, or similar separators'**
  String get zeppOsDebugInvalidHex;

  /// No description provided for @zeppOsDebugClearEventsTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear events for the current app?'**
  String get zeppOsDebugClearEventsTitle;

  /// No description provided for @zeppOsDebugClearEventsDescription.
  ///
  /// In en, this message translates to:
  /// **'All debug events for {appId} will be cleared.'**
  String zeppOsDebugClearEventsDescription(Object appId);

  /// No description provided for @zeppOsDebugClearEvents.
  ///
  /// In en, this message translates to:
  /// **'Clear events'**
  String get zeppOsDebugClearEvents;

  /// No description provided for @zeppOsDebugRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh status and events'**
  String get zeppOsDebugRefresh;

  /// No description provided for @zeppOsDebugAppList.
  ///
  /// In en, this message translates to:
  /// **'App-side list'**
  String get zeppOsDebugAppList;

  /// No description provided for @zeppOsDebugNoApps.
  ///
  /// In en, this message translates to:
  /// **'No cached scripts or watch app-side sessions have been detected.'**
  String get zeppOsDebugNoApps;

  /// No description provided for @zeppOsDebugCached.
  ///
  /// In en, this message translates to:
  /// **'Cached'**
  String get zeppOsDebugCached;

  /// No description provided for @zeppOsDebugNotCached.
  ///
  /// In en, this message translates to:
  /// **'Not cached'**
  String get zeppOsDebugNotCached;

  /// No description provided for @zeppOsDebugRuntimeRunning.
  ///
  /// In en, this message translates to:
  /// **'runtime running'**
  String get zeppOsDebugRuntimeRunning;

  /// No description provided for @zeppOsDebugRuntimeStopped.
  ///
  /// In en, this message translates to:
  /// **'runtime stopped'**
  String get zeppOsDebugRuntimeStopped;

  /// No description provided for @zeppOsDebugLocalRuntime.
  ///
  /// In en, this message translates to:
  /// **'Local runtime'**
  String get zeppOsDebugLocalRuntime;

  /// No description provided for @zeppOsDebugCannotStart.
  ///
  /// In en, this message translates to:
  /// **'This App ID has no cached script and cannot be started locally.'**
  String get zeppOsDebugCannotStart;

  /// No description provided for @zeppOsDebugCanStart.
  ///
  /// In en, this message translates to:
  /// **'The cached script can be started manually without fabricating watch session parameters.'**
  String get zeppOsDebugCanStart;

  /// No description provided for @zeppOsDebugScriptRunning.
  ///
  /// In en, this message translates to:
  /// **'The script is running in local QuickJS.'**
  String get zeppOsDebugScriptRunning;

  /// No description provided for @zeppOsDebugStartQuickJs.
  ///
  /// In en, this message translates to:
  /// **'Start QuickJS'**
  String get zeppOsDebugStartQuickJs;

  /// No description provided for @stop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stop;

  /// No description provided for @zeppOsDebugMessageEditor.
  ///
  /// In en, this message translates to:
  /// **'Message editor'**
  String get zeppOsDebugMessageEditor;

  /// No description provided for @zeppOsDebugUtf8Text.
  ///
  /// In en, this message translates to:
  /// **'UTF-8 text'**
  String get zeppOsDebugUtf8Text;

  /// No description provided for @zeppOsDebugJsonCompact.
  ///
  /// In en, this message translates to:
  /// **'JSON (compacted before sending)'**
  String get zeppOsDebugJsonCompact;

  /// No description provided for @zeppOsDebugHexBytes.
  ///
  /// In en, this message translates to:
  /// **'HEX bytes'**
  String get zeppOsDebugHexBytes;

  /// No description provided for @zeppOsDebugEncodingFailed.
  ///
  /// In en, this message translates to:
  /// **'The current content cannot be encoded in the selected mode'**
  String get zeppOsDebugEncodingFailed;

  /// No description provided for @zeppOsDebugByteCountUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Bytes: --'**
  String get zeppOsDebugByteCountUnavailable;

  /// No description provided for @zeppOsDebugBytePreview.
  ///
  /// In en, this message translates to:
  /// **'Bytes: {count}\nHEX: {hex}'**
  String zeppOsDebugBytePreview(Object count, Object hex);

  /// No description provided for @zeppOsDebugInjectLocal.
  ///
  /// In en, this message translates to:
  /// **'Inject inbound message into local runtime'**
  String get zeppOsDebugInjectLocal;

  /// No description provided for @zeppOsDebugSendToWatch.
  ///
  /// In en, this message translates to:
  /// **'Send to watch'**
  String get zeppOsDebugSendToWatch;

  /// No description provided for @zeppOsDebugWaitingForWatch.
  ///
  /// In en, this message translates to:
  /// **'Send to watch (waiting for a real session)'**
  String get zeppOsDebugWaitingForWatch;

  /// No description provided for @zeppOsDebugEvents.
  ///
  /// In en, this message translates to:
  /// **'Debug events'**
  String get zeppOsDebugEvents;

  /// No description provided for @zeppOsDebugClearCurrentApp.
  ///
  /// In en, this message translates to:
  /// **'Clear current app'**
  String get zeppOsDebugClearCurrentApp;

  /// No description provided for @zeppOsDebugSearch.
  ///
  /// In en, this message translates to:
  /// **'Search type, message, HEX, or readable text'**
  String get zeppOsDebugSearch;

  /// No description provided for @zeppOsDebugWatchOnly.
  ///
  /// In en, this message translates to:
  /// **'Real watch messages only'**
  String get zeppOsDebugWatchOnly;

  /// No description provided for @zeppOsDebugNoEvents.
  ///
  /// In en, this message translates to:
  /// **'No events match the current filters'**
  String get zeppOsDebugNoEvents;

  /// No description provided for @zeppOsDebugMessageActions.
  ///
  /// In en, this message translates to:
  /// **'Message actions'**
  String get zeppOsDebugMessageActions;

  /// No description provided for @zeppOsDebugLoadEditor.
  ///
  /// In en, this message translates to:
  /// **'Load in editor'**
  String get zeppOsDebugLoadEditor;

  /// No description provided for @zeppOsDebugCopyHex.
  ///
  /// In en, this message translates to:
  /// **'Copy HEX'**
  String get zeppOsDebugCopyHex;

  /// No description provided for @zeppOsDebugCopyText.
  ///
  /// In en, this message translates to:
  /// **'Copy text'**
  String get zeppOsDebugCopyText;

  /// No description provided for @zeppOsDebugSessionStatus.
  ///
  /// In en, this message translates to:
  /// **'Runtime and session status'**
  String get zeppOsDebugSessionStatus;

  /// No description provided for @zeppOsDebugCachedScript.
  ///
  /// In en, this message translates to:
  /// **'Cached script: {status}'**
  String zeppOsDebugCachedScript(Object status);

  /// No description provided for @zeppOsDebugLocalRuntimeStatus.
  ///
  /// In en, this message translates to:
  /// **'Local runtime: {status}'**
  String zeppOsDebugLocalRuntimeStatus(Object status);

  /// No description provided for @zeppOsDebugWatchSession.
  ///
  /// In en, this message translates to:
  /// **'Watch session: {status}'**
  String zeppOsDebugWatchSession(Object status);

  /// No description provided for @exists.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get exists;

  /// No description provided for @notExists.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get notExists;

  /// No description provided for @running.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get running;

  /// No description provided for @notRunning.
  ///
  /// In en, this message translates to:
  /// **'Not running'**
  String get notRunning;

  /// No description provided for @notOpen.
  ///
  /// In en, this message translates to:
  /// **'Not open'**
  String get notOpen;

  /// No description provided for @zeppOsDebugWatchSessionOpen.
  ///
  /// In en, this message translates to:
  /// **'Real session open'**
  String get zeppOsDebugWatchSessionOpen;

  /// No description provided for @zeppOsDebugRealHeader.
  ///
  /// In en, this message translates to:
  /// **'Real header'**
  String get zeppOsDebugRealHeader;

  /// No description provided for @zeppOsDebugLatestStartup.
  ///
  /// In en, this message translates to:
  /// **'Latest startup status: {status}'**
  String zeppOsDebugLatestStartup(Object status);

  /// No description provided for @zeppOsDebugWatchInbound.
  ///
  /// In en, this message translates to:
  /// **'From watch'**
  String get zeppOsDebugWatchInbound;

  /// No description provided for @zeppOsDebugWatchOutbound.
  ///
  /// In en, this message translates to:
  /// **'To watch'**
  String get zeppOsDebugWatchOutbound;

  /// No description provided for @zeppOsDebugLifecycle.
  ///
  /// In en, this message translates to:
  /// **'Lifecycle'**
  String get zeppOsDebugLifecycle;

  /// No description provided for @zeppOsMirrorInterval.
  ///
  /// In en, this message translates to:
  /// **'Frame interval'**
  String get zeppOsMirrorInterval;

  /// No description provided for @zeppOsMirrorIntervalRange.
  ///
  /// In en, this message translates to:
  /// **'10–250'**
  String get zeppOsMirrorIntervalRange;

  /// No description provided for @zeppOsOfflineMaps.
  ///
  /// In en, this message translates to:
  /// **'Offline maps'**
  String get zeppOsOfflineMaps;

  /// No description provided for @zeppOsOfflineMapsDescription.
  ///
  /// In en, this message translates to:
  /// **'Transfer existing map packages to the watch'**
  String get zeppOsOfflineMapsDescription;

  /// No description provided for @zeppOsAppSettings.
  ///
  /// In en, this message translates to:
  /// **'App settings'**
  String get zeppOsAppSettings;

  /// No description provided for @zeppOsAppSettingsDescription.
  ///
  /// In en, this message translates to:
  /// **'Manage cached settings for Zepp OS apps'**
  String get zeppOsAppSettingsDescription;

  /// No description provided for @zeppOsAppDebug.
  ///
  /// In en, this message translates to:
  /// **'App debugging'**
  String get zeppOsAppDebug;

  /// No description provided for @zeppOsAppDebugDescription.
  ///
  /// In en, this message translates to:
  /// **'Debug app-side scripts and device communication'**
  String get zeppOsAppDebugDescription;

  /// No description provided for @deviceMusicSync.
  ///
  /// In en, this message translates to:
  /// **'Music sync'**
  String get deviceMusicSync;

  /// No description provided for @deviceHealthTitle.
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get deviceHealthTitle;

  /// No description provided for @deviceHealthDescription.
  ///
  /// In en, this message translates to:
  /// **'Sync activity and sleep data from the device'**
  String get deviceHealthDescription;

  /// No description provided for @deviceHealthSyncCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Health data'**
  String get deviceHealthSyncCardTitle;

  /// No description provided for @deviceHealthNeverSynced.
  ///
  /// In en, this message translates to:
  /// **'No health data has been synchronized yet'**
  String get deviceHealthNeverSynced;

  /// No description provided for @deviceHealthLastSynced.
  ///
  /// In en, this message translates to:
  /// **'Last synchronized {time}'**
  String deviceHealthLastSynced(String time);

  /// No description provided for @deviceHealthSync.
  ///
  /// In en, this message translates to:
  /// **'Synchronize health data'**
  String get deviceHealthSync;

  /// No description provided for @deviceHealthSyncing.
  ///
  /// In en, this message translates to:
  /// **'Synchronizing'**
  String get deviceHealthSyncing;

  /// No description provided for @deviceHealthAutoSyncTitle.
  ///
  /// In en, this message translates to:
  /// **'Automatically sync health data'**
  String get deviceHealthAutoSyncTitle;

  /// No description provided for @deviceHealthAutoSyncDescription.
  ///
  /// In en, this message translates to:
  /// **'Automatically synchronize health data when synchronizing device data'**
  String get deviceHealthAutoSyncDescription;

  /// No description provided for @deviceHealthConnectFirst.
  ///
  /// In en, this message translates to:
  /// **'Connect the device to synchronize health data'**
  String get deviceHealthConnectFirst;

  /// No description provided for @deviceHealthPartialSync.
  ///
  /// In en, this message translates to:
  /// **'Some health data could not be synchronized'**
  String get deviceHealthPartialSync;

  /// No description provided for @deviceHealthToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get deviceHealthToday;

  /// No description provided for @deviceHealthSteps.
  ///
  /// In en, this message translates to:
  /// **'Steps'**
  String get deviceHealthSteps;

  /// No description provided for @deviceHealthDistance.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get deviceHealthDistance;

  /// No description provided for @deviceHealthCalories.
  ///
  /// In en, this message translates to:
  /// **'Calories'**
  String get deviceHealthCalories;

  /// No description provided for @deviceHealthHeartRate.
  ///
  /// In en, this message translates to:
  /// **'Heart rate'**
  String get deviceHealthHeartRate;

  /// No description provided for @deviceHealthRestingHeartRate.
  ///
  /// In en, this message translates to:
  /// **'Resting heart rate'**
  String get deviceHealthRestingHeartRate;

  /// No description provided for @deviceHealthAbnormalHeartRate.
  ///
  /// In en, this message translates to:
  /// **'Abnormal heart rate'**
  String get deviceHealthAbnormalHeartRate;

  /// No description provided for @deviceHealthHeartRateHigh.
  ///
  /// In en, this message translates to:
  /// **'High heart rate'**
  String get deviceHealthHeartRateHigh;

  /// No description provided for @deviceHealthHeartRateLow.
  ///
  /// In en, this message translates to:
  /// **'Low heart rate'**
  String get deviceHealthHeartRateLow;

  /// No description provided for @deviceHealthHeartHealth.
  ///
  /// In en, this message translates to:
  /// **'Heart health'**
  String get deviceHealthHeartHealth;

  /// No description provided for @deviceHealthHeartHealthMonitoring.
  ///
  /// In en, this message translates to:
  /// **'Heart health monitoring'**
  String get deviceHealthHeartHealthMonitoring;

  /// No description provided for @deviceHealthIrregularHeartbeat.
  ///
  /// In en, this message translates to:
  /// **'Irregular heartbeat'**
  String get deviceHealthIrregularHeartbeat;

  /// No description provided for @deviceHealthLowBloodOxygen.
  ///
  /// In en, this message translates to:
  /// **'Low blood oxygen'**
  String get deviceHealthLowBloodOxygen;

  /// No description provided for @deviceHealthHighStress.
  ///
  /// In en, this message translates to:
  /// **'High stress'**
  String get deviceHealthHighStress;

  /// No description provided for @deviceHealthDetected.
  ///
  /// In en, this message translates to:
  /// **'Detected'**
  String get deviceHealthDetected;

  /// No description provided for @deviceHealthSleep.
  ///
  /// In en, this message translates to:
  /// **'Recent sleep'**
  String get deviceHealthSleep;

  /// No description provided for @deviceHealthSleepCard.
  ///
  /// In en, this message translates to:
  /// **'Sleep'**
  String get deviceHealthSleepCard;

  /// No description provided for @deviceHealthAllDaySleep.
  ///
  /// In en, this message translates to:
  /// **'All-day sleep'**
  String get deviceHealthAllDaySleep;

  /// No description provided for @deviceHealthLongSleep.
  ///
  /// In en, this message translates to:
  /// **'Long sleep'**
  String get deviceHealthLongSleep;

  /// No description provided for @deviceHealthSleepStructure.
  ///
  /// In en, this message translates to:
  /// **'Sleep structure'**
  String get deviceHealthSleepStructure;

  /// No description provided for @deviceHealthSleepAverageHeartRate.
  ///
  /// In en, this message translates to:
  /// **'Average sleep heart rate'**
  String get deviceHealthSleepAverageHeartRate;

  /// No description provided for @deviceHealthSleepAverageBloodOxygen.
  ///
  /// In en, this message translates to:
  /// **'Average sleep blood oxygen'**
  String get deviceHealthSleepAverageBloodOxygen;

  /// No description provided for @deviceHealthAverageHeartRate.
  ///
  /// In en, this message translates to:
  /// **'Average heart rate {value} bpm'**
  String deviceHealthAverageHeartRate(int value);

  /// No description provided for @deviceHealthNoData.
  ///
  /// In en, this message translates to:
  /// **'No data available'**
  String get deviceHealthNoData;

  /// No description provided for @deviceHealthLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to load health data'**
  String get deviceHealthLoadFailed;

  /// No description provided for @deviceMusicUpload.
  ///
  /// In en, this message translates to:
  /// **'Transfer music'**
  String get deviceMusicUpload;

  /// No description provided for @deviceMusicSyncDescription.
  ///
  /// In en, this message translates to:
  /// **'Sync MP3 files to the device'**
  String get deviceMusicSyncDescription;

  /// No description provided for @deviceMusicChooseDialog.
  ///
  /// In en, this message translates to:
  /// **'Select an MP3 file to sync to the device'**
  String get deviceMusicChooseDialog;

  /// No description provided for @deviceMusicReadFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to read the selected MP3 file'**
  String get deviceMusicReadFailed;

  /// No description provided for @deviceMusicSizeInvalid.
  ///
  /// In en, this message translates to:
  /// **'MP3 files must be larger than 0 bytes and no larger than {maxMb} MB'**
  String deviceMusicSizeInvalid(int maxMb);

  /// No description provided for @deviceMusicUnknownArtist.
  ///
  /// In en, this message translates to:
  /// **'Unknown artist'**
  String get deviceMusicUnknownArtist;

  /// No description provided for @deviceMusicTransferred.
  ///
  /// In en, this message translates to:
  /// **'Music transfer complete'**
  String get deviceMusicTransferred;

  /// No description provided for @deviceMusicLibrary.
  ///
  /// In en, this message translates to:
  /// **'Device music'**
  String get deviceMusicLibrary;

  /// No description provided for @deviceMusicLibraryDescription.
  ///
  /// In en, this message translates to:
  /// **'Manage songs and playlists on the device'**
  String get deviceMusicLibraryDescription;

  /// No description provided for @deviceMusicSongs.
  ///
  /// In en, this message translates to:
  /// **'Songs'**
  String get deviceMusicSongs;

  /// No description provided for @deviceMusicSongsTotal.
  ///
  /// In en, this message translates to:
  /// **'{count} total'**
  String deviceMusicSongsTotal(int count);

  /// No description provided for @deviceMusicNoPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Not in a playlist'**
  String get deviceMusicNoPlaylist;

  /// No description provided for @deviceMusicPlaylists.
  ///
  /// In en, this message translates to:
  /// **'Playlists'**
  String get deviceMusicPlaylists;

  /// No description provided for @deviceMusicEmpty.
  ///
  /// In en, this message translates to:
  /// **'No songs on the device'**
  String get deviceMusicEmpty;

  /// No description provided for @deviceMusicNoPlaylists.
  ///
  /// In en, this message translates to:
  /// **'No playlists yet'**
  String get deviceMusicNoPlaylists;

  /// No description provided for @deviceMusicLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load device music: {error}'**
  String deviceMusicLoadFailed(String error);

  /// No description provided for @deviceMusicPlaylistCreate.
  ///
  /// In en, this message translates to:
  /// **'New playlist'**
  String get deviceMusicPlaylistCreate;

  /// No description provided for @deviceMusicPlaylistRename.
  ///
  /// In en, this message translates to:
  /// **'Rename playlist'**
  String get deviceMusicPlaylistRename;

  /// No description provided for @deviceMusicPlaylistName.
  ///
  /// In en, this message translates to:
  /// **'Playlist name'**
  String get deviceMusicPlaylistName;

  /// No description provided for @deviceMusicPlaylistLimit.
  ///
  /// In en, this message translates to:
  /// **'Up to {count} playlists'**
  String deviceMusicPlaylistLimit(int count);

  /// No description provided for @deviceMusicSongCount.
  ///
  /// In en, this message translates to:
  /// **'{count} songs'**
  String deviceMusicSongCount(int count);

  /// No description provided for @deviceMusicDeleteSong.
  ///
  /// In en, this message translates to:
  /// **'Delete this song from the device?'**
  String get deviceMusicDeleteSong;

  /// No description provided for @deviceMusicDeletePlaylist.
  ///
  /// In en, this message translates to:
  /// **'Delete this playlist?'**
  String get deviceMusicDeletePlaylist;

  /// No description provided for @deviceMusicDeletePlaylistDescription.
  ///
  /// In en, this message translates to:
  /// **'Songs in the playlist will remain on the device.'**
  String get deviceMusicDeletePlaylistDescription;

  /// No description provided for @deviceMusicManagePlaylists.
  ///
  /// In en, this message translates to:
  /// **'Manage playlists'**
  String get deviceMusicManagePlaylists;

  /// No description provided for @deviceMusicPlaylistMembership.
  ///
  /// In en, this message translates to:
  /// **'Playlists'**
  String get deviceMusicPlaylistMembership;

  /// No description provided for @deviceMusicTransferSpeed.
  ///
  /// In en, this message translates to:
  /// **'{speed}/s'**
  String deviceMusicTransferSpeed(String speed);

  /// No description provided for @deviceMusicSelectedFiles.
  ///
  /// In en, this message translates to:
  /// **'{count} files selected'**
  String deviceMusicSelectedFiles(int count);

  /// No description provided for @deviceMusicQueueProgress.
  ///
  /// In en, this message translates to:
  /// **'Transferring {current}/{total}: {name}'**
  String deviceMusicQueueProgress(int current, int total, String name);

  /// No description provided for @deviceRecordingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Recording sync'**
  String get deviceRecordingsTitle;

  /// No description provided for @deviceRecordingsDescription.
  ///
  /// In en, this message translates to:
  /// **'Sync and export recordings from the watch'**
  String get deviceRecordingsDescription;

  /// No description provided for @deviceRecordingsHint.
  ///
  /// In en, this message translates to:
  /// **'Recordings are received and verified one by one. Export each original file after synchronization.'**
  String get deviceRecordingsHint;

  /// No description provided for @deviceRecordingsSync.
  ///
  /// In en, this message translates to:
  /// **'Sync recordings'**
  String get deviceRecordingsSync;

  /// No description provided for @deviceRecordingsReading.
  ///
  /// In en, this message translates to:
  /// **'Reading recording list'**
  String get deviceRecordingsReading;

  /// No description provided for @deviceRecordingsProgress.
  ///
  /// In en, this message translates to:
  /// **'Received {completed}/{total}: {name}'**
  String deviceRecordingsProgress(int completed, int total, String name);

  /// No description provided for @deviceRecordingsProgressCount.
  ///
  /// In en, this message translates to:
  /// **'Received {completed}/{total}'**
  String deviceRecordingsProgressCount(int completed, int total);

  /// No description provided for @deviceRecordingsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Connect the watch and select Sync recordings'**
  String get deviceRecordingsEmpty;

  /// No description provided for @deviceRecordingsSave.
  ///
  /// In en, this message translates to:
  /// **'Export recording'**
  String get deviceRecordingsSave;

  /// No description provided for @deviceRecordingsNoneOnWatch.
  ///
  /// In en, this message translates to:
  /// **'No new recordings were found on the watch'**
  String get deviceRecordingsNoneOnWatch;

  /// No description provided for @deviceRecordingsSynced.
  ///
  /// In en, this message translates to:
  /// **'Synced {count} recordings'**
  String deviceRecordingsSynced(int count);

  /// No description provided for @deviceRecordingsSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not export recording: {error}'**
  String deviceRecordingsSaveFailed(String error);

  /// No description provided for @deviceMusicTransferTitle.
  ///
  /// In en, this message translates to:
  /// **'Transfer MP3 file'**
  String get deviceMusicTransferTitle;

  /// No description provided for @deviceMusicVelaDescription.
  ///
  /// In en, this message translates to:
  /// **'Sync MP3 files to the device. Each file must not exceed 100 MB.'**
  String get deviceMusicVelaDescription;

  /// No description provided for @deviceMusicZeppDescription.
  ///
  /// In en, this message translates to:
  /// **'MP3 files up to 50 MB are supported. Bluetooth Classic is recommended for faster transfers; BLE is also supported but takes longer.'**
  String get deviceMusicZeppDescription;

  /// No description provided for @deviceMusicChooseMp3.
  ///
  /// In en, this message translates to:
  /// **'Select MP3 file'**
  String get deviceMusicChooseMp3;

  /// No description provided for @deviceMusicSongTitle.
  ///
  /// In en, this message translates to:
  /// **'Track title'**
  String get deviceMusicSongTitle;

  /// No description provided for @deviceMusicArtist.
  ///
  /// In en, this message translates to:
  /// **'Artist'**
  String get deviceMusicArtist;

  /// No description provided for @deviceMusicFileSize.
  ///
  /// In en, this message translates to:
  /// **'File size: {size}'**
  String deviceMusicFileSize(Object size);

  /// No description provided for @deviceMusicProgress.
  ///
  /// In en, this message translates to:
  /// **'Transfer progress: {progress}%'**
  String deviceMusicProgress(Object progress);

  /// No description provided for @deviceMusicTransferring.
  ///
  /// In en, this message translates to:
  /// **'Transferring'**
  String get deviceMusicTransferring;

  /// No description provided for @deviceMusicSend.
  ///
  /// In en, this message translates to:
  /// **'Start transfer'**
  String get deviceMusicSend;

  /// No description provided for @zeppOsFindDevice.
  ///
  /// In en, this message translates to:
  /// **'Find device'**
  String get zeppOsFindDevice;

  /// No description provided for @zeppOsFindDeviceDescription.
  ///
  /// In en, this message translates to:
  /// **'Make the device vibrate or ring continuously'**
  String get zeppOsFindDeviceDescription;

  /// No description provided for @deviceFeaturesDeviceInfo.
  ///
  /// In en, this message translates to:
  /// **'Device info'**
  String get deviceFeaturesDeviceInfo;

  /// No description provided for @deviceFeaturesDeviceInfoDesc.
  ///
  /// In en, this message translates to:
  /// **'Firmware, storage and details'**
  String get deviceFeaturesDeviceInfoDesc;

  /// No description provided for @switchDeviceTitle.
  ///
  /// In en, this message translates to:
  /// **'Switch device'**
  String get switchDeviceTitle;

  /// No description provided for @savedDevices.
  ///
  /// In en, this message translates to:
  /// **'Saved devices'**
  String get savedDevices;

  /// No description provided for @deviceSwitchAddDevice.
  ///
  /// In en, this message translates to:
  /// **'Add device'**
  String get deviceSwitchAddDevice;

  /// No description provided for @scanAndAdd.
  ///
  /// In en, this message translates to:
  /// **'Scan and add'**
  String get scanAndAdd;

  /// No description provided for @authkey.
  ///
  /// In en, this message translates to:
  /// **'Auth key'**
  String get authkey;

  /// No description provided for @authkeyPrompt.
  ///
  /// In en, this message translates to:
  /// **'Enter device auth key'**
  String get authkeyPrompt;

  /// No description provided for @authkeyPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Auth key'**
  String get authkeyPlaceholder;

  /// No description provided for @connectFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection failed'**
  String get connectFailed;

  /// No description provided for @deviceConnectingTo.
  ///
  /// In en, this message translates to:
  /// **'Connecting to {deviceName}…'**
  String deviceConnectingTo(String deviceName);

  /// No description provided for @deviceConnectionPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing connection…'**
  String get deviceConnectionPreparing;

  /// No description provided for @deviceConnectionEstablishing.
  ///
  /// In en, this message translates to:
  /// **'Establishing {transport} connection…'**
  String deviceConnectionEstablishing(String transport);

  /// No description provided for @deviceConnectionInitializing.
  ///
  /// In en, this message translates to:
  /// **'Initializing device protocol…'**
  String get deviceConnectionInitializing;

  /// No description provided for @deviceConnectionAuthenticating.
  ///
  /// In en, this message translates to:
  /// **'Authenticating device…'**
  String get deviceConnectionAuthenticating;

  /// No description provided for @deviceConnectionFetchingStatus.
  ///
  /// In en, this message translates to:
  /// **'Reading device information…'**
  String get deviceConnectionFetchingStatus;

  /// No description provided for @deviceTransportBle.
  ///
  /// In en, this message translates to:
  /// **'BLE'**
  String get deviceTransportBle;

  /// No description provided for @deviceEndpointUnavailable.
  ///
  /// In en, this message translates to:
  /// **'No {transport} endpoint is available. Pair the device in system Bluetooth settings, then scan again.'**
  String deviceEndpointUnavailable(String transport);

  /// No description provided for @deviceTransportSpp.
  ///
  /// In en, this message translates to:
  /// **'SPP'**
  String get deviceTransportSpp;

  /// No description provided for @deviceCompatibilityUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unrecognized device'**
  String get deviceCompatibilityUnknown;

  /// No description provided for @webSerialTitle.
  ///
  /// In en, this message translates to:
  /// **'Web Serial'**
  String get webSerialTitle;

  /// No description provided for @webSerialHint.
  ///
  /// In en, this message translates to:
  /// **'On the web, OronBox connects to devices via Web Serial. Saved devices stay in this browser.'**
  String get webSerialHint;

  /// No description provided for @webSerialConnectDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Connect via Web Serial'**
  String get webSerialConnectDialogTitle;

  /// No description provided for @webSerialConnectDialogHint.
  ///
  /// In en, this message translates to:
  /// **'Enter the device auth key, then select the serial port in the browser prompt. The auth key is saved in this browser.'**
  String get webSerialConnectDialogHint;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @deviceActionsDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deviceActionsDelete;

  /// No description provided for @deviceActionsDisconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get deviceActionsDisconnect;

  /// No description provided for @deviceActionsShareQR.
  ///
  /// In en, this message translates to:
  /// **'Share QR'**
  String get deviceActionsShareQR;

  /// No description provided for @deviceShareOronBoxCode.
  ///
  /// In en, this message translates to:
  /// **'Switch to OronBox code'**
  String get deviceShareOronBoxCode;

  /// No description provided for @deviceShareAstroBoxCompatibleCode.
  ///
  /// In en, this message translates to:
  /// **'Switch to AstroBox compatible code'**
  String get deviceShareAstroBoxCompatibleCode;

  /// No description provided for @installTapToSelectFile.
  ///
  /// In en, this message translates to:
  /// **'Tap to select file'**
  String get installTapToSelectFile;

  /// No description provided for @deviceInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Device info'**
  String get deviceInfoTitle;

  /// No description provided for @deviceInfoGroupDevice.
  ///
  /// In en, this message translates to:
  /// **'Device'**
  String get deviceInfoGroupDevice;

  /// No description provided for @deviceInfoGroupSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get deviceInfoGroupSystem;

  /// No description provided for @deviceInfoGroupStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get deviceInfoGroupStatus;

  /// No description provided for @fieldName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get fieldName;

  /// No description provided for @fieldAddress.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get fieldAddress;

  /// No description provided for @fieldAuthkey.
  ///
  /// In en, this message translates to:
  /// **'Auth key'**
  String get fieldAuthkey;

  /// No description provided for @fieldConnectionType.
  ///
  /// In en, this message translates to:
  /// **'Connection type'**
  String get fieldConnectionType;

  /// No description provided for @fieldCodename.
  ///
  /// In en, this message translates to:
  /// **'Codename'**
  String get fieldCodename;

  /// No description provided for @fieldModel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get fieldModel;

  /// No description provided for @fieldImei.
  ///
  /// In en, this message translates to:
  /// **'IMEI'**
  String get fieldImei;

  /// No description provided for @fieldFirmware.
  ///
  /// In en, this message translates to:
  /// **'Firmware'**
  String get fieldFirmware;

  /// No description provided for @fieldSerial.
  ///
  /// In en, this message translates to:
  /// **'Serial'**
  String get fieldSerial;

  /// No description provided for @fieldBattery.
  ///
  /// In en, this message translates to:
  /// **'Battery'**
  String get fieldBattery;

  /// No description provided for @fieldChargeStatus.
  ///
  /// In en, this message translates to:
  /// **'Charge status'**
  String get fieldChargeStatus;

  /// No description provided for @fieldStorage.
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get fieldStorage;

  /// No description provided for @appManagementTitle.
  ///
  /// In en, this message translates to:
  /// **'App management'**
  String get appManagementTitle;

  /// No description provided for @appManagementNone.
  ///
  /// In en, this message translates to:
  /// **'No installed apps'**
  String get appManagementNone;

  /// No description provided for @appManagementShowSystemApps.
  ///
  /// In en, this message translates to:
  /// **'Show system apps'**
  String get appManagementShowSystemApps;

  /// No description provided for @watchfaceManagementTitle.
  ///
  /// In en, this message translates to:
  /// **'Watchface management'**
  String get watchfaceManagementTitle;

  /// No description provided for @watchfaceManagementNone.
  ///
  /// In en, this message translates to:
  /// **'No installed watchfaces'**
  String get watchfaceManagementNone;

  /// No description provided for @open.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get open;

  /// No description provided for @externalLinkTitle.
  ///
  /// In en, this message translates to:
  /// **'Open external link'**
  String get externalLinkTitle;

  /// No description provided for @externalLinkDescription.
  ///
  /// In en, this message translates to:
  /// **'You are about to visit {url}\n\nThis website is operated by a third party, is not affiliated with OronBox, and its security is unknown. Please proceed with caution. Do you want to continue?'**
  String externalLinkDescription(String url);

  /// No description provided for @externalLinkAstroBoxResourceHint.
  ///
  /// In en, this message translates to:
  /// **'This appears to be an AstroBox resource. You can also view and install it within OronBox'**
  String get externalLinkAstroBoxResourceHint;

  /// No description provided for @continueToWebsite.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueToWebsite;

  /// No description provided for @viewInOronBox.
  ///
  /// In en, this message translates to:
  /// **'View in OronBox'**
  String get viewInOronBox;

  /// No description provided for @uninstall.
  ///
  /// In en, this message translates to:
  /// **'Uninstall'**
  String get uninstall;

  /// No description provided for @enable.
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get enable;

  /// No description provided for @show.
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get show;

  /// No description provided for @hide.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get hide;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @copied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get copied;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @desktopTrayShow.
  ///
  /// In en, this message translates to:
  /// **'Show window'**
  String get desktopTrayShow;

  /// No description provided for @desktopTrayExit.
  ///
  /// In en, this message translates to:
  /// **'Exit OronBox'**
  String get desktopTrayExit;

  /// No description provided for @desktopCloseTitle.
  ///
  /// In en, this message translates to:
  /// **'Exit confirmation'**
  String get desktopCloseTitle;

  /// No description provided for @desktopCloseMessage.
  ///
  /// In en, this message translates to:
  /// **'Would you like to exit OronBox?'**
  String get desktopCloseMessage;

  /// No description provided for @desktopCloseRemember.
  ///
  /// In en, this message translates to:
  /// **'Do not ask again'**
  String get desktopCloseRemember;

  /// No description provided for @desktopCloseToTray.
  ///
  /// In en, this message translates to:
  /// **'Minimize to tray'**
  String get desktopCloseToTray;

  /// No description provided for @desktopCloseExit.
  ///
  /// In en, this message translates to:
  /// **'Exit OronBox'**
  String get desktopCloseExit;

  /// No description provided for @settingsDesktopCloseBehavior.
  ///
  /// In en, this message translates to:
  /// **'Window closing'**
  String get settingsDesktopCloseBehavior;

  /// No description provided for @settingsDesktopCloseBehaviorDesc.
  ///
  /// In en, this message translates to:
  /// **'Choose what happens when the main window is closed'**
  String get settingsDesktopCloseBehaviorDesc;

  /// No description provided for @settingsRemoveBondBeforeSpp.
  ///
  /// In en, this message translates to:
  /// **'Re-pair when connecting'**
  String get settingsRemoveBondBeforeSpp;

  /// No description provided for @settingsRemoveBondBeforeSppDesc.
  ///
  /// In en, this message translates to:
  /// **'Improves connection stability and prevents Xiaomi Fitness from taking the connection; turning it off may speed up connections'**
  String get settingsRemoveBondBeforeSppDesc;

  /// No description provided for @desktopCloseBehaviorAsk.
  ///
  /// In en, this message translates to:
  /// **'Ask every time'**
  String get desktopCloseBehaviorAsk;

  /// No description provided for @desktopCloseBehaviorExit.
  ///
  /// In en, this message translates to:
  /// **'Exit immediately'**
  String get desktopCloseBehaviorExit;

  /// No description provided for @desktopCloseBehaviorTray.
  ///
  /// In en, this message translates to:
  /// **'Minimize to tray'**
  String get desktopCloseBehaviorTray;

  /// No description provided for @quickApp.
  ///
  /// In en, this message translates to:
  /// **'Quickapp'**
  String get quickApp;

  /// No description provided for @miniprogram.
  ///
  /// In en, this message translates to:
  /// **'Miniprogram'**
  String get miniprogram;

  /// No description provided for @miniprograms.
  ///
  /// In en, this message translates to:
  /// **'Miniprograms'**
  String get miniprograms;

  /// No description provided for @watchface.
  ///
  /// In en, this message translates to:
  /// **'Watchface'**
  String get watchface;

  /// No description provided for @firmwareTool.
  ///
  /// In en, this message translates to:
  /// **'Firmware / Tool'**
  String get firmwareTool;

  /// No description provided for @free.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get free;

  /// No description provided for @paid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get paid;

  /// No description provided for @forcePaid.
  ///
  /// In en, this message translates to:
  /// **'Force Paid'**
  String get forcePaid;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @noContent.
  ///
  /// In en, this message translates to:
  /// **'No content'**
  String get noContent;

  /// No description provided for @preview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get preview;

  /// No description provided for @productDeviceRequirements.
  ///
  /// In en, this message translates to:
  /// **'Device requirements'**
  String get productDeviceRequirements;

  /// No description provided for @productOtherVersions.
  ///
  /// In en, this message translates to:
  /// **'Other versions'**
  String get productOtherVersions;

  /// No description provided for @productInQueue.
  ///
  /// In en, this message translates to:
  /// **'In queue'**
  String get productInQueue;

  /// No description provided for @settingsAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsAccount;

  /// No description provided for @settingsGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get settingsGeneral;

  /// No description provided for @settingsQueue.
  ///
  /// In en, this message translates to:
  /// **'Queue'**
  String get settingsQueue;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// No description provided for @settingsAccountLoginBBSDesc.
  ///
  /// In en, this message translates to:
  /// **'Sign in to access BandBBS resources'**
  String get settingsAccountLoginBBSDesc;

  /// No description provided for @settingsAccountBandBbsSigningIn.
  ///
  /// In en, this message translates to:
  /// **'Signing in'**
  String get settingsAccountBandBbsSigningIn;

  /// No description provided for @settingsAccountBandBbsOpenedBrowser.
  ///
  /// In en, this message translates to:
  /// **'Browser opened. Complete BandBBS authorization there'**
  String get settingsAccountBandBbsOpenedBrowser;

  /// No description provided for @settingsAccountBandBbsSignedIn.
  ///
  /// In en, this message translates to:
  /// **'BandBBS signed in'**
  String get settingsAccountBandBbsSignedIn;

  /// No description provided for @settingsAccountBandBbsLoginFailed.
  ///
  /// In en, this message translates to:
  /// **'BandBBS sign-in failed'**
  String get settingsAccountBandBbsLoginFailed;

  /// No description provided for @settingsBandBbsAccountRequired.
  ///
  /// In en, this message translates to:
  /// **'Sign in to your BandBBS account in Settings first'**
  String get settingsBandBbsAccountRequired;

  /// No description provided for @settingsAccountBBSAccount.
  ///
  /// In en, this message translates to:
  /// **'BandBBS account'**
  String get settingsAccountBBSAccount;

  /// No description provided for @bandBbsAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'BandBBS account'**
  String get bandBbsAccountTitle;

  /// No description provided for @bandBbsResourceId.
  ///
  /// In en, this message translates to:
  /// **'Resource ID'**
  String get bandBbsResourceId;

  /// No description provided for @bandBbsResourceIdHint.
  ///
  /// In en, this message translates to:
  /// **'Enter BandBBS resource ID'**
  String get bandBbsResourceIdHint;

  /// No description provided for @bandBbsQueryResource.
  ///
  /// In en, this message translates to:
  /// **'Query'**
  String get bandBbsQueryResource;

  /// No description provided for @bandBbsLogout.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get bandBbsLogout;

  /// No description provided for @bandBbsLoggedOut.
  ///
  /// In en, this message translates to:
  /// **'Signed out'**
  String get bandBbsLoggedOut;

  /// No description provided for @accountSignOutTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign out of {accountName}?'**
  String accountSignOutTitle(Object accountName);

  /// No description provided for @accountSignOutMessage.
  ///
  /// In en, this message translates to:
  /// **'You will need to sign in again to use related features.'**
  String get accountSignOutMessage;

  /// No description provided for @bandBbsLoadPreviews.
  ///
  /// In en, this message translates to:
  /// **'Load post previews'**
  String get bandBbsLoadPreviews;

  /// No description provided for @bandBbsLoadPreviewsDesc.
  ///
  /// In en, this message translates to:
  /// **'Automatically load attachment previews in the resource list'**
  String get bandBbsLoadPreviewsDesc;

  /// No description provided for @bandBbsShowAllCategories.
  ///
  /// In en, this message translates to:
  /// **'Show all categories'**
  String get bandBbsShowAllCategories;

  /// No description provided for @bandBbsShowAllCategoriesDesc.
  ///
  /// In en, this message translates to:
  /// **'Include categories for unsupported devices hidden by default'**
  String get bandBbsShowAllCategoriesDesc;

  /// No description provided for @settingsMiAccount.
  ///
  /// In en, this message translates to:
  /// **'Xiaomi account'**
  String get settingsMiAccount;

  /// No description provided for @settingsMiAccountDesc.
  ///
  /// In en, this message translates to:
  /// **'Sign in and sync authkeys from bound devices'**
  String get settingsMiAccountDesc;

  /// No description provided for @deviceSwitchMiAccountImport.
  ///
  /// In en, this message translates to:
  /// **'Sign in to Xiaomi account and sync bound devices'**
  String get deviceSwitchMiAccountImport;

  /// No description provided for @deviceSwitchWearableLogImport.
  ///
  /// In en, this message translates to:
  /// **'Import devices from Xiaomi Fitness logs'**
  String get deviceSwitchWearableLogImport;

  /// No description provided for @settingsMiAccountLoginTitle.
  ///
  /// In en, this message translates to:
  /// **'Xiaomi account login'**
  String get settingsMiAccountLoginTitle;

  /// No description provided for @settingsMiAccountUsername.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsMiAccountUsername;

  /// No description provided for @settingsMiAccountPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get settingsMiAccountPassword;

  /// No description provided for @settingsMiAccountRememberCredentials.
  ///
  /// In en, this message translates to:
  /// **'Remember account and password'**
  String get settingsMiAccountRememberCredentials;

  /// No description provided for @settingsMiAccountLoginAndSync.
  ///
  /// In en, this message translates to:
  /// **'Sign in and sync'**
  String get settingsMiAccountLoginAndSync;

  /// No description provided for @settingsMiAccountLogInvalid.
  ///
  /// In en, this message translates to:
  /// **'Unable to read this Xiaomi Fitness log'**
  String get settingsMiAccountLogInvalid;

  /// No description provided for @settingsMiAccountLogNoDevices.
  ///
  /// In en, this message translates to:
  /// **'No device with a complete MAC and authkey was found in the log'**
  String get settingsMiAccountLogNoDevices;

  /// No description provided for @settingsWearableLogSync.
  ///
  /// In en, this message translates to:
  /// **'Read Xiaomi Fitness log'**
  String get settingsWearableLogSync;

  /// No description provided for @settingsWearableLogGuide.
  ///
  /// In en, this message translates to:
  /// **'Open Xiaomi Fitness\nGo to About at the bottom of the Profile page\nRepeatedly tap the orange ring logo\nTap Confirm in the dialog\nWait for the log has been... toast\nReturn here and tap Scan'**
  String get settingsWearableLogGuide;

  /// No description provided for @settingsWearableLogFound.
  ///
  /// In en, this message translates to:
  /// **'Found {count} devices, tap one to import'**
  String settingsWearableLogFound(int count);

  /// No description provided for @settingsWearableLogImportedDevice.
  ///
  /// In en, this message translates to:
  /// **'Imported {name}'**
  String settingsWearableLogImportedDevice(Object name);

  /// No description provided for @settingsMiAccountMissingCredentials.
  ///
  /// In en, this message translates to:
  /// **'Enter your Xiaomi account and password'**
  String get settingsMiAccountMissingCredentials;

  /// No description provided for @settingsMiAccountTwoFactorPrompt.
  ///
  /// In en, this message translates to:
  /// **'Complete Xiaomi account two-factor verification in the verification page'**
  String get settingsMiAccountTwoFactorPrompt;

  /// No description provided for @settingsMiAccountLoginWindowClosed.
  ///
  /// In en, this message translates to:
  /// **'The login window was closed'**
  String get settingsMiAccountLoginWindowClosed;

  /// No description provided for @settingsMiAccountSyncedDevices.
  ///
  /// In en, this message translates to:
  /// **'Synced {count} Mi devices'**
  String settingsMiAccountSyncedDevices(int count);

  /// No description provided for @xiaomiAccountRequiredForEphemeris.
  ///
  /// In en, this message translates to:
  /// **'Sign in to your Xiaomi account before syncing ephemeris data'**
  String get xiaomiAccountRequiredForEphemeris;

  /// No description provided for @settingsHuamiAccount.
  ///
  /// In en, this message translates to:
  /// **'Amazfit account'**
  String get settingsHuamiAccount;

  /// No description provided for @settingsHuamiAccountDesc.
  ///
  /// In en, this message translates to:
  /// **'Sign in and save credentials for Zepp store access'**
  String get settingsHuamiAccountDesc;

  /// No description provided for @settingsHuamiAccountSigningIn.
  ///
  /// In en, this message translates to:
  /// **'Signing in'**
  String get settingsHuamiAccountSigningIn;

  /// No description provided for @settingsHuamiAccountSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Amazfit account signed in'**
  String get settingsHuamiAccountSignedIn;

  /// No description provided for @settingsHuamiAccountLoginTitle.
  ///
  /// In en, this message translates to:
  /// **'Amazfit account login'**
  String get settingsHuamiAccountLoginTitle;

  /// No description provided for @settingsHuamiAccountUsername.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsHuamiAccountUsername;

  /// No description provided for @settingsHuamiAccountPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get settingsHuamiAccountPassword;

  /// No description provided for @settingsHuamiAccountRememberCredentials.
  ///
  /// In en, this message translates to:
  /// **'Remember password'**
  String get settingsHuamiAccountRememberCredentials;

  /// No description provided for @settingsHuamiAccountLoginAndSave.
  ///
  /// In en, this message translates to:
  /// **'Sign in and save'**
  String get settingsHuamiAccountLoginAndSave;

  /// No description provided for @settingsHuamiAccountMissingCredentials.
  ///
  /// In en, this message translates to:
  /// **'Enter your Amazfit account and password'**
  String get settingsHuamiAccountMissingCredentials;

  /// No description provided for @settingsHuamiAccountRequired.
  ///
  /// In en, this message translates to:
  /// **'Sign in to your Amazfit account in Settings first'**
  String get settingsHuamiAccountRequired;

  /// No description provided for @understood.
  ///
  /// In en, this message translates to:
  /// **'I understand'**
  String get understood;

  /// No description provided for @settingsGeneralLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsGeneralLanguage;

  /// No description provided for @settingsGeneralLanguageDesc.
  ///
  /// In en, this message translates to:
  /// **'Change app display language'**
  String get settingsGeneralLanguageDesc;

  /// No description provided for @settingsWideNavigationPosition.
  ///
  /// In en, this message translates to:
  /// **'Navigation position'**
  String get settingsWideNavigationPosition;

  /// No description provided for @settingsWideNavigationPositionDesc.
  ///
  /// In en, this message translates to:
  /// **'Adjust side tab placement in the wide-screen state'**
  String get settingsWideNavigationPositionDesc;

  /// No description provided for @settingsWideNavigationPositionBottom.
  ///
  /// In en, this message translates to:
  /// **'Bottom'**
  String get settingsWideNavigationPositionBottom;

  /// No description provided for @settingsWideNavigationPositionCenter.
  ///
  /// In en, this message translates to:
  /// **'Center'**
  String get settingsWideNavigationPositionCenter;

  /// No description provided for @settingsWideNavigationPositionSplit.
  ///
  /// In en, this message translates to:
  /// **'Split'**
  String get settingsWideNavigationPositionSplit;

  /// No description provided for @settingsAutoReconnectTitle.
  ///
  /// In en, this message translates to:
  /// **'Auto reconnect'**
  String get settingsAutoReconnectTitle;

  /// No description provided for @settingsAutoReconnectDesc.
  ///
  /// In en, this message translates to:
  /// **'Automatically reconnect to the last paired device on startup'**
  String get settingsAutoReconnectDesc;

  /// No description provided for @settingsAutoReconnectOnDisconnectTitle.
  ///
  /// In en, this message translates to:
  /// **'Auto reconnect'**
  String get settingsAutoReconnectOnDisconnectTitle;

  /// No description provided for @settingsAutoReconnectOnDisconnectDesc.
  ///
  /// In en, this message translates to:
  /// **'Try to reconnect when the device is disconnected unexpectedly'**
  String get settingsAutoReconnectOnDisconnectDesc;

  /// No description provided for @deviceReconnectAttempting.
  ///
  /// In en, this message translates to:
  /// **'Device connection lost, trying to reconnect'**
  String get deviceReconnectAttempting;

  /// No description provided for @deviceReconnectSucceeded.
  ///
  /// In en, this message translates to:
  /// **'Reconnected successfully'**
  String get deviceReconnectSucceeded;

  /// No description provided for @deviceReconnectFailedPrefix.
  ///
  /// In en, this message translates to:
  /// **'Reconnect failed. Check: '**
  String get deviceReconnectFailedPrefix;

  /// No description provided for @settingsSourceOfficialCdn.
  ///
  /// In en, this message translates to:
  /// **'GitHub source CDN'**
  String get settingsSourceOfficialCdn;

  /// No description provided for @settingsSourceOfficialCdnDesc.
  ///
  /// In en, this message translates to:
  /// **'CDN used to fetch the GitHub-hosted community index'**
  String get settingsSourceOfficialCdnDesc;

  /// No description provided for @settingsQueueAutoInstall.
  ///
  /// In en, this message translates to:
  /// **'Auto install'**
  String get settingsQueueAutoInstall;

  /// No description provided for @settingsQueueAutoInstallDesc.
  ///
  /// In en, this message translates to:
  /// **'Start installation automatically after download'**
  String get settingsQueueAutoInstallDesc;

  /// No description provided for @settingsQueueDontClear.
  ///
  /// In en, this message translates to:
  /// **'Don\'t clear install queue'**
  String get settingsQueueDontClear;

  /// No description provided for @settingsQueueDontClearDesc.
  ///
  /// In en, this message translates to:
  /// **'Keep completed items in the install queue'**
  String get settingsQueueDontClearDesc;

  /// No description provided for @settingsRealtimeActivityNotification.
  ///
  /// In en, this message translates to:
  /// **'Real-time activity notification'**
  String get settingsRealtimeActivityNotification;

  /// No description provided for @settingsRealtimeActivityNotificationDesc.
  ///
  /// In en, this message translates to:
  /// **'Use a real-time activity notification to show queue progress'**
  String get settingsRealtimeActivityNotificationDesc;

  /// No description provided for @settingsAboutWebsite.
  ///
  /// In en, this message translates to:
  /// **'Official website'**
  String get settingsAboutWebsite;

  /// No description provided for @settingsTapToSignIn.
  ///
  /// In en, this message translates to:
  /// **'Tap to sign in'**
  String get settingsTapToSignIn;

  /// No description provided for @settingsConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get settingsConnected;

  /// No description provided for @settingsSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsSystem;

  /// No description provided for @settingsLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsLight;

  /// No description provided for @settingsDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsDark;

  /// No description provided for @settingsOledDark.
  ///
  /// In en, this message translates to:
  /// **'OLED dark'**
  String get settingsOledDark;

  /// No description provided for @settingsThemeMode.
  ///
  /// In en, this message translates to:
  /// **'Theme mode'**
  String get settingsThemeMode;

  /// No description provided for @settingsThemeModeDesc.
  ///
  /// In en, this message translates to:
  /// **'Change app theme appearance'**
  String get settingsThemeModeDesc;

  /// No description provided for @settingsDynamicColor.
  ///
  /// In en, this message translates to:
  /// **'Dynamic color'**
  String get settingsDynamicColor;

  /// No description provided for @settingsDynamicColorDesc.
  ///
  /// In en, this message translates to:
  /// **'Use system accent colors for the app theme'**
  String get settingsDynamicColorDesc;

  /// No description provided for @settingsColorScheme.
  ///
  /// In en, this message translates to:
  /// **'Color scheme'**
  String get settingsColorScheme;

  /// No description provided for @settingsColorSchemeDesc.
  ///
  /// In en, this message translates to:
  /// **'Choose the app accent color'**
  String get settingsColorSchemeDesc;

  /// No description provided for @settingsColorSchemePink.
  ///
  /// In en, this message translates to:
  /// **'Pink'**
  String get settingsColorSchemePink;

  /// No description provided for @settingsColorSchemePurple.
  ///
  /// In en, this message translates to:
  /// **'Purple'**
  String get settingsColorSchemePurple;

  /// No description provided for @settingsColorSchemeTeal.
  ///
  /// In en, this message translates to:
  /// **'Teal'**
  String get settingsColorSchemeTeal;

  /// No description provided for @settingsColorSchemeGreen.
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get settingsColorSchemeGreen;

  /// No description provided for @settingsColorSchemeRed.
  ///
  /// In en, this message translates to:
  /// **'Red'**
  String get settingsColorSchemeRed;

  /// No description provided for @settingsColorSchemeAmber.
  ///
  /// In en, this message translates to:
  /// **'Amber'**
  String get settingsColorSchemeAmber;

  /// No description provided for @settingsDesktopAccentSource.
  ///
  /// In en, this message translates to:
  /// **'Linux accent source'**
  String get settingsDesktopAccentSource;

  /// No description provided for @settingsDesktopAccentSourceDesc.
  ///
  /// In en, this message translates to:
  /// **'Choose whether to read accent colors from GTK or Qt'**
  String get settingsDesktopAccentSourceDesc;

  /// No description provided for @settingsDesktopAccentSourceSystem.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get settingsDesktopAccentSourceSystem;

  /// No description provided for @settingsDesktopAccentSourceGtk.
  ///
  /// In en, this message translates to:
  /// **'GTK'**
  String get settingsDesktopAccentSourceGtk;

  /// No description provided for @settingsDesktopAccentSourceQt.
  ///
  /// In en, this message translates to:
  /// **'Qt'**
  String get settingsDesktopAccentSourceQt;

  /// No description provided for @settingsCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get settingsCancel;

  /// No description provided for @settingsTeamRoleMain.
  ///
  /// In en, this message translates to:
  /// **'Main Developer / Designer'**
  String get settingsTeamRoleMain;

  /// No description provided for @settingsTeamRoleZeppOS.
  ///
  /// In en, this message translates to:
  /// **'ZeppOS implementation'**
  String get settingsTeamRoleZeppOS;

  /// No description provided for @settingsTeamRoleHarmony.
  ///
  /// In en, this message translates to:
  /// **'HarmonyOS adaptation'**
  String get settingsTeamRoleHarmony;

  /// No description provided for @settingsAboutSoftware.
  ///
  /// In en, this message translates to:
  /// **'About software'**
  String get settingsAboutSoftware;

  /// No description provided for @settingsAboutSoftwareDesc.
  ///
  /// In en, this message translates to:
  /// **'Version, changelog and development team'**
  String get settingsAboutSoftwareDesc;

  /// No description provided for @settingsAboutSoftwareTagline.
  ///
  /// In en, this message translates to:
  /// **'A pretty fast wearable management tool for VelaOS and ZeppOS, built with Flutter'**
  String get settingsAboutSoftwareTagline;

  /// No description provided for @settingsAboutSoftwareRepository.
  ///
  /// In en, this message translates to:
  /// **'Open GitHub repository'**
  String get settingsAboutSoftwareRepository;

  /// No description provided for @settingsAboutSoftwareTeam.
  ///
  /// In en, this message translates to:
  /// **'Development team'**
  String get settingsAboutSoftwareTeam;

  /// No description provided for @settingsSpecialThanks.
  ///
  /// In en, this message translates to:
  /// **'Special thanks'**
  String get settingsSpecialThanks;

  /// No description provided for @settingsAboutSoftwareBuildInfo.
  ///
  /// In en, this message translates to:
  /// **'Build info'**
  String get settingsAboutSoftwareBuildInfo;

  /// No description provided for @settingsAboutSoftwareCopyright.
  ///
  /// In en, this message translates to:
  /// **'Copyright © 2026 OrPudding'**
  String get settingsAboutSoftwareCopyright;

  /// No description provided for @acknowledgementsKazumi.
  ///
  /// In en, this message translates to:
  /// **'Reference for Material Design components and UI patterns.'**
  String get acknowledgementsKazumi;

  /// No description provided for @acknowledgementsAstroBoxPublic.
  ///
  /// In en, this message translates to:
  /// **'Reference for UI structure, resource workflows, and interaction design.'**
  String get acknowledgementsAstroBoxPublic;

  /// No description provided for @acknowledgementsAstroBoxNgCore.
  ///
  /// In en, this message translates to:
  /// **'Reference for Xiaomi device protocols, install flows, and transfer behavior.'**
  String get acknowledgementsAstroBoxNgCore;

  /// No description provided for @acknowledgementsAstroBoxNgBluetooth.
  ///
  /// In en, this message translates to:
  /// **'Reference for Bluetooth connection behavior.'**
  String get acknowledgementsAstroBoxNgBluetooth;

  /// No description provided for @acknowledgementsAstroBoxNgAccount.
  ///
  /// In en, this message translates to:
  /// **'Reference for Xiaomi account login, device sync, and authkey retrieval flows.'**
  String get acknowledgementsAstroBoxNgAccount;

  /// No description provided for @acknowledgementsAstroBoxNgProvider.
  ///
  /// In en, this message translates to:
  /// **'Reference for community resource indexes, CDN handling, and manifest parsing flows.'**
  String get acknowledgementsAstroBoxNgProvider;

  /// No description provided for @acknowledgementsAstroBoxNgAppWasm.
  ///
  /// In en, this message translates to:
  /// **'Reference for Web Serial and browser-side connection flows.'**
  String get acknowledgementsAstroBoxNgAppWasm;

  /// No description provided for @acknowledgementsGadgetbridge.
  ///
  /// In en, this message translates to:
  /// **'Reference for ZeppOS and wearable protocol research.'**
  String get acknowledgementsGadgetbridge;

  /// No description provided for @acknowledgementsBreezyWeather.
  ///
  /// In en, this message translates to:
  /// **'Reference for the China weather source implementation.'**
  String get acknowledgementsBreezyWeather;

  /// No description provided for @acknowledgementsOpenMeteo.
  ///
  /// In en, this message translates to:
  /// **'Weather forecasts, air quality, and geocoding data under CC BY 4.0'**
  String get acknowledgementsOpenMeteo;

  /// No description provided for @resourceHomeRecommended.
  ///
  /// In en, this message translates to:
  /// **'Recommended'**
  String get resourceHomeRecommended;

  /// No description provided for @resourceHomeFeatured.
  ///
  /// In en, this message translates to:
  /// **'Featured'**
  String get resourceHomeFeatured;

  /// No description provided for @resourceHomeUpdates.
  ///
  /// In en, this message translates to:
  /// **'Updates'**
  String get resourceHomeUpdates;

  /// No description provided for @blogTypeAnnouncement.
  ///
  /// In en, this message translates to:
  /// **'Announcement'**
  String get blogTypeAnnouncement;

  /// No description provided for @blogTypeRecommendation.
  ///
  /// In en, this message translates to:
  /// **'Recommendation'**
  String get blogTypeRecommendation;

  /// No description provided for @blogTypeDocs.
  ///
  /// In en, this message translates to:
  /// **'Docs'**
  String get blogTypeDocs;

  /// No description provided for @resourceHomeEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing to recommend yet'**
  String get resourceHomeEmptyTitle;

  /// No description provided for @resourceLibraryEndOfList.
  ///
  /// In en, this message translates to:
  /// **'You\'ve reached the end — check out resources from other sources?'**
  String get resourceLibraryEndOfList;

  /// No description provided for @resourceHomeEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'You can get resources from the library'**
  String get resourceHomeEmptySubtitle;

  /// No description provided for @openResourceLibrary.
  ///
  /// In en, this message translates to:
  /// **'Open resource library'**
  String get openResourceLibrary;

  /// No description provided for @downloadQueueTitle.
  ///
  /// In en, this message translates to:
  /// **'Download queue'**
  String get downloadQueueTitle;

  /// No description provided for @installQueueTitle.
  ///
  /// In en, this message translates to:
  /// **'Install queue'**
  String get installQueueTitle;

  /// No description provided for @queueClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get queueClear;

  /// No description provided for @queueStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get queueStart;

  /// No description provided for @queuePause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get queuePause;

  /// No description provided for @downloadQueueEmpty.
  ///
  /// In en, this message translates to:
  /// **'No download tasks'**
  String get downloadQueueEmpty;

  /// No description provided for @installQueueEmpty.
  ///
  /// In en, this message translates to:
  /// **'No install tasks'**
  String get installQueueEmpty;

  /// No description provided for @localAppInstall.
  ///
  /// In en, this message translates to:
  /// **'Local app install'**
  String get localAppInstall;

  /// No description provided for @localWatchfaceInstall.
  ///
  /// In en, this message translates to:
  /// **'Local watchface install'**
  String get localWatchfaceInstall;

  /// No description provided for @localFirmwareInstall.
  ///
  /// In en, this message translates to:
  /// **'Local firmware install'**
  String get localFirmwareInstall;

  /// No description provided for @queueStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get queueStatusPending;

  /// No description provided for @queueStatusDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading {percent}%'**
  String queueStatusDownloading(String percent);

  /// No description provided for @queueStatusInstalling.
  ///
  /// In en, this message translates to:
  /// **'Installing {percent}%'**
  String queueStatusInstalling(String percent);

  /// No description provided for @queueStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get queueStatusCompleted;

  /// No description provided for @queueStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get queueStatusFailed;

  /// No description provided for @queueDragToInstall.
  ///
  /// In en, this message translates to:
  /// **'Release to install an app, watchface, or plugin'**
  String get queueDragToInstall;

  /// No description provided for @queueAddedFiles.
  ///
  /// In en, this message translates to:
  /// **'Added {count} files to install queue'**
  String queueAddedFiles(int count);

  /// No description provided for @installQueueReadFailed.
  ///
  /// In en, this message translates to:
  /// **'Read failed'**
  String get installQueueReadFailed;

  /// No description provided for @installQueueUnsupportedFile.
  ///
  /// In en, this message translates to:
  /// **'Unsupported file'**
  String get installQueueUnsupportedFile;

  /// No description provided for @timeTodayAt.
  ///
  /// In en, this message translates to:
  /// **'Today {time}'**
  String timeTodayAt(Object time);

  /// No description provided for @timeYesterdayAt.
  ///
  /// In en, this message translates to:
  /// **'Yesterday {time}'**
  String timeYesterdayAt(Object time);

  /// No description provided for @settingsAccountBandBbsAccount.
  ///
  /// In en, this message translates to:
  /// **'BandBBS account'**
  String get settingsAccountBandBbsAccount;

  /// No description provided for @settingsAccountGitHub.
  ///
  /// In en, this message translates to:
  /// **'GitHub account'**
  String get settingsAccountGitHub;

  /// No description provided for @settingsAccountGitHubDesc.
  ///
  /// In en, this message translates to:
  /// **'Connect to publish AstroBox resources as yourself'**
  String get settingsAccountGitHubDesc;

  /// No description provided for @githubAccountNeedsBandBbs.
  ///
  /// In en, this message translates to:
  /// **'Sign in to BandBBS first'**
  String get githubAccountNeedsBandBbs;

  /// No description provided for @bandBbsPublishAuthTitle.
  ///
  /// In en, this message translates to:
  /// **'Publish authorization'**
  String get bandBbsPublishAuthTitle;

  /// No description provided for @bandBbsResourceQueryTitle.
  ///
  /// In en, this message translates to:
  /// **'Install purchased resources'**
  String get bandBbsResourceQueryTitle;

  /// No description provided for @settingsAboutLogs.
  ///
  /// In en, this message translates to:
  /// **'Runtime logs'**
  String get settingsAboutLogs;

  /// No description provided for @settingsAboutLogsDescription.
  ///
  /// In en, this message translates to:
  /// **'View, export, and manage runtime logs from the app and connected devices'**
  String get settingsAboutLogsDescription;

  /// No description provided for @settingsAboutLogsSize.
  ///
  /// In en, this message translates to:
  /// **'Currently using {size}'**
  String settingsAboutLogsSize(Object size);

  /// No description provided for @settingsAboutLogsExport.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get settingsAboutLogsExport;

  /// No description provided for @settingsAboutLogsExported.
  ///
  /// In en, this message translates to:
  /// **'Exported to {path}'**
  String settingsAboutLogsExported(Object path);

  /// No description provided for @settingsAboutLogsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No log files'**
  String get settingsAboutLogsEmpty;

  /// No description provided for @settingsAboutLogsClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get settingsAboutLogsClear;

  /// No description provided for @settingsDeviceLogsPull.
  ///
  /// In en, this message translates to:
  /// **'Pull device logs'**
  String get settingsDeviceLogsPull;

  /// No description provided for @settingsDeviceLogsTip.
  ///
  /// In en, this message translates to:
  /// **'This pulls logs from the connected Xiaomi wearable and may take a while. Keep the app in the foreground and the device screen on until it finishes.'**
  String get settingsDeviceLogsTip;

  /// No description provided for @settingsDeviceLogsStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get settingsDeviceLogsStart;

  /// No description provided for @settingsDeviceLogsPulling.
  ///
  /// In en, this message translates to:
  /// **'Pulling device logs'**
  String get settingsDeviceLogsPulling;

  /// No description provided for @settingsDeviceLogsWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the device to send logs'**
  String get settingsDeviceLogsWaiting;

  /// No description provided for @settingsDeviceLogsProgress.
  ///
  /// In en, this message translates to:
  /// **'Received {progress}%'**
  String settingsDeviceLogsProgress(Object progress);

  /// No description provided for @settingsDeviceLogsSaved.
  ///
  /// In en, this message translates to:
  /// **'Device logs saved as {name}'**
  String settingsDeviceLogsSaved(Object name);

  /// No description provided for @settingsDeviceLogsFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to pull device logs: {error}'**
  String settingsDeviceLogsFailed(Object error);

  /// No description provided for @settingsAboutLogsClearConfirm.
  ///
  /// In en, this message translates to:
  /// **'All log files except the current session will be deleted.'**
  String get settingsAboutLogsClearConfirm;

  /// No description provided for @settingsAboutLogsOpen.
  ///
  /// In en, this message translates to:
  /// **'Open logs folder'**
  String get settingsAboutLogsOpen;

  /// No description provided for @settingsAboutLogsOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to open the logs folder'**
  String get settingsAboutLogsOpenFailed;

  /// No description provided for @settingsLogsFileList.
  ///
  /// In en, this message translates to:
  /// **'Log files'**
  String get settingsLogsFileList;

  /// No description provided for @settingsAboutLogsWarningTitle.
  ///
  /// In en, this message translates to:
  /// **'Sensitive information warning'**
  String get settingsAboutLogsWarningTitle;

  /// No description provided for @settingsAboutLogsWarningMessage.
  ///
  /// In en, this message translates to:
  /// **'Logs may contain BandBBS, Xiaomi, or Amazfit login credentials and other sensitive information. Do not share them with anyone other than official OronBox maintainers!'**
  String get settingsAboutLogsWarningMessage;

  /// No description provided for @pluginPermissionRequestTitle.
  ///
  /// In en, this message translates to:
  /// **'Plugin permission request'**
  String get pluginPermissionRequestTitle;

  /// No description provided for @pluginPermissionRequestMessage.
  ///
  /// In en, this message translates to:
  /// **'\"{plugin}\" wants to {operation}.'**
  String pluginPermissionRequestMessage(Object plugin, Object operation);

  /// No description provided for @pluginPermissionOnce.
  ///
  /// In en, this message translates to:
  /// **'Allow once'**
  String get pluginPermissionOnce;

  /// No description provided for @pluginPermissionSession.
  ///
  /// In en, this message translates to:
  /// **'Allow this run'**
  String get pluginPermissionSession;

  /// No description provided for @pluginPermissionAlways.
  ///
  /// In en, this message translates to:
  /// **'Always allow'**
  String get pluginPermissionAlways;

  /// No description provided for @pluginPermissionDeny.
  ///
  /// In en, this message translates to:
  /// **'Deny'**
  String get pluginPermissionDeny;

  /// No description provided for @pluginPermissionOpenExternal.
  ///
  /// In en, this message translates to:
  /// **'open an external link'**
  String get pluginPermissionOpenExternal;

  /// No description provided for @pluginPermissionPickFile.
  ///
  /// In en, this message translates to:
  /// **'access host files'**
  String get pluginPermissionPickFile;

  /// No description provided for @pluginPermissionExportFile.
  ///
  /// In en, this message translates to:
  /// **'export a file to the host'**
  String get pluginPermissionExportFile;

  /// No description provided for @pluginPermissionNetwork.
  ///
  /// In en, this message translates to:
  /// **'access the network'**
  String get pluginPermissionNetwork;

  /// No description provided for @pluginPermissionInterconnect.
  ///
  /// In en, this message translates to:
  /// **'communicate with device applications'**
  String get pluginPermissionInterconnect;

  /// No description provided for @pluginPermissionProvider.
  ///
  /// In en, this message translates to:
  /// **'register a resource provider'**
  String get pluginPermissionProvider;

  /// No description provided for @pluginPermissionReadDevice.
  ///
  /// In en, this message translates to:
  /// **'read device information'**
  String get pluginPermissionReadDevice;

  /// No description provided for @pluginPermissionOperateDevice.
  ///
  /// In en, this message translates to:
  /// **'operate a device'**
  String get pluginPermissionOperateDevice;

  /// No description provided for @pluginPermissionObserveProtocol.
  ///
  /// In en, this message translates to:
  /// **'read raw device protocol data'**
  String get pluginPermissionObserveProtocol;

  /// No description provided for @pluginPermissionSendProtocol.
  ///
  /// In en, this message translates to:
  /// **'send raw protocol data to a device'**
  String get pluginPermissionSendProtocol;

  /// No description provided for @pluginPermissionReadAppSide.
  ///
  /// In en, this message translates to:
  /// **'read AppSide scripts and events'**
  String get pluginPermissionReadAppSide;

  /// No description provided for @pluginPermissionOperateAppSide.
  ///
  /// In en, this message translates to:
  /// **'manage AppSide sessions'**
  String get pluginPermissionOperateAppSide;

  /// No description provided for @pluginErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Plugin corrupted'**
  String get pluginErrorTitle;

  /// No description provided for @pluginErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'\"{plugin}\" cannot run and may be corrupted.\n\nError: {error}\n\nUninstall this plugin?'**
  String pluginErrorMessage(Object plugin, Object error);

  /// No description provided for @pluginPackageCorruptedMessage.
  ///
  /// In en, this message translates to:
  /// **'The selected plugin package cannot be read and may be corrupted. Obtain it again and try importing it.'**
  String get pluginPackageCorruptedMessage;

  /// No description provided for @pluginErrorClearData.
  ///
  /// In en, this message translates to:
  /// **'Clear plugin data'**
  String get pluginErrorClearData;

  /// No description provided for @pluginErrorUninstall.
  ///
  /// In en, this message translates to:
  /// **'Uninstall plugin'**
  String get pluginErrorUninstall;

  /// No description provided for @pluginErrorSafeMode.
  ///
  /// In en, this message translates to:
  /// **'Enter safe mode'**
  String get pluginErrorSafeMode;

  /// No description provided for @pluginSafeModeTitle.
  ///
  /// In en, this message translates to:
  /// **'Plugin safe mode is enabled'**
  String get pluginSafeModeTitle;

  /// No description provided for @pluginSafeModeDescription.
  ///
  /// In en, this message translates to:
  /// **'All plugins are stopped and will reload after safe mode is disabled.'**
  String get pluginSafeModeDescription;

  /// No description provided for @pluginSafeModeExit.
  ///
  /// In en, this message translates to:
  /// **'Exit safe mode'**
  String get pluginSafeModeExit;

  /// No description provided for @devTools.
  ///
  /// In en, this message translates to:
  /// **'DevTools'**
  String get devTools;

  /// No description provided for @devToolsDescriptionDesktop.
  ///
  /// In en, this message translates to:
  /// **'Open DevTools in a separate window'**
  String get devToolsDescriptionDesktop;

  /// No description provided for @devToolsDescriptionEntry.
  ///
  /// In en, this message translates to:
  /// **'Show a DevTools entry button in app bars'**
  String get devToolsDescriptionEntry;

  /// No description provided for @devToolsOperationFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to change the DevTools state'**
  String get devToolsOperationFailed;

  /// No description provided for @resourceTypeErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Incorrect resource type'**
  String get resourceTypeErrorTitle;

  /// No description provided for @resourceTypeUnknownTitle.
  ///
  /// In en, this message translates to:
  /// **'Unrecognized resource type'**
  String get resourceTypeUnknownTitle;

  /// No description provided for @resourceTypeUnknownNoType.
  ///
  /// In en, this message translates to:
  /// **'OronBox cannot identify the resource type of this file; it may be corrupted'**
  String get resourceTypeUnknownNoType;

  /// No description provided for @resourceTypeUnknownCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get resourceTypeUnknownCancel;

  /// No description provided for @resourceTypeMismatchMessage.
  ///
  /// In en, this message translates to:
  /// **'This appears to be a {detectedType} resource, but you selected {selectedType}. Choose how to install it'**
  String resourceTypeMismatchMessage(Object detectedType, Object selectedType);

  /// No description provided for @resourcePlatformMismatchMessage.
  ///
  /// In en, this message translates to:
  /// **'This appears to be a {resourceType} resource for a {resourcePlatform} device, but the connected device is {deviceName} ({devicePlatform}). It is not supported and forcing installation may cause unexpected problems'**
  String resourcePlatformMismatchMessage(
    Object resourcePlatform,
    Object resourceType,
    Object deviceName,
    Object devicePlatform,
  );

  /// No description provided for @resourceTypeUnknownMessage.
  ///
  /// In en, this message translates to:
  /// **'OronBox cannot identify the actual resource type. Install it as {selectedType} anyway?'**
  String resourceTypeUnknownMessage(Object selectedType);

  /// No description provided for @resourceInstallCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel installation'**
  String get resourceInstallCancel;

  /// No description provided for @resourceInstallAcknowledge.
  ///
  /// In en, this message translates to:
  /// **'I understand'**
  String get resourceInstallAcknowledge;

  /// No description provided for @resourceInstallForce.
  ///
  /// In en, this message translates to:
  /// **'Force install'**
  String get resourceInstallForce;

  /// No description provided for @resourceInstallForceCountdown.
  ///
  /// In en, this message translates to:
  /// **'Force install ({seconds}s)'**
  String resourceInstallForceCountdown(int seconds);

  /// No description provided for @resourceInstallAsSelected.
  ///
  /// In en, this message translates to:
  /// **'Continue as {type}'**
  String resourceInstallAsSelected(Object type);

  /// No description provided for @resourceInstallAsSelectedCountdown.
  ///
  /// In en, this message translates to:
  /// **'Continue as {type} ({seconds}s)'**
  String resourceInstallAsSelectedCountdown(Object type, int seconds);

  /// No description provided for @resourceInstallAsDetected.
  ///
  /// In en, this message translates to:
  /// **'Install as {type}'**
  String resourceInstallAsDetected(Object type);

  /// No description provided for @resourceTypeApp.
  ///
  /// In en, this message translates to:
  /// **'miniprogram'**
  String get resourceTypeApp;

  /// No description provided for @resourceTypeQuickApp.
  ///
  /// In en, this message translates to:
  /// **'quick app'**
  String get resourceTypeQuickApp;

  /// No description provided for @resourceTypeWatchface.
  ///
  /// In en, this message translates to:
  /// **'watchface'**
  String get resourceTypeWatchface;

  /// No description provided for @resourceTypeFirmware.
  ///
  /// In en, this message translates to:
  /// **'firmware'**
  String get resourceTypeFirmware;

  /// No description provided for @resourceInstallConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Install {type}'**
  String resourceInstallConfirmTitle(Object type);

  /// No description provided for @resourceInstallConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Install {fileName} ({fileSize})?'**
  String resourceInstallConfirmMessage(Object fileName, Object fileSize);

  /// No description provided for @resourceInstallConfirm.
  ///
  /// In en, this message translates to:
  /// **'Install'**
  String get resourceInstallConfirm;

  /// No description provided for @previewImages.
  ///
  /// In en, this message translates to:
  /// **'Preview images'**
  String get previewImages;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @submit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get submit;

  /// No description provided for @creatorConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm commit'**
  String get creatorConfirmTitle;

  /// No description provided for @creatorConfirmOronBox.
  ///
  /// In en, this message translates to:
  /// **'Commit to OronBox'**
  String get creatorConfirmOronBox;

  /// No description provided for @creatorConfirmBandBbs.
  ///
  /// In en, this message translates to:
  /// **'Sync to BandBBS: {category}'**
  String creatorConfirmBandBbs(Object category);

  /// No description provided for @creatorConfirmAstroBox.
  ///
  /// In en, this message translates to:
  /// **'Sync to AstroBox: {owner}/{repository}'**
  String creatorConfirmAstroBox(Object owner, Object repository);

  /// No description provided for @creatorBandBbsDirectPublish.
  ///
  /// In en, this message translates to:
  /// **'Sync to BandBBS'**
  String get creatorBandBbsDirectPublish;

  /// No description provided for @creatorBandBbsBoundUpdate.
  ///
  /// In en, this message translates to:
  /// **'Linked · Sync to BandBBS'**
  String get creatorBandBbsBoundUpdate;

  /// No description provided for @creatorBandBbsVersionTitle.
  ///
  /// In en, this message translates to:
  /// **'Version title'**
  String get creatorBandBbsVersionTitle;

  /// No description provided for @creatorBandBbsVersionMessage.
  ///
  /// In en, this message translates to:
  /// **'Update notes'**
  String get creatorBandBbsVersionMessage;

  /// No description provided for @creatorBandBbsVersionPairRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter both a version title and update notes, or leave both empty'**
  String get creatorBandBbsVersionPairRequired;

  /// No description provided for @creatorLinkedSections.
  ///
  /// In en, this message translates to:
  /// **'{count} linked sections'**
  String creatorLinkedSections(int count);

  /// No description provided for @creatorBandBbsBindingIds.
  ///
  /// In en, this message translates to:
  /// **'Section {categoryId} · Resource {resourceId}'**
  String creatorBandBbsBindingIds(Object categoryId, Object resourceId);

  /// No description provided for @creatorAstroBoxBoundSync.
  ///
  /// In en, this message translates to:
  /// **'Linked · Sync to AstroBox'**
  String get creatorAstroBoxBoundSync;

  /// No description provided for @creatorThisCommit.
  ///
  /// In en, this message translates to:
  /// **'This commit'**
  String get creatorThisCommit;

  /// No description provided for @creatorAstroBoxPrPublish.
  ///
  /// In en, this message translates to:
  /// **'Sync to AstroBox · {repository}'**
  String creatorAstroBoxPrPublish(Object repository);

  /// No description provided for @creatorOronBoxRequired.
  ///
  /// In en, this message translates to:
  /// **'Required. Resources are reviewed by OronBox'**
  String get creatorOronBoxRequired;

  /// No description provided for @creatorOpenInOronBox.
  ///
  /// In en, this message translates to:
  /// **'View in OronBox'**
  String get creatorOpenInOronBox;

  /// No description provided for @creatorAstroTagsHint.
  ///
  /// In en, this message translates to:
  /// **'Separate tags with English semicolons ;'**
  String get creatorAstroTagsHint;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @reviewNote.
  ///
  /// In en, this message translates to:
  /// **'Review note'**
  String get reviewNote;

  /// No description provided for @creatorReviewRejected.
  ///
  /// In en, this message translates to:
  /// **'Resource changes requested'**
  String get creatorReviewRejected;

  /// No description provided for @creatorReviewState.
  ///
  /// In en, this message translates to:
  /// **'Review status: {state}'**
  String creatorReviewState(Object state);

  /// No description provided for @creatorOperationWorking.
  ///
  /// In en, this message translates to:
  /// **'Working'**
  String get creatorOperationWorking;

  /// No description provided for @creatorProcessingImage.
  ///
  /// In en, this message translates to:
  /// **'Processing image'**
  String get creatorProcessingImage;

  /// No description provided for @creatorOperationRefreshing.
  ///
  /// In en, this message translates to:
  /// **'Refreshing creator data'**
  String get creatorOperationRefreshing;

  /// No description provided for @creatorOperationCreating.
  ///
  /// In en, this message translates to:
  /// **'Creating resource'**
  String get creatorOperationCreating;

  /// No description provided for @creatorOperationCreatingCollection.
  ///
  /// In en, this message translates to:
  /// **'Creating collection'**
  String get creatorOperationCreatingCollection;

  /// No description provided for @creatorOperationSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving changes'**
  String get creatorOperationSaving;

  /// No description provided for @creatorOperationDeleting.
  ///
  /// In en, this message translates to:
  /// **'Deleting'**
  String get creatorOperationDeleting;

  /// No description provided for @creatorOperationSubmitting.
  ///
  /// In en, this message translates to:
  /// **'Submitting for review'**
  String get creatorOperationSubmitting;

  /// No description provided for @creatorOperationAuthorizing.
  ///
  /// In en, this message translates to:
  /// **'Waiting for authorization'**
  String get creatorOperationAuthorizing;

  /// No description provided for @creatorResolvingPublicationTarget.
  ///
  /// In en, this message translates to:
  /// **'Resolving publication category'**
  String get creatorResolvingPublicationTarget;

  /// No description provided for @creatorStateApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get creatorStateApproved;

  /// No description provided for @creatorStateExternalReview.
  ///
  /// In en, this message translates to:
  /// **'External review'**
  String get creatorStateExternalReview;

  /// No description provided for @creatorStateFailed.
  ///
  /// In en, this message translates to:
  /// **'Publishing failed'**
  String get creatorStateFailed;

  /// No description provided for @creatorStateSuperseded.
  ///
  /// In en, this message translates to:
  /// **'Superseded by a newer revision'**
  String get creatorStateSuperseded;

  /// No description provided for @creatorStateCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get creatorStateCancelled;

  /// No description provided for @creatorNoResources.
  ///
  /// In en, this message translates to:
  /// **'No resources created yet'**
  String get creatorNoResources;

  /// No description provided for @creatorLoginRequiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to use Creator Center'**
  String get creatorLoginRequiredTitle;

  /// No description provided for @creatorLoginRequiredDescription.
  ///
  /// In en, this message translates to:
  /// **'Sign in to BandBBS and connect your OronBox account before creating, editing, or submitting resources'**
  String get creatorLoginRequiredDescription;

  /// No description provided for @creatorLoginAction.
  ///
  /// In en, this message translates to:
  /// **'Sign in to BandBBS'**
  String get creatorLoginAction;

  /// No description provided for @creatorBandBbsWriteReady.
  ///
  /// In en, this message translates to:
  /// **'BandBBS publishing authorized'**
  String get creatorBandBbsWriteReady;

  /// No description provided for @creatorBandBbsWriteMissing.
  ///
  /// In en, this message translates to:
  /// **'BandBBS publishing not authorized'**
  String get creatorBandBbsWriteMissing;

  /// No description provided for @creatorGitHubOwnPublishReady.
  ///
  /// In en, this message translates to:
  /// **'GitHub connected'**
  String get creatorGitHubOwnPublishReady;

  /// No description provided for @creatorGitHubOwnPublishMissing.
  ///
  /// In en, this message translates to:
  /// **'GitHub not connected'**
  String get creatorGitHubOwnPublishMissing;

  /// No description provided for @creatorAuthorize.
  ///
  /// In en, this message translates to:
  /// **'Authorize'**
  String get creatorAuthorize;

  /// No description provided for @installQueueFixWatchfaceId.
  ///
  /// In en, this message translates to:
  /// **'Fix watchface ID'**
  String get installQueueFixWatchfaceId;

  /// No description provided for @installQueueFixWatchfaceIdHint.
  ///
  /// In en, this message translates to:
  /// **'Enter up to 12 digits'**
  String get installQueueFixWatchfaceIdHint;

  /// No description provided for @authorize.
  ///
  /// In en, this message translates to:
  /// **'Authorize'**
  String get authorize;

  /// No description provided for @creatorBandBbsAuthorized.
  ///
  /// In en, this message translates to:
  /// **'BandBBS resource publishing is authorized'**
  String get creatorBandBbsAuthorized;

  /// No description provided for @creatorBandBbsAuthorizationRequired.
  ///
  /// In en, this message translates to:
  /// **'Authorize OronBox separately to publish BandBBS resources on your behalf'**
  String get creatorBandBbsAuthorizationRequired;

  /// No description provided for @connect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connect;

  /// No description provided for @legalAndPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Legal and privacy'**
  String get legalAndPrivacy;

  /// No description provided for @termsTitle.
  ///
  /// In en, this message translates to:
  /// **'Terms and disclaimer'**
  String get termsTitle;

  /// No description provided for @privacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy notice'**
  String get privacyTitle;

  /// No description provided for @resourcePublishingTitle.
  ///
  /// In en, this message translates to:
  /// **'Resource publishing agreement'**
  String get resourcePublishingTitle;

  /// No description provided for @reviewRulesTitle.
  ///
  /// In en, this message translates to:
  /// **'Resource review rules'**
  String get reviewRulesTitle;

  /// No description provided for @joinQqGroup.
  ///
  /// In en, this message translates to:
  /// **'Join QQ Group'**
  String get joinQqGroup;

  /// No description provided for @joinQqGroupDesc.
  ///
  /// In en, this message translates to:
  /// **'Chat with developers and other users for help'**
  String get joinQqGroupDesc;

  /// No description provided for @feedbackTitle.
  ///
  /// In en, this message translates to:
  /// **'Feedback'**
  String get feedbackTitle;

  /// No description provided for @feedbackDesc.
  ///
  /// In en, this message translates to:
  /// **'Submit feedback and view responses'**
  String get feedbackDesc;

  /// No description provided for @reportResource.
  ///
  /// In en, this message translates to:
  /// **'Report resource'**
  String get reportResource;

  /// No description provided for @reportComment.
  ///
  /// In en, this message translates to:
  /// **'Report comment'**
  String get reportComment;

  /// No description provided for @report.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get report;

  /// No description provided for @feedbackSubject.
  ///
  /// In en, this message translates to:
  /// **'Subject'**
  String get feedbackSubject;

  /// No description provided for @feedbackMessage.
  ///
  /// In en, this message translates to:
  /// **'Feedback or issue'**
  String get feedbackMessage;

  /// No description provided for @reportReason.
  ///
  /// In en, this message translates to:
  /// **'Reason for report'**
  String get reportReason;

  /// No description provided for @noFeedback.
  ///
  /// In en, this message translates to:
  /// **'No feedback yet'**
  String get noFeedback;

  /// No description provided for @feedbackProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing'**
  String get feedbackProcessing;

  /// No description provided for @feedbackReplied.
  ///
  /// In en, this message translates to:
  /// **'Replied'**
  String get feedbackReplied;

  /// No description provided for @feedbackOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get feedbackOpen;

  /// No description provided for @feedbackResolved.
  ///
  /// In en, this message translates to:
  /// **'Resolved'**
  String get feedbackResolved;

  /// No description provided for @feedbackDismissed.
  ///
  /// In en, this message translates to:
  /// **'Dismissed'**
  String get feedbackDismissed;

  /// No description provided for @feedbackClosed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get feedbackClosed;

  /// No description provided for @feedbackLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading tickets'**
  String get feedbackLoading;

  /// No description provided for @feedbackNewTicket.
  ///
  /// In en, this message translates to:
  /// **'New ticket'**
  String get feedbackNewTicket;

  /// No description provided for @feedbackYou.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get feedbackYou;

  /// No description provided for @feedbackResolution.
  ///
  /// In en, this message translates to:
  /// **'Resolution'**
  String get feedbackResolution;

  /// No description provided for @feedbackReplyHint.
  ///
  /// In en, this message translates to:
  /// **'Reply to this ticket'**
  String get feedbackReplyHint;

  /// No description provided for @feedbackConversationClosed.
  ///
  /// In en, this message translates to:
  /// **'This ticket is closed and cannot be replied to'**
  String get feedbackConversationClosed;

  /// No description provided for @checkUpdates.
  ///
  /// In en, this message translates to:
  /// **'Check for updates'**
  String get checkUpdates;

  /// No description provided for @updateChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking for updates…'**
  String get updateChecking;

  /// No description provided for @updateCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to check for updates'**
  String get updateCheckFailed;

  /// No description provided for @latestVersionInstalled.
  ///
  /// In en, this message translates to:
  /// **'You are using the latest version'**
  String get latestVersionInstalled;

  /// No description provided for @newVersionAvailable.
  ///
  /// In en, this message translates to:
  /// **'Version {version} is available'**
  String newVersionAvailable(Object version);

  /// No description provided for @oobeWelcomeSlogan.
  ///
  /// In en, this message translates to:
  /// **'A beautiful and fast VelaOS / ZeppOS wearable device manager, built with Flutter'**
  String get oobeWelcomeSlogan;

  /// No description provided for @oobeNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get oobeNext;

  /// No description provided for @oobeBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get oobeBack;

  /// No description provided for @oobeFeatureDevicesTitle.
  ///
  /// In en, this message translates to:
  /// **'Device connection'**
  String get oobeFeatureDevicesTitle;

  /// No description provided for @oobeFeatureDevicesBody.
  ///
  /// In en, this message translates to:
  /// **'Connect and manage VelaOS and ZeppOS wearable devices'**
  String get oobeFeatureDevicesBody;

  /// No description provided for @oobeFeatureResourcesTitle.
  ///
  /// In en, this message translates to:
  /// **'Resource center'**
  String get oobeFeatureResourcesTitle;

  /// No description provided for @oobeFeatureResourcesBody.
  ///
  /// In en, this message translates to:
  /// **'Supports the official OronBox source, AstroBox-Repo, BandBBS, and the Amazfit App Store'**
  String get oobeFeatureResourcesBody;

  /// No description provided for @oobeFeaturePluginsTitle.
  ///
  /// In en, this message translates to:
  /// **'JavaScript plugins'**
  String get oobeFeaturePluginsTitle;

  /// No description provided for @oobeFeaturePluginsBody.
  ///
  /// In en, this message translates to:
  /// **'A high-performance, highly extensible JavaScript plugin system with device interaction'**
  String get oobeFeaturePluginsBody;

  /// No description provided for @oobeFeaturePlatformsTitle.
  ///
  /// In en, this message translates to:
  /// **'Multi-platform'**
  String get oobeFeaturePlatformsTitle;

  /// No description provided for @oobeFeaturePlatformsBody.
  ///
  /// In en, this message translates to:
  /// **'Available on Android, Windows, macOS, Linux, and Web'**
  String get oobeFeaturePlatformsBody;

  /// No description provided for @oobeOpenSourceTitle.
  ///
  /// In en, this message translates to:
  /// **'Fully open source'**
  String get oobeOpenSourceTitle;

  /// No description provided for @oobeOpenSourceBody.
  ///
  /// In en, this message translates to:
  /// **'The OronBox client and server both follow GNU AGPL-3.0 with their complete source code available'**
  String get oobeOpenSourceBody;

  /// No description provided for @oobeAgreementHint.
  ///
  /// In en, this message translates to:
  /// **'Please read and scroll to the bottom'**
  String get oobeAgreementHint;

  /// No description provided for @oobeAgreeCheckbox.
  ///
  /// In en, this message translates to:
  /// **'I have read and agree'**
  String get oobeAgreeCheckbox;

  /// No description provided for @oobeDeclineExit.
  ///
  /// In en, this message translates to:
  /// **'Exit'**
  String get oobeDeclineExit;

  /// No description provided for @oobeDeclineWebHint.
  ///
  /// In en, this message translates to:
  /// **'You must accept the agreements to continue; please close this page'**
  String get oobeDeclineWebHint;

  /// No description provided for @oobeLoginTitle.
  ///
  /// In en, this message translates to:
  /// **'Connect your accounts'**
  String get oobeLoginTitle;

  /// No description provided for @oobeLoginBandBbsDesc.
  ///
  /// In en, this message translates to:
  /// **'Sign in with your BandBBS account to access BandBBS resources and prepare creator services'**
  String get oobeLoginBandBbsDesc;

  /// No description provided for @oobeLoginLocalNote.
  ///
  /// In en, this message translates to:
  /// **'Xiaomi and Amazfit sign-in run entirely on this device; related data is never sent to any third party other than Xiaomi/Amazfit'**
  String get oobeLoginLocalNote;

  /// No description provided for @oobeLoginXiaomiDesc.
  ///
  /// In en, this message translates to:
  /// **'Sign in with your Xiaomi account to sync your bound Xiaomi devices'**
  String get oobeLoginXiaomiDesc;

  /// No description provided for @oobeLoginHuamiDesc.
  ///
  /// In en, this message translates to:
  /// **'Sign in with your Amazfit account to access Amazfit app store resources'**
  String get oobeLoginHuamiDesc;

  /// No description provided for @oobeCdnTesting.
  ///
  /// In en, this message translates to:
  /// **'Testing…'**
  String get oobeCdnTesting;

  /// No description provided for @oobeCdnSelected.
  ///
  /// In en, this message translates to:
  /// **'Best CDN selected'**
  String get oobeCdnSelected;

  /// No description provided for @oobeCdnTitle.
  ///
  /// In en, this message translates to:
  /// **'GitHub CDN Speed Test'**
  String get oobeCdnTitle;

  /// No description provided for @oobeDoneTitle.
  ///
  /// In en, this message translates to:
  /// **'All set'**
  String get oobeDoneTitle;

  /// No description provided for @oobeDoneBody.
  ///
  /// In en, this message translates to:
  /// **'Start exploring OronBox'**
  String get oobeDoneBody;

  /// No description provided for @oobeFinish.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get oobeFinish;

  /// No description provided for @settingsReplayOobe.
  ///
  /// In en, this message translates to:
  /// **'Restart guide'**
  String get settingsReplayOobe;

  /// No description provided for @settingsReplayOobeDesc.
  ///
  /// In en, this message translates to:
  /// **'View the welcome guide and initial setup again'**
  String get settingsReplayOobeDesc;

  /// No description provided for @creatorConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get creatorConnect;

  /// No description provided for @comments.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get comments;

  /// No description provided for @commentEmpty.
  ///
  /// In en, this message translates to:
  /// **'No comments yet'**
  String get commentEmpty;

  /// No description provided for @commentHint.
  ///
  /// In en, this message translates to:
  /// **'Write a comment'**
  String get commentHint;

  /// No description provided for @commentLoginRequired.
  ///
  /// In en, this message translates to:
  /// **'Sign in with BandBBS to comment'**
  String get commentLoginRequired;

  /// No description provided for @commentPending.
  ///
  /// In en, this message translates to:
  /// **'Pending review'**
  String get commentPending;

  /// No description provided for @commentBlocked.
  ///
  /// In en, this message translates to:
  /// **'This comment did not meet the community guidelines'**
  String get commentBlocked;

  /// No description provided for @commentModerationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Comment moderation is temporarily unavailable'**
  String get commentModerationUnavailable;

  /// No description provided for @commentRateLimited.
  ///
  /// In en, this message translates to:
  /// **'You are commenting too quickly'**
  String get commentRateLimited;

  /// No description provided for @commentReplying.
  ///
  /// In en, this message translates to:
  /// **'Reply to comment'**
  String get commentReplying;

  /// No description provided for @loadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get loadMore;

  /// No description provided for @more.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// No description provided for @reply.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get reply;

  /// No description provided for @inbox.
  ///
  /// In en, this message translates to:
  /// **'Inbox'**
  String get inbox;

  /// No description provided for @inboxLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading messages'**
  String get inboxLoading;

  /// No description provided for @inboxEmpty.
  ///
  /// In en, this message translates to:
  /// **'No messages'**
  String get inboxEmpty;

  /// No description provided for @inboxClear.
  ///
  /// In en, this message translates to:
  /// **'Clear messages'**
  String get inboxClear;

  /// No description provided for @inboxClearFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not clear messages. Try again later.'**
  String get inboxClearFailed;

  /// No description provided for @messageUnknownTitle.
  ///
  /// In en, this message translates to:
  /// **'Notification'**
  String get messageUnknownTitle;

  /// No description provided for @messageUnknownBody.
  ///
  /// In en, this message translates to:
  /// **'The notification data is unavailable.'**
  String get messageUnknownBody;

  /// No description provided for @messageCommentRepliedTitle.
  ///
  /// In en, this message translates to:
  /// **'New comment reply'**
  String get messageCommentRepliedTitle;

  /// No description provided for @messageCommentHiddenTitle.
  ///
  /// In en, this message translates to:
  /// **'Comment hidden'**
  String get messageCommentHiddenTitle;

  /// No description provided for @messageCommentHiddenAutomatedBody.
  ///
  /// In en, this message translates to:
  /// **'Your comment did not pass automated moderation and is currently hidden. You can submit an appeal from the message.'**
  String get messageCommentHiddenAutomatedBody;

  /// No description provided for @messageCommentHiddenReviewedBody.
  ///
  /// In en, this message translates to:
  /// **'Your comment was hidden after manual review.'**
  String get messageCommentHiddenReviewedBody;

  /// No description provided for @messageReviewApprovedTitle.
  ///
  /// In en, this message translates to:
  /// **'Resource approved'**
  String get messageReviewApprovedTitle;

  /// No description provided for @messageReviewRejectedTitle.
  ///
  /// In en, this message translates to:
  /// **'Resource needs changes'**
  String get messageReviewRejectedTitle;

  /// No description provided for @messageResourceSuspendedTitle.
  ///
  /// In en, this message translates to:
  /// **'Resource delisted'**
  String get messageResourceSuspendedTitle;

  /// No description provided for @messageResourceFrozenTitle.
  ///
  /// In en, this message translates to:
  /// **'Resource frozen'**
  String get messageResourceFrozenTitle;

  /// No description provided for @messageResourceDeletedTitle.
  ///
  /// In en, this message translates to:
  /// **'Resource deleted'**
  String get messageResourceDeletedTitle;

  /// No description provided for @messageResourceRestoredTitle.
  ///
  /// In en, this message translates to:
  /// **'Resource restored'**
  String get messageResourceRestoredTitle;

  /// No description provided for @messageReportUpdatedTitle.
  ///
  /// In en, this message translates to:
  /// **'Report updated'**
  String get messageReportUpdatedTitle;

  /// No description provided for @messagePluginApprovedTitle.
  ///
  /// In en, this message translates to:
  /// **'Plugin approved'**
  String get messagePluginApprovedTitle;

  /// No description provided for @messagePluginRelistedTitle.
  ///
  /// In en, this message translates to:
  /// **'Plugin relisted'**
  String get messagePluginRelistedTitle;

  /// No description provided for @messagePluginRejectedTitle.
  ///
  /// In en, this message translates to:
  /// **'Plugin needs changes'**
  String get messagePluginRejectedTitle;

  /// No description provided for @messagePluginDelistedTitle.
  ///
  /// In en, this message translates to:
  /// **'Plugin delisted'**
  String get messagePluginDelistedTitle;

  /// No description provided for @messageCollectionApprovedTitle.
  ///
  /// In en, this message translates to:
  /// **'Collection approved'**
  String get messageCollectionApprovedTitle;

  /// No description provided for @messageCollectionRejectedTitle.
  ///
  /// In en, this message translates to:
  /// **'Collection needs changes'**
  String get messageCollectionRejectedTitle;

  /// No description provided for @messageCoinAddedTitle.
  ///
  /// In en, this message translates to:
  /// **'Coins added'**
  String get messageCoinAddedTitle;

  /// No description provided for @messageCoinDeductedTitle.
  ///
  /// In en, this message translates to:
  /// **'Coins deducted'**
  String get messageCoinDeductedTitle;

  /// No description provided for @messageCoinReversedTitle.
  ///
  /// In en, this message translates to:
  /// **'Coin transaction reversed'**
  String get messageCoinReversedTitle;

  /// No description provided for @messageCoinVoteRevokedTitle.
  ///
  /// In en, this message translates to:
  /// **'Coin contribution revoked'**
  String get messageCoinVoteRevokedTitle;

  /// No description provided for @messageAppealOverturnedTitle.
  ///
  /// In en, this message translates to:
  /// **'Appeal accepted'**
  String get messageAppealOverturnedTitle;

  /// No description provided for @messageAppealUpheldTitle.
  ///
  /// In en, this message translates to:
  /// **'Original decision upheld'**
  String get messageAppealUpheldTitle;

  /// No description provided for @messageAppealDismissedTitle.
  ///
  /// In en, this message translates to:
  /// **'Appeal dismissed'**
  String get messageAppealDismissedTitle;

  /// No description provided for @messageAccountBannedTitle.
  ///
  /// In en, this message translates to:
  /// **'Account suspended'**
  String get messageAccountBannedTitle;

  /// No description provided for @messageAccountUnbannedTitle.
  ///
  /// In en, this message translates to:
  /// **'Account suspension lifted'**
  String get messageAccountUnbannedTitle;

  /// No description provided for @messageCreatorFrozenTitle.
  ///
  /// In en, this message translates to:
  /// **'Creator access frozen'**
  String get messageCreatorFrozenTitle;

  /// No description provided for @messageCreatorUnfrozenTitle.
  ///
  /// In en, this message translates to:
  /// **'Creator access restored'**
  String get messageCreatorUnfrozenTitle;

  /// No description provided for @messageRoleChangedTitle.
  ///
  /// In en, this message translates to:
  /// **'Account role changed'**
  String get messageRoleChangedTitle;

  /// No description provided for @messageRoleUser.
  ///
  /// In en, this message translates to:
  /// **'user'**
  String get messageRoleUser;

  /// No description provided for @messageRoleReviewer.
  ///
  /// In en, this message translates to:
  /// **'reviewer'**
  String get messageRoleReviewer;

  /// No description provided for @messageRoleAdministrator.
  ///
  /// In en, this message translates to:
  /// **'administrator'**
  String get messageRoleAdministrator;

  /// No description provided for @messageApprovedBody.
  ///
  /// In en, this message translates to:
  /// **'Your submission passed review.'**
  String get messageApprovedBody;

  /// No description provided for @messageNeedsChangesBody.
  ///
  /// In en, this message translates to:
  /// **'Review found issues that require changes.'**
  String get messageNeedsChangesBody;

  /// No description provided for @messageReasonBody.
  ///
  /// In en, this message translates to:
  /// **'Reason: {reason}'**
  String messageReasonBody(String reason);

  /// No description provided for @messageReviewNoteBody.
  ///
  /// In en, this message translates to:
  /// **'Review note: {note}'**
  String messageReviewNoteBody(String note);

  /// No description provided for @messageStatusChangedBody.
  ///
  /// In en, this message translates to:
  /// **'The status of this item has changed.'**
  String get messageStatusChangedBody;

  /// No description provided for @messageReportStatusBody.
  ///
  /// In en, this message translates to:
  /// **'Report status: {status}'**
  String messageReportStatusBody(String status);

  /// No description provided for @messageCoinAddedBody.
  ///
  /// In en, this message translates to:
  /// **'{amount} coins were added to your account.'**
  String messageCoinAddedBody(String amount);

  /// No description provided for @messageCoinDeductedBody.
  ///
  /// In en, this message translates to:
  /// **'{amount} coins were deducted from your account.'**
  String messageCoinDeductedBody(String amount);

  /// No description provided for @messageCoinVoteRevokedBody.
  ///
  /// In en, this message translates to:
  /// **'Your contribution of {amount} coins to this resource was revoked.'**
  String messageCoinVoteRevokedBody(String amount);

  /// No description provided for @messageAppealOverturnedBody.
  ///
  /// In en, this message translates to:
  /// **'The administrator reversed the original decision.'**
  String get messageAppealOverturnedBody;

  /// No description provided for @messageAppealUpheldBody.
  ///
  /// In en, this message translates to:
  /// **'The original decision remains unchanged after review.'**
  String get messageAppealUpheldBody;

  /// No description provided for @messageAppealDismissedBody.
  ///
  /// In en, this message translates to:
  /// **'The appeal was not accepted.'**
  String get messageAppealDismissedBody;

  /// No description provided for @messageRoleChangedBody.
  ///
  /// In en, this message translates to:
  /// **'Your account role is now {role}.'**
  String messageRoleChangedBody(String role);

  /// No description provided for @cleanMode.
  ///
  /// In en, this message translates to:
  /// **'Feature switches'**
  String get cleanMode;

  /// No description provided for @cleanModeDescription.
  ///
  /// In en, this message translates to:
  /// **'Manage main navigation, community features, and resource sources'**
  String get cleanModeDescription;

  /// No description provided for @cleanPluginsEntry.
  ///
  /// In en, this message translates to:
  /// **'Plugins entry'**
  String get cleanPluginsEntry;

  /// No description provided for @cleanSourceHuamiAppStore.
  ///
  /// In en, this message translates to:
  /// **'Amazfit App Store'**
  String get cleanSourceHuamiAppStore;

  /// No description provided for @announcementAcknowledge.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get announcementAcknowledge;

  /// No description provided for @cleanHomeFeed.
  ///
  /// In en, this message translates to:
  /// **'Home feed'**
  String get cleanHomeFeed;

  /// No description provided for @cleanExplore.
  ///
  /// In en, this message translates to:
  /// **'Resource library'**
  String get cleanExplore;

  /// No description provided for @cleanInbox.
  ///
  /// In en, this message translates to:
  /// **'Inbox'**
  String get cleanInbox;

  /// No description provided for @cleanAnnouncements.
  ///
  /// In en, this message translates to:
  /// **'Announcement popups'**
  String get cleanAnnouncements;

  /// No description provided for @cleanComments.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get cleanComments;

  /// No description provided for @cleanCreator.
  ///
  /// In en, this message translates to:
  /// **'Creator center'**
  String get cleanCreator;

  /// No description provided for @cleanBandBbsLogin.
  ///
  /// In en, this message translates to:
  /// **'BandBBS sign-in'**
  String get cleanBandBbsLogin;

  /// No description provided for @cleanGitHubLogin.
  ///
  /// In en, this message translates to:
  /// **'GitHub sign-in'**
  String get cleanGitHubLogin;

  /// No description provided for @cleanSourceOronBox.
  ///
  /// In en, this message translates to:
  /// **'OronBox source'**
  String get cleanSourceOronBox;

  /// No description provided for @cleanSourceBandBbs.
  ///
  /// In en, this message translates to:
  /// **'BandBBS source'**
  String get cleanSourceBandBbs;

  /// No description provided for @cleanSourceAstroBox.
  ///
  /// In en, this message translates to:
  /// **'AstroBox source'**
  String get cleanSourceAstroBox;

  /// No description provided for @cleanExploreEntry.
  ///
  /// In en, this message translates to:
  /// **'Explore entry'**
  String get cleanExploreEntry;

  /// No description provided for @cleanNavigationGroup.
  ///
  /// In en, this message translates to:
  /// **'Main navigation'**
  String get cleanNavigationGroup;

  /// No description provided for @cleanExploreContentGroup.
  ///
  /// In en, this message translates to:
  /// **'Explore content'**
  String get cleanExploreContentGroup;

  /// No description provided for @cleanHomeSectionsGroup.
  ///
  /// In en, this message translates to:
  /// **'Home sections'**
  String get cleanHomeSectionsGroup;

  /// No description provided for @cleanHomeBanner.
  ///
  /// In en, this message translates to:
  /// **'Banner carousel'**
  String get cleanHomeBanner;

  /// No description provided for @cleanHomeEditorSections.
  ///
  /// In en, this message translates to:
  /// **'Editor sections'**
  String get cleanHomeEditorSections;

  /// No description provided for @cleanResourceSourcesGroup.
  ///
  /// In en, this message translates to:
  /// **'Resource sources'**
  String get cleanResourceSourcesGroup;

  /// No description provided for @cleanCommunityGroup.
  ///
  /// In en, this message translates to:
  /// **'Community features'**
  String get cleanCommunityGroup;

  /// No description provided for @settingsCategoryAccounts.
  ///
  /// In en, this message translates to:
  /// **'Accounts and authorization'**
  String get settingsCategoryAccounts;

  /// No description provided for @settingsCategoryAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance and navigation'**
  String get settingsCategoryAppearance;

  /// No description provided for @settingsCategoryConnection.
  ///
  /// In en, this message translates to:
  /// **'Connections and downloads'**
  String get settingsCategoryConnection;

  /// No description provided for @settingsCategorySupport.
  ///
  /// In en, this message translates to:
  /// **'Support and information'**
  String get settingsCategorySupport;

  /// No description provided for @settingsCategoryAdvanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced settings'**
  String get settingsCategoryAdvanced;

  /// No description provided for @settingsAdvancedDescription.
  ///
  /// In en, this message translates to:
  /// **'View logs and developer tools'**
  String get settingsAdvancedDescription;

  /// No description provided for @debugServerTitle.
  ///
  /// In en, this message translates to:
  /// **'Debug service'**
  String get debugServerTitle;

  /// No description provided for @debugServerDescription.
  ///
  /// In en, this message translates to:
  /// **'Expose a local API for trusted development tools'**
  String get debugServerDescription;

  /// No description provided for @debugServerEnable.
  ///
  /// In en, this message translates to:
  /// **'Enable debug service'**
  String get debugServerEnable;

  /// No description provided for @debugServerEnableDescription.
  ///
  /// In en, this message translates to:
  /// **'Allow approved clients on the local network to inspect and control OronBox'**
  String get debugServerEnableDescription;

  /// No description provided for @debugServerEndpoint.
  ///
  /// In en, this message translates to:
  /// **'Endpoint'**
  String get debugServerEndpoint;

  /// No description provided for @debugServerFingerprint.
  ///
  /// In en, this message translates to:
  /// **'Server fingerprint'**
  String get debugServerFingerprint;

  /// No description provided for @debugServerPendingClients.
  ///
  /// In en, this message translates to:
  /// **'Pending approvals'**
  String get debugServerPendingClients;

  /// No description provided for @debugServerAuthorizedClients.
  ///
  /// In en, this message translates to:
  /// **'Approved clients'**
  String get debugServerAuthorizedClients;

  /// No description provided for @debugServerApprove.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get debugServerApprove;

  /// No description provided for @debugServerReject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get debugServerReject;

  /// No description provided for @debugServerRevoke.
  ///
  /// In en, this message translates to:
  /// **'Revoke access'**
  String get debugServerRevoke;

  /// No description provided for @debugServerNoPendingClients.
  ///
  /// In en, this message translates to:
  /// **'No clients are waiting for approval'**
  String get debugServerNoPendingClients;

  /// No description provided for @debugServerNoAuthorizedClients.
  ///
  /// In en, this message translates to:
  /// **'No approved clients'**
  String get debugServerNoAuthorizedClients;

  /// No description provided for @debugServerSecurityNotice.
  ///
  /// In en, this message translates to:
  /// **'Only enable this service on a trusted network'**
  String get debugServerSecurityNotice;

  /// No description provided for @debugServerStartFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not start the debug service'**
  String get debugServerStartFailed;

  /// No description provided for @debugServerStopFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not stop the debug service'**
  String get debugServerStopFailed;

  /// No description provided for @xmsDeveloperMode.
  ///
  /// In en, this message translates to:
  /// **'XMS developer mode'**
  String get xmsDeveloperMode;

  /// No description provided for @xmsDeveloperModeDescription.
  ///
  /// In en, this message translates to:
  /// **'Allow Android app signatures to differ'**
  String get xmsDeveloperModeDescription;

  /// No description provided for @oronBoxCoinsTitle.
  ///
  /// In en, this message translates to:
  /// **'Resource coins'**
  String get oronBoxCoinsTitle;

  /// No description provided for @oronBoxCoinsBalance.
  ///
  /// In en, this message translates to:
  /// **'Coin balance: {balance}'**
  String oronBoxCoinsBalance(String balance);

  /// No description provided for @oronBoxCoinsCheckin.
  ///
  /// In en, this message translates to:
  /// **'Check in'**
  String get oronBoxCoinsCheckin;

  /// No description provided for @oronBoxCoinsCheckedIn.
  ///
  /// In en, this message translates to:
  /// **'Checked in'**
  String get oronBoxCoinsCheckedIn;

  /// No description provided for @oronBoxCoinsCheckinReward.
  ///
  /// In en, this message translates to:
  /// **'Received {count} coins'**
  String oronBoxCoinsCheckinReward(int count);

  /// No description provided for @oronBoxCoinsDescription.
  ///
  /// In en, this message translates to:
  /// **'Check in daily for 1–5 coins and use them to support creators'**
  String get oronBoxCoinsDescription;

  /// No description provided for @resourceFromCollection.
  ///
  /// In en, this message translates to:
  /// **'From collection {name}'**
  String resourceFromCollection(String name);

  /// No description provided for @resourceCoin.
  ///
  /// In en, this message translates to:
  /// **'Coin'**
  String get resourceCoin;

  /// No description provided for @resourceCoinNotSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Not signed in'**
  String get resourceCoinNotSignedIn;

  /// No description provided for @resourceCoinDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Coin this resource'**
  String get resourceCoinDialogTitle;

  /// No description provided for @resourceCoinDialogMessage.
  ///
  /// In en, this message translates to:
  /// **'Coin this resource?\nThis action cannot be undone\n\nCoins help the resource receive more exposure\nThe creator receives 10% of the contributed amount\nCheck in at Settings - BandBBS account to earn coins'**
  String get resourceCoinDialogMessage;

  /// No description provided for @resourceCoinOne.
  ///
  /// In en, this message translates to:
  /// **'Give 1 coin'**
  String get resourceCoinOne;

  /// No description provided for @resourceCoinTwo.
  ///
  /// In en, this message translates to:
  /// **'Give 2 coins'**
  String get resourceCoinTwo;

  /// No description provided for @resourceCoinCount.
  ///
  /// In en, this message translates to:
  /// **'{count} coins'**
  String resourceCoinCount(int count);

  /// No description provided for @resourceCoinSuccess.
  ///
  /// In en, this message translates to:
  /// **'Coin sent'**
  String get resourceCoinSuccess;

  /// No description provided for @resourceCoinVoted.
  ///
  /// In en, this message translates to:
  /// **'Coined'**
  String get resourceCoinVoted;

  /// No description provided for @resourceFeatured.
  ///
  /// In en, this message translates to:
  /// **'Featured'**
  String get resourceFeatured;

  /// No description provided for @resourceCollection.
  ///
  /// In en, this message translates to:
  /// **'Collection'**
  String get resourceCollection;

  /// No description provided for @resourceCollectionType.
  ///
  /// In en, this message translates to:
  /// **'{type} Collection'**
  String resourceCollectionType(String type);

  /// No description provided for @creatorCollections.
  ///
  /// In en, this message translates to:
  /// **'Resource collections'**
  String get creatorCollections;

  /// No description provided for @creatorCollectionTag.
  ///
  /// In en, this message translates to:
  /// **'Collection'**
  String get creatorCollectionTag;

  /// No description provided for @creatorNewCollection.
  ///
  /// In en, this message translates to:
  /// **'New collection'**
  String get creatorNewCollection;

  /// No description provided for @creatorMoveToCollection.
  ///
  /// In en, this message translates to:
  /// **'Move to collection'**
  String get creatorMoveToCollection;

  /// No description provided for @creatorMoveToCollectionConfirm.
  ///
  /// In en, this message translates to:
  /// **'Move the {count} selected resources into this collection?'**
  String creatorMoveToCollectionConfirm(int count);

  /// No description provided for @creatorDissolveCollection.
  ///
  /// In en, this message translates to:
  /// **'Dissolve collection'**
  String get creatorDissolveCollection;

  /// No description provided for @creatorResourceList.
  ///
  /// In en, this message translates to:
  /// **'Resources'**
  String get creatorResourceList;

  /// No description provided for @creatorAdditionalLinks.
  ///
  /// In en, this message translates to:
  /// **'Additional links'**
  String get creatorAdditionalLinks;

  /// No description provided for @creatorAddLink.
  ///
  /// In en, this message translates to:
  /// **'Add link'**
  String get creatorAddLink;

  /// No description provided for @creatorLinkTitle.
  ///
  /// In en, this message translates to:
  /// **'Link name'**
  String get creatorLinkTitle;

  /// No description provided for @creatorLinkUrl.
  ///
  /// In en, this message translates to:
  /// **'Link URL'**
  String get creatorLinkUrl;

  /// No description provided for @creatorCollectionName.
  ///
  /// In en, this message translates to:
  /// **'Collection name'**
  String get creatorCollectionName;

  /// No description provided for @creatorCollectionSummary.
  ///
  /// In en, this message translates to:
  /// **'Collection summary'**
  String get creatorCollectionSummary;

  /// No description provided for @creatorCollectionRepresentative.
  ///
  /// In en, this message translates to:
  /// **'Representative resource'**
  String get creatorCollectionRepresentative;

  /// No description provided for @creatorCollectionDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this collection? Its resources will only be unlinked.'**
  String get creatorCollectionDeleteConfirm;

  /// No description provided for @creatorContentAttributes.
  ///
  /// In en, this message translates to:
  /// **'Content attributes'**
  String get creatorContentAttributes;

  /// No description provided for @creatorConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get creatorConfirm;

  /// No description provided for @creatorCollectionAddResource.
  ///
  /// In en, this message translates to:
  /// **'Add to collection'**
  String get creatorCollectionAddResource;

  /// No description provided for @creatorCollectionResourceCount.
  ///
  /// In en, this message translates to:
  /// **'{count} resources'**
  String creatorCollectionResourceCount(int count);

  /// No description provided for @communityImportSelected.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String communityImportSelected(int count);

  /// No description provided for @communityImportResultCreated.
  ///
  /// In en, this message translates to:
  /// **'Draft created'**
  String get communityImportResultCreated;

  /// No description provided for @communityImportResultFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get communityImportResultFailed;

  /// No description provided for @communityImportUnsupported.
  ///
  /// In en, this message translates to:
  /// **'This type cannot be imported yet'**
  String get communityImportUnsupported;

  /// No description provided for @communityImportDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Already exists in the creator center'**
  String get communityImportDuplicate;

  /// No description provided for @communityImportNoArtifacts.
  ///
  /// In en, this message translates to:
  /// **'No importable resource files'**
  String get communityImportNoArtifacts;

  /// No description provided for @creatorImportExternal.
  ///
  /// In en, this message translates to:
  /// **'Import existing resources from other platforms'**
  String get creatorImportExternal;

  /// No description provided for @creatorNewResourceDescription.
  ///
  /// In en, this message translates to:
  /// **'Create and maintain a resource from OronBox'**
  String get creatorNewResourceDescription;

  /// No description provided for @creatorNewCollectionDescription.
  ///
  /// In en, this message translates to:
  /// **'Create a collection for related resources'**
  String get creatorNewCollectionDescription;

  /// No description provided for @creatorImportExternalDescription.
  ///
  /// In en, this message translates to:
  /// **'Experimental: import your existing resources from BandBBS or AstroBox-Repo'**
  String get creatorImportExternalDescription;

  /// No description provided for @creatorImportAlreadyImported.
  ///
  /// In en, this message translates to:
  /// **'Imported and linked'**
  String get creatorImportAlreadyImported;

  /// No description provided for @creatorImportReviewNotice.
  ///
  /// In en, this message translates to:
  /// **'Imported content may be incomplete or misidentified. Review and adjust every field before submitting.'**
  String get creatorImportReviewNotice;

  /// No description provided for @creatorImportLogTitle.
  ///
  /// In en, this message translates to:
  /// **'Processing log'**
  String get creatorImportLogTitle;

  /// No description provided for @communityImportPickerEmpty.
  ///
  /// In en, this message translates to:
  /// **'No resources'**
  String get communityImportPickerEmpty;

  /// No description provided for @creatorWizardChooseAction.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get creatorWizardChooseAction;

  /// No description provided for @creatorImportSelectTitle.
  ///
  /// In en, this message translates to:
  /// **'Select resources'**
  String get creatorImportSelectTitle;

  /// No description provided for @creatorImportProgressTitle.
  ///
  /// In en, this message translates to:
  /// **'Importing'**
  String get creatorImportProgressTitle;

  /// No description provided for @creatorImportResultTitle.
  ///
  /// In en, this message translates to:
  /// **'Import result'**
  String get creatorImportResultTitle;

  /// No description provided for @creatorImportGitHubHint.
  ///
  /// In en, this message translates to:
  /// **'Connect GitHub to list your AstroBox resources'**
  String get creatorImportGitHubHint;

  /// No description provided for @creatorImportGitHubConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect GitHub'**
  String get creatorImportGitHubConnect;

  /// No description provided for @creatorImportStageDetails.
  ///
  /// In en, this message translates to:
  /// **'Fetching details'**
  String get creatorImportStageDetails;

  /// No description provided for @creatorImportStageDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading files'**
  String get creatorImportStageDownloading;

  /// No description provided for @creatorImportStageMedia.
  ///
  /// In en, this message translates to:
  /// **'Processing images'**
  String get creatorImportStageMedia;

  /// No description provided for @creatorImportStageUploading.
  ///
  /// In en, this message translates to:
  /// **'Creating draft'**
  String get creatorImportStageUploading;

  /// No description provided for @creatorImportContinue.
  ///
  /// In en, this message translates to:
  /// **'Import another'**
  String get creatorImportContinue;

  /// No description provided for @creatorImportPartialFailureTitle.
  ///
  /// In en, this message translates to:
  /// **'Some resources could not be read'**
  String get creatorImportPartialFailureTitle;

  /// No description provided for @creatorImportPartialFailureMessage.
  ///
  /// In en, this message translates to:
  /// **'{count} resource(s) could not be read\nYou can retry the failed items or continue with the resources that were read successfully'**
  String creatorImportPartialFailureMessage(int count);

  /// No description provided for @creatorImportRetryFailed.
  ///
  /// In en, this message translates to:
  /// **'Retry failed items'**
  String get creatorImportRetryFailed;

  /// No description provided for @creatorImportContinuePartial.
  ///
  /// In en, this message translates to:
  /// **'Continue anyway'**
  String get creatorImportContinuePartial;

  /// No description provided for @creatorImportWarnings.
  ///
  /// In en, this message translates to:
  /// **'{count} warnings'**
  String creatorImportWarnings(int count);

  /// No description provided for @creatorDeleteExternalBandbbs.
  ///
  /// In en, this message translates to:
  /// **'Also delete the BandBBS resources'**
  String get creatorDeleteExternalBandbbs;

  /// No description provided for @creatorDeleteExternalAstrobox.
  ///
  /// In en, this message translates to:
  /// **'Also submit a deletion PR to AstroBox-Repo'**
  String get creatorDeleteExternalAstrobox;

  /// No description provided for @creatorDeleteExternalWarning.
  ///
  /// In en, this message translates to:
  /// **'External deletions cannot be undone'**
  String get creatorDeleteExternalWarning;

  /// No description provided for @creatorDeletePrSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Deletion PR submitted'**
  String get creatorDeletePrSubmitted;

  /// No description provided for @githubCdnFallback.
  ///
  /// In en, this message translates to:
  /// **'GitHub request failed, retrying via {cdn}'**
  String githubCdnFallback(Object cdn);

  /// No description provided for @deviceConnectBle.
  ///
  /// In en, this message translates to:
  /// **'Connect via BLE'**
  String get deviceConnectBle;

  /// No description provided for @deviceConnectBtClassic.
  ///
  /// In en, this message translates to:
  /// **'Connect via BT Classic'**
  String get deviceConnectBtClassic;

  /// No description provided for @bandBbsIdLabel.
  ///
  /// In en, this message translates to:
  /// **'BandBBS ID {id}'**
  String bandBbsIdLabel(Object id);

  /// No description provided for @oobeCdnTestFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get oobeCdnTestFailed;

  /// No description provided for @settingsGithubCdnAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get settingsGithubCdnAuto;

  /// No description provided for @updateDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading update'**
  String get updateDownloading;

  /// No description provided for @updateInstalling.
  ///
  /// In en, this message translates to:
  /// **'Installing update'**
  String get updateInstalling;

  /// No description provided for @updateFailed.
  ///
  /// In en, this message translates to:
  /// **'Update failed'**
  String get updateFailed;

  /// No description provided for @updateNoApkForAbi.
  ///
  /// In en, this message translates to:
  /// **'No APK is available for ABI {abi}'**
  String updateNoApkForAbi(String abi);

  /// No description provided for @cleanUpdateGroup.
  ///
  /// In en, this message translates to:
  /// **'Updates'**
  String get cleanUpdateGroup;

  /// No description provided for @cleanCheckUpdates.
  ///
  /// In en, this message translates to:
  /// **'Check for updates on launch'**
  String get cleanCheckUpdates;

  /// No description provided for @updateLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get updateLater;

  /// No description provided for @updateNow.
  ///
  /// In en, this message translates to:
  /// **'Update now'**
  String get updateNow;

  /// No description provided for @updateGoToPage.
  ///
  /// In en, this message translates to:
  /// **'Go to download page'**
  String get updateGoToPage;

  /// No description provided for @updateDownloadFromCloud.
  ///
  /// In en, this message translates to:
  /// **'Download from cloud drive'**
  String get updateDownloadFromCloud;

  /// No description provided for @updateDownloadFromOfficial.
  ///
  /// In en, this message translates to:
  /// **'Download from official website'**
  String get updateDownloadFromOfficial;

  /// No description provided for @creatorImportNoticeTitle.
  ///
  /// In en, this message translates to:
  /// **'Import existing resources'**
  String get creatorImportNoticeTitle;

  /// No description provided for @creatorImportNoticeMessage.
  ///
  /// In en, this message translates to:
  /// **'Resources supporting multiple devices may be published to multiple BandBBS sections\nYou can select multiple BandBBS entries when importing, but select entries from the same resource\nClick Import to merge the selected entries into one resource\nIf the import fails, open the corresponding draft and delete it\nDeleting a draft will not delete resources linked on other platforms'**
  String get creatorImportNoticeMessage;

  /// No description provided for @creatorImportNoticeConfirm.
  ///
  /// In en, this message translates to:
  /// **'Continue import'**
  String get creatorImportNoticeConfirm;

  /// No description provided for @creatorImportSameResourceHint.
  ///
  /// In en, this message translates to:
  /// **'Select only one resource for each import'**
  String get creatorImportSameResourceHint;

  /// No description provided for @creatorFullVersionExternalPurchase.
  ///
  /// In en, this message translates to:
  /// **'Requires external purchase'**
  String get creatorFullVersionExternalPurchase;

  /// No description provided for @creatorExternalPurchaseDescription.
  ///
  /// In en, this message translates to:
  /// **'OronBox and AstroBox will publish the resource files as a trial version with a purchase button, while BandBBS publishes it as a \"Third-party purchase\" resource. You are responsible for handling payment-related matters yourself'**
  String get creatorExternalPurchaseDescription;

  /// No description provided for @creatorExternalPurchaseLink.
  ///
  /// In en, this message translates to:
  /// **'Purchase link'**
  String get creatorExternalPurchaseLink;

  /// No description provided for @creatorExternalPurchaseAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount (CNY)'**
  String get creatorExternalPurchaseAmount;

  /// No description provided for @creatorExternalPurchaseLinkRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid external purchase link'**
  String get creatorExternalPurchaseLinkRequired;

  /// No description provided for @creatorExternalPurchaseAmountRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid CNY amount'**
  String get creatorExternalPurchaseAmountRequired;

  /// No description provided for @resourcePurchaseFullVersion.
  ///
  /// In en, this message translates to:
  /// **'External purchase'**
  String get resourcePurchaseFullVersion;

  /// No description provided for @creatorBandBbsOverwritePrevious.
  ///
  /// In en, this message translates to:
  /// **'Overwrite previous submission'**
  String get creatorBandBbsOverwritePrevious;

  /// No description provided for @creatorBandBbsOverwritePreviousDescription.
  ///
  /// In en, this message translates to:
  /// **'Create the new version first, then delete the previous BandBBS submission'**
  String get creatorBandBbsOverwritePreviousDescription;

  /// No description provided for @deviceAboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About device'**
  String get deviceAboutTitle;

  /// No description provided for @deviceValueUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Not provided'**
  String get deviceValueUnavailable;

  /// No description provided for @deviceHealthActivityOverview.
  ///
  /// In en, this message translates to:
  /// **'Activity overview'**
  String get deviceHealthActivityOverview;

  /// No description provided for @deviceHealthActiveCalories.
  ///
  /// In en, this message translates to:
  /// **'Active calories'**
  String get deviceHealthActiveCalories;

  /// No description provided for @deviceHealthStanding.
  ///
  /// In en, this message translates to:
  /// **'Standing'**
  String get deviceHealthStanding;

  /// No description provided for @deviceHealthBloodOxygen.
  ///
  /// In en, this message translates to:
  /// **'Blood oxygen'**
  String get deviceHealthBloodOxygen;

  /// No description provided for @deviceHealthStress.
  ///
  /// In en, this message translates to:
  /// **'Stress'**
  String get deviceHealthStress;

  /// No description provided for @deviceHealthVitality.
  ///
  /// In en, this message translates to:
  /// **'Vitality'**
  String get deviceHealthVitality;

  /// No description provided for @deviceHealthWorkout.
  ///
  /// In en, this message translates to:
  /// **'Workouts'**
  String get deviceHealthWorkout;

  /// No description provided for @deviceHealthTodayTotal.
  ///
  /// In en, this message translates to:
  /// **'Today\'s total'**
  String get deviceHealthTodayTotal;

  /// No description provided for @deviceHealthRecordCount.
  ///
  /// In en, this message translates to:
  /// **'records'**
  String get deviceHealthRecordCount;

  /// No description provided for @deviceHealthNoDetailedRange.
  ///
  /// In en, this message translates to:
  /// **'No detailed range'**
  String get deviceHealthNoDetailedRange;

  /// No description provided for @deviceHealthActivityTrend.
  ///
  /// In en, this message translates to:
  /// **'Activity trend'**
  String get deviceHealthActivityTrend;

  /// No description provided for @deviceHealthTrend.
  ///
  /// In en, this message translates to:
  /// **'Trend'**
  String get deviceHealthTrend;

  /// No description provided for @deviceHealthDayView.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get deviceHealthDayView;

  /// No description provided for @deviceHealthWeekView.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get deviceHealthWeekView;

  /// No description provided for @deviceHealthMonthView.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get deviceHealthMonthView;

  /// No description provided for @deviceHealthLatest.
  ///
  /// In en, this message translates to:
  /// **'Latest'**
  String get deviceHealthLatest;

  /// No description provided for @deviceHealthAverage.
  ///
  /// In en, this message translates to:
  /// **'Average'**
  String get deviceHealthAverage;

  /// No description provided for @deviceHealthRange.
  ///
  /// In en, this message translates to:
  /// **'Range'**
  String get deviceHealthRange;

  /// No description provided for @deviceHealthNoSamples.
  ///
  /// In en, this message translates to:
  /// **'No detailed samples'**
  String get deviceHealthNoSamples;

  /// No description provided for @deviceHealthCurrentVitality.
  ///
  /// In en, this message translates to:
  /// **'Current vitality'**
  String get deviceHealthCurrentVitality;

  /// No description provided for @deviceHealthLightIntensity.
  ///
  /// In en, this message translates to:
  /// **'Light intensity'**
  String get deviceHealthLightIntensity;

  /// No description provided for @deviceHealthModerateHighIntensity.
  ///
  /// In en, this message translates to:
  /// **'Moderate to high intensity'**
  String get deviceHealthModerateHighIntensity;

  /// No description provided for @deviceHealthNoSleep.
  ///
  /// In en, this message translates to:
  /// **'No sleep data'**
  String get deviceHealthNoSleep;

  /// No description provided for @deviceHealthNoWorkouts.
  ///
  /// In en, this message translates to:
  /// **'No workout records'**
  String get deviceHealthNoWorkouts;

  /// No description provided for @deviceHealthSleepStages.
  ///
  /// In en, this message translates to:
  /// **'Sleep stages'**
  String get deviceHealthSleepStages;

  /// No description provided for @deviceHealthSleepHrv.
  ///
  /// In en, this message translates to:
  /// **'Sleep HRV'**
  String get deviceHealthSleepHrv;

  /// No description provided for @deviceHealthSleepAwake.
  ///
  /// In en, this message translates to:
  /// **'Awake'**
  String get deviceHealthSleepAwake;

  /// No description provided for @deviceHealthSleepLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get deviceHealthSleepLight;

  /// No description provided for @deviceHealthSleepDeep.
  ///
  /// In en, this message translates to:
  /// **'Deep'**
  String get deviceHealthSleepDeep;

  /// No description provided for @deviceHealthSleepRem.
  ///
  /// In en, this message translates to:
  /// **'REM'**
  String get deviceHealthSleepRem;

  /// No description provided for @deviceHealthSleepNoStages.
  ///
  /// In en, this message translates to:
  /// **'No sleep stage data'**
  String get deviceHealthSleepNoStages;

  /// No description provided for @deviceHealthStepValue.
  ///
  /// In en, this message translates to:
  /// **'{value} steps'**
  String deviceHealthStepValue(Object value);

  /// No description provided for @deviceHealthFeatureDescription.
  ///
  /// In en, this message translates to:
  /// **'View activity, heart rate, blood oxygen, stress, and sleep data'**
  String get deviceHealthFeatureDescription;

  /// No description provided for @weatherSyncTitle.
  ///
  /// In en, this message translates to:
  /// **'Weather sync'**
  String get weatherSyncTitle;

  /// No description provided for @weatherSyncDescription.
  ///
  /// In en, this message translates to:
  /// **'Select a city and sync current weather and forecasts'**
  String get weatherSyncDescription;

  /// No description provided for @weatherAutoSyncTitle.
  ///
  /// In en, this message translates to:
  /// **'Automatically sync weather data'**
  String get weatherAutoSyncTitle;

  /// No description provided for @weatherAutoSyncDescription.
  ///
  /// In en, this message translates to:
  /// **'Automatically synchronize weather data when synchronizing device data'**
  String get weatherAutoSyncDescription;

  /// No description provided for @alarmManagementTitle.
  ///
  /// In en, this message translates to:
  /// **'Alarm management'**
  String get alarmManagementTitle;

  /// No description provided for @alarmManagementDescription.
  ///
  /// In en, this message translates to:
  /// **'Add, edit, enable, or delete device alarms'**
  String get alarmManagementDescription;

  /// No description provided for @findDeviceDescription.
  ///
  /// In en, this message translates to:
  /// **'Make the device vibrate or ring continuously'**
  String get findDeviceDescription;

  /// No description provided for @appOrderTitle.
  ///
  /// In en, this message translates to:
  /// **'App order'**
  String get appOrderTitle;

  /// No description provided for @appOrderDescription.
  ///
  /// In en, this message translates to:
  /// **'Drag to reorder apps in the device launcher'**
  String get appOrderDescription;

  /// No description provided for @appOrderSaved.
  ///
  /// In en, this message translates to:
  /// **'App order saved'**
  String get appOrderSaved;

  /// No description provided for @appOrderReload.
  ///
  /// In en, this message translates to:
  /// **'Reload'**
  String get appOrderReload;

  /// No description provided for @appOrderUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo changes'**
  String get appOrderUndo;

  /// No description provided for @appOrderSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get appOrderSaving;

  /// No description provided for @appOrderSave.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get appOrderSave;

  /// No description provided for @appOrderEmpty.
  ///
  /// In en, this message translates to:
  /// **'The device returned no reorderable apps'**
  String get appOrderEmpty;

  /// No description provided for @appLayoutTitle.
  ///
  /// In en, this message translates to:
  /// **'App layout'**
  String get appLayoutTitle;

  /// No description provided for @appLayoutDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose how the device app list is displayed'**
  String get appLayoutDescription;

  /// No description provided for @appLayoutLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to load app layout'**
  String get appLayoutLoadFailed;

  /// No description provided for @appLayoutList.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get appLayoutList;

  /// No description provided for @appLayoutGrid.
  ///
  /// In en, this message translates to:
  /// **'Grid'**
  String get appLayoutGrid;

  /// No description provided for @appLayoutTextGrid.
  ///
  /// In en, this message translates to:
  /// **'Grid with labels'**
  String get appLayoutTextGrid;

  /// No description provided for @firmwareUpdateDescription.
  ///
  /// In en, this message translates to:
  /// **'Check for updates or install local firmware'**
  String get firmwareUpdateDescription;

  /// No description provided for @deviceAboutDescription.
  ///
  /// In en, this message translates to:
  /// **'View model, system version, storage, and device identifiers'**
  String get deviceAboutDescription;

  /// No description provided for @alarmAdd.
  ///
  /// In en, this message translates to:
  /// **'Add alarm'**
  String get alarmAdd;

  /// No description provided for @alarmEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit alarm'**
  String get alarmEdit;

  /// No description provided for @alarmHour.
  ///
  /// In en, this message translates to:
  /// **'Hour'**
  String get alarmHour;

  /// No description provided for @alarmMinute.
  ///
  /// In en, this message translates to:
  /// **'Minute'**
  String get alarmMinute;

  /// No description provided for @alarmRepeat.
  ///
  /// In en, this message translates to:
  /// **'Repeat'**
  String get alarmRepeat;

  /// No description provided for @alarmOnce.
  ///
  /// In en, this message translates to:
  /// **'Once'**
  String get alarmOnce;

  /// No description provided for @alarmEveryDay.
  ///
  /// In en, this message translates to:
  /// **'Every day'**
  String get alarmEveryDay;

  /// No description provided for @alarmWorkdays.
  ///
  /// In en, this message translates to:
  /// **'Workdays'**
  String get alarmWorkdays;

  /// No description provided for @alarmHolidays.
  ///
  /// In en, this message translates to:
  /// **'Holidays'**
  String get alarmHolidays;

  /// No description provided for @alarmCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get alarmCustom;

  /// No description provided for @alarmLabel.
  ///
  /// In en, this message translates to:
  /// **'Label'**
  String get alarmLabel;

  /// No description provided for @alarmDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete alarm?'**
  String get alarmDeleteTitle;

  /// No description provided for @alarmWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get alarmWeekly;

  /// No description provided for @alarmMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get alarmMonthly;

  /// No description provided for @alarmYearly.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get alarmYearly;

  /// No description provided for @alarmNoRepeat.
  ///
  /// In en, this message translates to:
  /// **'Does not repeat'**
  String get alarmNoRepeat;

  /// No description provided for @alarmCustomDays.
  ///
  /// In en, this message translates to:
  /// **'Week {days}'**
  String alarmCustomDays(Object days);

  /// No description provided for @weekdayMonShort.
  ///
  /// In en, this message translates to:
  /// **'M'**
  String get weekdayMonShort;

  /// No description provided for @weekdayTueShort.
  ///
  /// In en, this message translates to:
  /// **'T'**
  String get weekdayTueShort;

  /// No description provided for @weekdayWedShort.
  ///
  /// In en, this message translates to:
  /// **'W'**
  String get weekdayWedShort;

  /// No description provided for @weekdayThuShort.
  ///
  /// In en, this message translates to:
  /// **'T'**
  String get weekdayThuShort;

  /// No description provided for @weekdayFriShort.
  ///
  /// In en, this message translates to:
  /// **'F'**
  String get weekdayFriShort;

  /// No description provided for @weekdaySatShort.
  ///
  /// In en, this message translates to:
  /// **'S'**
  String get weekdaySatShort;

  /// No description provided for @weekdaySunShort.
  ///
  /// In en, this message translates to:
  /// **'S'**
  String get weekdaySunShort;

  /// No description provided for @weatherCityLabel.
  ///
  /// In en, this message translates to:
  /// **'Sync city'**
  String get weatherCityLabel;

  /// No description provided for @weatherCityHint.
  ///
  /// In en, this message translates to:
  /// **'Enter a city name'**
  String get weatherCityHint;

  /// No description provided for @weatherSyncAction.
  ///
  /// In en, this message translates to:
  /// **'Sync weather'**
  String get weatherSyncAction;

  /// No description provided for @weatherSyncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing…'**
  String get weatherSyncing;

  /// No description provided for @weatherHumidity.
  ///
  /// In en, this message translates to:
  /// **'Humidity'**
  String get weatherHumidity;

  /// No description provided for @weatherWind.
  ///
  /// In en, this message translates to:
  /// **'Wind'**
  String get weatherWind;

  /// No description provided for @weatherAirQuality.
  ///
  /// In en, this message translates to:
  /// **'Air quality'**
  String get weatherAirQuality;

  /// No description provided for @weatherAqiGood.
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get weatherAqiGood;

  /// No description provided for @weatherAqiModerate.
  ///
  /// In en, this message translates to:
  /// **'Moderate'**
  String get weatherAqiModerate;

  /// No description provided for @weatherAqiSensitive.
  ///
  /// In en, this message translates to:
  /// **'Unhealthy for sensitive groups'**
  String get weatherAqiSensitive;

  /// No description provided for @weatherAqiUnhealthy.
  ///
  /// In en, this message translates to:
  /// **'Unhealthy'**
  String get weatherAqiUnhealthy;

  /// No description provided for @weatherAqiVeryUnhealthy.
  ///
  /// In en, this message translates to:
  /// **'Very unhealthy'**
  String get weatherAqiVeryUnhealthy;

  /// No description provided for @weatherAqiHazardous.
  ///
  /// In en, this message translates to:
  /// **'Hazardous'**
  String get weatherAqiHazardous;

  /// No description provided for @weatherUv.
  ///
  /// In en, this message translates to:
  /// **'UV index'**
  String get weatherUv;

  /// No description provided for @weatherPressure.
  ///
  /// In en, this message translates to:
  /// **'Pressure'**
  String get weatherPressure;

  /// No description provided for @weatherNext24Hours.
  ///
  /// In en, this message translates to:
  /// **'Next 24 hours'**
  String get weatherNext24Hours;

  /// No description provided for @weatherNext7Days.
  ///
  /// In en, this message translates to:
  /// **'Next 7 days'**
  String get weatherNext7Days;

  /// No description provided for @weatherDataSource.
  ///
  /// In en, this message translates to:
  /// **'Data source: {source}'**
  String weatherDataSource(Object source);

  /// No description provided for @weatherLevelDirection.
  ///
  /// In en, this message translates to:
  /// **'Level {level} · {direction}'**
  String weatherLevelDirection(Object level, Object direction);

  /// No description provided for @weatherLevelDirectionCompact.
  ///
  /// In en, this message translates to:
  /// **'Level {level} {direction}'**
  String weatherLevelDirectionCompact(Object level, Object direction);

  /// No description provided for @weatherForecastSummary.
  ///
  /// In en, this message translates to:
  /// **'{condition} · Sunrise {sunrise} · Sunset {sunset}'**
  String weatherForecastSummary(
    Object condition,
    Object sunrise,
    Object sunset,
  );

  /// No description provided for @weatherClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get weatherClear;

  /// No description provided for @weatherPartlyCloudy.
  ///
  /// In en, this message translates to:
  /// **'Partly cloudy'**
  String get weatherPartlyCloudy;

  /// No description provided for @weatherCloudy.
  ///
  /// In en, this message translates to:
  /// **'Cloudy'**
  String get weatherCloudy;

  /// No description provided for @weatherLightRain.
  ///
  /// In en, this message translates to:
  /// **'Light rain'**
  String get weatherLightRain;

  /// No description provided for @weatherHeavyRain.
  ///
  /// In en, this message translates to:
  /// **'Heavy rain'**
  String get weatherHeavyRain;

  /// No description provided for @weatherThunderstorm.
  ///
  /// In en, this message translates to:
  /// **'Thunderstorm'**
  String get weatherThunderstorm;

  /// No description provided for @weatherSnow.
  ///
  /// In en, this message translates to:
  /// **'Snow'**
  String get weatherSnow;

  /// No description provided for @weatherFog.
  ///
  /// In en, this message translates to:
  /// **'Fog'**
  String get weatherFog;

  /// No description provided for @weatherUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get weatherUnknown;

  /// No description provided for @weatherUnknownDate.
  ///
  /// In en, this message translates to:
  /// **'Unknown date'**
  String get weatherUnknownDate;

  /// No description provided for @weatherUpdatedAt.
  ///
  /// In en, this message translates to:
  /// **'Updated {time}'**
  String weatherUpdatedAt(Object time);

  /// No description provided for @windNorth.
  ///
  /// In en, this message translates to:
  /// **'N'**
  String get windNorth;

  /// No description provided for @windNorthEast.
  ///
  /// In en, this message translates to:
  /// **'NE'**
  String get windNorthEast;

  /// No description provided for @windEast.
  ///
  /// In en, this message translates to:
  /// **'E'**
  String get windEast;

  /// No description provided for @windSouthEast.
  ///
  /// In en, this message translates to:
  /// **'SE'**
  String get windSouthEast;

  /// No description provided for @windSouth.
  ///
  /// In en, this message translates to:
  /// **'S'**
  String get windSouth;

  /// No description provided for @windSouthWest.
  ///
  /// In en, this message translates to:
  /// **'SW'**
  String get windSouthWest;

  /// No description provided for @windWest.
  ///
  /// In en, this message translates to:
  /// **'W'**
  String get windWest;

  /// No description provided for @windNorthWest.
  ///
  /// In en, this message translates to:
  /// **'NW'**
  String get windNorthWest;

  /// No description provided for @xiaomiScreenshotTitle.
  ///
  /// In en, this message translates to:
  /// **'Device screenshot'**
  String get xiaomiScreenshotTitle;

  /// No description provided for @xiaomiScreenshotDescription.
  ///
  /// In en, this message translates to:
  /// **'Use the wearable\'s key combination to take a screenshot; it will sync here automatically'**
  String get xiaomiScreenshotDescription;

  /// No description provided for @xiaomiScreenshotAction.
  ///
  /// In en, this message translates to:
  /// **'Capture screenshot'**
  String get xiaomiScreenshotAction;

  /// No description provided for @xiaomiScreenshotLoading.
  ///
  /// In en, this message translates to:
  /// **'Capturing screenshot…'**
  String get xiaomiScreenshotLoading;

  /// No description provided for @xiaomiScreenshotEmpty.
  ///
  /// In en, this message translates to:
  /// **'No screenshot yet'**
  String get xiaomiScreenshotEmpty;

  /// No description provided for @xiaomiScreenshotFailed.
  ///
  /// In en, this message translates to:
  /// **'Screenshot failed'**
  String get xiaomiScreenshotFailed;

  /// No description provided for @xiaomiScreenshotSaved.
  ///
  /// In en, this message translates to:
  /// **'Watch screenshot saved to: {path}'**
  String xiaomiScreenshotSaved(Object path);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ja', 'ru', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'zh':
      {
        switch (locale.countryCode) {
          case 'TW':
            return AppLocalizationsZhTw();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
    case 'ru':
      return AppLocalizationsRu();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
