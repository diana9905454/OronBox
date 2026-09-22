// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get homeTab => 'Home';

  @override
  String get exploreTab => 'Explore';

  @override
  String get devicesTab => 'Devices';

  @override
  String get pluginsTab => 'Plugins';

  @override
  String get pluginImport => 'Import plugin';

  @override
  String get pluginInstalled => 'Installed';

  @override
  String get pluginMarket => 'Plugin market';

  @override
  String get pluginMarketUnavailable =>
      'The plugin market is not available yet';

  @override
  String get pluginEmpty => 'No plugins installed';

  @override
  String get pluginSelectHint => 'Select a plugin to view its features';

  @override
  String get pluginFeatures => 'Features';

  @override
  String get pluginDetails => 'Details';

  @override
  String get pluginNoFeatures => 'This plugin has no available features';

  @override
  String get pluginAuthor => 'Author';

  @override
  String get pluginVersion => 'Version';

  @override
  String get pluginApiLevel => 'API level';

  @override
  String get pluginWebsite => 'Website';

  @override
  String get pluginPermissions => 'Permissions';

  @override
  String get pluginInstallConfirmTitle => 'Confirm plugin installation';

  @override
  String get pluginUpdateConfirmTitle => 'Confirm plugin update';

  @override
  String get pluginDeclaredPermissions =>
      'This plugin declares the following permissions:';

  @override
  String get pluginNoPermissions => 'No permissions declared';

  @override
  String get pluginUpToDate => 'Installed and up to date';

  @override
  String get pluginUninstallTitle => 'Uninstall plugin';

  @override
  String get pluginUninstallMessage =>
      'The plugin\'s data will also be removed';

  @override
  String get pluginUpload => 'Upload plugin';

  @override
  String get pluginPublishTitle => 'Publish plugin';

  @override
  String get pluginPublishNew => 'Will be published as a new plugin';

  @override
  String get pluginPublishUpdate =>
      'Will update the published plugin with the same ID';

  @override
  String get pluginTakedown => 'Take down';

  @override
  String get pluginTakedownConfirm =>
      'The plugin will be permanently removed from the market';

  @override
  String get pluginLoginRequired => 'Sign in to upload plugins';

  @override
  String get pluginSubmittedForReview =>
      'Submitted for review. It will be listed once approved';

  @override
  String get pluginStatePending => 'Pending review';

  @override
  String get pluginStateRejected => 'Rejected';

  @override
  String get pluginStateDelisted => 'Delisted';

  @override
  String get pluginLegacyWarningTitle => 'Legacy plugin';

  @override
  String get pluginLegacyWarningMessage =>
      'This is an AstroBox v1 plugin. OronBox will try to run it in compatibility mode, but issues may occur.\nCheck for an updated native OronBox plugin, or ask the author to adapt it';

  @override
  String get settingsTab => 'Settings';

  @override
  String get search => 'Search';

  @override
  String get resourceListView => 'List view';

  @override
  String get resourceGridView => 'Card view';

  @override
  String get refresh => 'Refresh';

  @override
  String get refreshing => 'Refreshing';

  @override
  String get notifications => 'Notifications';

  @override
  String get newlyPublished => 'Newly published';

  @override
  String get resourceLibrary => 'Resource library';

  @override
  String get resourceDetails => 'Resource details';

  @override
  String get resourceCollectionDetails => 'Collection details';

  @override
  String get resourceArticleDetails => 'Article details';

  @override
  String get creatorCenter => 'Creator center';

  @override
  String get creatorNewResource => 'New resource';

  @override
  String get creatorResourceName => 'Resource name';

  @override
  String get creatorResourceSummary => 'Resource summary';

  @override
  String get creatorResourceMetadataRequired =>
      'Resource name and summary are required';

  @override
  String get creatorSubmitValidationFailed =>
      'Please fix the following before submitting';

  @override
  String get creatorPaidType => 'Payment type';

  @override
  String get creatorSaveDraft => 'Save draft';

  @override
  String get creatorAddArtifact => 'Add resource file';

  @override
  String get creatorBindDevices => 'Bind devices';

  @override
  String get creatorDeleteResource => 'Delete';

  @override
  String get creatorIconCover => 'Icon & cover';

  @override
  String get creatorInvalidImage =>
      'Unable to decode this image; use PNG/JPEG/WebP';

  @override
  String get creatorInvalidPackage =>
      'This file is not a Vela quick app or watchface';

  @override
  String creatorPublishPreparing(Object done, Object total) {
    return 'Processing file $done/$total';
  }

  @override
  String creatorPublishUploading(Object percent) {
    return 'Uploading $percent%';
  }

  @override
  String get creatorPublishServer => 'Server is processing…';

  @override
  String get creatorAstroBoxItemId => 'Item ID';

  @override
  String get creatorAstroBoxRepository => 'Repository name';

  @override
  String get creatorAstroBoxTags => 'Tags (comma separated)';

  @override
  String get creatorAstroBoxAuthor =>
      'Author (must match your AstroBox username)';

  @override
  String get creatorAstroBoxBindAccount => 'Bind AstroBox account';

  @override
  String get replace => 'Replace';

  @override
  String get delete => 'Delete';

  @override
  String get creatorSubmitReview => 'Submit';

  @override
  String get creatorArchiveAction => 'Delist';

  @override
  String get creatorArchiveConfirm =>
      'Delisting hides this resource from the store. You can restore it anytime.';

  @override
  String get creatorRestoreAction => 'Relist';

  @override
  String get creatorDeleteConfirm =>
      'This draft resource will be permanently deleted.';

  @override
  String get creatorDeletePublishedConfirm =>
      'Permanently deletes the OronBox resource and the corresponding BandBBS resources. This cannot be undone. Content already published on AstroBox is not affected; contact the AstroBox-Repo maintainers to delist it.';

  @override
  String creatorArtifactCount(Object count) {
    return '$count packages';
  }

  @override
  String creatorKindMismatchMessage(Object detected, Object expected) {
    return 'This file looks like a $detected, but this resource is a $expected. You can keep it, but please confirm before submitting for review.';
  }

  @override
  String creatorDeviceMoveBlocked(Object name) {
    return '\"$name\" has only this device bound and cannot be moved';
  }

  @override
  String get creatorSelectDevices => 'Select supported devices';

  @override
  String creatorSelectedDeviceCount(Object count) {
    return '$count devices selected';
  }

  @override
  String get creatorNoDevicesSelected => 'No devices selected';

  @override
  String get creatorDeviceSelectionDone => 'Done';

  @override
  String get creatorAtLeastOneDevice =>
      'Each resource file must bind at least one device';

  @override
  String get resourceAstroBoxEncryptedTitle =>
      'OronBox cannot process this AstroBox resource';

  @override
  String get resourceAstroBoxEncryptedMessage =>
      'This resource uses AstroBox Creator Console\'s private encrypted upload. OronBox cannot decrypt, download, or install it. Please open it with AstroBox instead.';

  @override
  String get resourceAstroBoxEncryptedAction => 'Got it';

  @override
  String get filter => 'Filter';

  @override
  String get resourceTypeFilter => 'Resource type';

  @override
  String get resourceCompatibleDevicesFilter => 'Compatible devices';

  @override
  String get currentDevice => 'Current device';

  @override
  String get currentWatchface => 'Current watchface';

  @override
  String get all => 'All';

  @override
  String get watchfaces => 'Watchface';

  @override
  String get module => 'Module';

  @override
  String get quickApps => 'Quickapps';

  @override
  String get firmwareTools => 'Firmware / Tools';

  @override
  String get oronBox => 'OronBox';

  @override
  String get bandbbs => 'BandBBS';

  @override
  String get astroBox => 'AstroBox';

  @override
  String get local => 'Local';

  @override
  String get install => 'Install';

  @override
  String get update => 'Update';

  @override
  String get description => 'Description';

  @override
  String get supportedDevices => 'Supported devices';

  @override
  String get downloads => 'Downloads';

  @override
  String downloadTimes(int count) {
    return '$count downloads';
  }

  @override
  String get changelog => 'Changelog';

  @override
  String get changelogUnavailable => 'No changelog yet';

  @override
  String get notFound => 'Not found';

  @override
  String get downloadStarted => 'Download started';

  @override
  String get compatible => 'Compatible with';

  @override
  String get incompatible => 'Incompatible with';

  @override
  String get incompatibleSuffix => '';

  @override
  String get myResources => 'My resources';

  @override
  String get drafts => 'Drafts';

  @override
  String get pendingReview => 'Pending review';

  @override
  String get published => 'Published';

  @override
  String get creatorStateSuspended => 'Delisted';

  @override
  String get creatorStateFrozen => 'Frozen';

  @override
  String get creatorSuspendedByOwnerNotice =>
      'The resource is delisted. Keep editing and resubmit for review, or restore it directly';

  @override
  String get creatorSuspendedByAdminNotice =>
      'An administrator delisted this resource. Edit and resubmit for review; it is restored once approved';

  @override
  String get creatorFrozenNotice =>
      'An administrator froze this resource. It can no longer be edited and only an administrator can lift the freeze';

  @override
  String creatorModerationReason(Object reason) {
    return 'Reason: $reason';
  }

  @override
  String get creatorBannedTitle => 'Account banned';

  @override
  String get creatorBannedDescription =>
      'Your account was banned by an administrator and the creator center is unavailable. Contact the team through a support ticket if you believe this is a mistake';

  @override
  String get creatorFrozenTitle => 'Creator capability frozen';

  @override
  String get creatorFrozenDescription =>
      'An administrator froze your creator capability, so you cannot submit or manage resources for now. The rest of your account is unaffected';

  @override
  String get creatorBandBbsNoDevices =>
      'Select supported devices for the resource file first';

  @override
  String creatorBandBbsUnmappedDevices(Object devices) {
    return 'No BandBBS category could be resolved for: $devices';
  }

  @override
  String get creatorBandBbsSharedCategory =>
      'Devices in the same BandBBS category are bound to multiple packages. Bind one package per category';

  @override
  String get creatorBandBbsUnresolved => 'Unable to resolve a BandBBS category';

  @override
  String get creatorOptionalIcon => 'Icon (optional, 1:1)';

  @override
  String get creatorOptionalCover => 'Cover (optional, 3:2)';

  @override
  String get creatorRequiredIcon => 'Icon (required for AstroBox, 1:1)';

  @override
  String get creatorRequiredCover => 'Cover (required for AstroBox, 3:2)';

  @override
  String get creatorIconShapeHint =>
      'The icon is not square and may look wrong in AstroBox';

  @override
  String get creatorCoverShapeHint =>
      'The cover is not 3:2 and may look wrong in AstroBox';

  @override
  String get creatorTermsBandBbs => 'BandBBS community terms and rules';

  @override
  String get creatorTermsAstroBox => 'AstroBox-Repo submission standards';

  @override
  String get creatorTermsAccept =>
      'I have read and accept the publishing agreements above';

  @override
  String get creatorTermsContinue => 'Enter Creator Center';

  @override
  String get agree => 'Agree';

  @override
  String get creatorRulesAccept =>
      'I have read and agree to the review rules above';

  @override
  String get creatorBandBbsTermsNotice =>
      'After OronBox review, this resource is published directly to the matching BandBBS categories. Deleting the OronBox resource also deletes the corresponding BandBBS resources.';

  @override
  String get creatorBandBbsLimitsNotice =>
      'One-click publishing to BandBBS has the following limitations, which must be fixed manually after publishing:\n1. BandBBS provides no API to upload the resource icon, so the icon will appear blank on BandBBS; please update it manually on the BandBBS site\n2. BandBBS provides no API for discussion-forum tags, so the resource\'s forum attributes will not be set, which may get the resource removed; please set the correct forum manually on the BandBBS site';

  @override
  String get creatorAstroBoxTermsNotice =>
      'After OronBox review, a resource repository is created and a PR is submitted to the official AstroBox repository, reviewed independently by AstroBox maintainers. To delist after publication, contact the AstroBox-Repo maintainers.';

  @override
  String get creatorAstroBoxReviewNotice =>
      'Resources published to AstroBox must meet the review requirements:\n1. The resource must not contain obscene, politically sensitive or otherwise illegal content\n2. The resource quality must not be too low, e.g. a watchface made by merely swapping a template, or an overly simple quickapp\n3. The cover should be attractive and aesthetically pleasing, with a 3:2 ratio (recommended 1200x800); icon recommended 192x192\n4. The resource must run its basic functions properly on supported devices\n5. Uploading others\' resources without authorization is forbidden\n6. When using well-known IP assets, the preview must include a copyright notice image (stating the assets are unrelated to AstroBox and Xiaomi)';

  @override
  String get failed => 'Failed / Needs action';

  @override
  String get basicInfo => 'Basic info';

  @override
  String get packageFiles => 'Resource files';

  @override
  String get publishTargets => 'Publish targets';

  @override
  String get scan => 'Scan';

  @override
  String get logs => 'Logs';

  @override
  String get pairedDevices => 'Paired devices';

  @override
  String get apps => 'Apps';

  @override
  String get deviceAppCount => 'App count';

  @override
  String get deviceWatchfaceCount => 'Watchface count';

  @override
  String get connection => 'Connection';

  @override
  String get protocol => 'Protocol';

  @override
  String get error => 'Error';

  @override
  String get errorBluetoothUnavailable =>
      'Bluetooth is not available. Check that Bluetooth is enabled and OronBox has permission to use it';

  @override
  String get errorBluetoothConnectFailed =>
      'Connection failed. Check Bluetooth permission, keep the device nearby and not in use, enable Connect new phone on the device, then try again';

  @override
  String get errorBluetoothDisconnected =>
      'Bluetooth disconnected. Reconnect the device and try again';

  @override
  String get errorOperationTimeout =>
      'Operation timed out. Make sure the device is still nearby and try again';

  @override
  String get errorDeviceNotReady =>
      'Device is not ready. Connect and authenticate the device first';

  @override
  String get errorBleCharacteristicsMissing =>
      'Required BLE channels were not found. Reconnect the device or check whether it supports this feature';

  @override
  String get errorWebSerialUnavailable =>
      'This browser does not support Web Serial. Use Chrome, Edge, or another Web Serial compatible browser';

  @override
  String get errorAccountPasswordIncorrect =>
      'Xiaomi account username or password is incorrect';

  @override
  String get errorAccountTwoFactorIncomplete =>
      'Xiaomi account two-factor verification was not completed. Sign in again';

  @override
  String get errorXiaomiAccountSessionExpired =>
      'Your Xiaomi account session has expired. Sign in again';

  @override
  String get errorOronBoxSessionExpired =>
      'Your OronBox session has expired. Sign in to BandBBS again';

  @override
  String get errorNetworkUnavailable =>
      'Unable to reach the service. Check your network and try again';

  @override
  String get errorServiceUnavailable =>
      'The service is temporarily unavailable. Try again later';

  @override
  String get errorPermissionDenied =>
      'You do not have permission to perform this operation';

  @override
  String get errorContentNotFound =>
      'The requested content no longer exists or is unavailable';

  @override
  String get errorRequestConflict =>
      'The content has changed. Refresh it and try again';

  @override
  String get errorCoinBalanceInsufficient => 'You do not have enough coins';

  @override
  String get errorCoinResourceLimit =>
      'You can give at most 2 coins to this resource';

  @override
  String get errorCoinOwnResource => 'You cannot coin your own resource';

  @override
  String get errorCoinVotingFrozen => 'Coin voting is currently frozen';

  @override
  String get errorCoinAccountTooNew =>
      'Your account must be at least 24 hours old to give coins';

  @override
  String get errorCoinOperationFailed =>
      'The coin could not be sent. Try again';

  @override
  String get errorCoinStatusUnavailable =>
      'Coin status is unavailable. Tap to retry';

  @override
  String get errorOperationFailed => 'The operation failed. Try again';

  @override
  String get errorUnknown => 'Something went wrong. Try again';

  @override
  String get errorDownloadQuotaExceeded =>
      'Today\'s download limit has been reached';

  @override
  String get errorGitHubNotConfigured => 'GitHub publishing is not configured';

  @override
  String get errorRateLimited =>
      'Too many requests. Wait a moment and try again';

  @override
  String get errorFileTooLarge => 'The selected file is too large';

  @override
  String get errorInvalidRequest =>
      'Some submitted information is invalid. Check it and try again';

  @override
  String get errorOperationCancelled => 'Operation cancelled';

  @override
  String get errorUnsupportedFileType =>
      'Unsupported or unrecognized file type';

  @override
  String get errorCertificateVerificationFailed =>
      'Certificate verification failed. If you are using a proxy, disable HTTPS interception for this app or make sure its certificate is trusted';

  @override
  String errorUnknownWithDetail(Object detail) {
    return 'Operation failed: $detail';
  }

  @override
  String get appearance => 'Appearance';

  @override
  String get resources => 'Resources';

  @override
  String get communitySourceAstroBoxRepo => 'AstroBox';

  @override
  String get communitySourceBandBbs => 'BandBBS Community';

  @override
  String get communitySourceHuamiAppStore => 'Amazfit App Store';

  @override
  String get devices => 'Devices';

  @override
  String creatorCompatibleDeviceCount(int count) {
    return '$count devices';
  }

  @override
  String get categories => 'Categories';

  @override
  String get advanced => 'Advanced';

  @override
  String get openSourceLicenses => 'Open source licenses';

  @override
  String get acknowledgements => 'Special Acknowledgements';

  @override
  String get deviceNotConnected => 'Not connected';

  @override
  String get deviceConnected => 'Connected';

  @override
  String get deviceDisconnected => 'Disconnected';

  @override
  String get deviceReconnect => 'Reconnect';

  @override
  String get deviceConnect => 'Connect';

  @override
  String get deviceSwitch => 'Switch';

  @override
  String get deviceSyncTime => 'Sync';

  @override
  String get deviceCharging => 'Charging';

  @override
  String get deviceLastChargedNow => 'Charged just now';

  @override
  String deviceLastChargedMinutes(int count) {
    return 'Charged $count min ago';
  }

  @override
  String deviceLastChargedHours(int count) {
    return 'Charged $count hr ago';
  }

  @override
  String deviceLastChargedDays(int count) {
    return 'Charged $count days ago';
  }

  @override
  String get deviceFeaturesInstallApp => 'Install app';

  @override
  String get deviceFeaturesInstallWatchface => 'Install watchface';

  @override
  String get deviceFeaturesInstallFirmware => 'Firmware update';

  @override
  String get deviceFeaturesInstallFirmwareDesc =>
      'Check for device updates or install local firmware';

  @override
  String get firmwareCheckingUpdates => 'Checking for firmware updates';

  @override
  String get firmwareNoUpdatesFound =>
      'No newer firmware was found for this device';

  @override
  String get firmwareSourceUnavailable =>
      'An online firmware source is not yet available for this device type';

  @override
  String get firmwareVersionUnknown => 'Current firmware version unavailable';

  @override
  String get firmwareCurrentVersion => 'Current version';

  @override
  String get firmwareLatestRelease => 'Latest firmware';

  @override
  String get firmwareHistoricalReleases => 'Historical firmware';

  @override
  String get firmwareUpToDate => 'Your firmware is up to date';

  @override
  String get firmwareUpdateAvailable => 'An update is available';

  @override
  String get firmwareDownloadLatestFull => 'Download latest full package';

  @override
  String get firmwareUpdateNow => 'Update';

  @override
  String get firmwareReleaseNotes => 'Release notes';

  @override
  String get firmwareReleaseNotesUnavailable => 'No release notes available';

  @override
  String get download => 'Download';

  @override
  String get downloadTaskAdded => 'Added to the download queue';

  @override
  String get zeppOsMoreFeatures => 'Special features';

  @override
  String get zeppOsMoreFeaturesDescription =>
      'Manage additional features for Zepp OS devices';

  @override
  String get zeppOsDeviceFeaturesSection => 'Device features';

  @override
  String get zeppOsAppsAndDevelopmentSection => 'Apps and development';

  @override
  String get zeppOsAssistant => 'Voice lab';

  @override
  String get zeppOsAssistantDescription =>
      'Capture, monitor, and reply to watch voice assistant sessions';

  @override
  String get zeppOsScreenMirror => 'Screen mirroring';

  @override
  String get zeppOsScreenMirrorDescription =>
      'View the watch screen on this device';

  @override
  String get zeppOsScreenMirrorSemantics => 'Zepp OS watch screen mirror';

  @override
  String zeppOsScreenMirrorUnsupported(Object error) {
    return 'This screen format cannot be displayed: $error';
  }

  @override
  String get expand => 'Expand';

  @override
  String get collapse => 'Collapse';

  @override
  String get voiceLabTitle => 'Voice lab';

  @override
  String get voiceLabXiaoAi => 'XiaoAI';

  @override
  String get voiceLabReceivingAudio => 'Receiving audio from the watch';

  @override
  String get voiceLabWaiting => 'Waiting for a voice session';

  @override
  String get voiceLabContinuousCapture => 'Continuous capture';

  @override
  String get voiceLabContinuousCaptureDescription =>
      'Request the next recording when the current one ends';

  @override
  String get voiceLabDisableMonitoring => 'Disable live monitoring';

  @override
  String get voiceLabEnableMonitoring => 'Enable live monitoring';

  @override
  String get voiceLabReplyLabel => 'Reply sent to the watch';

  @override
  String get voiceLabReplyHint => 'Enter a reply';

  @override
  String get voiceLabReplyQueued =>
      'Reply queued until the current recording ends';

  @override
  String get voiceLabReplySent => 'Reply sent to the watch';

  @override
  String get voiceLabCapturedData => 'Captured data';

  @override
  String get voiceLabDecoder => 'Decoder';

  @override
  String get voiceLabOpusFrames => 'Opus frames';

  @override
  String get voiceLabDataSize => 'Data size';

  @override
  String get voiceLabPcmSamples => 'PCM samples';

  @override
  String get voiceLabExportOpus => 'Export Opus';

  @override
  String get voiceLabExportWav => 'Export WAV';

  @override
  String get voiceLabClearCapture => 'Clear captured data';

  @override
  String get voiceLabSaveRecording => 'Save voice recording';

  @override
  String get voiceLabSaveOpus => 'Save Opus audio';

  @override
  String get voiceLabAudioProcessingFailedPrefix => 'Audio processing failed';

  @override
  String voiceLabAudioProcessingFailed(Object error) {
    return 'Audio processing failed: $error';
  }

  @override
  String voiceLabContinuousCaptureFailed(Object error) {
    return 'Could not configure continuous capture: $error';
  }

  @override
  String voiceLabAssistantSwitchFailed(Object error) {
    return 'Could not switch voice assistant: $error';
  }

  @override
  String voiceLabExportWavFailed(Object error) {
    return 'Could not export WAV: $error';
  }

  @override
  String voiceLabExportOpusFailed(Object error) {
    return 'Could not export Opus: $error';
  }

  @override
  String get send => 'Send';

  @override
  String sendFailed(Object error) {
    return 'Could not send: $error';
  }

  @override
  String get ready => 'Ready';

  @override
  String get initializing => 'Initializing';

  @override
  String get zeppOsMapSelectPackage => 'Select a Zepp OS map package';

  @override
  String get zeppOsMapReadFailed => 'Could not read the map package';

  @override
  String get zeppOsMapTransferTitle => 'Transfer offline map';

  @override
  String zeppOsMapGarminDetected(Object fileName, Object mapName) {
    return '$fileName\nDetected a single-file Garmin IMG map: $mapName';
  }

  @override
  String get zeppOsMapGarminNoPreview =>
      'This map does not contain a Zepp OS 11/x/y tile tree. The original IMG will be transferred as a single-file map package, so a coverage preview is unavailable.';

  @override
  String zeppOsMapTileSummary(Object fileName, Object count) {
    return '$fileName · $count tiles\nThe preview shows package coverage, not the Garmin IMG rendering on the watch.';
  }

  @override
  String get zeppOsMapStartTransfer => 'Start transfer';

  @override
  String get zeppOsMapTransferringBluetooth => 'Transferring over Bluetooth';

  @override
  String get zeppOsMapTransferComplete => 'Offline map transfer complete';

  @override
  String get zeppOsMapConversionFailed => 'Map could not be converted safely';

  @override
  String get zeppOsMapBtClassicHint =>
      'BT Classic bulk transfer is active. After transfer starts, confirm the installation on the watch.';

  @override
  String get zeppOsMapBleHint =>
      'BLE supports map packages up to 2 MB. Switch to BT Classic before transferring a larger map. After transfer starts, confirm the installation on the watch.';

  @override
  String get zeppOsMapPreviewTooLarge =>
      'The map area is too large to preview in full';

  @override
  String zeppOsSettingPageLoadFailed(Object error) {
    return 'Could not load the settings page: $error';
  }

  @override
  String zeppOsAppCompatibilitySaved(Object appId) {
    return 'Compatibility files saved for $appId';
  }

  @override
  String zeppOsAppStorageSaved(Object appId) {
    return 'settingsStorage saved for $appId';
  }

  @override
  String get zeppOsAppSupplementFiles => 'Add app-side or setting files';

  @override
  String get zeppOsAppSupplementCompatibility =>
      'Add mini-app compatibility files';

  @override
  String get zeppOsAppReplaceCompatibility =>
      'Add or replace compatibility files';

  @override
  String get zeppOsAppSideAvailable => 'app-side ✓';

  @override
  String get zeppOsAppSideMissing => 'app-side missing';

  @override
  String get zeppOsSettingAvailable => 'setting ✓';

  @override
  String get zeppOsSettingMissing => 'setting missing';

  @override
  String get zeppOsAppEditStorage => 'Edit settingsStorage';

  @override
  String get zeppOsStorageKeyRequired => 'Key is required';

  @override
  String zeppOsStorageDuplicateKey(Object key) {
    return 'Duplicate key: $key';
  }

  @override
  String get zeppOsStorageDescription =>
      'This data is shared by the setting page and app-side, and is stored as strings according to the Zepp OS specification.';

  @override
  String get zeppOsStorageEmpty => 'No stored entries';

  @override
  String get zeppOsStorageKey => 'Key';

  @override
  String get zeppOsStorageValue => 'Value';

  @override
  String get clear => 'Clear';

  @override
  String get save => 'Save';

  @override
  String get selectedFileReadFailed => 'Could not read the selected file';

  @override
  String get zeppOsAppInvalidHexId => 'Enter a valid hexadecimal App ID';

  @override
  String get zeppOsAppSelectCompatibilityFile =>
      'Select at least one app-side.js or setting.js file';

  @override
  String get zeppOsAppHexId => 'App ID (hexadecimal)';

  @override
  String get optionalDisplayName => 'Display name (optional)';

  @override
  String get zeppOsAppSideUnchanged => 'Keep existing app-side';

  @override
  String get zeppOsSettingUnchanged => 'Keep existing setting';

  @override
  String get selectFile => 'Select file';

  @override
  String get zeppOsAppCompatibilityOverwriteHint =>
      'Saving replaces compatibility files with the same name for this App ID, but does not modify the mini app on the watch.';

  @override
  String zeppOsDebugRefreshFailed(Object error) {
    return 'Automatic refresh failed: $error';
  }

  @override
  String get zeppOsDebugInvalidHex =>
      'HEX must contain complete bytes separated by spaces, line breaks, 0x, commas, or similar separators';

  @override
  String get zeppOsDebugClearEventsTitle => 'Clear events for the current app?';

  @override
  String zeppOsDebugClearEventsDescription(Object appId) {
    return 'All debug events for $appId will be cleared.';
  }

  @override
  String get zeppOsDebugClearEvents => 'Clear events';

  @override
  String get zeppOsDebugRefresh => 'Refresh status and events';

  @override
  String get zeppOsDebugAppList => 'App-side list';

  @override
  String get zeppOsDebugNoApps =>
      'No cached scripts or watch app-side sessions have been detected.';

  @override
  String get zeppOsDebugCached => 'Cached';

  @override
  String get zeppOsDebugNotCached => 'Not cached';

  @override
  String get zeppOsDebugRuntimeRunning => 'runtime running';

  @override
  String get zeppOsDebugRuntimeStopped => 'runtime stopped';

  @override
  String get zeppOsDebugLocalRuntime => 'Local runtime';

  @override
  String get zeppOsDebugCannotStart =>
      'This App ID has no cached script and cannot be started locally.';

  @override
  String get zeppOsDebugCanStart =>
      'The cached script can be started manually without fabricating watch session parameters.';

  @override
  String get zeppOsDebugScriptRunning =>
      'The script is running in local QuickJS.';

  @override
  String get zeppOsDebugStartQuickJs => 'Start QuickJS';

  @override
  String get stop => 'Stop';

  @override
  String get zeppOsDebugMessageEditor => 'Message editor';

  @override
  String get zeppOsDebugUtf8Text => 'UTF-8 text';

  @override
  String get zeppOsDebugJsonCompact => 'JSON (compacted before sending)';

  @override
  String get zeppOsDebugHexBytes => 'HEX bytes';

  @override
  String get zeppOsDebugEncodingFailed =>
      'The current content cannot be encoded in the selected mode';

  @override
  String get zeppOsDebugByteCountUnavailable => 'Bytes: --';

  @override
  String zeppOsDebugBytePreview(Object count, Object hex) {
    return 'Bytes: $count\nHEX: $hex';
  }

  @override
  String get zeppOsDebugInjectLocal =>
      'Inject inbound message into local runtime';

  @override
  String get zeppOsDebugSendToWatch => 'Send to watch';

  @override
  String get zeppOsDebugWaitingForWatch =>
      'Send to watch (waiting for a real session)';

  @override
  String get zeppOsDebugEvents => 'Debug events';

  @override
  String get zeppOsDebugClearCurrentApp => 'Clear current app';

  @override
  String get zeppOsDebugSearch => 'Search type, message, HEX, or readable text';

  @override
  String get zeppOsDebugWatchOnly => 'Real watch messages only';

  @override
  String get zeppOsDebugNoEvents => 'No events match the current filters';

  @override
  String get zeppOsDebugMessageActions => 'Message actions';

  @override
  String get zeppOsDebugLoadEditor => 'Load in editor';

  @override
  String get zeppOsDebugCopyHex => 'Copy HEX';

  @override
  String get zeppOsDebugCopyText => 'Copy text';

  @override
  String get zeppOsDebugSessionStatus => 'Runtime and session status';

  @override
  String zeppOsDebugCachedScript(Object status) {
    return 'Cached script: $status';
  }

  @override
  String zeppOsDebugLocalRuntimeStatus(Object status) {
    return 'Local runtime: $status';
  }

  @override
  String zeppOsDebugWatchSession(Object status) {
    return 'Watch session: $status';
  }

  @override
  String get exists => 'Available';

  @override
  String get notExists => 'Unavailable';

  @override
  String get running => 'Running';

  @override
  String get notRunning => 'Not running';

  @override
  String get notOpen => 'Not open';

  @override
  String get zeppOsDebugWatchSessionOpen => 'Real session open';

  @override
  String get zeppOsDebugRealHeader => 'Real header';

  @override
  String zeppOsDebugLatestStartup(Object status) {
    return 'Latest startup status: $status';
  }

  @override
  String get zeppOsDebugWatchInbound => 'From watch';

  @override
  String get zeppOsDebugWatchOutbound => 'To watch';

  @override
  String get zeppOsDebugLifecycle => 'Lifecycle';

  @override
  String get zeppOsMirrorInterval => 'Frame interval';

  @override
  String get zeppOsMirrorIntervalRange => '10–250';

  @override
  String get zeppOsOfflineMaps => 'Offline maps';

  @override
  String get zeppOsOfflineMapsDescription =>
      'Transfer existing map packages to the watch';

  @override
  String get zeppOsAppSettings => 'App settings';

  @override
  String get zeppOsAppSettingsDescription =>
      'Manage cached settings for Zepp OS apps';

  @override
  String get zeppOsAppDebug => 'App debugging';

  @override
  String get zeppOsAppDebugDescription =>
      'Debug app-side scripts and device communication';

  @override
  String get deviceMusicSync => 'Music sync';

  @override
  String get deviceHealthTitle => 'Health';

  @override
  String get deviceHealthDescription =>
      'Sync activity and sleep data from the device';

  @override
  String get deviceHealthSyncCardTitle => 'Health data';

  @override
  String get deviceHealthNeverSynced =>
      'No health data has been synchronized yet';

  @override
  String deviceHealthLastSynced(String time) {
    return 'Last synchronized $time';
  }

  @override
  String get deviceHealthSync => 'Synchronize health data';

  @override
  String get deviceHealthSyncing => 'Synchronizing';

  @override
  String get deviceHealthAutoSyncTitle => 'Automatically sync health data';

  @override
  String get deviceHealthAutoSyncDescription =>
      'Automatically synchronize health data when synchronizing device data';

  @override
  String get deviceHealthConnectFirst =>
      'Connect the device to synchronize health data';

  @override
  String get deviceHealthPartialSync =>
      'Some health data could not be synchronized';

  @override
  String get deviceHealthToday => 'Today';

  @override
  String get deviceHealthSteps => 'Steps';

  @override
  String get deviceHealthDistance => 'Distance';

  @override
  String get deviceHealthCalories => 'Calories';

  @override
  String get deviceHealthHeartRate => 'Heart rate';

  @override
  String get deviceHealthRestingHeartRate => 'Resting heart rate';

  @override
  String get deviceHealthAbnormalHeartRate => 'Abnormal heart rate';

  @override
  String get deviceHealthHeartRateHigh => 'High heart rate';

  @override
  String get deviceHealthHeartRateLow => 'Low heart rate';

  @override
  String get deviceHealthHeartHealth => 'Heart health';

  @override
  String get deviceHealthHeartHealthMonitoring => 'Heart health monitoring';

  @override
  String get deviceHealthIrregularHeartbeat => 'Irregular heartbeat';

  @override
  String get deviceHealthLowBloodOxygen => 'Low blood oxygen';

  @override
  String get deviceHealthHighStress => 'High stress';

  @override
  String get deviceHealthDetected => 'Detected';

  @override
  String get deviceHealthSleep => 'Recent sleep';

  @override
  String get deviceHealthSleepCard => 'Sleep';

  @override
  String get deviceHealthAllDaySleep => 'All-day sleep';

  @override
  String get deviceHealthLongSleep => 'Long sleep';

  @override
  String get deviceHealthSleepStructure => 'Sleep structure';

  @override
  String get deviceHealthSleepAverageHeartRate => 'Average sleep heart rate';

  @override
  String get deviceHealthSleepAverageBloodOxygen =>
      'Average sleep blood oxygen';

  @override
  String deviceHealthAverageHeartRate(int value) {
    return 'Average heart rate $value bpm';
  }

  @override
  String get deviceHealthNoData => 'No data available';

  @override
  String get deviceHealthLoadFailed => 'Unable to load health data';

  @override
  String get deviceMusicUpload => 'Transfer music';

  @override
  String get deviceMusicSyncDescription => 'Sync MP3 files to the device';

  @override
  String get deviceMusicChooseDialog =>
      'Select an MP3 file to sync to the device';

  @override
  String get deviceMusicReadFailed => 'Unable to read the selected MP3 file';

  @override
  String deviceMusicSizeInvalid(int maxMb) {
    return 'MP3 files must be larger than 0 bytes and no larger than $maxMb MB';
  }

  @override
  String get deviceMusicUnknownArtist => 'Unknown artist';

  @override
  String get deviceMusicTransferred => 'Music transfer complete';

  @override
  String get deviceMusicLibrary => 'Device music';

  @override
  String get deviceMusicLibraryDescription =>
      'Manage songs and playlists on the device';

  @override
  String get deviceMusicSongs => 'Songs';

  @override
  String deviceMusicSongsTotal(int count) {
    return '$count total';
  }

  @override
  String get deviceMusicNoPlaylist => 'Not in a playlist';

  @override
  String get deviceMusicPlaylists => 'Playlists';

  @override
  String get deviceMusicEmpty => 'No songs on the device';

  @override
  String get deviceMusicNoPlaylists => 'No playlists yet';

  @override
  String deviceMusicLoadFailed(String error) {
    return 'Failed to load device music: $error';
  }

  @override
  String get deviceMusicPlaylistCreate => 'New playlist';

  @override
  String get deviceMusicPlaylistRename => 'Rename playlist';

  @override
  String get deviceMusicPlaylistName => 'Playlist name';

  @override
  String deviceMusicPlaylistLimit(int count) {
    return 'Up to $count playlists';
  }

  @override
  String deviceMusicSongCount(int count) {
    return '$count songs';
  }

  @override
  String get deviceMusicDeleteSong => 'Delete this song from the device?';

  @override
  String get deviceMusicDeletePlaylist => 'Delete this playlist?';

  @override
  String get deviceMusicDeletePlaylistDescription =>
      'Songs in the playlist will remain on the device.';

  @override
  String get deviceMusicManagePlaylists => 'Manage playlists';

  @override
  String get deviceMusicPlaylistMembership => 'Playlists';

  @override
  String deviceMusicTransferSpeed(String speed) {
    return '$speed/s';
  }

  @override
  String deviceMusicSelectedFiles(int count) {
    return '$count files selected';
  }

  @override
  String deviceMusicQueueProgress(int current, int total, String name) {
    return 'Transferring $current/$total: $name';
  }

  @override
  String get deviceRecordingsTitle => 'Recording sync';

  @override
  String get deviceRecordingsDescription =>
      'Sync and export recordings from the watch';

  @override
  String get deviceRecordingsHint =>
      'Recordings are received and verified one by one. Export each original file after synchronization.';

  @override
  String get deviceRecordingsSync => 'Sync recordings';

  @override
  String get deviceRecordingsReading => 'Reading recording list';

  @override
  String deviceRecordingsProgress(int completed, int total, String name) {
    return 'Received $completed/$total: $name';
  }

  @override
  String deviceRecordingsProgressCount(int completed, int total) {
    return 'Received $completed/$total';
  }

  @override
  String get deviceRecordingsEmpty =>
      'Connect the watch and select Sync recordings';

  @override
  String get deviceRecordingsSave => 'Export recording';

  @override
  String get deviceRecordingsNoneOnWatch =>
      'No new recordings were found on the watch';

  @override
  String deviceRecordingsSynced(int count) {
    return 'Synced $count recordings';
  }

  @override
  String deviceRecordingsSaveFailed(String error) {
    return 'Could not export recording: $error';
  }

  @override
  String get deviceMusicTransferTitle => 'Transfer MP3 file';

  @override
  String get deviceMusicVelaDescription =>
      'Sync MP3 files to the device. Each file must not exceed 100 MB.';

  @override
  String get deviceMusicZeppDescription =>
      'MP3 files up to 50 MB are supported. Bluetooth Classic is recommended for faster transfers; BLE is also supported but takes longer.';

  @override
  String get deviceMusicChooseMp3 => 'Select MP3 file';

  @override
  String get deviceMusicSongTitle => 'Track title';

  @override
  String get deviceMusicArtist => 'Artist';

  @override
  String deviceMusicFileSize(Object size) {
    return 'File size: $size';
  }

  @override
  String deviceMusicProgress(Object progress) {
    return 'Transfer progress: $progress%';
  }

  @override
  String get deviceMusicTransferring => 'Transferring';

  @override
  String get deviceMusicSend => 'Start transfer';

  @override
  String get zeppOsFindDevice => 'Find device';

  @override
  String get zeppOsFindDeviceDescription =>
      'Make the device vibrate or ring continuously';

  @override
  String get deviceFeaturesDeviceInfo => 'Device info';

  @override
  String get deviceFeaturesDeviceInfoDesc => 'Firmware, storage and details';

  @override
  String get switchDeviceTitle => 'Switch device';

  @override
  String get savedDevices => 'Saved devices';

  @override
  String get deviceSwitchAddDevice => 'Add device';

  @override
  String get scanAndAdd => 'Scan and add';

  @override
  String get authkey => 'Auth key';

  @override
  String get authkeyPrompt => 'Enter device auth key';

  @override
  String get authkeyPlaceholder => 'Auth key';

  @override
  String get connectFailed => 'Connection failed';

  @override
  String deviceConnectingTo(String deviceName) {
    return 'Connecting to $deviceName…';
  }

  @override
  String get deviceConnectionPreparing => 'Preparing connection…';

  @override
  String deviceConnectionEstablishing(String transport) {
    return 'Establishing $transport connection…';
  }

  @override
  String get deviceConnectionInitializing => 'Initializing device protocol…';

  @override
  String get deviceConnectionAuthenticating => 'Authenticating device…';

  @override
  String get deviceConnectionFetchingStatus => 'Reading device information…';

  @override
  String get deviceTransportBle => 'BLE';

  @override
  String deviceEndpointUnavailable(String transport) {
    return 'No $transport endpoint is available. Pair the device in system Bluetooth settings, then scan again.';
  }

  @override
  String get deviceTransportSpp => 'SPP';

  @override
  String get deviceCompatibilityUnknown => 'Unrecognized device';

  @override
  String get webSerialTitle => 'Web Serial';

  @override
  String get webSerialHint =>
      'On the web, OronBox connects to devices via Web Serial. Saved devices stay in this browser.';

  @override
  String get webSerialConnectDialogTitle => 'Connect via Web Serial';

  @override
  String get webSerialConnectDialogHint =>
      'Enter the device auth key, then select the serial port in the browser prompt. The auth key is saved in this browser.';

  @override
  String get cancel => 'Cancel';

  @override
  String get deviceActionsDelete => 'Delete';

  @override
  String get deviceActionsDisconnect => 'Disconnect';

  @override
  String get deviceActionsShareQR => 'Share QR';

  @override
  String get deviceShareOronBoxCode => 'Switch to OronBox code';

  @override
  String get deviceShareAstroBoxCompatibleCode =>
      'Switch to AstroBox compatible code';

  @override
  String get installTapToSelectFile => 'Tap to select file';

  @override
  String get deviceInfoTitle => 'Device info';

  @override
  String get deviceInfoGroupDevice => 'Device';

  @override
  String get deviceInfoGroupSystem => 'System';

  @override
  String get deviceInfoGroupStatus => 'Status';

  @override
  String get fieldName => 'Name';

  @override
  String get fieldAddress => 'Address';

  @override
  String get fieldAuthkey => 'Auth key';

  @override
  String get fieldConnectionType => 'Connection type';

  @override
  String get fieldCodename => 'Codename';

  @override
  String get fieldModel => 'Model';

  @override
  String get fieldImei => 'IMEI';

  @override
  String get fieldFirmware => 'Firmware';

  @override
  String get fieldSerial => 'Serial';

  @override
  String get fieldBattery => 'Battery';

  @override
  String get fieldChargeStatus => 'Charge status';

  @override
  String get fieldStorage => 'Storage';

  @override
  String get appManagementTitle => 'App management';

  @override
  String get appManagementNone => 'No installed apps';

  @override
  String get appManagementShowSystemApps => 'Show system apps';

  @override
  String get watchfaceManagementTitle => 'Watchface management';

  @override
  String get watchfaceManagementNone => 'No installed watchfaces';

  @override
  String get open => 'Open';

  @override
  String get externalLinkTitle => 'Open external link';

  @override
  String externalLinkDescription(String url) {
    return 'You are about to visit $url\n\nThis website is operated by a third party, is not affiliated with OronBox, and its security is unknown. Please proceed with caution. Do you want to continue?';
  }

  @override
  String get externalLinkAstroBoxResourceHint =>
      'This appears to be an AstroBox resource. You can also view and install it within OronBox';

  @override
  String get continueToWebsite => 'Continue';

  @override
  String get viewInOronBox => 'View in OronBox';

  @override
  String get uninstall => 'Uninstall';

  @override
  String get enable => 'Enable';

  @override
  String get show => 'Show';

  @override
  String get hide => 'Hide';

  @override
  String get copy => 'Copy';

  @override
  String get copied => 'Copied';

  @override
  String get close => 'Close';

  @override
  String get desktopTrayShow => 'Show window';

  @override
  String get desktopTrayExit => 'Exit OronBox';

  @override
  String get desktopCloseTitle => 'Exit confirmation';

  @override
  String get desktopCloseMessage => 'Would you like to exit OronBox?';

  @override
  String get desktopCloseRemember => 'Do not ask again';

  @override
  String get desktopCloseToTray => 'Minimize to tray';

  @override
  String get desktopCloseExit => 'Exit OronBox';

  @override
  String get settingsDesktopCloseBehavior => 'Window closing';

  @override
  String get settingsDesktopCloseBehaviorDesc =>
      'Choose what happens when the main window is closed';

  @override
  String get settingsRemoveBondBeforeSpp => 'Re-pair when connecting';

  @override
  String get settingsRemoveBondBeforeSppDesc =>
      'Improves connection stability and prevents Xiaomi Fitness from taking the connection; turning it off may speed up connections';

  @override
  String get desktopCloseBehaviorAsk => 'Ask every time';

  @override
  String get desktopCloseBehaviorExit => 'Exit immediately';

  @override
  String get desktopCloseBehaviorTray => 'Minimize to tray';

  @override
  String get quickApp => 'Quickapp';

  @override
  String get miniprogram => 'Miniprogram';

  @override
  String get miniprograms => 'Miniprograms';

  @override
  String get watchface => 'Watchface';

  @override
  String get firmwareTool => 'Firmware / Tool';

  @override
  String get free => 'Free';

  @override
  String get paid => 'Paid';

  @override
  String get forcePaid => 'Force Paid';

  @override
  String get version => 'Version';

  @override
  String get noContent => 'No content';

  @override
  String get preview => 'Preview';

  @override
  String get productDeviceRequirements => 'Device requirements';

  @override
  String get productOtherVersions => 'Other versions';

  @override
  String get productInQueue => 'In queue';

  @override
  String get settingsAccount => 'Account';

  @override
  String get settingsGeneral => 'General';

  @override
  String get settingsQueue => 'Queue';

  @override
  String get settingsAbout => 'About';

  @override
  String get settingsAccountLoginBBSDesc =>
      'Sign in to access BandBBS resources';

  @override
  String get settingsAccountBandBbsSigningIn => 'Signing in';

  @override
  String get settingsAccountBandBbsOpenedBrowser =>
      'Browser opened. Complete BandBBS authorization there';

  @override
  String get settingsAccountBandBbsSignedIn => 'BandBBS signed in';

  @override
  String get settingsAccountBandBbsLoginFailed => 'BandBBS sign-in failed';

  @override
  String get settingsBandBbsAccountRequired =>
      'Sign in to your BandBBS account in Settings first';

  @override
  String get settingsAccountBBSAccount => 'BandBBS account';

  @override
  String get bandBbsAccountTitle => 'BandBBS account';

  @override
  String get bandBbsResourceId => 'Resource ID';

  @override
  String get bandBbsResourceIdHint => 'Enter BandBBS resource ID';

  @override
  String get bandBbsQueryResource => 'Query';

  @override
  String get bandBbsLogout => 'Sign out';

  @override
  String get bandBbsLoggedOut => 'Signed out';

  @override
  String accountSignOutTitle(Object accountName) {
    return 'Sign out of $accountName?';
  }

  @override
  String get accountSignOutMessage =>
      'You will need to sign in again to use related features.';

  @override
  String get bandBbsLoadPreviews => 'Load post previews';

  @override
  String get bandBbsLoadPreviewsDesc =>
      'Automatically load attachment previews in the resource list';

  @override
  String get bandBbsShowAllCategories => 'Show all categories';

  @override
  String get bandBbsShowAllCategoriesDesc =>
      'Include categories for unsupported devices hidden by default';

  @override
  String get settingsMiAccount => 'Xiaomi account';

  @override
  String get settingsMiAccountDesc =>
      'Sign in and sync authkeys from bound devices';

  @override
  String get deviceSwitchMiAccountImport =>
      'Sign in to Xiaomi account and sync bound devices';

  @override
  String get deviceSwitchWearableLogImport =>
      'Import devices from Xiaomi Fitness logs';

  @override
  String get settingsMiAccountLoginTitle => 'Xiaomi account login';

  @override
  String get settingsMiAccountUsername => 'Account';

  @override
  String get settingsMiAccountPassword => 'Password';

  @override
  String get settingsMiAccountRememberCredentials =>
      'Remember account and password';

  @override
  String get settingsMiAccountLoginAndSync => 'Sign in and sync';

  @override
  String get settingsMiAccountLogInvalid =>
      'Unable to read this Xiaomi Fitness log';

  @override
  String get settingsMiAccountLogNoDevices =>
      'No device with a complete MAC and authkey was found in the log';

  @override
  String get settingsWearableLogSync => 'Read Xiaomi Fitness log';

  @override
  String get settingsWearableLogGuide =>
      'Open Xiaomi Fitness\nGo to About at the bottom of the Profile page\nRepeatedly tap the orange ring logo\nTap Confirm in the dialog\nWait for the log has been... toast\nReturn here and tap Scan';

  @override
  String settingsWearableLogFound(int count) {
    return 'Found $count devices, tap one to import';
  }

  @override
  String settingsWearableLogImportedDevice(Object name) {
    return 'Imported $name';
  }

  @override
  String get settingsMiAccountMissingCredentials =>
      'Enter your Xiaomi account and password';

  @override
  String get settingsMiAccountTwoFactorPrompt =>
      'Complete Xiaomi account two-factor verification in the verification page';

  @override
  String get settingsMiAccountLoginWindowClosed =>
      'The login window was closed';

  @override
  String settingsMiAccountSyncedDevices(int count) {
    return 'Synced $count Mi devices';
  }

  @override
  String get xiaomiAccountRequiredForEphemeris =>
      'Sign in to your Xiaomi account before syncing ephemeris data';

  @override
  String get settingsHuamiAccount => 'Amazfit account';

  @override
  String get settingsHuamiAccountDesc =>
      'Sign in and save credentials for Zepp store access';

  @override
  String get settingsHuamiAccountSigningIn => 'Signing in';

  @override
  String get settingsHuamiAccountSignedIn => 'Amazfit account signed in';

  @override
  String get settingsHuamiAccountLoginTitle => 'Amazfit account login';

  @override
  String get settingsHuamiAccountUsername => 'Account';

  @override
  String get settingsHuamiAccountPassword => 'Password';

  @override
  String get settingsHuamiAccountRememberCredentials => 'Remember password';

  @override
  String get settingsHuamiAccountLoginAndSave => 'Sign in and save';

  @override
  String get settingsHuamiAccountMissingCredentials =>
      'Enter your Amazfit account and password';

  @override
  String get settingsHuamiAccountRequired =>
      'Sign in to your Amazfit account in Settings first';

  @override
  String get understood => 'I understand';

  @override
  String get settingsGeneralLanguage => 'Language';

  @override
  String get settingsGeneralLanguageDesc => 'Change app display language';

  @override
  String get settingsWideNavigationPosition => 'Navigation position';

  @override
  String get settingsWideNavigationPositionDesc =>
      'Adjust side tab placement in the wide-screen state';

  @override
  String get settingsWideNavigationPositionBottom => 'Bottom';

  @override
  String get settingsWideNavigationPositionCenter => 'Center';

  @override
  String get settingsWideNavigationPositionSplit => 'Split';

  @override
  String get settingsAutoReconnectTitle => 'Auto reconnect';

  @override
  String get settingsAutoReconnectDesc =>
      'Automatically reconnect to the last paired device on startup';

  @override
  String get settingsAutoReconnectOnDisconnectTitle => 'Auto reconnect';

  @override
  String get settingsAutoReconnectOnDisconnectDesc =>
      'Try to reconnect when the device is disconnected unexpectedly';

  @override
  String get deviceReconnectAttempting =>
      'Device connection lost, trying to reconnect';

  @override
  String get deviceReconnectSucceeded => 'Reconnected successfully';

  @override
  String get deviceReconnectFailedPrefix => 'Reconnect failed. Check: ';

  @override
  String get settingsSourceOfficialCdn => 'GitHub source CDN';

  @override
  String get settingsSourceOfficialCdnDesc =>
      'CDN used to fetch the GitHub-hosted community index';

  @override
  String get settingsQueueAutoInstall => 'Auto install';

  @override
  String get settingsQueueAutoInstallDesc =>
      'Start installation automatically after download';

  @override
  String get settingsQueueDontClear => 'Don\'t clear install queue';

  @override
  String get settingsQueueDontClearDesc =>
      'Keep completed items in the install queue';

  @override
  String get settingsRealtimeActivityNotification =>
      'Real-time activity notification';

  @override
  String get settingsRealtimeActivityNotificationDesc =>
      'Use a real-time activity notification to show queue progress';

  @override
  String get settingsAboutWebsite => 'Official website';

  @override
  String get settingsTapToSignIn => 'Tap to sign in';

  @override
  String get settingsConnected => 'Connected';

  @override
  String get settingsSystem => 'System';

  @override
  String get settingsLight => 'Light';

  @override
  String get settingsDark => 'Dark';

  @override
  String get settingsOledDark => 'OLED dark';

  @override
  String get settingsThemeMode => 'Theme mode';

  @override
  String get settingsThemeModeDesc => 'Change app theme appearance';

  @override
  String get settingsDynamicColor => 'Dynamic color';

  @override
  String get settingsDynamicColorDesc =>
      'Use system accent colors for the app theme';

  @override
  String get settingsColorScheme => 'Color scheme';

  @override
  String get settingsColorSchemeDesc => 'Choose the app accent color';

  @override
  String get settingsColorSchemePink => 'Pink';

  @override
  String get settingsColorSchemePurple => 'Purple';

  @override
  String get settingsColorSchemeTeal => 'Teal';

  @override
  String get settingsColorSchemeGreen => 'Green';

  @override
  String get settingsColorSchemeRed => 'Red';

  @override
  String get settingsColorSchemeAmber => 'Amber';

  @override
  String get settingsDesktopAccentSource => 'Linux accent source';

  @override
  String get settingsDesktopAccentSourceDesc =>
      'Choose whether to read accent colors from GTK or Qt';

  @override
  String get settingsDesktopAccentSourceSystem => 'Auto';

  @override
  String get settingsDesktopAccentSourceGtk => 'GTK';

  @override
  String get settingsDesktopAccentSourceQt => 'Qt';

  @override
  String get settingsCancel => 'Cancel';

  @override
  String get settingsTeamRoleMain => 'Main Developer / Designer';

  @override
  String get settingsTeamRoleZeppOS => 'ZeppOS implementation';

  @override
  String get settingsTeamRoleHarmony => 'HarmonyOS adaptation';

  @override
  String get settingsAboutSoftware => 'About software';

  @override
  String get settingsAboutSoftwareDesc =>
      'Version, changelog and development team';

  @override
  String get settingsAboutSoftwareTagline =>
      'A pretty fast wearable management tool for VelaOS and ZeppOS, built with Flutter';

  @override
  String get settingsAboutSoftwareRepository => 'Open GitHub repository';

  @override
  String get settingsAboutSoftwareTeam => 'Development team';

  @override
  String get settingsSpecialThanks => 'Special thanks';

  @override
  String get settingsAboutSoftwareBuildInfo => 'Build info';

  @override
  String get settingsAboutSoftwareCopyright => 'Copyright © 2026 OrPudding';

  @override
  String get acknowledgementsKazumi =>
      'Reference for Material Design components and UI patterns.';

  @override
  String get acknowledgementsAstroBoxPublic =>
      'Reference for UI structure, resource workflows, and interaction design.';

  @override
  String get acknowledgementsAstroBoxNgCore =>
      'Reference for Xiaomi device protocols, install flows, and transfer behavior.';

  @override
  String get acknowledgementsAstroBoxNgBluetooth =>
      'Reference for Bluetooth connection behavior.';

  @override
  String get acknowledgementsAstroBoxNgAccount =>
      'Reference for Xiaomi account login, device sync, and authkey retrieval flows.';

  @override
  String get acknowledgementsAstroBoxNgProvider =>
      'Reference for community resource indexes, CDN handling, and manifest parsing flows.';

  @override
  String get acknowledgementsAstroBoxNgAppWasm =>
      'Reference for Web Serial and browser-side connection flows.';

  @override
  String get acknowledgementsGadgetbridge =>
      'Reference for ZeppOS and wearable protocol research.';

  @override
  String get acknowledgementsBreezyWeather =>
      'Reference for the China weather source implementation.';

  @override
  String get acknowledgementsOpenMeteo =>
      'Weather forecasts, air quality, and geocoding data under CC BY 4.0';

  @override
  String get resourceHomeRecommended => 'Recommended';

  @override
  String get resourceHomeFeatured => 'Featured';

  @override
  String get resourceHomeUpdates => 'Updates';

  @override
  String get blogTypeAnnouncement => 'Announcement';

  @override
  String get blogTypeRecommendation => 'Recommendation';

  @override
  String get blogTypeDocs => 'Docs';

  @override
  String get resourceHomeEmptyTitle => 'Nothing to recommend yet';

  @override
  String get resourceLibraryEndOfList =>
      'You\'ve reached the end — check out resources from other sources?';

  @override
  String get resourceHomeEmptySubtitle =>
      'You can get resources from the library';

  @override
  String get openResourceLibrary => 'Open resource library';

  @override
  String get downloadQueueTitle => 'Download queue';

  @override
  String get installQueueTitle => 'Install queue';

  @override
  String get queueClear => 'Clear';

  @override
  String get queueStart => 'Start';

  @override
  String get queuePause => 'Pause';

  @override
  String get downloadQueueEmpty => 'No download tasks';

  @override
  String get installQueueEmpty => 'No install tasks';

  @override
  String get localAppInstall => 'Local app install';

  @override
  String get localWatchfaceInstall => 'Local watchface install';

  @override
  String get localFirmwareInstall => 'Local firmware install';

  @override
  String get queueStatusPending => 'Waiting';

  @override
  String queueStatusDownloading(String percent) {
    return 'Downloading $percent%';
  }

  @override
  String queueStatusInstalling(String percent) {
    return 'Installing $percent%';
  }

  @override
  String get queueStatusCompleted => 'Completed';

  @override
  String get queueStatusFailed => 'Failed';

  @override
  String get queueDragToInstall =>
      'Release to install an app, watchface, or plugin';

  @override
  String queueAddedFiles(int count) {
    return 'Added $count files to install queue';
  }

  @override
  String get installQueueReadFailed => 'Read failed';

  @override
  String get installQueueUnsupportedFile => 'Unsupported file';

  @override
  String timeTodayAt(Object time) {
    return 'Today $time';
  }

  @override
  String timeYesterdayAt(Object time) {
    return 'Yesterday $time';
  }

  @override
  String get settingsAccountBandBbsAccount => 'BandBBS account';

  @override
  String get settingsAccountGitHub => 'GitHub account';

  @override
  String get settingsAccountGitHubDesc =>
      'Connect to publish AstroBox resources as yourself';

  @override
  String get githubAccountNeedsBandBbs => 'Sign in to BandBBS first';

  @override
  String get bandBbsPublishAuthTitle => 'Publish authorization';

  @override
  String get bandBbsResourceQueryTitle => 'Install purchased resources';

  @override
  String get settingsAboutLogs => 'Runtime logs';

  @override
  String get settingsAboutLogsDescription =>
      'View, export, and manage runtime logs from the app and connected devices';

  @override
  String settingsAboutLogsSize(Object size) {
    return 'Currently using $size';
  }

  @override
  String get settingsAboutLogsExport => 'Export';

  @override
  String settingsAboutLogsExported(Object path) {
    return 'Exported to $path';
  }

  @override
  String get settingsAboutLogsEmpty => 'No log files';

  @override
  String get settingsAboutLogsClear => 'Clear';

  @override
  String get settingsDeviceLogsPull => 'Pull device logs';

  @override
  String get settingsDeviceLogsTip =>
      'This pulls logs from the connected Xiaomi wearable and may take a while. Keep the app in the foreground and the device screen on until it finishes.';

  @override
  String get settingsDeviceLogsStart => 'Start';

  @override
  String get settingsDeviceLogsPulling => 'Pulling device logs';

  @override
  String get settingsDeviceLogsWaiting => 'Waiting for the device to send logs';

  @override
  String settingsDeviceLogsProgress(Object progress) {
    return 'Received $progress%';
  }

  @override
  String settingsDeviceLogsSaved(Object name) {
    return 'Device logs saved as $name';
  }

  @override
  String settingsDeviceLogsFailed(Object error) {
    return 'Unable to pull device logs: $error';
  }

  @override
  String get settingsAboutLogsClearConfirm =>
      'All log files except the current session will be deleted.';

  @override
  String get settingsAboutLogsOpen => 'Open logs folder';

  @override
  String get settingsAboutLogsOpenFailed => 'Unable to open the logs folder';

  @override
  String get settingsLogsFileList => 'Log files';

  @override
  String get settingsAboutLogsWarningTitle => 'Sensitive information warning';

  @override
  String get settingsAboutLogsWarningMessage =>
      'Logs may contain BandBBS, Xiaomi, or Amazfit login credentials and other sensitive information. Do not share them with anyone other than official OronBox maintainers!';

  @override
  String get pluginPermissionRequestTitle => 'Plugin permission request';

  @override
  String pluginPermissionRequestMessage(Object plugin, Object operation) {
    return '\"$plugin\" wants to $operation.';
  }

  @override
  String get pluginPermissionOnce => 'Allow once';

  @override
  String get pluginPermissionSession => 'Allow this run';

  @override
  String get pluginPermissionAlways => 'Always allow';

  @override
  String get pluginPermissionDeny => 'Deny';

  @override
  String get pluginPermissionOpenExternal => 'open an external link';

  @override
  String get pluginPermissionPickFile => 'access host files';

  @override
  String get pluginPermissionExportFile => 'export a file to the host';

  @override
  String get pluginPermissionNetwork => 'access the network';

  @override
  String get pluginPermissionInterconnect =>
      'communicate with device applications';

  @override
  String get pluginPermissionProvider => 'register a resource provider';

  @override
  String get pluginPermissionReadDevice => 'read device information';

  @override
  String get pluginPermissionOperateDevice => 'operate a device';

  @override
  String get pluginPermissionObserveProtocol => 'read raw device protocol data';

  @override
  String get pluginPermissionSendProtocol =>
      'send raw protocol data to a device';

  @override
  String get pluginPermissionReadAppSide => 'read AppSide scripts and events';

  @override
  String get pluginPermissionOperateAppSide => 'manage AppSide sessions';

  @override
  String get pluginErrorTitle => 'Plugin corrupted';

  @override
  String pluginErrorMessage(Object plugin, Object error) {
    return '\"$plugin\" cannot run and may be corrupted.\n\nError: $error\n\nUninstall this plugin?';
  }

  @override
  String get pluginPackageCorruptedMessage =>
      'The selected plugin package cannot be read and may be corrupted. Obtain it again and try importing it.';

  @override
  String get pluginErrorClearData => 'Clear plugin data';

  @override
  String get pluginErrorUninstall => 'Uninstall plugin';

  @override
  String get pluginErrorSafeMode => 'Enter safe mode';

  @override
  String get pluginSafeModeTitle => 'Plugin safe mode is enabled';

  @override
  String get pluginSafeModeDescription =>
      'All plugins are stopped and will reload after safe mode is disabled.';

  @override
  String get pluginSafeModeExit => 'Exit safe mode';

  @override
  String get devTools => 'DevTools';

  @override
  String get devToolsDescriptionDesktop => 'Open DevTools in a separate window';

  @override
  String get devToolsDescriptionEntry =>
      'Show a DevTools entry button in app bars';

  @override
  String get devToolsOperationFailed => 'Unable to change the DevTools state';

  @override
  String get resourceTypeErrorTitle => 'Incorrect resource type';

  @override
  String get resourceTypeUnknownTitle => 'Unrecognized resource type';

  @override
  String get resourceTypeUnknownNoType =>
      'OronBox cannot identify the resource type of this file; it may be corrupted';

  @override
  String get resourceTypeUnknownCancel => 'Cancel';

  @override
  String resourceTypeMismatchMessage(Object detectedType, Object selectedType) {
    return 'This appears to be a $detectedType resource, but you selected $selectedType. Choose how to install it';
  }

  @override
  String resourcePlatformMismatchMessage(
    Object resourcePlatform,
    Object resourceType,
    Object deviceName,
    Object devicePlatform,
  ) {
    return 'This appears to be a $resourceType resource for a $resourcePlatform device, but the connected device is $deviceName ($devicePlatform). It is not supported and forcing installation may cause unexpected problems';
  }

  @override
  String resourceTypeUnknownMessage(Object selectedType) {
    return 'OronBox cannot identify the actual resource type. Install it as $selectedType anyway?';
  }

  @override
  String get resourceInstallCancel => 'Cancel installation';

  @override
  String get resourceInstallAcknowledge => 'I understand';

  @override
  String get resourceInstallForce => 'Force install';

  @override
  String resourceInstallForceCountdown(int seconds) {
    return 'Force install (${seconds}s)';
  }

  @override
  String resourceInstallAsSelected(Object type) {
    return 'Continue as $type';
  }

  @override
  String resourceInstallAsSelectedCountdown(Object type, int seconds) {
    return 'Continue as $type (${seconds}s)';
  }

  @override
  String resourceInstallAsDetected(Object type) {
    return 'Install as $type';
  }

  @override
  String get resourceTypeApp => 'miniprogram';

  @override
  String get resourceTypeQuickApp => 'quick app';

  @override
  String get resourceTypeWatchface => 'watchface';

  @override
  String get resourceTypeFirmware => 'firmware';

  @override
  String resourceInstallConfirmTitle(Object type) {
    return 'Install $type';
  }

  @override
  String resourceInstallConfirmMessage(Object fileName, Object fileSize) {
    return 'Install $fileName ($fileSize)?';
  }

  @override
  String get resourceInstallConfirm => 'Install';

  @override
  String get previewImages => 'Preview images';

  @override
  String get add => 'Add';

  @override
  String get submit => 'Submit';

  @override
  String get creatorConfirmTitle => 'Confirm commit';

  @override
  String get creatorConfirmOronBox => 'Commit to OronBox';

  @override
  String creatorConfirmBandBbs(Object category) {
    return 'Sync to BandBBS: $category';
  }

  @override
  String creatorConfirmAstroBox(Object owner, Object repository) {
    return 'Sync to AstroBox: $owner/$repository';
  }

  @override
  String get creatorBandBbsDirectPublish => 'Sync to BandBBS';

  @override
  String get creatorBandBbsBoundUpdate => 'Linked · Sync to BandBBS';

  @override
  String get creatorBandBbsVersionTitle => 'Version title';

  @override
  String get creatorBandBbsVersionMessage => 'Update notes';

  @override
  String get creatorBandBbsVersionPairRequired =>
      'Enter both a version title and update notes, or leave both empty';

  @override
  String creatorLinkedSections(int count) {
    return '$count linked sections';
  }

  @override
  String creatorBandBbsBindingIds(Object categoryId, Object resourceId) {
    return 'Section $categoryId · Resource $resourceId';
  }

  @override
  String get creatorAstroBoxBoundSync => 'Linked · Sync to AstroBox';

  @override
  String get creatorThisCommit => 'This commit';

  @override
  String creatorAstroBoxPrPublish(Object repository) {
    return 'Sync to AstroBox · $repository';
  }

  @override
  String get creatorOronBoxRequired =>
      'Required. Resources are reviewed by OronBox';

  @override
  String get creatorOpenInOronBox => 'View in OronBox';

  @override
  String get creatorAstroTagsHint => 'Separate tags with English semicolons ;';

  @override
  String get retry => 'Retry';

  @override
  String get reviewNote => 'Review note';

  @override
  String get creatorReviewRejected => 'Resource changes requested';

  @override
  String creatorReviewState(Object state) {
    return 'Review status: $state';
  }

  @override
  String get creatorOperationWorking => 'Working';

  @override
  String get creatorProcessingImage => 'Processing image';

  @override
  String get creatorOperationRefreshing => 'Refreshing creator data';

  @override
  String get creatorOperationCreating => 'Creating resource';

  @override
  String get creatorOperationCreatingCollection => 'Creating collection';

  @override
  String get creatorOperationSaving => 'Saving changes';

  @override
  String get creatorOperationDeleting => 'Deleting';

  @override
  String get creatorOperationSubmitting => 'Submitting for review';

  @override
  String get creatorOperationAuthorizing => 'Waiting for authorization';

  @override
  String get creatorResolvingPublicationTarget =>
      'Resolving publication category';

  @override
  String get creatorStateApproved => 'Approved';

  @override
  String get creatorStateExternalReview => 'External review';

  @override
  String get creatorStateFailed => 'Publishing failed';

  @override
  String get creatorStateSuperseded => 'Superseded by a newer revision';

  @override
  String get creatorStateCancelled => 'Cancelled';

  @override
  String get creatorNoResources => 'No resources created yet';

  @override
  String get creatorLoginRequiredTitle => 'Sign in to use Creator Center';

  @override
  String get creatorLoginRequiredDescription =>
      'Sign in to BandBBS and connect your OronBox account before creating, editing, or submitting resources';

  @override
  String get creatorLoginAction => 'Sign in to BandBBS';

  @override
  String get creatorBandBbsWriteReady => 'BandBBS publishing authorized';

  @override
  String get creatorBandBbsWriteMissing => 'BandBBS publishing not authorized';

  @override
  String get creatorGitHubOwnPublishReady => 'GitHub connected';

  @override
  String get creatorGitHubOwnPublishMissing => 'GitHub not connected';

  @override
  String get creatorAuthorize => 'Authorize';

  @override
  String get installQueueFixWatchfaceId => 'Fix watchface ID';

  @override
  String get installQueueFixWatchfaceIdHint => 'Enter up to 12 digits';

  @override
  String get authorize => 'Authorize';

  @override
  String get creatorBandBbsAuthorized =>
      'BandBBS resource publishing is authorized';

  @override
  String get creatorBandBbsAuthorizationRequired =>
      'Authorize OronBox separately to publish BandBBS resources on your behalf';

  @override
  String get connect => 'Connect';

  @override
  String get legalAndPrivacy => 'Legal and privacy';

  @override
  String get termsTitle => 'Terms and disclaimer';

  @override
  String get privacyTitle => 'Privacy notice';

  @override
  String get resourcePublishingTitle => 'Resource publishing agreement';

  @override
  String get reviewRulesTitle => 'Resource review rules';

  @override
  String get joinQqGroup => 'Join QQ Group';

  @override
  String get joinQqGroupDesc => 'Chat with developers and other users for help';

  @override
  String get feedbackTitle => 'Feedback';

  @override
  String get feedbackDesc => 'Submit feedback and view responses';

  @override
  String get reportResource => 'Report resource';

  @override
  String get reportComment => 'Report comment';

  @override
  String get report => 'Report';

  @override
  String get feedbackSubject => 'Subject';

  @override
  String get feedbackMessage => 'Feedback or issue';

  @override
  String get reportReason => 'Reason for report';

  @override
  String get noFeedback => 'No feedback yet';

  @override
  String get feedbackProcessing => 'Processing';

  @override
  String get feedbackReplied => 'Replied';

  @override
  String get feedbackOpen => 'Open';

  @override
  String get feedbackResolved => 'Resolved';

  @override
  String get feedbackDismissed => 'Dismissed';

  @override
  String get feedbackClosed => 'Closed';

  @override
  String get feedbackLoading => 'Loading tickets';

  @override
  String get feedbackNewTicket => 'New ticket';

  @override
  String get feedbackYou => 'You';

  @override
  String get feedbackResolution => 'Resolution';

  @override
  String get feedbackReplyHint => 'Reply to this ticket';

  @override
  String get feedbackConversationClosed =>
      'This ticket is closed and cannot be replied to';

  @override
  String get checkUpdates => 'Check for updates';

  @override
  String get updateChecking => 'Checking for updates…';

  @override
  String get updateCheckFailed => 'Unable to check for updates';

  @override
  String get latestVersionInstalled => 'You are using the latest version';

  @override
  String newVersionAvailable(Object version) {
    return 'Version $version is available';
  }

  @override
  String get oobeWelcomeSlogan =>
      'A beautiful and fast VelaOS / ZeppOS wearable device manager, built with Flutter';

  @override
  String get oobeNext => 'Next';

  @override
  String get oobeBack => 'Back';

  @override
  String get oobeFeatureDevicesTitle => 'Device connection';

  @override
  String get oobeFeatureDevicesBody =>
      'Connect and manage VelaOS and ZeppOS wearable devices';

  @override
  String get oobeFeatureResourcesTitle => 'Resource center';

  @override
  String get oobeFeatureResourcesBody =>
      'Supports the official OronBox source, AstroBox-Repo, BandBBS, and the Amazfit App Store';

  @override
  String get oobeFeaturePluginsTitle => 'JavaScript plugins';

  @override
  String get oobeFeaturePluginsBody =>
      'A high-performance, highly extensible JavaScript plugin system with device interaction';

  @override
  String get oobeFeaturePlatformsTitle => 'Multi-platform';

  @override
  String get oobeFeaturePlatformsBody =>
      'Available on Android, Windows, macOS, Linux, and Web';

  @override
  String get oobeOpenSourceTitle => 'Fully open source';

  @override
  String get oobeOpenSourceBody =>
      'The OronBox client and server both follow GNU AGPL-3.0 with their complete source code available';

  @override
  String get oobeAgreementHint => 'Please read and scroll to the bottom';

  @override
  String get oobeAgreeCheckbox => 'I have read and agree';

  @override
  String get oobeDeclineExit => 'Exit';

  @override
  String get oobeDeclineWebHint =>
      'You must accept the agreements to continue; please close this page';

  @override
  String get oobeLoginTitle => 'Connect your accounts';

  @override
  String get oobeLoginBandBbsDesc =>
      'Sign in with your BandBBS account to access BandBBS resources and prepare creator services';

  @override
  String get oobeLoginLocalNote =>
      'Xiaomi and Amazfit sign-in run entirely on this device; related data is never sent to any third party other than Xiaomi/Amazfit';

  @override
  String get oobeLoginXiaomiDesc =>
      'Sign in with your Xiaomi account to sync your bound Xiaomi devices';

  @override
  String get oobeLoginHuamiDesc =>
      'Sign in with your Amazfit account to access Amazfit app store resources';

  @override
  String get oobeCdnTesting => 'Testing…';

  @override
  String get oobeCdnSelected => 'Best CDN selected';

  @override
  String get oobeCdnTitle => 'GitHub CDN Speed Test';

  @override
  String get oobeDoneTitle => 'All set';

  @override
  String get oobeDoneBody => 'Start exploring OronBox';

  @override
  String get oobeFinish => 'Finish';

  @override
  String get settingsReplayOobe => 'Restart guide';

  @override
  String get settingsReplayOobeDesc =>
      'View the welcome guide and initial setup again';

  @override
  String get creatorConnect => 'Connect';

  @override
  String get comments => 'Comments';

  @override
  String get commentEmpty => 'No comments yet';

  @override
  String get commentHint => 'Write a comment';

  @override
  String get commentLoginRequired => 'Sign in with BandBBS to comment';

  @override
  String get commentPending => 'Pending review';

  @override
  String get commentBlocked =>
      'This comment did not meet the community guidelines';

  @override
  String get commentModerationUnavailable =>
      'Comment moderation is temporarily unavailable';

  @override
  String get commentRateLimited => 'You are commenting too quickly';

  @override
  String get commentReplying => 'Reply to comment';

  @override
  String get loadMore => 'Load more';

  @override
  String get more => 'More';

  @override
  String get reply => 'Reply';

  @override
  String get inbox => 'Inbox';

  @override
  String get inboxLoading => 'Loading messages';

  @override
  String get inboxEmpty => 'No messages';

  @override
  String get inboxClear => 'Clear messages';

  @override
  String get inboxClearFailed => 'Could not clear messages. Try again later.';

  @override
  String get messageUnknownTitle => 'Notification';

  @override
  String get messageUnknownBody => 'The notification data is unavailable.';

  @override
  String get messageCommentRepliedTitle => 'New comment reply';

  @override
  String get messageCommentHiddenTitle => 'Comment hidden';

  @override
  String get messageCommentHiddenAutomatedBody =>
      'Your comment did not pass automated moderation and is currently hidden. You can submit an appeal from the message.';

  @override
  String get messageCommentHiddenReviewedBody =>
      'Your comment was hidden after manual review.';

  @override
  String get messageReviewApprovedTitle => 'Resource approved';

  @override
  String get messageReviewRejectedTitle => 'Resource needs changes';

  @override
  String get messageResourceSuspendedTitle => 'Resource delisted';

  @override
  String get messageResourceFrozenTitle => 'Resource frozen';

  @override
  String get messageResourceDeletedTitle => 'Resource deleted';

  @override
  String get messageResourceRestoredTitle => 'Resource restored';

  @override
  String get messageReportUpdatedTitle => 'Report updated';

  @override
  String get messagePluginApprovedTitle => 'Plugin approved';

  @override
  String get messagePluginRelistedTitle => 'Plugin relisted';

  @override
  String get messagePluginRejectedTitle => 'Plugin needs changes';

  @override
  String get messagePluginDelistedTitle => 'Plugin delisted';

  @override
  String get messageCollectionApprovedTitle => 'Collection approved';

  @override
  String get messageCollectionRejectedTitle => 'Collection needs changes';

  @override
  String get messageCoinAddedTitle => 'Coins added';

  @override
  String get messageCoinDeductedTitle => 'Coins deducted';

  @override
  String get messageCoinReversedTitle => 'Coin transaction reversed';

  @override
  String get messageCoinVoteRevokedTitle => 'Coin contribution revoked';

  @override
  String get messageAppealOverturnedTitle => 'Appeal accepted';

  @override
  String get messageAppealUpheldTitle => 'Original decision upheld';

  @override
  String get messageAppealDismissedTitle => 'Appeal dismissed';

  @override
  String get messageAccountBannedTitle => 'Account suspended';

  @override
  String get messageAccountUnbannedTitle => 'Account suspension lifted';

  @override
  String get messageCreatorFrozenTitle => 'Creator access frozen';

  @override
  String get messageCreatorUnfrozenTitle => 'Creator access restored';

  @override
  String get messageRoleChangedTitle => 'Account role changed';

  @override
  String get messageRoleUser => 'user';

  @override
  String get messageRoleReviewer => 'reviewer';

  @override
  String get messageRoleAdministrator => 'administrator';

  @override
  String get messageApprovedBody => 'Your submission passed review.';

  @override
  String get messageNeedsChangesBody =>
      'Review found issues that require changes.';

  @override
  String messageReasonBody(String reason) {
    return 'Reason: $reason';
  }

  @override
  String messageReviewNoteBody(String note) {
    return 'Review note: $note';
  }

  @override
  String get messageStatusChangedBody => 'The status of this item has changed.';

  @override
  String messageReportStatusBody(String status) {
    return 'Report status: $status';
  }

  @override
  String messageCoinAddedBody(String amount) {
    return '$amount coins were added to your account.';
  }

  @override
  String messageCoinDeductedBody(String amount) {
    return '$amount coins were deducted from your account.';
  }

  @override
  String messageCoinVoteRevokedBody(String amount) {
    return 'Your contribution of $amount coins to this resource was revoked.';
  }

  @override
  String get messageAppealOverturnedBody =>
      'The administrator reversed the original decision.';

  @override
  String get messageAppealUpheldBody =>
      'The original decision remains unchanged after review.';

  @override
  String get messageAppealDismissedBody => 'The appeal was not accepted.';

  @override
  String messageRoleChangedBody(String role) {
    return 'Your account role is now $role.';
  }

  @override
  String get cleanMode => 'Feature switches';

  @override
  String get cleanModeDescription =>
      'Manage main navigation, community features, and resource sources';

  @override
  String get cleanPluginsEntry => 'Plugins entry';

  @override
  String get cleanSourceHuamiAppStore => 'Amazfit App Store';

  @override
  String get announcementAcknowledge => 'Got it';

  @override
  String get cleanHomeFeed => 'Home feed';

  @override
  String get cleanExplore => 'Resource library';

  @override
  String get cleanInbox => 'Inbox';

  @override
  String get cleanAnnouncements => 'Announcement popups';

  @override
  String get cleanComments => 'Comments';

  @override
  String get cleanCreator => 'Creator center';

  @override
  String get cleanBandBbsLogin => 'BandBBS sign-in';

  @override
  String get cleanGitHubLogin => 'GitHub sign-in';

  @override
  String get cleanSourceOronBox => 'OronBox source';

  @override
  String get cleanSourceBandBbs => 'BandBBS source';

  @override
  String get cleanSourceAstroBox => 'AstroBox source';

  @override
  String get cleanExploreEntry => 'Explore entry';

  @override
  String get cleanNavigationGroup => 'Main navigation';

  @override
  String get cleanExploreContentGroup => 'Explore content';

  @override
  String get cleanHomeSectionsGroup => 'Home sections';

  @override
  String get cleanHomeBanner => 'Banner carousel';

  @override
  String get cleanHomeEditorSections => 'Editor sections';

  @override
  String get cleanResourceSourcesGroup => 'Resource sources';

  @override
  String get cleanCommunityGroup => 'Community features';

  @override
  String get settingsCategoryAccounts => 'Accounts and authorization';

  @override
  String get settingsCategoryAppearance => 'Appearance and navigation';

  @override
  String get settingsCategoryConnection => 'Connections and downloads';

  @override
  String get settingsCategorySupport => 'Support and information';

  @override
  String get settingsCategoryAdvanced => 'Advanced settings';

  @override
  String get settingsAdvancedDescription => 'View logs and developer tools';

  @override
  String get debugServerTitle => 'Debug service';

  @override
  String get debugServerDescription =>
      'Expose a local API for trusted development tools';

  @override
  String get debugServerEnable => 'Enable debug service';

  @override
  String get debugServerEnableDescription =>
      'Allow approved clients on the local network to inspect and control OronBox';

  @override
  String get debugServerEndpoint => 'Endpoint';

  @override
  String get debugServerFingerprint => 'Server fingerprint';

  @override
  String get debugServerPendingClients => 'Pending approvals';

  @override
  String get debugServerAuthorizedClients => 'Approved clients';

  @override
  String get debugServerApprove => 'Approve';

  @override
  String get debugServerReject => 'Reject';

  @override
  String get debugServerRevoke => 'Revoke access';

  @override
  String get debugServerNoPendingClients =>
      'No clients are waiting for approval';

  @override
  String get debugServerNoAuthorizedClients => 'No approved clients';

  @override
  String get debugServerSecurityNotice =>
      'Only enable this service on a trusted network';

  @override
  String get debugServerStartFailed => 'Could not start the debug service';

  @override
  String get debugServerStopFailed => 'Could not stop the debug service';

  @override
  String get xmsDeveloperMode => 'XMS developer mode';

  @override
  String get xmsDeveloperModeDescription =>
      'Allow Android app signatures to differ';

  @override
  String get oronBoxCoinsTitle => 'Resource coins';

  @override
  String oronBoxCoinsBalance(String balance) {
    return 'Coin balance: $balance';
  }

  @override
  String get oronBoxCoinsCheckin => 'Check in';

  @override
  String get oronBoxCoinsCheckedIn => 'Checked in';

  @override
  String oronBoxCoinsCheckinReward(int count) {
    return 'Received $count coins';
  }

  @override
  String get oronBoxCoinsDescription =>
      'Check in daily for 1–5 coins and use them to support creators';

  @override
  String resourceFromCollection(String name) {
    return 'From collection $name';
  }

  @override
  String get resourceCoin => 'Coin';

  @override
  String get resourceCoinNotSignedIn => 'Not signed in';

  @override
  String get resourceCoinDialogTitle => 'Coin this resource';

  @override
  String get resourceCoinDialogMessage =>
      'Coin this resource?\nThis action cannot be undone\n\nCoins help the resource receive more exposure\nThe creator receives 10% of the contributed amount\nCheck in at Settings - BandBBS account to earn coins';

  @override
  String get resourceCoinOne => 'Give 1 coin';

  @override
  String get resourceCoinTwo => 'Give 2 coins';

  @override
  String resourceCoinCount(int count) {
    return '$count coins';
  }

  @override
  String get resourceCoinSuccess => 'Coin sent';

  @override
  String get resourceCoinVoted => 'Coined';

  @override
  String get resourceFeatured => 'Featured';

  @override
  String get resourceCollection => 'Collection';

  @override
  String resourceCollectionType(String type) {
    return '$type Collection';
  }

  @override
  String get creatorCollections => 'Resource collections';

  @override
  String get creatorCollectionTag => 'Collection';

  @override
  String get creatorNewCollection => 'New collection';

  @override
  String get creatorMoveToCollection => 'Move to collection';

  @override
  String creatorMoveToCollectionConfirm(int count) {
    return 'Move the $count selected resources into this collection?';
  }

  @override
  String get creatorDissolveCollection => 'Dissolve collection';

  @override
  String get creatorResourceList => 'Resources';

  @override
  String get creatorAdditionalLinks => 'Additional links';

  @override
  String get creatorAddLink => 'Add link';

  @override
  String get creatorLinkTitle => 'Link name';

  @override
  String get creatorLinkUrl => 'Link URL';

  @override
  String get creatorCollectionName => 'Collection name';

  @override
  String get creatorCollectionSummary => 'Collection summary';

  @override
  String get creatorCollectionRepresentative => 'Representative resource';

  @override
  String get creatorCollectionDeleteConfirm =>
      'Delete this collection? Its resources will only be unlinked.';

  @override
  String get creatorContentAttributes => 'Content attributes';

  @override
  String get creatorConfirm => 'Confirm';

  @override
  String get creatorCollectionAddResource => 'Add to collection';

  @override
  String creatorCollectionResourceCount(int count) {
    return '$count resources';
  }

  @override
  String communityImportSelected(int count) {
    return '$count selected';
  }

  @override
  String get communityImportResultCreated => 'Draft created';

  @override
  String get communityImportResultFailed => 'Failed';

  @override
  String get communityImportUnsupported => 'This type cannot be imported yet';

  @override
  String get communityImportDuplicate => 'Already exists in the creator center';

  @override
  String get communityImportNoArtifacts => 'No importable resource files';

  @override
  String get creatorImportExternal =>
      'Import existing resources from other platforms';

  @override
  String get creatorNewResourceDescription =>
      'Create and maintain a resource from OronBox';

  @override
  String get creatorNewCollectionDescription =>
      'Create a collection for related resources';

  @override
  String get creatorImportExternalDescription =>
      'Experimental: import your existing resources from BandBBS or AstroBox-Repo';

  @override
  String get creatorImportAlreadyImported => 'Imported and linked';

  @override
  String get creatorImportReviewNotice =>
      'Imported content may be incomplete or misidentified. Review and adjust every field before submitting.';

  @override
  String get creatorImportLogTitle => 'Processing log';

  @override
  String get communityImportPickerEmpty => 'No resources';

  @override
  String get creatorWizardChooseAction => 'Create';

  @override
  String get creatorImportSelectTitle => 'Select resources';

  @override
  String get creatorImportProgressTitle => 'Importing';

  @override
  String get creatorImportResultTitle => 'Import result';

  @override
  String get creatorImportGitHubHint =>
      'Connect GitHub to list your AstroBox resources';

  @override
  String get creatorImportGitHubConnect => 'Connect GitHub';

  @override
  String get creatorImportStageDetails => 'Fetching details';

  @override
  String get creatorImportStageDownloading => 'Downloading files';

  @override
  String get creatorImportStageMedia => 'Processing images';

  @override
  String get creatorImportStageUploading => 'Creating draft';

  @override
  String get creatorImportContinue => 'Import another';

  @override
  String get creatorImportPartialFailureTitle =>
      'Some resources could not be read';

  @override
  String creatorImportPartialFailureMessage(int count) {
    return '$count resource(s) could not be read\nYou can retry the failed items or continue with the resources that were read successfully';
  }

  @override
  String get creatorImportRetryFailed => 'Retry failed items';

  @override
  String get creatorImportContinuePartial => 'Continue anyway';

  @override
  String creatorImportWarnings(int count) {
    return '$count warnings';
  }

  @override
  String get creatorDeleteExternalBandbbs =>
      'Also delete the BandBBS resources';

  @override
  String get creatorDeleteExternalAstrobox =>
      'Also submit a deletion PR to AstroBox-Repo';

  @override
  String get creatorDeleteExternalWarning =>
      'External deletions cannot be undone';

  @override
  String get creatorDeletePrSubmitted => 'Deletion PR submitted';

  @override
  String githubCdnFallback(Object cdn) {
    return 'GitHub request failed, retrying via $cdn';
  }

  @override
  String get deviceConnectBle => 'Connect via BLE';

  @override
  String get deviceConnectBtClassic => 'Connect via BT Classic';

  @override
  String bandBbsIdLabel(Object id) {
    return 'BandBBS ID $id';
  }

  @override
  String get oobeCdnTestFailed => 'Failed';

  @override
  String get settingsGithubCdnAuto => 'Auto';

  @override
  String get updateDownloading => 'Downloading update';

  @override
  String get updateInstalling => 'Installing update';

  @override
  String get updateFailed => 'Update failed';

  @override
  String updateNoApkForAbi(String abi) {
    return 'No APK is available for ABI $abi';
  }

  @override
  String get cleanUpdateGroup => 'Updates';

  @override
  String get cleanCheckUpdates => 'Check for updates on launch';

  @override
  String get updateLater => 'Later';

  @override
  String get updateNow => 'Update now';

  @override
  String get updateGoToPage => 'Go to download page';

  @override
  String get updateDownloadFromCloud => 'Download from cloud drive';

  @override
  String get updateDownloadFromOfficial => 'Download from official website';

  @override
  String get creatorImportNoticeTitle => 'Import existing resources';

  @override
  String get creatorImportNoticeMessage =>
      'Resources supporting multiple devices may be published to multiple BandBBS sections\nYou can select multiple BandBBS entries when importing, but select entries from the same resource\nClick Import to merge the selected entries into one resource\nIf the import fails, open the corresponding draft and delete it\nDeleting a draft will not delete resources linked on other platforms';

  @override
  String get creatorImportNoticeConfirm => 'Continue import';

  @override
  String get creatorImportSameResourceHint =>
      'Select only one resource for each import';

  @override
  String get creatorFullVersionExternalPurchase => 'Requires external purchase';

  @override
  String get creatorExternalPurchaseDescription =>
      'OronBox and AstroBox will publish the resource files as a trial version with a purchase button, while BandBBS publishes it as a \"Third-party purchase\" resource. You are responsible for handling payment-related matters yourself';

  @override
  String get creatorExternalPurchaseLink => 'Purchase link';

  @override
  String get creatorExternalPurchaseAmount => 'Amount (CNY)';

  @override
  String get creatorExternalPurchaseLinkRequired =>
      'Enter a valid external purchase link';

  @override
  String get creatorExternalPurchaseAmountRequired =>
      'Enter a valid CNY amount';

  @override
  String get resourcePurchaseFullVersion => 'External purchase';

  @override
  String get creatorBandBbsOverwritePrevious => 'Overwrite previous submission';

  @override
  String get creatorBandBbsOverwritePreviousDescription =>
      'Create the new version first, then delete the previous BandBBS submission';

  @override
  String get deviceAboutTitle => 'About device';

  @override
  String get deviceValueUnavailable => 'Not provided';

  @override
  String get deviceHealthActivityOverview => 'Activity overview';

  @override
  String get deviceHealthActiveCalories => 'Active calories';

  @override
  String get deviceHealthStanding => 'Standing';

  @override
  String get deviceHealthBloodOxygen => 'Blood oxygen';

  @override
  String get deviceHealthStress => 'Stress';

  @override
  String get deviceHealthVitality => 'Vitality';

  @override
  String get deviceHealthWorkout => 'Workouts';

  @override
  String get deviceHealthTodayTotal => 'Today\'s total';

  @override
  String get deviceHealthRecordCount => 'records';

  @override
  String get deviceHealthNoDetailedRange => 'No detailed range';

  @override
  String get deviceHealthActivityTrend => 'Activity trend';

  @override
  String get deviceHealthTrend => 'Trend';

  @override
  String get deviceHealthDayView => 'Day';

  @override
  String get deviceHealthWeekView => 'Week';

  @override
  String get deviceHealthMonthView => 'Month';

  @override
  String get deviceHealthLatest => 'Latest';

  @override
  String get deviceHealthAverage => 'Average';

  @override
  String get deviceHealthRange => 'Range';

  @override
  String get deviceHealthNoSamples => 'No detailed samples';

  @override
  String get deviceHealthCurrentVitality => 'Current vitality';

  @override
  String get deviceHealthLightIntensity => 'Light intensity';

  @override
  String get deviceHealthModerateHighIntensity => 'Moderate to high intensity';

  @override
  String get deviceHealthNoSleep => 'No sleep data';

  @override
  String get deviceHealthNoWorkouts => 'No workout records';

  @override
  String get deviceHealthSleepStages => 'Sleep stages';

  @override
  String get deviceHealthSleepHrv => 'Sleep HRV';

  @override
  String get deviceHealthSleepAwake => 'Awake';

  @override
  String get deviceHealthSleepLight => 'Light';

  @override
  String get deviceHealthSleepDeep => 'Deep';

  @override
  String get deviceHealthSleepRem => 'REM';

  @override
  String get deviceHealthSleepNoStages => 'No sleep stage data';

  @override
  String deviceHealthStepValue(Object value) {
    return '$value steps';
  }

  @override
  String get deviceHealthFeatureDescription =>
      'View activity, heart rate, blood oxygen, stress, and sleep data';

  @override
  String get weatherSyncTitle => 'Weather sync';

  @override
  String get weatherSyncDescription =>
      'Select a city and sync current weather and forecasts';

  @override
  String get weatherAutoSyncTitle => 'Automatically sync weather data';

  @override
  String get weatherAutoSyncDescription =>
      'Automatically synchronize weather data when synchronizing device data';

  @override
  String get alarmManagementTitle => 'Alarm management';

  @override
  String get alarmManagementDescription =>
      'Add, edit, enable, or delete device alarms';

  @override
  String get findDeviceDescription =>
      'Make the device vibrate or ring continuously';

  @override
  String get appOrderTitle => 'App order';

  @override
  String get appOrderDescription =>
      'Drag to reorder apps in the device launcher';

  @override
  String get appOrderSaved => 'App order saved';

  @override
  String get appOrderReload => 'Reload';

  @override
  String get appOrderUndo => 'Undo changes';

  @override
  String get appOrderSaving => 'Saving…';

  @override
  String get appOrderSave => 'Save changes';

  @override
  String get appOrderEmpty => 'The device returned no reorderable apps';

  @override
  String get appLayoutTitle => 'App layout';

  @override
  String get appLayoutDescription =>
      'Choose how the device app list is displayed';

  @override
  String get appLayoutLoadFailed => 'Unable to load app layout';

  @override
  String get appLayoutList => 'List';

  @override
  String get appLayoutGrid => 'Grid';

  @override
  String get appLayoutTextGrid => 'Grid with labels';

  @override
  String get firmwareUpdateDescription =>
      'Check for updates or install local firmware';

  @override
  String get deviceAboutDescription =>
      'View model, system version, storage, and device identifiers';

  @override
  String get alarmAdd => 'Add alarm';

  @override
  String get alarmEdit => 'Edit alarm';

  @override
  String get alarmHour => 'Hour';

  @override
  String get alarmMinute => 'Minute';

  @override
  String get alarmRepeat => 'Repeat';

  @override
  String get alarmOnce => 'Once';

  @override
  String get alarmEveryDay => 'Every day';

  @override
  String get alarmWorkdays => 'Workdays';

  @override
  String get alarmHolidays => 'Holidays';

  @override
  String get alarmCustom => 'Custom';

  @override
  String get alarmLabel => 'Label';

  @override
  String get alarmDeleteTitle => 'Delete alarm?';

  @override
  String get alarmWeekly => 'Weekly';

  @override
  String get alarmMonthly => 'Monthly';

  @override
  String get alarmYearly => 'Yearly';

  @override
  String get alarmNoRepeat => 'Does not repeat';

  @override
  String alarmCustomDays(Object days) {
    return 'Week $days';
  }

  @override
  String get weekdayMonShort => 'M';

  @override
  String get weekdayTueShort => 'T';

  @override
  String get weekdayWedShort => 'W';

  @override
  String get weekdayThuShort => 'T';

  @override
  String get weekdayFriShort => 'F';

  @override
  String get weekdaySatShort => 'S';

  @override
  String get weekdaySunShort => 'S';

  @override
  String get weatherCityLabel => 'Sync city';

  @override
  String get weatherCityHint => 'Enter a city name';

  @override
  String get weatherSyncAction => 'Sync weather';

  @override
  String get weatherSyncing => 'Syncing…';

  @override
  String get weatherHumidity => 'Humidity';

  @override
  String get weatherWind => 'Wind';

  @override
  String get weatherAirQuality => 'Air quality';

  @override
  String get weatherAqiGood => 'Good';

  @override
  String get weatherAqiModerate => 'Moderate';

  @override
  String get weatherAqiSensitive => 'Unhealthy for sensitive groups';

  @override
  String get weatherAqiUnhealthy => 'Unhealthy';

  @override
  String get weatherAqiVeryUnhealthy => 'Very unhealthy';

  @override
  String get weatherAqiHazardous => 'Hazardous';

  @override
  String get weatherUv => 'UV index';

  @override
  String get weatherPressure => 'Pressure';

  @override
  String get weatherNext24Hours => 'Next 24 hours';

  @override
  String get weatherNext7Days => 'Next 7 days';

  @override
  String weatherDataSource(Object source) {
    return 'Data source: $source';
  }

  @override
  String weatherLevelDirection(Object level, Object direction) {
    return 'Level $level · $direction';
  }

  @override
  String weatherLevelDirectionCompact(Object level, Object direction) {
    return 'Level $level $direction';
  }

  @override
  String weatherForecastSummary(
    Object condition,
    Object sunrise,
    Object sunset,
  ) {
    return '$condition · Sunrise $sunrise · Sunset $sunset';
  }

  @override
  String get weatherClear => 'Clear';

  @override
  String get weatherPartlyCloudy => 'Partly cloudy';

  @override
  String get weatherCloudy => 'Cloudy';

  @override
  String get weatherLightRain => 'Light rain';

  @override
  String get weatherHeavyRain => 'Heavy rain';

  @override
  String get weatherThunderstorm => 'Thunderstorm';

  @override
  String get weatherSnow => 'Snow';

  @override
  String get weatherFog => 'Fog';

  @override
  String get weatherUnknown => 'Unknown';

  @override
  String get weatherUnknownDate => 'Unknown date';

  @override
  String weatherUpdatedAt(Object time) {
    return 'Updated $time';
  }

  @override
  String get windNorth => 'N';

  @override
  String get windNorthEast => 'NE';

  @override
  String get windEast => 'E';

  @override
  String get windSouthEast => 'SE';

  @override
  String get windSouth => 'S';

  @override
  String get windSouthWest => 'SW';

  @override
  String get windWest => 'W';

  @override
  String get windNorthWest => 'NW';

  @override
  String get xiaomiScreenshotTitle => 'Device screenshot';

  @override
  String get xiaomiScreenshotDescription =>
      'Use the wearable\'s key combination to take a screenshot; it will sync here automatically';

  @override
  String get xiaomiScreenshotAction => 'Capture screenshot';

  @override
  String get xiaomiScreenshotLoading => 'Capturing screenshot…';

  @override
  String get xiaomiScreenshotEmpty => 'No screenshot yet';

  @override
  String get xiaomiScreenshotFailed => 'Screenshot failed';

  @override
  String xiaomiScreenshotSaved(Object path) {
    return 'Watch screenshot saved to: $path';
  }
}
