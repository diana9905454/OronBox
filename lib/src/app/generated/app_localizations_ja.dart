// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get homeTab => 'ホーム';

  @override
  String get exploreTab => '探索';

  @override
  String get devicesTab => 'デバイス';

  @override
  String get pluginsTab => 'プラグイン';

  @override
  String get pluginImport => 'プラグインをインポート';

  @override
  String get pluginInstalled => 'インストール済み';

  @override
  String get pluginMarket => 'プラグインマーケット';

  @override
  String get pluginMarketUnavailable => 'プラグインマーケットはまだ利用できません';

  @override
  String get pluginEmpty => 'インストール済みのプラグインはありません';

  @override
  String get pluginSelectHint => 'プラグインを選択して機能を表示';

  @override
  String get pluginFeatures => '機能';

  @override
  String get pluginDetails => '詳細';

  @override
  String get pluginNoFeatures => '利用可能な機能はありません';

  @override
  String get pluginAuthor => '作成者';

  @override
  String get pluginVersion => 'バージョン';

  @override
  String get pluginApiLevel => 'APIレベル';

  @override
  String get pluginWebsite => 'ウェブサイト';

  @override
  String get pluginPermissions => '権限';

  @override
  String get pluginInstallConfirmTitle => 'プラグインのインストールを確認';

  @override
  String get pluginUpdateConfirmTitle => 'プラグインの更新を確認';

  @override
  String get pluginDeclaredPermissions => 'このプラグインは次の権限を宣言しています：';

  @override
  String get pluginNoPermissions => '権限は宣言されていません';

  @override
  String get pluginUpToDate => '最新版がインストールされています';

  @override
  String get pluginUninstallTitle => 'プラグインをアンインストール';

  @override
  String get pluginUninstallMessage => 'プラグインのデータも削除されます';

  @override
  String get pluginUpload => 'プラグインをアップロード';

  @override
  String get pluginPublishTitle => 'プラグインを公開';

  @override
  String get pluginPublishNew => '新しいプラグインとして公開';

  @override
  String get pluginPublishUpdate => '同じIDの公開済みプラグインを更新';

  @override
  String get pluginTakedown => '非公開にする';

  @override
  String get pluginTakedownConfirm => 'このプラグインをマーケットから完全に削除します';

  @override
  String get pluginLoginRequired => 'プラグインをアップロードするにはログインしてください';

  @override
  String get pluginSubmittedForReview => '審査に送信しました。承認後に掲載されます';

  @override
  String get pluginStatePending => '審査中';

  @override
  String get pluginStateRejected => '却下';

  @override
  String get pluginStateDelisted => '非公開';

  @override
  String get pluginLegacyWarningTitle => '旧形式のプラグイン';

  @override
  String get pluginLegacyWarningMessage =>
      'これはAstroBox v1プラグインです。OronBoxは互換モードで実行しますが、問題が発生する可能性があります。\\nOronBoxネイティブ版への更新を確認するか、作者に対応を依頼してください';

  @override
  String get settingsTab => '設定';

  @override
  String get search => '検索';

  @override
  String get resourceListView => 'リスト表示';

  @override
  String get resourceGridView => 'カード表示';

  @override
  String get refresh => '更新';

  @override
  String get refreshing => '更新中';

  @override
  String get notifications => '通知';

  @override
  String get newlyPublished => '新着';

  @override
  String get resourceLibrary => 'リソースライブラリ';

  @override
  String get resourceDetails => 'リソース詳細';

  @override
  String get resourceCollectionDetails => 'コレクション詳細';

  @override
  String get resourceArticleDetails => '記事詳細';

  @override
  String get creatorCenter => 'クリエイターセンター';

  @override
  String get creatorNewResource => '新しいリソース';

  @override
  String get creatorResourceName => 'リソース名';

  @override
  String get creatorResourceSummary => 'リソース概要';

  @override
  String get creatorResourceMetadataRequired => 'リソース名と概要は必須です';

  @override
  String get creatorSubmitValidationFailed => '送信前に次の項目を確認してください';

  @override
  String get creatorPaidType => '支払いタイプ';

  @override
  String get creatorSaveDraft => '下書きを保存';

  @override
  String get creatorAddArtifact => 'リソースファイルを追加';

  @override
  String get creatorBindDevices => 'デバイスを紐付け';

  @override
  String get creatorDeleteResource => '削除';

  @override
  String get creatorIconCover => 'アイコンとカバー';

  @override
  String get creatorInvalidImage => '画像を読み込めません。PNG/JPEG/WebPを使用してください';

  @override
  String get creatorInvalidPackage => 'Velaクイックアプリまたは文字盤ではありません';

  @override
  String creatorPublishPreparing(Object done, Object total) {
    return 'ファイルを処理中 $done/$total';
  }

  @override
  String creatorPublishUploading(Object percent) {
    return 'アップロード中 $percent%';
  }

  @override
  String get creatorPublishServer => 'サーバーで処理中…';

  @override
  String get creatorAstroBoxItemId => 'アイテムID';

  @override
  String get creatorAstroBoxRepository => 'リポジトリ名';

  @override
  String get creatorAstroBoxTags => 'タグ（カンマ区切り）';

  @override
  String get creatorAstroBoxAuthor => '作者（AstroBoxユーザー名と一致）';

  @override
  String get creatorAstroBoxBindAccount => 'AstroBoxアカウントを連携';

  @override
  String get replace => '置換';

  @override
  String get delete => '削除';

  @override
  String get creatorSubmitReview => '送信';

  @override
  String get creatorArchiveAction => '非公開';

  @override
  String get creatorArchiveConfirm => '非公開にするとストアから隠れます。いつでも再公開できます';

  @override
  String get creatorRestoreAction => '再公開';

  @override
  String get creatorDeleteConfirm => 'この下書きリソースを完全に削除します';

  @override
  String get creatorDeletePublishedConfirm =>
      'OronBoxリソースと対応するBandBBSリソースを完全に削除します。この操作は取り消せません。AstroBoxで公開済みの内容には影響しません。非公開はAstroBox-Repoの管理者に依頼してください';

  @override
  String creatorArtifactCount(Object count) {
    return '$count個のパッケージ';
  }

  @override
  String creatorKindMismatchMessage(Object detected, Object expected) {
    return 'このファイルは$detectedのようですが、リソースは$expectedです。保持できますが、審査送信前に確認してください';
  }

  @override
  String creatorDeviceMoveBlocked(Object name) {
    return '「$name」にはこのデバイスしか紐付いていないため移動できません';
  }

  @override
  String get creatorSelectDevices => '対応デバイスを選択';

  @override
  String creatorSelectedDeviceCount(Object count) {
    return '$count台を選択';
  }

  @override
  String get creatorNoDevicesSelected => 'デバイスが選択されていません';

  @override
  String get creatorDeviceSelectionDone => '完了';

  @override
  String get creatorAtLeastOneDevice => '各リソースファイルには少なくとも1台のデバイスを紐付けてください';

  @override
  String get resourceAstroBoxEncryptedTitle => 'OronBoxはこのAstroBoxリソースを処理できません';

  @override
  String get resourceAstroBoxEncryptedMessage =>
      'このリソースはAstroBox Creator Consoleの非公開暗号化アップロードを使用しています。OronBoxでは復号、ダウンロード、インストールできません。AstroBoxで開いてください';

  @override
  String get resourceAstroBoxEncryptedAction => '了解';

  @override
  String get filter => 'フィルター';

  @override
  String get resourceTypeFilter => 'リソースの種類';

  @override
  String get resourceCompatibleDevicesFilter => '対応デバイス';

  @override
  String get currentDevice => '現在のデバイス';

  @override
  String get currentWatchface => '現在の文字盤';

  @override
  String get all => 'すべて';

  @override
  String get watchfaces => '文字盤';

  @override
  String get module => 'モジュール';

  @override
  String get quickApps => 'クイックアプリ';

  @override
  String get firmwareTools => 'ファームウェア / ツール';

  @override
  String get oronBox => 'OronBox';

  @override
  String get bandbbs => 'BandBBS';

  @override
  String get astroBox => 'AstroBox';

  @override
  String get local => 'ローカル';

  @override
  String get install => 'インストール';

  @override
  String get update => '更新';

  @override
  String get description => '説明';

  @override
  String get supportedDevices => '対応デバイス';

  @override
  String get downloads => 'ダウンロード';

  @override
  String downloadTimes(int count) {
    return '$count回ダウンロード';
  }

  @override
  String get changelog => '更新履歴';

  @override
  String get changelogUnavailable => '更新履歴はありません';

  @override
  String get notFound => '見つかりません';

  @override
  String get downloadStarted => 'ダウンロードを開始';

  @override
  String get compatible => '対応：';

  @override
  String get incompatible => '非対応：';

  @override
  String get incompatibleSuffix => '';

  @override
  String get myResources => 'マイリソース';

  @override
  String get drafts => '下書き';

  @override
  String get pendingReview => '審査中';

  @override
  String get published => '公開済み';

  @override
  String get creatorStateSuspended => '非公開';

  @override
  String get creatorStateFrozen => '凍結';

  @override
  String get creatorSuspendedByOwnerNotice =>
      'このリソースは非公開です。編集して審査に再送するか、直接再公開してください';

  @override
  String get creatorSuspendedByAdminNotice =>
      '管理者がこのリソースを非公開にしました。編集して審査に再送してください。承認後に再公開されます';

  @override
  String get creatorFrozenNotice => '管理者がこのリソースを凍結しました。編集できず、解除できるのは管理者のみです';

  @override
  String creatorModerationReason(Object reason) {
    return '理由：$reason';
  }

  @override
  String get creatorBannedTitle => 'アカウント停止';

  @override
  String get creatorBannedDescription =>
      '管理者によりアカウントが停止され、クリエイターセンターを利用できません。誤りと思われる場合はサポートチケットでチームに連絡してください';

  @override
  String get creatorFrozenTitle => 'クリエイター機能の凍結';

  @override
  String get creatorFrozenDescription =>
      '管理者によりクリエイター機能が凍結されているため、現在リソースの送信や管理はできません。その他のアカウント機能には影響しません';

  @override
  String get creatorBandBbsNoDevices => '先にリソースファイルへ対応デバイスを選択してください';

  @override
  String creatorBandBbsUnmappedDevices(Object devices) {
    return '対応するBandBBSカテゴリーが見つかりません：$devices';
  }

  @override
  String get creatorBandBbsSharedCategory =>
      '同じBandBBSカテゴリーのデバイスが複数パッケージに紐付いています。カテゴリーごとに1つのパッケージを紐付けてください';

  @override
  String get creatorBandBbsUnresolved => 'BandBBSカテゴリーを解決できません';

  @override
  String get creatorOptionalIcon => 'アイコン（任意、1:1）';

  @override
  String get creatorOptionalCover => 'カバー（任意、3:2）';

  @override
  String get creatorRequiredIcon => 'アイコン（AstroBox必須、1:1）';

  @override
  String get creatorRequiredCover => 'カバー（AstroBox必須、3:2）';

  @override
  String get creatorIconShapeHint =>
      'アイコンが正方形ではないため、AstroBoxで正しく表示されない可能性があります';

  @override
  String get creatorCoverShapeHint =>
      'カバーが3:2ではないため、AstroBoxで正しく表示されない可能性があります';

  @override
  String get creatorTermsBandBbs => 'BandBBSコミュニティの利用規約とルール';

  @override
  String get creatorTermsAstroBox => 'AstroBox-Repo投稿基準';

  @override
  String get creatorTermsAccept => '上記の公開規約を読み、同意します';

  @override
  String get creatorTermsContinue => 'クリエイターセンターへ';

  @override
  String get agree => '同意する';

  @override
  String get creatorRulesAccept => '上記の審査ルールを読み、同意します';

  @override
  String get creatorBandBbsTermsNotice =>
      'OronBoxの審査後、リソースは対応するBandBBSカテゴリーへ直接公開されます。OronBoxリソースを削除すると対応するBandBBSリソースも削除されます';

  @override
  String get creatorBandBbsLimitsNotice =>
      'BandBBSへのワンクリック公開には次の制限があります。公開後に手動で修正してください：\\n1. BandBBSにはリソースアイコンのアップロードAPIがないため、アイコンが空欄になります。BandBBSサイトで手動更新してください\\n2. BandBBSにはディスカッションフォーラムタグのAPIがないため、フォーラム属性が設定されず削除される可能性があります。BandBBSサイトで正しいフォーラムを手動設定してください';

  @override
  String get creatorAstroBoxTermsNotice =>
      'OronBoxの審査後、リポジトリを作成し公式AstroBoxリポジトリへPRを送信します。審査はAstroBox管理者が独立して行います。公開後の非公開はAstroBox-Repo管理者に依頼してください';

  @override
  String get creatorAstroBoxReviewNotice =>
      'AstroBoxへ公開するリソースは次の審査要件を満たす必要があります：\\n1. わいせつ、政治的に敏感、その他違法な内容を含まないこと\\n2. テンプレートを置き換えただけの文字盤や単純すぎるクイックアプリなど、品質が低すぎないこと\\n3. カバーは魅力的で3:2比率（推奨1200x800）、アイコンは192x192を推奨\\n4. 対応デバイスで基本機能が正常に動作すること\\n5. 許可なく他者のリソースをアップロードしないこと\\n6. 有名IPの素材を使用する場合、AstroBoxおよびXiaomiとは無関係であることを示す著作権表示画像をプレビューに含めること';

  @override
  String get failed => '失敗 / 要対応';

  @override
  String get basicInfo => '基本情報';

  @override
  String get packageFiles => 'リソースファイル';

  @override
  String get publishTargets => '公開先';

  @override
  String get scan => 'スキャン';

  @override
  String get logs => 'ログ';

  @override
  String get pairedDevices => 'ペアリング済みデバイス';

  @override
  String get apps => 'アプリ';

  @override
  String get deviceAppCount => 'アプリ数';

  @override
  String get deviceWatchfaceCount => '文字盤数';

  @override
  String get connection => '接続';

  @override
  String get protocol => 'プロトコル';

  @override
  String get error => 'エラー';

  @override
  String get errorBluetoothUnavailable =>
      'Bluetoothを利用できません。Bluetoothが有効で、OronBoxに使用許可があることを確認してください';

  @override
  String get errorBluetoothConnectFailed =>
      '接続に失敗しました。Bluetooth権限を確認し、デバイスを近くに置いて使用中でない状態にし、デバイスで「新しいスマホに接続」を有効にしてから再試行してください';

  @override
  String get errorBluetoothDisconnected =>
      'Bluetoothが切断されました。デバイスを再接続して再試行してください';

  @override
  String get errorOperationTimeout =>
      '操作がタイムアウトしました。デバイスが近くにあることを確認して再試行してください';

  @override
  String get errorDeviceNotReady => 'デバイスの準備ができていません。先に接続して認証してください';

  @override
  String get errorBleCharacteristicsMissing =>
      '必要なBLEチャンネルが見つかりません。再接続するか、この機能に対応しているか確認してください';

  @override
  String get errorWebSerialUnavailable =>
      'このブラウザーはWeb Serialに対応していません。Chrome、Edgeなど対応ブラウザーを使用してください';

  @override
  String get errorAccountPasswordIncorrect =>
      'Xiaomiアカウントのユーザー名またはパスワードが正しくありません';

  @override
  String get errorAccountTwoFactorIncomplete =>
      'Xiaomiアカウントの2段階認証が完了していません。再度サインインしてください';

  @override
  String get errorXiaomiAccountSessionExpired =>
      'Xiaomiアカウントのセッションが期限切れです。再度サインインしてください';

  @override
  String get errorOronBoxSessionExpired =>
      'OronBoxのセッションが期限切れです。BandBBSに再度サインインしてください';

  @override
  String get errorNetworkUnavailable => 'サービスに接続できません。ネットワークを確認して再試行してください';

  @override
  String get errorServiceUnavailable => 'サービスが一時的に利用できません。後でもう一度お試しください';

  @override
  String get errorPermissionDenied => 'この操作を実行する権限がありません';

  @override
  String get errorContentNotFound => '要求された内容は存在しないか利用できません';

  @override
  String get errorRequestConflict => '内容が変更されました。更新して再試行してください';

  @override
  String get errorCoinBalanceInsufficient => 'コインが不足しています';

  @override
  String get errorCoinResourceLimit => 'このリソースに贈れるコインは最大2枚です';

  @override
  String get errorCoinOwnResource => '自分のリソースにはコインを贈れません';

  @override
  String get errorCoinVotingFrozen => 'コイン投票は現在停止しています';

  @override
  String get errorCoinAccountTooNew => 'コインを贈るにはアカウント作成から24時間以上必要です';

  @override
  String get errorCoinOperationFailed => 'コインを送信できませんでした。再試行してください';

  @override
  String get errorCoinStatusUnavailable => 'コイン状態を取得できません。タップして再試行してください';

  @override
  String get errorOperationFailed => '操作に失敗しました。再試行してください';

  @override
  String get errorUnknown => '問題が発生しました。再試行してください';

  @override
  String get errorDownloadQuotaExceeded => '本日のダウンロード上限に達しました';

  @override
  String get errorGitHubNotConfigured => 'GitHub公開が設定されていません';

  @override
  String get errorRateLimited => 'リクエストが多すぎます。少し待って再試行してください';

  @override
  String get errorFileTooLarge => '選択したファイルが大きすぎます';

  @override
  String get errorInvalidRequest => '入力内容に問題があります。確認して再試行してください';

  @override
  String get errorOperationCancelled => '操作をキャンセルしました';

  @override
  String get errorUnsupportedFileType => '未対応または認識できないファイル形式です';

  @override
  String get errorCertificateVerificationFailed =>
      '証明書の検証に失敗しました。プロキシを使用している場合はHTTPSインターセプトを無効にするか、証明書を信頼してください';

  @override
  String errorUnknownWithDetail(Object detail) {
    return '操作に失敗しました：$detail';
  }

  @override
  String get appearance => '外観';

  @override
  String get resources => 'リソース';

  @override
  String get communitySourceAstroBoxRepo => 'AstroBox';

  @override
  String get communitySourceBandBbs => 'BandBBSコミュニティ';

  @override
  String get communitySourceHuamiAppStore => 'Amazfitアプリストア';

  @override
  String get devices => 'デバイス';

  @override
  String creatorCompatibleDeviceCount(int count) {
    return '$count台のデバイス';
  }

  @override
  String get categories => 'カテゴリー';

  @override
  String get advanced => '詳細設定';

  @override
  String get openSourceLicenses => 'オープンソースライセンス';

  @override
  String get acknowledgements => '謝辞';

  @override
  String get deviceNotConnected => '未接続';

  @override
  String get deviceConnected => '接続済み';

  @override
  String get deviceDisconnected => '切断済み';

  @override
  String get deviceReconnect => '再接続';

  @override
  String get deviceConnect => '接続';

  @override
  String get deviceSwitch => '切り替え';

  @override
  String get deviceSyncTime => '同期';

  @override
  String get deviceCharging => '充電中';

  @override
  String get deviceLastChargedNow => '充電したばかり';

  @override
  String deviceLastChargedMinutes(int count) {
    return '$count分前に充電';
  }

  @override
  String deviceLastChargedHours(int count) {
    return '$count時間前に充電';
  }

  @override
  String deviceLastChargedDays(int count) {
    return '$count日前に充電';
  }

  @override
  String get deviceFeaturesInstallApp => 'アプリをインストール';

  @override
  String get deviceFeaturesInstallWatchface => '文字盤をインストール';

  @override
  String get deviceFeaturesInstallFirmware => 'ファームウェア更新';

  @override
  String get deviceFeaturesInstallFirmwareDesc =>
      'デバイスの更新を確認するか、ローカルファームウェアをインストールします';

  @override
  String get firmwareCheckingUpdates => 'ファームウェア更新を確認中';

  @override
  String get firmwareNoUpdatesFound => 'このデバイスに新しいファームウェアはありません';

  @override
  String get firmwareSourceUnavailable => 'このデバイス種別のオンラインファームウェアソースはまだ利用できません';

  @override
  String get firmwareVersionUnknown => '現在のファームウェアバージョンは不明です';

  @override
  String get firmwareCurrentVersion => '現在のバージョン';

  @override
  String get firmwareLatestRelease => '最新リリース';

  @override
  String get firmwareHistoricalReleases => '過去のファームウェア';

  @override
  String get firmwareUpToDate => 'ファームウェアは最新です';

  @override
  String get firmwareUpdateAvailable => '更新があります';

  @override
  String get firmwareDownloadLatestFull => '最新の完全パッケージをダウンロード';

  @override
  String get firmwareUpdateNow => '更新';

  @override
  String get firmwareReleaseNotes => 'リリースノート';

  @override
  String get firmwareReleaseNotesUnavailable => 'リリースノートはありません';

  @override
  String get download => 'ダウンロード';

  @override
  String get downloadTaskAdded => 'ダウンロードキューに追加しました';

  @override
  String get zeppOsMoreFeatures => '特別な機能';

  @override
  String get zeppOsMoreFeaturesDescription => 'Zepp OSデバイスの追加機能を管理';

  @override
  String get zeppOsDeviceFeaturesSection => 'デバイス機能';

  @override
  String get zeppOsAppsAndDevelopmentSection => 'アプリと開発';

  @override
  String get zeppOsAssistant => 'ボイスラボ';

  @override
  String get zeppOsAssistantDescription => '時計の音声アシスタントセッションを取得、監視、返信';

  @override
  String get zeppOsScreenMirror => '画面ミラーリング';

  @override
  String get zeppOsScreenMirrorDescription => '時計の画面をこのデバイスに表示';

  @override
  String get zeppOsScreenMirrorSemantics => 'Zepp OS時計画面ミラー';

  @override
  String zeppOsScreenMirrorUnsupported(Object error) {
    return 'この画面形式は表示できません：$error';
  }

  @override
  String get expand => '展開';

  @override
  String get collapse => '折りたたむ';

  @override
  String get voiceLabTitle => 'ボイスラボ';

  @override
  String get voiceLabXiaoAi => '小愛';

  @override
  String get voiceLabReceivingAudio => '時計から音声を受信中';

  @override
  String get voiceLabWaiting => '音声セッションを待機中';

  @override
  String get voiceLabContinuousCapture => '継続キャプチャ';

  @override
  String get voiceLabContinuousCaptureDescription => '現在の録音が終わると次の録音を要求';

  @override
  String get voiceLabDisableMonitoring => 'ライブ監視を無効化';

  @override
  String get voiceLabEnableMonitoring => 'ライブ監視を有効化';

  @override
  String get voiceLabReplyLabel => '時計へ返信を送信';

  @override
  String get voiceLabReplyHint => '返信を入力';

  @override
  String get voiceLabReplyQueued => '現在の録音終了後に返信します';

  @override
  String get voiceLabReplySent => '時計へ返信しました';

  @override
  String get voiceLabCapturedData => '取得データ';

  @override
  String get voiceLabDecoder => 'デコーダー';

  @override
  String get voiceLabOpusFrames => 'Opusフレーム';

  @override
  String get voiceLabDataSize => 'データサイズ';

  @override
  String get voiceLabPcmSamples => 'PCMサンプル';

  @override
  String get voiceLabExportOpus => 'Opusを書き出し';

  @override
  String get voiceLabExportWav => 'WAVを書き出し';

  @override
  String get voiceLabClearCapture => '取得データを消去';

  @override
  String get voiceLabSaveRecording => '録音を保存';

  @override
  String get voiceLabSaveOpus => 'Opus音声を保存';

  @override
  String get voiceLabAudioProcessingFailedPrefix => '音声処理に失敗';

  @override
  String voiceLabAudioProcessingFailed(Object error) {
    return '音声処理に失敗しました：$error';
  }

  @override
  String voiceLabContinuousCaptureFailed(Object error) {
    return '継続キャプチャを設定できません：$error';
  }

  @override
  String voiceLabAssistantSwitchFailed(Object error) {
    return '音声アシスタントを切り替えられません：$error';
  }

  @override
  String voiceLabExportWavFailed(Object error) {
    return 'WAVを書き出せません：$error';
  }

  @override
  String voiceLabExportOpusFailed(Object error) {
    return 'Opusを書き出せません：$error';
  }

  @override
  String get send => '送信';

  @override
  String sendFailed(Object error) {
    return '送信できません：$error';
  }

  @override
  String get ready => '準備完了';

  @override
  String get initializing => '初期化中';

  @override
  String get zeppOsMapSelectPackage => 'Zepp OS地図パッケージを選択';

  @override
  String get zeppOsMapReadFailed => '地図パッケージを読み込めません';

  @override
  String get zeppOsMapTransferTitle => 'オフライン地図を転送';

  @override
  String zeppOsMapGarminDetected(Object fileName, Object mapName) {
    return '$fileName\n単一ファイルのGarmin IMG地図を検出：$mapName';
  }

  @override
  String get zeppOsMapGarminNoPreview =>
      'この地図にはZepp OS 11/x/yタイルツリーがありません。元のIMGを単一ファイルの地図パッケージとして転送するため、範囲プレビューは利用できません';

  @override
  String zeppOsMapTileSummary(Object fileName, Object count) {
    return '$fileName · $countタイル\nプレビューはパッケージの範囲であり時計上のGarmin IMG表示ではありません';
  }

  @override
  String get zeppOsMapStartTransfer => '転送開始';

  @override
  String get zeppOsMapTransferringBluetooth => 'Bluetoothで転送中';

  @override
  String get zeppOsMapTransferComplete => 'オフライン地図の転送完了';

  @override
  String get zeppOsMapConversionFailed => '地図を安全に変換できません';

  @override
  String get zeppOsMapBtClassicHint =>
      'BT Classicによる一括転送が有効です。転送開始後、時計でインストールを確認してください';

  @override
  String get zeppOsMapBleHint =>
      'BLEは2MBまでの地図パッケージに対応します。大きな地図は転送前にBT Classicへ切り替えてください。転送開始後、時計でインストールを確認してください';

  @override
  String get zeppOsMapPreviewTooLarge => '地図の範囲が大きすぎるため全体をプレビューできません';

  @override
  String zeppOsSettingPageLoadFailed(Object error) {
    return '設定ページを読み込めません：$error';
  }

  @override
  String zeppOsAppCompatibilitySaved(Object appId) {
    return '$appIdの互換ファイルを保存しました';
  }

  @override
  String zeppOsAppStorageSaved(Object appId) {
    return '$appIdのsettingsStorageを保存しました';
  }

  @override
  String get zeppOsAppSupplementFiles => 'アプリ側または設定ファイルを追加';

  @override
  String get zeppOsAppSupplementCompatibility => 'ミニアプリ互換ファイルを追加';

  @override
  String get zeppOsAppReplaceCompatibility => '互換ファイルを追加または置換';

  @override
  String get zeppOsAppSideAvailable => 'アプリ側 ✓';

  @override
  String get zeppOsAppSideMissing => 'アプリ側なし';

  @override
  String get zeppOsSettingAvailable => '設定 ✓';

  @override
  String get zeppOsSettingMissing => '設定なし';

  @override
  String get zeppOsAppEditStorage => 'settingsStorageを編集';

  @override
  String get zeppOsStorageKeyRequired => 'キーは必須です';

  @override
  String zeppOsStorageDuplicateKey(Object key) {
    return 'キーが重複しています：$key';
  }

  @override
  String get zeppOsStorageDescription =>
      'このデータは設定ページとアプリ側で共有され、Zepp OS仕様に従って文字列として保存されます';

  @override
  String get zeppOsStorageEmpty => '保存された項目はありません';

  @override
  String get zeppOsStorageKey => 'キー';

  @override
  String get zeppOsStorageValue => '値';

  @override
  String get clear => '消去';

  @override
  String get save => '保存';

  @override
  String get selectedFileReadFailed => '選択したファイルを読み込めません';

  @override
  String get zeppOsAppInvalidHexId => '有効な16進数のアプリIDを入力してください';

  @override
  String get zeppOsAppSelectCompatibilityFile =>
      'app-side.jsまたはsetting.jsを1つ以上選択してください';

  @override
  String get zeppOsAppHexId => 'アプリID（16進数）';

  @override
  String get optionalDisplayName => '表示名（任意）';

  @override
  String get zeppOsAppSideUnchanged => '既存のアプリ側を保持';

  @override
  String get zeppOsSettingUnchanged => '既存の設定を保持';

  @override
  String get selectFile => 'ファイルを選択';

  @override
  String get zeppOsAppCompatibilityOverwriteHint =>
      '保存すると同じアプリIDの互換ファイルを置き換えますが、時計上のミニアプリは変更しません';

  @override
  String zeppOsDebugRefreshFailed(Object error) {
    return '自動更新に失敗しました：$error';
  }

  @override
  String get zeppOsDebugInvalidHex => 'HEXはスペース、改行、0x、カンマなどで区切った完全なバイト列にしてください';

  @override
  String get zeppOsDebugClearEventsTitle => '現在のアプリのイベントを消去しますか？';

  @override
  String zeppOsDebugClearEventsDescription(Object appId) {
    return '$appIdのすべてのデバッグイベントを消去します';
  }

  @override
  String get zeppOsDebugClearEvents => 'イベントを消去';

  @override
  String get zeppOsDebugRefresh => '状態とイベントを更新';

  @override
  String get zeppOsDebugAppList => 'アプリ側一覧';

  @override
  String get zeppOsDebugNoApps => 'キャッシュ済みスクリプトまたは時計のアプリ側セッションは検出されませんでした';

  @override
  String get zeppOsDebugCached => 'キャッシュ済み';

  @override
  String get zeppOsDebugNotCached => 'キャッシュなし';

  @override
  String get zeppOsDebugRuntimeRunning => 'ランタイム実行中';

  @override
  String get zeppOsDebugRuntimeStopped => 'ランタイム停止中';

  @override
  String get zeppOsDebugLocalRuntime => 'ローカルランタイム';

  @override
  String get zeppOsDebugCannotStart => 'このアプリIDにはキャッシュ済みスクリプトがないためローカル起動できません';

  @override
  String get zeppOsDebugCanStart => 'キャッシュ済みスクリプトを時計のセッション情報なしで手動起動できます';

  @override
  String get zeppOsDebugScriptRunning => 'スクリプトはローカルQuickJSで実行中です';

  @override
  String get zeppOsDebugStartQuickJs => 'QuickJSを起動';

  @override
  String get stop => '停止';

  @override
  String get zeppOsDebugMessageEditor => 'メッセージエディター';

  @override
  String get zeppOsDebugUtf8Text => 'UTF-8テキスト';

  @override
  String get zeppOsDebugJsonCompact => 'JSON（送信前に圧縮）';

  @override
  String get zeppOsDebugHexBytes => 'HEXバイト';

  @override
  String get zeppOsDebugEncodingFailed => '現在の内容を選択した形式でエンコードできません';

  @override
  String get zeppOsDebugByteCountUnavailable => 'バイト数：--';

  @override
  String zeppOsDebugBytePreview(Object count, Object hex) {
    return 'バイト数：$count\nHEX：$hex';
  }

  @override
  String get zeppOsDebugInjectLocal => 'ローカルランタイムへ受信メッセージを注入';

  @override
  String get zeppOsDebugSendToWatch => '時計へ送信';

  @override
  String get zeppOsDebugWaitingForWatch => '時計へ送信（実セッション待ち）';

  @override
  String get zeppOsDebugEvents => 'デバッグイベント';

  @override
  String get zeppOsDebugClearCurrentApp => '現在のアプリを消去';

  @override
  String get zeppOsDebugSearch => '種類、メッセージ、HEX、または表示テキストを検索';

  @override
  String get zeppOsDebugWatchOnly => '時計からの実メッセージのみ';

  @override
  String get zeppOsDebugNoEvents => '条件に一致するイベントはありません';

  @override
  String get zeppOsDebugMessageActions => 'メッセージ操作';

  @override
  String get zeppOsDebugLoadEditor => 'エディターに読み込む';

  @override
  String get zeppOsDebugCopyHex => 'HEXをコピー';

  @override
  String get zeppOsDebugCopyText => 'テキストをコピー';

  @override
  String get zeppOsDebugSessionStatus => 'ランタイムとセッション状態';

  @override
  String zeppOsDebugCachedScript(Object status) {
    return 'キャッシュ済みスクリプト：$status';
  }

  @override
  String zeppOsDebugLocalRuntimeStatus(Object status) {
    return 'ローカルランタイム：$status';
  }

  @override
  String zeppOsDebugWatchSession(Object status) {
    return '時計セッション：$status';
  }

  @override
  String get exists => '利用可能';

  @override
  String get notExists => '利用不可';

  @override
  String get running => '実行中';

  @override
  String get notRunning => '停止中';

  @override
  String get notOpen => '未開放';

  @override
  String get zeppOsDebugWatchSessionOpen => '実セッションが開いています';

  @override
  String get zeppOsDebugRealHeader => '実ヘッダー';

  @override
  String zeppOsDebugLatestStartup(Object status) {
    return '最新起動状態：$status';
  }

  @override
  String get zeppOsDebugWatchInbound => '時計から';

  @override
  String get zeppOsDebugWatchOutbound => '時計へ';

  @override
  String get zeppOsDebugLifecycle => 'ライフサイクル';

  @override
  String get zeppOsMirrorInterval => 'フレーム間隔';

  @override
  String get zeppOsMirrorIntervalRange => '10–250';

  @override
  String get zeppOsOfflineMaps => 'オフライン地図';

  @override
  String get zeppOsOfflineMapsDescription => '既存の地図パッケージを時計へ転送';

  @override
  String get zeppOsAppSettings => 'アプリ設定';

  @override
  String get zeppOsAppSettingsDescription => 'Zepp OSアプリのキャッシュ済み設定を管理';

  @override
  String get zeppOsAppDebug => 'アプリデバッグ';

  @override
  String get zeppOsAppDebugDescription => 'アプリ側スクリプトとデバイス通信をデバッグ';

  @override
  String get deviceMusicSync => '音楽同期';

  @override
  String get deviceHealthTitle => 'ヘルスケア';

  @override
  String get deviceHealthDescription => 'デバイスの活動量と睡眠データを同期';

  @override
  String get deviceHealthSyncCardTitle => 'ヘルスデータ';

  @override
  String get deviceHealthNeverSynced => 'ヘルスデータはまだ同期されていません';

  @override
  String deviceHealthLastSynced(String time) {
    return '最終同期 $time';
  }

  @override
  String get deviceHealthSync => 'ヘルスデータを同期';

  @override
  String get deviceHealthSyncing => '同期中';

  @override
  String get deviceHealthAutoSyncTitle => 'ヘルスデータを自動同期';

  @override
  String get deviceHealthAutoSyncDescription => 'デバイスデータの同期時にヘルスデータを自動同期';

  @override
  String get deviceHealthConnectFirst => 'ヘルスデータを同期するにはデバイスを接続してください';

  @override
  String get deviceHealthPartialSync => '一部のヘルスデータを同期できませんでした';

  @override
  String get deviceHealthToday => '今日';

  @override
  String get deviceHealthSteps => '歩数';

  @override
  String get deviceHealthDistance => '距離';

  @override
  String get deviceHealthCalories => 'カロリー';

  @override
  String get deviceHealthHeartRate => '心拍数';

  @override
  String get deviceHealthRestingHeartRate => '安静時心拍数';

  @override
  String get deviceHealthAbnormalHeartRate => '異常心拍数';

  @override
  String get deviceHealthHeartRateHigh => '心拍数が高い';

  @override
  String get deviceHealthHeartRateLow => '心拍数が低い';

  @override
  String get deviceHealthHeartHealth => '心臓の健康';

  @override
  String get deviceHealthHeartHealthMonitoring => '心臓の健康モニタリング';

  @override
  String get deviceHealthIrregularHeartbeat => '不規則な心拍';

  @override
  String get deviceHealthLowBloodOxygen => '血中酸素低下';

  @override
  String get deviceHealthHighStress => '高ストレス';

  @override
  String get deviceHealthDetected => '検出済み';

  @override
  String get deviceHealthSleep => '最近の睡眠';

  @override
  String get deviceHealthSleepCard => '睡眠';

  @override
  String get deviceHealthAllDaySleep => '終日の睡眠';

  @override
  String get deviceHealthLongSleep => '長時間の睡眠';

  @override
  String get deviceHealthSleepStructure => '睡眠構造';

  @override
  String get deviceHealthSleepAverageHeartRate => '睡眠中の平均心拍数';

  @override
  String get deviceHealthSleepAverageBloodOxygen => '睡眠中の平均血中酸素';

  @override
  String deviceHealthAverageHeartRate(int value) {
    return '平均心拍数 $value bpm';
  }

  @override
  String get deviceHealthNoData => 'データがありません';

  @override
  String get deviceHealthLoadFailed => 'ヘルスデータを読み込めません';

  @override
  String get deviceMusicUpload => '音楽を転送';

  @override
  String get deviceMusicSyncDescription => 'MP3ファイルをデバイスへ同期';

  @override
  String get deviceMusicChooseDialog => 'デバイスへ同期するMP3ファイルを選択';

  @override
  String get deviceMusicReadFailed => '選択したMP3ファイルを読み込めません';

  @override
  String deviceMusicSizeInvalid(int maxMb) {
    return 'MP3は0バイトより大きく、${maxMb}MB以下にしてください';
  }

  @override
  String get deviceMusicUnknownArtist => '不明なアーティスト';

  @override
  String get deviceMusicTransferred => '音楽の転送完了';

  @override
  String get deviceMusicLibrary => 'デバイスの音楽';

  @override
  String get deviceMusicLibraryDescription => 'デバイス上の曲とプレイリストを管理';

  @override
  String get deviceMusicSongs => '曲';

  @override
  String deviceMusicSongsTotal(int count) {
    return '合計$count曲';
  }

  @override
  String get deviceMusicNoPlaylist => 'プレイリスト未登録';

  @override
  String get deviceMusicPlaylists => 'プレイリスト';

  @override
  String get deviceMusicEmpty => 'デバイスに曲がありません';

  @override
  String get deviceMusicNoPlaylists => 'プレイリストはまだありません';

  @override
  String deviceMusicLoadFailed(String error) {
    return 'デバイスの音楽を読み込めません：$error';
  }

  @override
  String get deviceMusicPlaylistCreate => '新しいプレイリスト';

  @override
  String get deviceMusicPlaylistRename => 'プレイリスト名を変更';

  @override
  String get deviceMusicPlaylistName => 'プレイリスト名';

  @override
  String deviceMusicPlaylistLimit(int count) {
    return '最大$count個のプレイリスト';
  }

  @override
  String deviceMusicSongCount(int count) {
    return '$count曲';
  }

  @override
  String get deviceMusicDeleteSong => 'この曲をデバイスから削除しますか？';

  @override
  String get deviceMusicDeletePlaylist => 'このプレイリストを削除しますか？';

  @override
  String get deviceMusicDeletePlaylistDescription => 'プレイリスト内の曲はデバイスに残ります';

  @override
  String get deviceMusicManagePlaylists => 'プレイリストを管理';

  @override
  String get deviceMusicPlaylistMembership => 'プレイリスト';

  @override
  String deviceMusicTransferSpeed(String speed) {
    return '$speed/秒';
  }

  @override
  String deviceMusicSelectedFiles(int count) {
    return '$countファイルを選択';
  }

  @override
  String deviceMusicQueueProgress(int current, int total, String name) {
    return '転送中 $current/$total：$name';
  }

  @override
  String get deviceRecordingsTitle => '録音の同期';

  @override
  String get deviceRecordingsDescription => '時計から録音を同期して書き出し';

  @override
  String get deviceRecordingsHint => '録音は1件ずつ受信・検証します。同期後に各元ファイルを書き出してください';

  @override
  String get deviceRecordingsSync => '録音を同期';

  @override
  String get deviceRecordingsReading => '録音一覧を読み込み中';

  @override
  String deviceRecordingsProgress(int completed, int total, String name) {
    return '受信済み $completed/$total：$name';
  }

  @override
  String deviceRecordingsProgressCount(int completed, int total) {
    return '受信済み $completed/$total';
  }

  @override
  String get deviceRecordingsEmpty => '時計を接続し、「録音を同期」を選択してください';

  @override
  String get deviceRecordingsSave => '録音を書き出し';

  @override
  String get deviceRecordingsNoneOnWatch => '時計に新しい録音はありません';

  @override
  String deviceRecordingsSynced(int count) {
    return '$count件の録音を同期しました';
  }

  @override
  String deviceRecordingsSaveFailed(String error) {
    return '録音を書き出せません：$error';
  }

  @override
  String get deviceMusicTransferTitle => 'MP3ファイルを転送';

  @override
  String get deviceMusicVelaDescription =>
      'MP3ファイルをデバイスへ同期します。1ファイル100MB以下にしてください';

  @override
  String get deviceMusicZeppDescription =>
      '50MB以下のMP3に対応しています。高速転送にはBluetooth Classicを推奨します。BLEも利用できますが時間がかかります';

  @override
  String get deviceMusicChooseMp3 => 'MP3ファイルを選択';

  @override
  String get deviceMusicSongTitle => '曲名';

  @override
  String get deviceMusicArtist => 'アーティスト';

  @override
  String deviceMusicFileSize(Object size) {
    return 'ファイルサイズ：$size';
  }

  @override
  String deviceMusicProgress(Object progress) {
    return '転送進捗：$progress%';
  }

  @override
  String get deviceMusicTransferring => '転送中';

  @override
  String get deviceMusicSend => '転送開始';

  @override
  String get zeppOsFindDevice => 'デバイスを探す';

  @override
  String get zeppOsFindDeviceDescription => 'デバイスを振動させるか着信音を鳴らし続けます';

  @override
  String get deviceFeaturesDeviceInfo => 'デバイス情報';

  @override
  String get deviceFeaturesDeviceInfoDesc => 'ファームウェア、容量、詳細情報';

  @override
  String get switchDeviceTitle => 'デバイスを切り替え';

  @override
  String get savedDevices => '保存済みデバイス';

  @override
  String get deviceSwitchAddDevice => 'デバイスを追加';

  @override
  String get scanAndAdd => 'スキャンして追加';

  @override
  String get authkey => '認証キー';

  @override
  String get authkeyPrompt => 'デバイスの認証キーを入力';

  @override
  String get authkeyPlaceholder => '認証キー';

  @override
  String get connectFailed => '接続に失敗しました';

  @override
  String deviceConnectingTo(String deviceName) {
    return '$deviceNameへ接続中…';
  }

  @override
  String get deviceConnectionPreparing => '接続を準備中…';

  @override
  String deviceConnectionEstablishing(String transport) {
    return '$transport接続を確立中…';
  }

  @override
  String get deviceConnectionInitializing => 'デバイスプロトコルを初期化中…';

  @override
  String get deviceConnectionAuthenticating => 'デバイスを認証中…';

  @override
  String get deviceConnectionFetchingStatus => 'デバイス情報を読み込み中…';

  @override
  String get deviceTransportBle => 'BLE';

  @override
  String deviceEndpointUnavailable(String transport) {
    return '$transportエンドポイントがありません。システムBluetooth設定でペアリングしてから再スキャンしてください';
  }

  @override
  String get deviceTransportSpp => 'SPP';

  @override
  String get deviceCompatibilityUnknown => '互換性不明';

  @override
  String get webSerialTitle => 'Web Serial';

  @override
  String get webSerialHint => '対応ブラウザーでデバイスを接続';

  @override
  String get webSerialConnectDialogTitle => 'Web Serialで接続';

  @override
  String get webSerialConnectDialogHint => 'シリアルデバイスを選択してください';

  @override
  String get cancel => 'キャンセル';

  @override
  String get deviceActionsDelete => 'デバイスを削除';

  @override
  String get deviceActionsDisconnect => '切断';

  @override
  String get deviceActionsShareQR => 'QRコードを共有';

  @override
  String get deviceShareOronBoxCode => 'OronBoxコード';

  @override
  String get deviceShareAstroBoxCompatibleCode => 'AstroBox互換コード';

  @override
  String get installTapToSelectFile => 'タップしてファイルを選択';

  @override
  String get deviceInfoTitle => 'デバイス情報';

  @override
  String get deviceInfoGroupDevice => 'デバイス';

  @override
  String get deviceInfoGroupSystem => 'システム';

  @override
  String get deviceInfoGroupStatus => '状態';

  @override
  String get fieldName => '名前';

  @override
  String get fieldAddress => 'アドレス';

  @override
  String get fieldAuthkey => '認証キー';

  @override
  String get fieldConnectionType => '接続方式';

  @override
  String get fieldCodename => 'コードネーム';

  @override
  String get fieldModel => 'モデル';

  @override
  String get fieldImei => 'IMEI';

  @override
  String get fieldFirmware => 'ファームウェア';

  @override
  String get fieldSerial => 'シリアル番号';

  @override
  String get fieldBattery => 'バッテリー';

  @override
  String get fieldChargeStatus => '充電状態';

  @override
  String get fieldStorage => 'ストレージ';

  @override
  String get appManagementTitle => 'アプリ管理';

  @override
  String get appManagementNone => 'アプリはありません';

  @override
  String get appManagementShowSystemApps => 'システムアプリを表示';

  @override
  String get watchfaceManagementTitle => '文字盤管理';

  @override
  String get watchfaceManagementNone => '文字盤はありません';

  @override
  String get open => '開く';

  @override
  String get externalLinkTitle => '外部リンク';

  @override
  String externalLinkDescription(String url) {
    return '$url を開こうとしています\n\nこのウェブサイトは第三者が運営しており、OronBox とは関係ありません。安全性は確認できません。注意して続行してください。続行しますか？';
  }

  @override
  String get externalLinkAstroBoxResourceHint => 'AstroBoxでリソースを表示';

  @override
  String get continueToWebsite => 'ウェブサイトへ進む';

  @override
  String get viewInOronBox => 'OronBoxで表示';

  @override
  String get uninstall => 'アンインストール';

  @override
  String get enable => '有効化';

  @override
  String get show => '表示';

  @override
  String get hide => '非表示';

  @override
  String get copy => 'コピー';

  @override
  String get copied => 'コピーしました';

  @override
  String get close => '閉じる';

  @override
  String get desktopTrayShow => 'OronBoxを表示';

  @override
  String get desktopTrayExit => 'OronBoxを終了';

  @override
  String get desktopCloseTitle => 'ウィンドウを閉じる';

  @override
  String get desktopCloseMessage => 'ウィンドウを閉じたときの動作を選択';

  @override
  String get desktopCloseRemember => '今後もこの設定を使用';

  @override
  String get desktopCloseToTray => 'トレイに最小化';

  @override
  String get desktopCloseExit => '終了';

  @override
  String get settingsDesktopCloseBehavior => 'ウィンドウを閉じる';

  @override
  String get settingsDesktopCloseBehaviorDesc => '閉じるボタンを押したときの動作';

  @override
  String get settingsRemoveBondBeforeSpp => '接続時に再ペアリング';

  @override
  String get settingsRemoveBondBeforeSppDesc =>
      '接続の安定性を高め、Xiaomi Fitness に接続を奪われるのを防ぎます。オフにすると接続が速くなる場合があります';

  @override
  String get desktopCloseBehaviorAsk => '毎回確認';

  @override
  String get desktopCloseBehaviorExit => 'アプリを終了';

  @override
  String get desktopCloseBehaviorTray => 'トレイに最小化';

  @override
  String get quickApp => 'クイックアプリ';

  @override
  String get miniprogram => 'ミニプログラム';

  @override
  String get miniprograms => 'ミニプログラム';

  @override
  String get watchface => '文字盤';

  @override
  String get firmwareTool => 'ファームウェア / ツール';

  @override
  String get free => '無料';

  @override
  String get paid => '有料';

  @override
  String get forcePaid => '有料必須';

  @override
  String get version => 'バージョン';

  @override
  String get noContent => '内容なし';

  @override
  String get preview => 'プレビュー';

  @override
  String get productDeviceRequirements => '対応デバイス';

  @override
  String get productOtherVersions => 'その他のバージョン';

  @override
  String get productInQueue => 'キューに追加済み';

  @override
  String get settingsAccount => 'アカウント';

  @override
  String get settingsGeneral => '一般';

  @override
  String get settingsQueue => 'キュー';

  @override
  String get settingsAbout => 'このアプリについて';

  @override
  String get settingsAccountLoginBBSDesc => 'BandBBSにサインインしてリソースを利用・公開';

  @override
  String get settingsAccountBandBbsSigningIn => 'BandBBSにサインイン中…';

  @override
  String get settingsAccountBandBbsOpenedBrowser => 'ブラウザーでBandBBSを開きました';

  @override
  String get settingsAccountBandBbsSignedIn => 'BandBBSにサインインしました';

  @override
  String get settingsAccountBandBbsLoginFailed => 'BandBBSへのサインインに失敗しました';

  @override
  String get settingsBandBbsAccountRequired => '先にBandBBSアカウントへサインインしてください';

  @override
  String get settingsAccountBBSAccount => 'BandBBSアカウント';

  @override
  String get bandBbsAccountTitle => 'BandBBSアカウント';

  @override
  String get bandBbsResourceId => 'BandBBSリソースID';

  @override
  String get bandBbsResourceIdHint => 'リソースIDを入力';

  @override
  String get bandBbsQueryResource => 'リソースを検索';

  @override
  String get bandBbsLogout => 'BandBBSからログアウト';

  @override
  String get bandBbsLoggedOut => 'ログアウトしました';

  @override
  String accountSignOutTitle(Object accountName) {
    return '$accountName からサインアウトしますか？';
  }

  @override
  String get accountSignOutMessage => 'このアカウントからサインアウトしますか？';

  @override
  String get bandBbsLoadPreviews => 'プレビューを読み込む';

  @override
  String get bandBbsLoadPreviewsDesc => 'BandBBSからプレビュー画像を取得';

  @override
  String get bandBbsShowAllCategories => 'すべてのカテゴリーを表示';

  @override
  String get bandBbsShowAllCategoriesDesc => '対応デバイスのないカテゴリーも表示';

  @override
  String get settingsMiAccount => 'Xiaomiアカウント';

  @override
  String get settingsMiAccountDesc => 'Xiaomiアカウントでバインド済みデバイスを同期';

  @override
  String get deviceSwitchMiAccountImport => 'Xiaomiアカウントから同期';

  @override
  String get deviceSwitchWearableLogImport => 'Xiaomi Fitnessログから読み込む';

  @override
  String get settingsMiAccountLoginTitle => 'Xiaomiアカウントにサインイン';

  @override
  String get settingsMiAccountUsername => 'ユーザー名';

  @override
  String get settingsMiAccountPassword => 'パスワード';

  @override
  String get settingsMiAccountRememberCredentials => '認証情報を保存';

  @override
  String get settingsMiAccountLoginAndSync => 'サインインして同期';

  @override
  String get settingsMiAccountLogInvalid => 'ログファイルが無効です';

  @override
  String get settingsMiAccountLogNoDevices => 'デバイスが見つかりません';

  @override
  String get settingsWearableLogSync => 'Fitnessログを同期';

  @override
  String get settingsWearableLogGuide => 'Xiaomi Fitnessでログを取得し、ここでスキャンしてください';

  @override
  String settingsWearableLogFound(int count) {
    return '$count台のデバイスを検出';
  }

  @override
  String settingsWearableLogImportedDevice(Object name) {
    return '$name をインポートしました';
  }

  @override
  String get settingsMiAccountMissingCredentials => 'ユーザー名とパスワードを入力してください';

  @override
  String get settingsMiAccountTwoFactorPrompt => '2段階認証を完了してください';

  @override
  String get settingsMiAccountLoginWindowClosed => 'ログインウィンドウが閉じられました';

  @override
  String settingsMiAccountSyncedDevices(int count) {
    return '小米デバイス $count 台を同期しました';
  }

  @override
  String get xiaomiAccountRequiredForEphemeris =>
      'Xiaomiアカウントにサインインしてからエフェメリスデータを同期してください';

  @override
  String get settingsHuamiAccount => 'Amazfitアカウント';

  @override
  String get settingsHuamiAccountDesc => 'Amazfitアカウントでアプリストアのリソースを利用';

  @override
  String get settingsHuamiAccountSigningIn => 'Amazfitアカウントにサインイン中…';

  @override
  String get settingsHuamiAccountSignedIn => 'Amazfitアカウントにサインインしました';

  @override
  String get settingsHuamiAccountLoginTitle => 'Amazfitアカウントにサインイン';

  @override
  String get settingsHuamiAccountUsername => 'アカウント';

  @override
  String get settingsHuamiAccountPassword => 'パスワード';

  @override
  String get settingsHuamiAccountRememberCredentials => 'パスワードを保存';

  @override
  String get settingsHuamiAccountLoginAndSave => 'サインインして保存';

  @override
  String get settingsHuamiAccountMissingCredentials =>
      'Amazfitアカウントとパスワードを入力してください';

  @override
  String get settingsHuamiAccountRequired => '先に設定でAmazfitアカウントへサインインしてください';

  @override
  String get understood => '了解';

  @override
  String get settingsGeneralLanguage => '言語';

  @override
  String get settingsGeneralLanguageDesc => 'アプリの表示言語を変更';

  @override
  String get settingsWideNavigationPosition => 'ナビゲーション位置';

  @override
  String get settingsWideNavigationPositionDesc => '横長画面でのサイドタブ位置を調整';

  @override
  String get settingsWideNavigationPositionBottom => '下';

  @override
  String get settingsWideNavigationPositionCenter => '中央';

  @override
  String get settingsWideNavigationPositionSplit => '分割';

  @override
  String get settingsAutoReconnectTitle => '自動再接続';

  @override
  String get settingsAutoReconnectDesc => '起動時に最後にペアリングしたデバイスへ自動接続';

  @override
  String get settingsAutoReconnectOnDisconnectTitle => '自動再接続';

  @override
  String get settingsAutoReconnectOnDisconnectDesc =>
      'デバイスが予期せず切断されたときに再接続を試みる';

  @override
  String get deviceReconnectAttempting => 'デバイス接続に異常があり、再接続を試行中';

  @override
  String get deviceReconnectSucceeded => '再接続しました';

  @override
  String get deviceReconnectFailedPrefix => '再接続に失敗しました。確認してください：';

  @override
  String get settingsSourceOfficialCdn => 'GitHubソースCDN';

  @override
  String get settingsSourceOfficialCdnDesc => 'GitHub上のコミュニティインデックス取得に使用するCDN';

  @override
  String get settingsQueueAutoInstall => '自動インストール';

  @override
  String get settingsQueueAutoInstallDesc => 'ダウンロード後に自動でインストール開始';

  @override
  String get settingsQueueDontClear => 'インストールキューを消去しない';

  @override
  String get settingsQueueDontClearDesc => '完了項目をインストールキューに残す';

  @override
  String get settingsRealtimeActivityNotification => 'リアルタイムアクティビティ通知';

  @override
  String get settingsRealtimeActivityNotificationDesc =>
      'リアルタイムアクティビティ通知でキューの進捗を表示';

  @override
  String get settingsAboutWebsite => '公式ウェブサイト';

  @override
  String get settingsTapToSignIn => 'タップしてサインイン';

  @override
  String get settingsConnected => '接続済み';

  @override
  String get settingsSystem => 'システム';

  @override
  String get settingsLight => 'ライト';

  @override
  String get settingsDark => 'ダーク';

  @override
  String get settingsOledDark => 'OLEDダーク';

  @override
  String get settingsThemeMode => 'テーマモード';

  @override
  String get settingsThemeModeDesc => 'アプリのテーマ表示を変更';

  @override
  String get settingsDynamicColor => 'ダイナミックカラー';

  @override
  String get settingsDynamicColorDesc => 'システムのアクセント色をアプリテーマに使用';

  @override
  String get settingsColorScheme => '配色';

  @override
  String get settingsColorSchemeDesc => 'アプリのアクセント色を選択';

  @override
  String get settingsColorSchemePink => 'ピンク';

  @override
  String get settingsColorSchemePurple => '紫';

  @override
  String get settingsColorSchemeTeal => '青緑';

  @override
  String get settingsColorSchemeGreen => '緑';

  @override
  String get settingsColorSchemeRed => '赤';

  @override
  String get settingsColorSchemeAmber => '琥珀';

  @override
  String get settingsDesktopAccentSource => 'Linuxアクセント色のソース';

  @override
  String get settingsDesktopAccentSourceDesc => 'GTKまたはQtからアクセント色を読み込むか選択';

  @override
  String get settingsDesktopAccentSourceSystem => '自動';

  @override
  String get settingsDesktopAccentSourceGtk => 'GTK';

  @override
  String get settingsDesktopAccentSourceQt => 'Qt';

  @override
  String get settingsCancel => 'キャンセル';

  @override
  String get settingsTeamRoleMain => 'メイン開発者 / デザイナー';

  @override
  String get settingsTeamRoleZeppOS => 'ZeppOS実装';

  @override
  String get settingsAboutSoftware => 'ソフトウェア情報';

  @override
  String get settingsAboutSoftwareDesc => 'バージョン、更新履歴、開発チーム';

  @override
  String get settingsAboutSoftwareTagline =>
      'Flutterで作られたVelaOSとZeppOS向けの高速なウェアラブル管理ツール';

  @override
  String get settingsAboutSoftwareRepository => 'GitHubリポジトリを開く';

  @override
  String get settingsAboutSoftwareTeam => '開発チーム';

  @override
  String get settingsAboutSoftwareBuildInfo => 'ビルド情報';

  @override
  String get settingsAboutSoftwareCopyright => 'Copyright © 2026 OrPudding';

  @override
  String get acknowledgementsKazumi => 'Material DesignのコンポーネントとUIパターンを参考にしました';

  @override
  String get acknowledgementsAstroBoxPublic =>
      'UI構成、リソースワークフロー、インタラクション設計を参考にしました';

  @override
  String get acknowledgementsAstroBoxNgCore =>
      'Xiaomiデバイスプロトコル、インストール、転送処理を参考にしました';

  @override
  String get acknowledgementsAstroBoxNgBluetooth => 'Bluetooth接続処理を参考にしました';

  @override
  String get acknowledgementsAstroBoxNgAccount =>
      'Xiaomiアカウントログイン、デバイス同期、認証キー取得処理を参考にしました';

  @override
  String get acknowledgementsAstroBoxNgProvider =>
      'コミュニティリソースインデックス、CDN、マニフェスト解析を参考にしました';

  @override
  String get acknowledgementsAstroBoxNgAppWasm =>
      'Web Serialとブラウザー側接続処理を参考にしました';

  @override
  String get acknowledgementsGadgetbridge => 'ZeppOSおよびウェアラブルプロトコル研究を参考にしました';

  @override
  String get acknowledgementsBreezyWeather => '中国向け天気ソース実装の参考';

  @override
  String get acknowledgementsOpenMeteo => 'CC BY 4.0で提供される天気予報、空気質、ジオコーディングデータ';

  @override
  String get resourceHomeRecommended => 'おすすめ';

  @override
  String get resourceHomeFeatured => '注目';

  @override
  String get resourceHomeUpdates => '更新';

  @override
  String get blogTypeAnnouncement => 'お知らせ';

  @override
  String get blogTypeRecommendation => 'おすすめ';

  @override
  String get blogTypeDocs => 'ドキュメント';

  @override
  String get resourceHomeEmptyTitle => 'おすすめはまだありません';

  @override
  String get resourceLibraryEndOfList => '最後まで表示しました。他のソースのリソースも確認しますか？';

  @override
  String get resourceHomeEmptySubtitle => 'リソースライブラリから取得できます';

  @override
  String get openResourceLibrary => 'リソースライブラリを開く';

  @override
  String get downloadQueueTitle => 'ダウンロードキュー';

  @override
  String get installQueueTitle => 'インストールキュー';

  @override
  String get queueClear => '消去';

  @override
  String get queueStart => '開始';

  @override
  String get queuePause => '一時停止';

  @override
  String get downloadQueueEmpty => 'ダウンロードタスクはありません';

  @override
  String get installQueueEmpty => 'インストールタスクはありません';

  @override
  String get localAppInstall => 'ローカルアプリをインストール';

  @override
  String get localWatchfaceInstall => 'ローカル文字盤をインストール';

  @override
  String get localFirmwareInstall => 'ローカルファームウェアをインストール';

  @override
  String get queueStatusPending => '待機中';

  @override
  String queueStatusDownloading(String percent) {
    return 'ダウンロード中 $percent%';
  }

  @override
  String queueStatusInstalling(String percent) {
    return 'インストール中 $percent%';
  }

  @override
  String get queueStatusCompleted => '完了';

  @override
  String get queueStatusFailed => '失敗';

  @override
  String get queueDragToInstall => '離してアプリ、文字盤、プラグインをインストール';

  @override
  String queueAddedFiles(int count) {
    return '$countファイルをインストールキューに追加';
  }

  @override
  String get installQueueReadFailed => '読み込み失敗';

  @override
  String get installQueueUnsupportedFile => '未対応ファイル';

  @override
  String timeTodayAt(Object time) {
    return '今日 $time';
  }

  @override
  String timeYesterdayAt(Object time) {
    return '昨日 $time';
  }

  @override
  String get settingsAccountBandBbsAccount => 'BandBBSアカウント';

  @override
  String get settingsAccountGitHub => 'GitHubアカウント';

  @override
  String get settingsAccountGitHubDesc => 'GitHubを接続してAstroBoxリソースを自分の名前で公開';

  @override
  String get githubAccountNeedsBandBbs => '先にBandBBSへサインインしてください';

  @override
  String get bandBbsPublishAuthTitle => '公開の認証';

  @override
  String get bandBbsResourceQueryTitle => '購入済みリソースをインストール';

  @override
  String get settingsAboutLogs => '実行ログ';

  @override
  String get settingsAboutLogsDescription => 'アプリと接続デバイスの実行ログを表示、書き出し、管理';

  @override
  String settingsAboutLogsSize(Object size) {
    return '現在の使用量：$size';
  }

  @override
  String get settingsAboutLogsExport => '書き出し';

  @override
  String settingsAboutLogsExported(Object path) {
    return '$pathへ書き出しました';
  }

  @override
  String get settingsAboutLogsEmpty => 'ログファイルはありません';

  @override
  String get settingsAboutLogsClear => '消去';

  @override
  String get settingsDeviceLogsPull => 'デバイスログを取得';

  @override
  String get settingsDeviceLogsTip =>
      '接続中のXiaomiウェアラブルからログを取得します。時間がかかる場合があります。完了までアプリを前面に表示し、デバイス画面をオンにしてください';

  @override
  String get settingsDeviceLogsStart => '開始';

  @override
  String get settingsDeviceLogsPulling => 'デバイスログを取得中';

  @override
  String get settingsDeviceLogsWaiting => 'デバイスからの送信を待っています';

  @override
  String settingsDeviceLogsProgress(Object progress) {
    return '受信済み $progress%';
  }

  @override
  String settingsDeviceLogsSaved(Object name) {
    return 'デバイスログを$nameとして保存しました';
  }

  @override
  String settingsDeviceLogsFailed(Object error) {
    return 'デバイスログを取得できません：$error';
  }

  @override
  String get settingsAboutLogsClearConfirm => '現在のセッションを除くすべてのログファイルを削除します';

  @override
  String get settingsAboutLogsOpen => 'ログフォルダーを開く';

  @override
  String get settingsAboutLogsOpenFailed => 'ログフォルダーを開けません';

  @override
  String get settingsLogsFileList => 'ログファイル';

  @override
  String get settingsAboutLogsWarningTitle => '機密情報に関する注意';

  @override
  String get settingsAboutLogsWarningMessage =>
      'ログにはBandBBS、Xiaomi、Amazfitのログイン情報など機密情報が含まれる場合があります。公式OronBoxメンテナー以外には共有しないでください！';

  @override
  String get pluginPermissionRequestTitle => 'プラグイン権限の要求';

  @override
  String pluginPermissionRequestMessage(Object plugin, Object operation) {
    return '「$plugin」は$operationを要求しています';
  }

  @override
  String get pluginPermissionOnce => '今回のみ許可';

  @override
  String get pluginPermissionSession => '今回の実行中は許可';

  @override
  String get pluginPermissionAlways => '常に許可';

  @override
  String get pluginPermissionDeny => '拒否';

  @override
  String get pluginPermissionOpenExternal => '外部リンクを開く';

  @override
  String get pluginPermissionPickFile => 'ホストのファイルへアクセス';

  @override
  String get pluginPermissionExportFile => 'ホストへファイルを書き出す';

  @override
  String get pluginPermissionNetwork => 'ネットワークへアクセス';

  @override
  String get pluginPermissionInterconnect => 'デバイスアプリと通信';

  @override
  String get pluginPermissionProvider => 'リソースプロバイダーを登録';

  @override
  String get pluginPermissionReadDevice => 'デバイス情報を読む';

  @override
  String get pluginPermissionOperateDevice => 'デバイスを操作';

  @override
  String get pluginPermissionObserveProtocol => 'デバイスプロトコルの生データを読む';

  @override
  String get pluginPermissionSendProtocol => 'デバイスへ生プロトコルを送信';

  @override
  String get pluginPermissionReadAppSide => 'AppSideスクリプトとイベントを読む';

  @override
  String get pluginPermissionOperateAppSide => 'AppSideセッションを管理';

  @override
  String get pluginErrorTitle => 'プラグインが破損しています';

  @override
  String pluginErrorMessage(Object plugin, Object error) {
    return '「$plugin」を実行できません。破損している可能性があります。\\n\\nエラー：$error\\n\\nこのプラグインをアンインストールしますか？';
  }

  @override
  String get pluginPackageCorruptedMessage =>
      '選択したプラグインパッケージを読み取れません。破損している可能性があります。再取得してからインポートしてください。';

  @override
  String get pluginErrorClearData => 'プラグインデータを消去';

  @override
  String get pluginErrorUninstall => 'プラグインをアンインストール';

  @override
  String get pluginErrorSafeMode => 'セーフモードに入る';

  @override
  String get pluginSafeModeTitle => 'プラグインセーフモードが有効';

  @override
  String get pluginSafeModeDescription =>
      'すべてのプラグインを停止しています。セーフモードを無効にすると再読み込みされます';

  @override
  String get pluginSafeModeExit => 'セーフモードを終了';

  @override
  String get devTools => '開発者ツール';

  @override
  String get devToolsDescriptionDesktop => '別ウィンドウで開発者ツールを開く';

  @override
  String get devToolsDescriptionEntry => 'アプリバーに開発者ツールボタンを表示';

  @override
  String get devToolsOperationFailed => '開発者ツールの状態を変更できません';

  @override
  String get resourceTypeErrorTitle => 'リソース種別が正しくありません';

  @override
  String get resourceTypeUnknownTitle => 'リソース種別を認識できません';

  @override
  String get resourceTypeUnknownNoType =>
      'OronBoxはこのファイルのリソース種別を判別できません。このファイルは破損している可能性があります';

  @override
  String get resourceTypeUnknownCancel => 'キャンセル';

  @override
  String resourceTypeMismatchMessage(Object detectedType, Object selectedType) {
    return '$detectedTypeリソースのようですが、$selectedTypeを選択しています。インストール方法を選択してください';
  }

  @override
  String resourcePlatformMismatchMessage(
    Object resourcePlatform,
    Object resourceType,
    Object deviceName,
    Object devicePlatform,
  ) {
    return 'これは $resourcePlatform デバイス向けの $resourceType ですが、接続中のデバイスは $deviceName（$devicePlatform）です。未対応のため、強制インストールは予期しない問題を起こす可能性があります';
  }

  @override
  String resourceTypeUnknownMessage(Object selectedType) {
    return '実際のリソース種別を判別できません。$selectedTypeとしてインストールしますか？';
  }

  @override
  String get resourceInstallCancel => 'インストールをキャンセル';

  @override
  String get resourceInstallAcknowledge => '理解しました';

  @override
  String get resourceInstallForce => '強制インストール';

  @override
  String resourceInstallForceCountdown(int seconds) {
    return '強制インストール（$seconds秒）';
  }

  @override
  String resourceInstallAsSelected(Object type) {
    return '$typeとして続行';
  }

  @override
  String resourceInstallAsSelectedCountdown(Object type, int seconds) {
    return '$typeとして続行（$seconds秒）';
  }

  @override
  String resourceInstallAsDetected(Object type) {
    return '$typeとしてインストール';
  }

  @override
  String get resourceTypeApp => 'ミニプログラム';

  @override
  String get resourceTypeQuickApp => 'クイックアプリ';

  @override
  String get resourceTypeWatchface => '文字盤';

  @override
  String get resourceTypeFirmware => 'ファームウェア';

  @override
  String resourceInstallConfirmTitle(Object type) {
    return '$typeをインストール';
  }

  @override
  String resourceInstallConfirmMessage(Object fileName, Object fileSize) {
    return '$fileName（$fileSize）をインストールしますか？';
  }

  @override
  String get resourceInstallConfirm => 'インストール';

  @override
  String get previewImages => '画像をプレビュー';

  @override
  String get add => '追加';

  @override
  String get submit => '送信';

  @override
  String get creatorConfirmTitle => 'コミットを確認';

  @override
  String get creatorConfirmOronBox => 'OronBoxへコミット';

  @override
  String creatorConfirmBandBbs(Object category) {
    return 'BandBBSへ同期：$category';
  }

  @override
  String creatorConfirmAstroBox(Object owner, Object repository) {
    return 'AstroBoxへ同期：$owner/$repository';
  }

  @override
  String get creatorBandBbsDirectPublish => 'BandBBSへ同期';

  @override
  String get creatorBandBbsBoundUpdate => '連携済み・BandBBSへ同期';

  @override
  String get creatorBandBbsVersionTitle => 'バージョンタイトル';

  @override
  String get creatorBandBbsVersionMessage => '更新内容';

  @override
  String get creatorBandBbsVersionPairRequired =>
      'バージョンタイトルと更新内容は両方入力するか、両方空欄にしてください';

  @override
  String creatorLinkedSections(int count) {
    return '$countセクションを連携';
  }

  @override
  String creatorBandBbsBindingIds(Object categoryId, Object resourceId) {
    return 'セクション$categoryId・リソース$resourceId';
  }

  @override
  String get creatorAstroBoxBoundSync => '連携済み・AstroBoxへ同期';

  @override
  String get creatorThisCommit => 'このコミット';

  @override
  String creatorAstroBoxPrPublish(Object repository) {
    return 'AstroBoxへ同期・$repository';
  }

  @override
  String get creatorOronBoxRequired => '必須。リソースはOronBoxで審査されます';

  @override
  String get creatorOpenInOronBox => 'OronBoxで表示';

  @override
  String get creatorAstroTagsHint => '英語セミコロン ; でタグを区切る';

  @override
  String get retry => '再試行';

  @override
  String get reviewNote => '審査メモ';

  @override
  String get creatorReviewRejected => 'リソースの修正が必要です';

  @override
  String creatorReviewState(Object state) {
    return '審査状態：$state';
  }

  @override
  String get creatorOperationWorking => '処理中';

  @override
  String get creatorProcessingImage => '画像を処理中';

  @override
  String get creatorOperationRefreshing => 'クリエイターデータを更新中';

  @override
  String get creatorOperationCreating => 'リソースを作成中';

  @override
  String get creatorOperationCreatingCollection => 'コレクションを作成中';

  @override
  String get creatorOperationSaving => '変更を保存中';

  @override
  String get creatorOperationDeleting => '削除中';

  @override
  String get creatorOperationSubmitting => '審査へ送信中';

  @override
  String get creatorOperationAuthorizing => '認証を待機中';

  @override
  String get creatorResolvingPublicationTarget => '公開カテゴリーを解決中';

  @override
  String get creatorStateApproved => '承認済み';

  @override
  String get creatorStateExternalReview => '外部審査中';

  @override
  String get creatorStateFailed => '公開に失敗';

  @override
  String get creatorStateSuperseded => '新しい改訂に置き換え済み';

  @override
  String get creatorStateCancelled => 'キャンセル済み';

  @override
  String get creatorNoResources => '作成したリソースはありません';

  @override
  String get creatorLoginRequiredTitle => 'クリエイターセンターを利用するにはサインインしてください';

  @override
  String get creatorLoginRequiredDescription =>
      'リソースの作成、編集、送信を行うにはBandBBSへサインインし、OronBoxアカウントを連携してください';

  @override
  String get creatorLoginAction => 'BandBBSにサインイン';

  @override
  String get creatorBandBbsWriteReady => 'BandBBS公開の認証済み';

  @override
  String get creatorBandBbsWriteMissing => 'BandBBS公開が未認証';

  @override
  String get creatorGitHubOwnPublishReady => 'GitHub接続済み';

  @override
  String get creatorGitHubOwnPublishMissing => 'GitHub未接続';

  @override
  String get creatorAuthorize => '認証';

  @override
  String get installQueueFixWatchfaceId => '文字盤IDを修正';

  @override
  String get installQueueFixWatchfaceIdHint => '12桁以内の数字を入力';

  @override
  String get authorize => '認証';

  @override
  String get creatorBandBbsAuthorized => 'BandBBSリソース公開が認証済み';

  @override
  String get creatorBandBbsAuthorizationRequired =>
      'BandBBSリソースを代理公開するにはOronBoxを別途認証してください';

  @override
  String get connect => '接続';

  @override
  String get legalAndPrivacy => '法務とプライバシー';

  @override
  String get termsTitle => '利用規約と免責事項';

  @override
  String get privacyTitle => 'プライバシー通知';

  @override
  String get resourcePublishingTitle => 'リソース公開規約';

  @override
  String get reviewRulesTitle => 'リソース審査ルール';

  @override
  String get joinQqGroup => 'QQグループに参加';

  @override
  String get joinQqGroupDesc => '開発者や他のユーザーと相談できます';

  @override
  String get feedbackTitle => 'フィードバック';

  @override
  String get feedbackDesc => 'フィードバックを送信して回答を確認';

  @override
  String get reportResource => 'リソースを通報';

  @override
  String get reportComment => 'コメントを通報';

  @override
  String get report => '通報';

  @override
  String get feedbackSubject => '件名';

  @override
  String get feedbackMessage => 'フィードバックまたは問題';

  @override
  String get reportReason => '通報理由';

  @override
  String get noFeedback => 'フィードバックはまだありません';

  @override
  String get feedbackProcessing => '処理中';

  @override
  String get feedbackReplied => '返信済み';

  @override
  String get feedbackOpen => '受付中';

  @override
  String get feedbackResolved => '解決済み';

  @override
  String get feedbackDismissed => '却下済み';

  @override
  String get feedbackClosed => '終了';

  @override
  String get feedbackLoading => 'チケットを読み込み中';

  @override
  String get feedbackNewTicket => '新しいチケット';

  @override
  String get feedbackYou => 'あなた';

  @override
  String get feedbackResolution => '解決内容';

  @override
  String get feedbackReplyHint => 'このチケットに返信';

  @override
  String get feedbackConversationClosed => 'このチケットは終了しており返信できません';

  @override
  String get checkUpdates => '更新を確認';

  @override
  String get updateChecking => '更新を確認中…';

  @override
  String get updateCheckFailed => '更新を確認できません';

  @override
  String get latestVersionInstalled => '最新版を使用しています';

  @override
  String newVersionAvailable(Object version) {
    return 'バージョン $version を利用できます';
  }

  @override
  String get oobeWelcomeSlogan =>
      'Flutterで作られた美しく高速なVelaOS / ZeppOSウェアラブル管理ツール';

  @override
  String get oobeNext => '次へ';

  @override
  String get oobeBack => '戻る';

  @override
  String get oobeFeatureDevicesTitle => 'デバイス接続';

  @override
  String get oobeFeatureDevicesBody => 'VelaOSとZeppOSのウェアラブルを接続・管理';

  @override
  String get oobeFeatureResourcesTitle => 'リソースセンター';

  @override
  String get oobeFeatureResourcesBody =>
      '公式OronBoxソース、AstroBox-Repo、BandBBS、Amazfitアプリストアに対応';

  @override
  String get oobeFeaturePluginsTitle => 'JavaScriptプラグイン';

  @override
  String get oobeFeaturePluginsBody =>
      'デバイス操作に対応した高性能で拡張性の高いJavaScriptプラグインシステム';

  @override
  String get oobeFeaturePlatformsTitle => 'マルチプラットフォーム';

  @override
  String get oobeFeaturePlatformsBody => 'Android、Windows、macOS、Linux、Webで利用可能';

  @override
  String get oobeOpenSourceTitle => '完全オープンソース';

  @override
  String get oobeOpenSourceBody =>
      'OronBoxクライアントとサーバーはGNU AGPL-3.0に従い、ソースコードを公開しています';

  @override
  String get oobeAgreementHint => '最後まで読んでスクロールしてください';

  @override
  String get oobeAgreeCheckbox => '読み、同意します';

  @override
  String get oobeDeclineExit => '終了';

  @override
  String get oobeDeclineWebHint => '続行するには規約に同意してください。このページを閉じてください';

  @override
  String get oobeLoginTitle => 'アカウントを接続';

  @override
  String get oobeLoginBandBbsDesc =>
      'BandBBSリソースを利用し、クリエイター機能を準備するためBandBBSにサインイン';

  @override
  String get oobeLoginLocalNote =>
      'XiaomiとAmazfitのサインインはこのデバイス上だけで実行されます。関連データはXiaomi/Amazfit以外の第三者へ送信されません';

  @override
  String get oobeLoginXiaomiDesc => 'バインド済みXiaomiデバイスを同期するためXiaomiアカウントにサインイン';

  @override
  String get oobeLoginHuamiDesc =>
      'Amazfitアプリストアのリソースを利用するためAmazfitアカウントにサインイン';

  @override
  String get oobeCdnTesting => 'テスト中…';

  @override
  String get oobeCdnSelected => '最速のCDNを選択しました';

  @override
  String get oobeCdnTitle => 'GitHub CDN速度テスト';

  @override
  String get oobeDoneTitle => '準備完了';

  @override
  String get oobeDoneBody => 'OronBoxを探索しましょう';

  @override
  String get oobeFinish => '完了';

  @override
  String get settingsReplayOobe => 'ガイドを再表示';

  @override
  String get settingsReplayOobeDesc => 'ようこそガイドと初期設定をもう一度表示';

  @override
  String get creatorConnect => '接続';

  @override
  String get comments => 'コメント';

  @override
  String get commentEmpty => 'コメントはまだありません';

  @override
  String get commentHint => 'コメントを書く';

  @override
  String get commentLoginRequired => 'コメントするにはBandBBSにサインインしてください';

  @override
  String get commentPending => '審査待ち';

  @override
  String get commentBlocked => 'このコメントはコミュニティガイドラインに適合しません';

  @override
  String get commentModerationUnavailable => 'コメント審査は一時的に利用できません';

  @override
  String get commentRateLimited => 'コメントが速すぎます';

  @override
  String get commentReplying => 'コメントに返信';

  @override
  String get loadMore => 'もっと見る';

  @override
  String get more => 'その他';

  @override
  String get reply => '返信';

  @override
  String get inbox => '受信箱';

  @override
  String get inboxLoading => 'メッセージを読み込み中';

  @override
  String get inboxEmpty => 'メッセージはありません';

  @override
  String get inboxClear => 'メッセージを消去';

  @override
  String get inboxClearFailed => 'メッセージを消去できません。後でもう一度お試しください';

  @override
  String get messageUnknownTitle => '通知';

  @override
  String get messageUnknownBody => '通知の詳細データを取得できません。';

  @override
  String get messageCommentRepliedTitle => 'コメントへの新しい返信';

  @override
  String get messageCommentHiddenTitle => 'コメントが非表示になりました';

  @override
  String get messageCommentHiddenAutomatedBody =>
      'コメントは自動審査を通過しなかったため、現在非表示です。メッセージから異議申し立てができます。';

  @override
  String get messageCommentHiddenReviewedBody => 'コメントは手動審査後に非表示になりました。';

  @override
  String get messageReviewApprovedTitle => 'リソースが承認されました';

  @override
  String get messageReviewRejectedTitle => 'リソースの修正が必要です';

  @override
  String get messageResourceSuspendedTitle => 'リソースが公開停止になりました';

  @override
  String get messageResourceFrozenTitle => 'リソースが凍結されました';

  @override
  String get messageResourceDeletedTitle => 'リソースが削除されました';

  @override
  String get messageResourceRestoredTitle => 'リソースが復元されました';

  @override
  String get messageReportUpdatedTitle => '報告の状態が更新されました';

  @override
  String get messagePluginApprovedTitle => 'プラグインが承認されました';

  @override
  String get messagePluginRelistedTitle => 'プラグインが再公開されました';

  @override
  String get messagePluginRejectedTitle => 'プラグインの修正が必要です';

  @override
  String get messagePluginDelistedTitle => 'プラグインが公開停止になりました';

  @override
  String get messageCollectionApprovedTitle => 'コレクションが承認されました';

  @override
  String get messageCollectionRejectedTitle => 'コレクションの修正が必要です';

  @override
  String get messageCoinAddedTitle => 'コインが追加されました';

  @override
  String get messageCoinDeductedTitle => 'コインが差し引かれました';

  @override
  String get messageCoinReversedTitle => 'コイン取引が取り消されました';

  @override
  String get messageCoinVoteRevokedTitle => 'コインの支援が無効になりました';

  @override
  String get messageAppealOverturnedTitle => '異議申し立てが認められました';

  @override
  String get messageAppealUpheldTitle => '元の決定が維持されました';

  @override
  String get messageAppealDismissedTitle => '異議申し立てが却下されました';

  @override
  String get messageAccountBannedTitle => 'アカウントが停止されました';

  @override
  String get messageAccountUnbannedTitle => 'アカウント停止が解除されました';

  @override
  String get messageCreatorFrozenTitle => 'クリエイター権限が凍結されました';

  @override
  String get messageCreatorUnfrozenTitle => 'クリエイター権限が復元されました';

  @override
  String get messageRoleChangedTitle => 'アカウントの役割が変更されました';

  @override
  String get messageRoleUser => 'ユーザー';

  @override
  String get messageRoleReviewer => 'レビュアー';

  @override
  String get messageRoleAdministrator => '管理者';

  @override
  String get messageApprovedBody => '提出内容は審査に合格しました。';

  @override
  String get messageNeedsChangesBody => '審査で修正が必要な問題が見つかりました。';

  @override
  String messageReasonBody(String reason) {
    return '理由：$reason';
  }

  @override
  String messageReviewNoteBody(String note) {
    return '審査メモ：$note';
  }

  @override
  String get messageStatusChangedBody => 'この項目の状態が変更されました。';

  @override
  String messageReportStatusBody(String status) {
    return '報告の状態：$status';
  }

  @override
  String messageCoinAddedBody(String amount) {
    return 'アカウントに $amount コインが追加されました。';
  }

  @override
  String messageCoinDeductedBody(String amount) {
    return 'アカウントから $amount コインが差し引かれました。';
  }

  @override
  String messageCoinVoteRevokedBody(String amount) {
    return 'このリソースへの $amount コインの支援が無効になりました。';
  }

  @override
  String get messageAppealOverturnedBody => '管理者が元の決定を取り消しました。';

  @override
  String get messageAppealUpheldBody => '再審査後も元の決定が維持されました。';

  @override
  String get messageAppealDismissedBody => '異議申し立ては受理されませんでした。';

  @override
  String messageRoleChangedBody(String role) {
    return 'アカウントの役割は $role になりました。';
  }

  @override
  String get cleanMode => '機能スイッチ';

  @override
  String get cleanModeDescription => 'メインナビゲーション、コミュニティ機能、リソースソースを管理';

  @override
  String get cleanPluginsEntry => 'プラグイン入口';

  @override
  String get cleanSourceHuamiAppStore => 'Amazfitアプリストア';

  @override
  String get announcementAcknowledge => '了解';

  @override
  String get cleanHomeFeed => 'ホームフィード';

  @override
  String get cleanExplore => 'リソースライブラリ';

  @override
  String get cleanInbox => '受信箱';

  @override
  String get cleanAnnouncements => 'お知らせポップアップ';

  @override
  String get cleanComments => 'コメント';

  @override
  String get cleanCreator => 'クリエイターセンター';

  @override
  String get cleanBandBbsLogin => 'BandBBSサインイン';

  @override
  String get cleanGitHubLogin => 'GitHubサインイン';

  @override
  String get cleanSourceOronBox => 'OronBoxソース';

  @override
  String get cleanSourceBandBbs => 'BandBBSソース';

  @override
  String get cleanSourceAstroBox => 'AstroBoxソース';

  @override
  String get cleanExploreEntry => '探索入口';

  @override
  String get cleanNavigationGroup => 'メインナビゲーション';

  @override
  String get cleanExploreContentGroup => '探索コンテンツ';

  @override
  String get cleanHomeSectionsGroup => 'ホームセクション';

  @override
  String get cleanHomeBanner => 'バナーカルーセル';

  @override
  String get cleanHomeEditorSections => '編集セクション';

  @override
  String get cleanResourceSourcesGroup => 'リソースソース';

  @override
  String get cleanCommunityGroup => 'コミュニティ機能';

  @override
  String get settingsCategoryAccounts => 'アカウントと認証';

  @override
  String get settingsCategoryAppearance => '外観とナビゲーション';

  @override
  String get settingsCategoryConnection => '接続とダウンロード';

  @override
  String get settingsCategorySupport => 'サポートと情報';

  @override
  String get settingsCategoryAdvanced => '詳細設定';

  @override
  String get settingsAdvancedDescription => 'ログと開発者ツールを表示します';

  @override
  String get debugServerTitle => 'デバッグサービス';

  @override
  String get debugServerDescription => '信頼できる開発ツール向けにローカル API を提供します';

  @override
  String get debugServerEnable => 'デバッグサービスを有効にする';

  @override
  String get debugServerEnableDescription =>
      '承認したローカルネットワーク上のクライアントに OronBox の確認と操作を許可します';

  @override
  String get debugServerEndpoint => '接続先';

  @override
  String get debugServerFingerprint => 'サーバーフィンガープリント';

  @override
  String get debugServerPendingClients => '承認待ちクライアント';

  @override
  String get debugServerAuthorizedClients => '承認済みクライアント';

  @override
  String get debugServerApprove => '承認';

  @override
  String get debugServerReject => '拒否';

  @override
  String get debugServerRevoke => 'アクセスを取り消す';

  @override
  String get debugServerNoPendingClients => '承認を待っているクライアントはありません';

  @override
  String get debugServerNoAuthorizedClients => '承認済みクライアントはありません';

  @override
  String get debugServerSecurityNotice => '信頼できるネットワークでのみ有効にしてください';

  @override
  String get debugServerStartFailed => 'デバッグサービスを起動できませんでした';

  @override
  String get debugServerStopFailed => 'デバッグサービスを停止できませんでした';

  @override
  String get xmsDeveloperMode => 'XMS開発者モード';

  @override
  String get xmsDeveloperModeDescription => 'Androidアプリの署名差異を許可';

  @override
  String get oronBoxCoinsTitle => 'リソースコイン';

  @override
  String oronBoxCoinsBalance(String balance) {
    return 'コイン残高：$balance';
  }

  @override
  String get oronBoxCoinsCheckin => 'チェックイン';

  @override
  String get oronBoxCoinsCheckedIn => 'チェックイン済み';

  @override
  String oronBoxCoinsCheckinReward(int count) {
    return '$countコインを獲得';
  }

  @override
  String get oronBoxCoinsDescription => '毎日チェックインで1～5コインを獲得し、クリエイターを支援できます';

  @override
  String resourceFromCollection(String name) {
    return 'コレクション「$name」から';
  }

  @override
  String get resourceCoin => 'コイン';

  @override
  String get resourceCoinNotSignedIn => '未サインイン';

  @override
  String get resourceCoinDialogTitle => 'このリソースにコインを贈る';

  @override
  String get resourceCoinDialogMessage =>
      'このリソースにコインを贈りますか？\nこの操作は取り消せません\n\nコインはリソースの露出を高めます\nクリエイターは贈られた量の10%を受け取ります\n設定 - BandBBSアカウントでチェックインしてコインを獲得できます';

  @override
  String get resourceCoinOne => '1コインを贈る';

  @override
  String get resourceCoinTwo => '2コインを贈る';

  @override
  String resourceCoinCount(int count) {
    return '$countコイン';
  }

  @override
  String get resourceCoinSuccess => 'コインを送信しました';

  @override
  String get resourceCoinVoted => 'コイン済み';

  @override
  String get resourceFeatured => '注目';

  @override
  String get resourceCollection => 'コレクション';

  @override
  String resourceCollectionType(String type) {
    return '$typeコレクション';
  }

  @override
  String get creatorCollections => 'リソースコレクション';

  @override
  String get creatorCollectionTag => 'コレクション';

  @override
  String get creatorNewCollection => '新しいコレクション';

  @override
  String get creatorMoveToCollection => 'コレクションへ移動';

  @override
  String creatorMoveToCollectionConfirm(int count) {
    return '選択した$count件のリソースをこのコレクションへ移動しますか？';
  }

  @override
  String get creatorDissolveCollection => 'コレクションを解散';

  @override
  String get creatorResourceList => 'リソース';

  @override
  String get creatorAdditionalLinks => '追加リンク';

  @override
  String get creatorAddLink => 'リンクを追加';

  @override
  String get creatorLinkTitle => 'リンク名';

  @override
  String get creatorLinkUrl => 'リンクURL';

  @override
  String get creatorCollectionName => 'コレクション名';

  @override
  String get creatorCollectionSummary => 'コレクション概要';

  @override
  String get creatorCollectionRepresentative => '代表リソース';

  @override
  String get creatorCollectionDeleteConfirm =>
      'このコレクションを削除しますか？リソースとの紐付けだけ解除されます';

  @override
  String get creatorContentAttributes => 'コンテンツ属性';

  @override
  String get creatorConfirm => '確認';

  @override
  String get creatorCollectionAddResource => 'コレクションに追加';

  @override
  String creatorCollectionResourceCount(int count) {
    return '$count件のリソース';
  }

  @override
  String communityImportSelected(int count) {
    return '$count件を選択';
  }

  @override
  String get communityImportResultCreated => '下書きを作成しました';

  @override
  String get communityImportResultFailed => '失敗';

  @override
  String get communityImportUnsupported => 'この種別はまだインポートできません';

  @override
  String get communityImportDuplicate => 'クリエイターセンターにすでに存在します';

  @override
  String get communityImportNoArtifacts => 'インポート可能なリソースファイルがありません';

  @override
  String get creatorImportExternal => '他のプラットフォームから既存リソースをインポート';

  @override
  String get creatorNewResourceDescription => 'OronBoxでリソースを作成・管理';

  @override
  String get creatorNewCollectionDescription => '関連リソースのコレクションを作成';

  @override
  String get creatorImportExternalDescription =>
      '試験的機能：BandBBSまたはAstroBox-Repoから既存リソースをインポート';

  @override
  String get creatorImportAlreadyImported => 'インポート済み・連携済み';

  @override
  String get creatorImportReviewNotice =>
      'インポート内容が不完全または誤認識されている可能性があります。送信前にすべての項目を確認・修正してください';

  @override
  String get creatorImportLogTitle => '処理ログ';

  @override
  String get communityImportPickerEmpty => 'リソースはありません';

  @override
  String get creatorWizardChooseAction => '作成';

  @override
  String get creatorImportSelectTitle => 'リソースを選択';

  @override
  String get creatorImportProgressTitle => 'インポート中';

  @override
  String get creatorImportResultTitle => 'インポート結果';

  @override
  String get creatorImportGitHubHint => 'GitHubを接続してAstroBoxリソースを一覧表示';

  @override
  String get creatorImportGitHubConnect => 'GitHubを接続';

  @override
  String get creatorImportStageDetails => '詳細を取得中';

  @override
  String get creatorImportStageDownloading => 'ファイルをダウンロード中';

  @override
  String get creatorImportStageMedia => '画像を処理中';

  @override
  String get creatorImportStageUploading => '下書きを作成中';

  @override
  String get creatorImportContinue => '続けてインポート';

  @override
  String get creatorImportPartialFailureTitle => '一部のリソースを読み込めませんでした';

  @override
  String creatorImportPartialFailureMessage(int count) {
    return '$count件のリソースを読み込めませんでした\n失敗した項目を再試行するか、正常に読み込めたリソースだけで続行できます';
  }

  @override
  String get creatorImportRetryFailed => '失敗した項目を再試行';

  @override
  String get creatorImportContinuePartial => '続行';

  @override
  String creatorImportWarnings(int count) {
    return '$count件の警告';
  }

  @override
  String get creatorDeleteExternalBandbbs => 'BandBBSのリソースも削除';

  @override
  String get creatorDeleteExternalAstrobox => 'AstroBox-Repoへ削除PRも送信';

  @override
  String get creatorDeleteExternalWarning => '外部での削除は取り消せません';

  @override
  String get creatorDeletePrSubmitted => '削除PRを送信しました';

  @override
  String githubCdnFallback(Object cdn) {
    return 'GitHubリクエストに失敗。$cdn経由で再試行中';
  }

  @override
  String get deviceConnectBle => 'BLEで接続';

  @override
  String get deviceConnectBtClassic => 'BT Classicで接続';

  @override
  String bandBbsIdLabel(Object id) {
    return 'BandBBS ID $id';
  }

  @override
  String get oobeCdnTestFailed => '失敗';

  @override
  String get settingsGithubCdnAuto => '自動';

  @override
  String get updateDownloading => '更新をダウンロード中';

  @override
  String get updateInstalling => '更新をインストール中';

  @override
  String get updateFailed => '更新に失敗';

  @override
  String updateNoApkForAbi(String abi) {
    return 'ABI $abi向けAPKがありません';
  }

  @override
  String get cleanUpdateGroup => '更新';

  @override
  String get cleanCheckUpdates => '起動時に更新を確認';

  @override
  String get updateLater => '後で';

  @override
  String get updateNow => '今すぐ更新';

  @override
  String get updateGoToPage => 'ダウンロードページを開く';

  @override
  String get updateDownloadFromCloud => 'クラウドからダウンロード';

  @override
  String get updateDownloadFromOfficial => '公式サイトからダウンロード';

  @override
  String get creatorImportNoticeTitle => '既存リソースをインポート';

  @override
  String get creatorImportNoticeMessage =>
      '複数デバイスに対応するリソースはBandBBSの複数セクションに公開されている場合があります\nインポート時は複数のBandBBS項目を選択できますが、同じリソースの項目だけを選択してください\nインポートを押すと選択項目を1つのリソースへ統合します\nインポートに失敗した場合は対応する下書きを開いて削除してください\n下書きを削除しても他プラットフォームに連携済みのリソースは削除されません';

  @override
  String get creatorImportNoticeConfirm => 'インポートを続行';

  @override
  String get creatorImportSameResourceHint => '1回のインポートでは同じリソースだけを選択してください';

  @override
  String get creatorFullVersionExternalPurchase => '外部購入が必要';

  @override
  String get creatorExternalPurchaseDescription =>
      'OronBox と AstroBox ではリソースファイルを試用版として公開し、購入ボタンを表示します。BandBBS では「第三者購入」リソースとして公開され、支払いに関する手続きはご自身で行ってください';

  @override
  String get creatorExternalPurchaseLink => '購入リンク';

  @override
  String get creatorExternalPurchaseAmount => '金額（CNY）';

  @override
  String get creatorExternalPurchaseLinkRequired => '有効な外部購入リンクを入力してください';

  @override
  String get creatorExternalPurchaseAmountRequired => '有効な CNY 金額を入力してください';

  @override
  String get resourcePurchaseFullVersion => '外部購入';

  @override
  String get creatorBandBbsOverwritePrevious => '前回の投稿を上書き';

  @override
  String get creatorBandBbsOverwritePreviousDescription =>
      '新しいバージョンを作成してから、BandBBS の前回の投稿を削除します';

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
  String get deviceHealthDayView => '日';

  @override
  String get deviceHealthWeekView => '週';

  @override
  String get deviceHealthMonthView => '月';

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
  String get deviceHealthSleepStages => '睡眠ステージ';

  @override
  String get deviceHealthSleepHrv => '睡眠 HRV';

  @override
  String get deviceHealthSleepAwake => '覚醒';

  @override
  String get deviceHealthSleepLight => '浅い睡眠';

  @override
  String get deviceHealthSleepDeep => '深い睡眠';

  @override
  String get deviceHealthSleepRem => 'REM';

  @override
  String get deviceHealthSleepNoStages => '睡眠ステージのデータなし';

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
  String get weatherAutoSyncTitle => '天気データを自動同期';

  @override
  String get weatherAutoSyncDescription => 'デバイスデータの同期時に天気データを自動同期';

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
  String get weatherAqiGood => '良好';

  @override
  String get weatherAqiModerate => '普通';

  @override
  String get weatherAqiSensitive => '敏感な人に影響';

  @override
  String get weatherAqiUnhealthy => '不健康';

  @override
  String get weatherAqiVeryUnhealthy => '非常に不健康';

  @override
  String get weatherAqiHazardous => '危険';

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
    return 'データソース：$source';
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
  String get xiaomiScreenshotTitle => 'デバイスのスクリーンショット';

  @override
  String get xiaomiScreenshotDescription =>
      'デバイスのキー操作でスクリーンショットを撮ると、ここに自動同期されます';

  @override
  String get xiaomiScreenshotAction => 'スクリーンショットを取得';

  @override
  String get xiaomiScreenshotLoading => '取得中…';

  @override
  String get xiaomiScreenshotEmpty => 'スクリーンショットはありません';

  @override
  String get xiaomiScreenshotFailed => 'スクリーンショットを取得できませんでした';

  @override
  String xiaomiScreenshotSaved(Object path) {
    return 'ウォッチのスクリーンショットを保存しました：$path';
  }
}
