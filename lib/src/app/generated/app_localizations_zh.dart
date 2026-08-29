// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get homeTab => '首页';

  @override
  String get exploreTab => '探索';

  @override
  String get devicesTab => '设备';

  @override
  String get pluginsTab => '插件';

  @override
  String get pluginImport => '导入插件';

  @override
  String get pluginInstalled => '已安装';

  @override
  String get pluginMarket => '插件市场';

  @override
  String get pluginMarketUnavailable => '插件市场暂未接入';

  @override
  String get pluginEmpty => '尚未安装插件';

  @override
  String get pluginSelectHint => '选择一个插件查看功能';

  @override
  String get pluginFeatures => '功能';

  @override
  String get pluginDetails => '详情';

  @override
  String get pluginNoFeatures => '此插件没有可用功能';

  @override
  String get pluginAuthor => '作者';

  @override
  String get pluginVersion => '版本';

  @override
  String get pluginApiLevel => 'API 级别';

  @override
  String get pluginWebsite => '网站';

  @override
  String get pluginPermissions => '权限';

  @override
  String get pluginInstallConfirmTitle => '插件安装确认';

  @override
  String get pluginUpdateConfirmTitle => '插件更新确认';

  @override
  String get pluginDeclaredPermissions => '此插件声明了以下权限：';

  @override
  String get pluginNoPermissions => '未声明任何权限';

  @override
  String get pluginUpToDate => '已安装且为最新版本';

  @override
  String get pluginUninstallTitle => '卸载插件';

  @override
  String get pluginUninstallMessage => '插件数据也将被删除';

  @override
  String get pluginUpload => '上传插件';

  @override
  String get pluginPublishTitle => '发布插件';

  @override
  String get pluginPublishNew => '将作为新插件发布';

  @override
  String get pluginPublishUpdate => '将更新已发布的同名插件';

  @override
  String get pluginTakedown => '下架';

  @override
  String get pluginTakedownConfirm => '下架后该插件将从市场永久移除';

  @override
  String get pluginLoginRequired => '登录后上传插件';

  @override
  String get pluginSubmittedForReview => '已提交审核，通过后将上架';

  @override
  String get pluginStatePending => '审核中';

  @override
  String get pluginStateRejected => '审核未通过';

  @override
  String get pluginStateDelisted => '已被下架';

  @override
  String get pluginLegacyWarningTitle => 'Legacy 插件';

  @override
  String get pluginLegacyWarningMessage =>
      '这是一个 AstroBox v1 插件，OronBox 会尝试以兼容模式转译运行，但可能遇到一些问题\n请尝试检查并更新 OronBox 原生插件或与插件作者联系适配';

  @override
  String get settingsTab => '设置';

  @override
  String get search => '搜索';

  @override
  String get resourceListView => '列表视图';

  @override
  String get resourceGridView => '卡片视图';

  @override
  String get refresh => '刷新';

  @override
  String get refreshing => '正在刷新';

  @override
  String get notifications => '通知';

  @override
  String get newlyPublished => '最新发布';

  @override
  String get resourceLibrary => '资源库';

  @override
  String get resourceDetails => '资源详情';

  @override
  String get resourceCollectionDetails => '合集详情';

  @override
  String get resourceArticleDetails => '文章详情';

  @override
  String get creatorCenter => '创作者中心';

  @override
  String get creatorNewResource => '新建资源';

  @override
  String get creatorResourceName => '资源名称';

  @override
  String get creatorResourceSummary => '资源简介';

  @override
  String get creatorResourceMetadataRequired => '资源名称和简介不能为空';

  @override
  String get creatorSubmitValidationFailed => '提交前请先处理以下问题';

  @override
  String get creatorPaidType => '付费类型';

  @override
  String get creatorSaveDraft => '保存草稿';

  @override
  String get creatorAddArtifact => '添加资源文件';

  @override
  String get creatorBindDevices => '绑定设备';

  @override
  String get creatorDeleteResource => '删除';

  @override
  String get creatorIconCover => '图标与封面';

  @override
  String get creatorInvalidImage => '无法解码该图片，请使用 PNG/JPEG/WebP';

  @override
  String get creatorInvalidPackage => '该文件不是 Vela 快应用或表盘';

  @override
  String creatorPublishPreparing(Object done, Object total) {
    return '正在处理文件 $done/$total';
  }

  @override
  String creatorPublishUploading(Object percent) {
    return '正在上传 $percent%';
  }

  @override
  String get creatorPublishServer => '服务器处理中…';

  @override
  String get creatorAstroBoxItemId => '资源 ID';

  @override
  String get creatorAstroBoxRepository => '仓库名';

  @override
  String get creatorAstroBoxTags => '标签（逗号分隔）';

  @override
  String get creatorAstroBoxAuthor => '作者（确保与你的AstroBox用户名一致）';

  @override
  String get creatorAstroBoxBindAccount => '绑定 AstroBox 账号';

  @override
  String get replace => '更换';

  @override
  String get delete => '删除';

  @override
  String get creatorSubmitReview => '提交';

  @override
  String get creatorArchiveAction => '下架';

  @override
  String get creatorArchiveConfirm => '下架后该资源将从商店隐藏，可随时恢复';

  @override
  String get creatorRestoreAction => '恢复上架';

  @override
  String get creatorDeleteConfirm => '将永久删除该草稿资源，无法恢复';

  @override
  String get creatorDeletePublishedConfirm =>
      '将永久删除 OronBox 资源，并同步删除对应的米坛资源，无法恢复\nAstroBox 上已发布的内容不受影响，如需下架请联系 AstroBox-Repo 维护者';

  @override
  String creatorArtifactCount(Object count) {
    return '$count 个安装包';
  }

  @override
  String creatorKindMismatchMessage(Object detected, Object expected) {
    return '这似乎是一个$detected文件，而你正在创建$expected资源。可以继续保留，但提交审核前请确认。';
  }

  @override
  String creatorDeviceMoveBlocked(Object name) {
    return '「$name」仅剩这一台绑定设备，无法移动';
  }

  @override
  String get creatorSelectDevices => '选择支持的设备';

  @override
  String creatorSelectedDeviceCount(Object count) {
    return '已选择 $count 台设备';
  }

  @override
  String get creatorNoDevicesSelected => '尚未选择设备';

  @override
  String get creatorDeviceSelectionDone => '完成';

  @override
  String get creatorAtLeastOneDevice => '每个资源文件至少要绑定一台设备';

  @override
  String get resourceAstroBoxEncryptedTitle => '此 AstroBox 资源无法由 OronBox 处理';

  @override
  String get resourceAstroBoxEncryptedMessage =>
      '此资源使用 AstroBox Creator Console 的私有加密上传\nOronBox 无法解密、下载或安装它\n请改用 AstroBox 打开';

  @override
  String get resourceAstroBoxEncryptedAction => '知道了';

  @override
  String get filter => '筛选';

  @override
  String get resourceTypeFilter => '资源类型';

  @override
  String get resourceCompatibleDevicesFilter => '适配设备';

  @override
  String get currentDevice => '当前设备';

  @override
  String get currentWatchface => '当前表盘';

  @override
  String get all => '全部';

  @override
  String get watchfaces => '表盘';

  @override
  String get module => '模块';

  @override
  String get quickApps => '快应用';

  @override
  String get firmwareTools => '固件 / 工具';

  @override
  String get oronBox => 'OronBox';

  @override
  String get bandbbs => 'BandBBS';

  @override
  String get astroBox => 'AstroBox';

  @override
  String get local => '本地';

  @override
  String get install => '安装';

  @override
  String get update => '更新';

  @override
  String get description => '描述';

  @override
  String get supportedDevices => '支持的设备';

  @override
  String get downloads => '下载包';

  @override
  String downloadTimes(int count) {
    return '$count 次下载';
  }

  @override
  String get changelog => '更新日志';

  @override
  String get changelogUnavailable => '暂无更新日志';

  @override
  String get notFound => '未找到';

  @override
  String get downloadStarted => '开始下载';

  @override
  String get compatible => '兼容';

  @override
  String get incompatible => '不兼容';

  @override
  String get incompatibleSuffix => '，可能无法正常使用';

  @override
  String get myResources => '我的资源';

  @override
  String get drafts => '草稿';

  @override
  String get pendingReview => '审核中';

  @override
  String get published => '已发布';

  @override
  String get creatorStateSuspended => '已下架';

  @override
  String get creatorStateFrozen => '已冻结';

  @override
  String get creatorSuspendedByOwnerNotice => '资源已下架，可继续编辑并重新提交审核，或直接恢复上架';

  @override
  String get creatorSuspendedByAdminNotice =>
      '资源已被管理员下架，可修改后重新提交审核，审核通过后自动恢复上架';

  @override
  String get creatorFrozenNotice => '资源已被管理员冻结，内容不可修改，仅管理员可解除';

  @override
  String creatorModerationReason(Object reason) {
    return '原因：$reason';
  }

  @override
  String get creatorBannedTitle => '账号已被封禁';

  @override
  String get creatorBannedDescription => '你的账号已被管理员封禁，无法使用创作者中心。如有疑问请通过工单联系管理员';

  @override
  String get creatorFrozenTitle => '创作者功能已被冻结';

  @override
  String get creatorFrozenDescription =>
      '你的创作者功能已被管理员冻结，暂时无法提交或管理资源。账号的其它功能不受影响';

  @override
  String get creatorBandBbsNoDevices => '请先为资源文件选择支持的设备';

  @override
  String creatorBandBbsUnmappedDevices(Object devices) {
    return '无法确定以下设备对应的米坛资源分区：$devices';
  }

  @override
  String get creatorBandBbsSharedCategory => '同一米坛分区的设备绑定了多个安装包，请让每个分区只对应一个包';

  @override
  String get creatorBandBbsUnresolved => '无法自动确定米坛分区';

  @override
  String get creatorOptionalIcon => '图标（可选，1:1）';

  @override
  String get creatorOptionalCover => '封面（可选，3:2）';

  @override
  String get creatorRequiredIcon => '图标（AstroBox 必选，1:1）';

  @override
  String get creatorRequiredCover => '封面（AstroBox 必选，3:2）';

  @override
  String get creatorIconShapeHint => '当前图标不是方形，在 AstroBox 中可能显示异常';

  @override
  String get creatorCoverShapeHint => '当前封面不是 3:2，在 AstroBox 中可能显示异常';

  @override
  String get creatorTermsBandBbs => '米坛社区条款和规则';

  @override
  String get creatorTermsAstroBox => 'AstroBox-Repo 投稿规范';

  @override
  String get creatorTermsAccept => '我已阅读并同意上述发布协议';

  @override
  String get creatorTermsContinue => '进入创作者中心';

  @override
  String get agree => '同意';

  @override
  String get creatorRulesAccept => '我已阅读并同意上述审核标准';

  @override
  String get creatorBandBbsTermsNotice =>
      'OronBox 审核通过后将以此资源信息直接发布到米坛对应分区\n删除 OronBox 资源会同步删除对应的米坛资源';

  @override
  String get creatorBandBbsLimitsNotice =>
      '一键发布米坛存在以下限制，发布后需手动处理：\n1. 米坛未提供资源 icon 上传接口，资源 icon 会显示为空白，需前往米坛社区手动修改\n2. 米坛未提供讨论区 tag 接口，资源的讨论区属性不会被设置，可能导致资源被删除，需前往米坛社区手动设置正确讨论区';

  @override
  String get creatorAstroBoxTermsNotice =>
      'OronBox 审核通过后将创建资源分仓库并向 AstroBox 官方仓库提交 PR，由 AstroBox 维护者独立审核\n发布后如需下架，请联系 AstroBox-Repo 维护者';

  @override
  String get creatorAstroBoxReviewNotice =>
      '发布到 AstroBox 的资源需满足以下要求：\n1. 资源本体不得包含色情低俗、政治敏感等不良内容或违反法律法规的内容\n2. 资源质量不得过低，例如仅模板换图制作的表盘、功能过于简陋的快应用\n3. 头图应美观且符合大众审美，比例 3:2（推荐 1200x800），图标推荐 192x192\n4. 资源在支持的设备上应能正常运行基本功能\n5. 禁止未经原作者授权盗传他人资源\n6. 使用知名 IP 素材时，preview 中必须包含版权声明图（声明素材与 AstroBox 及小米无关）';

  @override
  String get failed => '失败 / 需处理';

  @override
  String get basicInfo => '基本信息';

  @override
  String get packageFiles => '资源文件';

  @override
  String get publishTargets => '发布目标';

  @override
  String get scan => '扫描';

  @override
  String get logs => '日志';

  @override
  String get pairedDevices => '已配对设备';

  @override
  String get apps => '应用';

  @override
  String get deviceAppCount => '应用数量';

  @override
  String get deviceWatchfaceCount => '表盘数量';

  @override
  String get connection => '连接';

  @override
  String get protocol => '协议';

  @override
  String get error => '错误';

  @override
  String get errorBluetoothUnavailable =>
      '蓝牙不可用，请检查蓝牙是否已开启，并确认系统权限已允许 OronBox 使用蓝牙';

  @override
  String get errorBluetoothConnectFailed =>
      '连接失败，请确认蓝牙权限已授予且蓝牙已开启、设备在附近、未被其他工具或设备占用，并在设备端开启“连接新手机”模式后重试';

  @override
  String get errorBluetoothDisconnected => '蓝牙连接已断开，请重新连接设备';

  @override
  String get errorOperationTimeout => '操作超时，请确认设备仍在附近并重试';

  @override
  String get errorDeviceNotReady => '设备尚未准备好，请先连接并完成认证';

  @override
  String get errorBleCharacteristicsMissing =>
      '未找到需要的 BLE 通道，请重新连接设备或检查设备是否支持该功能';

  @override
  String get errorWebSerialUnavailable =>
      '当前浏览器不支持 Web Serial，请使用 Chrome / Edge 等支持 Web Serial 的浏览器';

  @override
  String get errorAccountPasswordIncorrect => '小米账号或密码错误';

  @override
  String get errorAccountTwoFactorIncomplete => '小米账号二次验证未完成，请重新登录';

  @override
  String get errorOronBoxSessionExpired => 'OronBox 登录已过期，请重新登录米坛账号';

  @override
  String get errorNetworkUnavailable => '无法连接服务，请检查网络后重试';

  @override
  String get errorServiceUnavailable => '服务暂时不可用，请稍后重试';

  @override
  String get errorPermissionDenied => '当前账号没有执行此操作的权限';

  @override
  String get errorContentNotFound => '请求的内容不存在或已不可用';

  @override
  String get errorRequestConflict => '内容状态已发生变化，请刷新后重试';

  @override
  String get errorCoinBalanceInsufficient => '硬币余额不足';

  @override
  String get errorCoinResourceLimit => '该资源最多投 2 颗币';

  @override
  String get errorCoinOwnResource => '不能给自己的资源投币';

  @override
  String get errorCoinVotingFrozen => '投币功能已被冻结';

  @override
  String get errorCoinAccountTooNew => '账号注册满 24 小时后才能投币';

  @override
  String get errorCoinOperationFailed => '投币失败，请重试';

  @override
  String get errorCoinStatusUnavailable => '无法获取投币状态，点击重试';

  @override
  String get errorOperationFailed => '操作失败，请重试';

  @override
  String get errorUnknown => '发生未知错误，请重试';

  @override
  String get errorDownloadQuotaExceeded => '已达到今日下载次数限制';

  @override
  String get errorGitHubNotConfigured => 'GitHub 发布尚未配置';

  @override
  String get errorRateLimited => '操作过于频繁，请稍后重试';

  @override
  String get errorFileTooLarge => '所选文件过大';

  @override
  String get errorInvalidRequest => '提交的信息有误，请检查后重试';

  @override
  String get errorOperationCancelled => '操作已取消';

  @override
  String get errorUnsupportedFileType => '不支持或无法识别的文件类型';

  @override
  String get errorCertificateVerificationFailed =>
      '证书校验失败，如正在使用代理，请关闭代理对本应用的 HTTPS 拦截，或确保证书受信任';

  @override
  String errorUnknownWithDetail(Object detail) {
    return '操作失败：$detail';
  }

  @override
  String get appearance => '外观';

  @override
  String get resources => '资源';

  @override
  String get communitySourceAstroBoxRepo => 'AstroBox Repo';

  @override
  String get communitySourceBandBbs => '米坛社区';

  @override
  String get communitySourceHuamiAppStore => '华米应用商店';

  @override
  String get devices => '设备';

  @override
  String creatorCompatibleDeviceCount(int count) {
    return '$count 个设备';
  }

  @override
  String get categories => '分区';

  @override
  String get advanced => '高级';

  @override
  String get openSourceLicenses => '开放源代码许可';

  @override
  String get acknowledgements => '特别鸣谢';

  @override
  String get deviceNotConnected => '未连接';

  @override
  String get deviceConnected => '已连接';

  @override
  String get deviceDisconnected => '已断开';

  @override
  String get deviceReconnect => '重新连接';

  @override
  String get deviceConnect => '连接设备';

  @override
  String get deviceSwitch => '切换设备';

  @override
  String get deviceSyncTime => '同步';

  @override
  String get deviceCharging => '充电中';

  @override
  String get deviceLastChargedNow => '刚刚充电';

  @override
  String deviceLastChargedMinutes(int count) {
    return '$count 分钟前充电';
  }

  @override
  String deviceLastChargedHours(int count) {
    return '$count 小时前充电';
  }

  @override
  String deviceLastChargedDays(int count) {
    return '$count 天前充电';
  }

  @override
  String get deviceFeaturesInstallApp => '安装应用';

  @override
  String get deviceFeaturesInstallWatchface => '安装表盘';

  @override
  String get deviceFeaturesInstallFirmware => '固件更新';

  @override
  String get deviceFeaturesInstallFirmwareDesc => '检查设备更新或安装本地固件';

  @override
  String get firmwareCheckingUpdates => '正在检查固件更新';

  @override
  String get firmwareNoUpdatesFound => '未找到适用于当前设备的新版本';

  @override
  String get firmwareSourceUnavailable => '暂未接入此类设备的在线固件源';

  @override
  String get firmwareVersionUnknown => '未获取到当前固件版本';

  @override
  String get firmwareCurrentVersion => '当前版本';

  @override
  String get firmwareLatestRelease => '最新固件';

  @override
  String get firmwareHistoricalReleases => '历史固件';

  @override
  String get firmwareUpToDate => '当前已是最新版本';

  @override
  String get firmwareUpdateAvailable => '发现可用更新';

  @override
  String get firmwareDownloadLatestFull => '下载最新完整包';

  @override
  String get firmwareUpdateNow => '更新';

  @override
  String get firmwareReleaseNotes => '更新日志';

  @override
  String get firmwareReleaseNotesUnavailable => '暂无更新日志';

  @override
  String get download => '下载';

  @override
  String get downloadTaskAdded => '已加入下载队列';

  @override
  String get zeppOsMoreFeatures => '特色功能';

  @override
  String get zeppOsMoreFeaturesDescription => '管理 Zepp OS 设备的扩展功能';

  @override
  String get zeppOsDeviceFeaturesSection => '设备功能';

  @override
  String get zeppOsAppsAndDevelopmentSection => '应用与开发';

  @override
  String get zeppOsAssistant => '语音实验室';

  @override
  String get zeppOsAssistantDescription => '采集、监听并回复手表语音助手会话';

  @override
  String get zeppOsScreenMirror => '屏幕镜像';

  @override
  String get zeppOsScreenMirrorDescription => '在当前设备上查看手表画面';

  @override
  String get zeppOsScreenMirrorSemantics => 'Zepp OS 手表屏幕镜像';

  @override
  String zeppOsScreenMirrorUnsupported(Object error) {
    return '无法显示当前画面格式：$error';
  }

  @override
  String get expand => '展开';

  @override
  String get collapse => '收起';

  @override
  String get voiceLabTitle => '语音实验室';

  @override
  String get voiceLabXiaoAi => '小爱同学';

  @override
  String get voiceLabReceivingAudio => '正在接收手表音频';

  @override
  String get voiceLabWaiting => '等待语音会话';

  @override
  String get voiceLabContinuousCapture => '连续采集';

  @override
  String get voiceLabContinuousCaptureDescription => '当前语音结束后自动请求下一段';

  @override
  String get voiceLabDisableMonitoring => '关闭实时监听';

  @override
  String get voiceLabEnableMonitoring => '开启实时监听';

  @override
  String get voiceLabReplyLabel => '返回给手表的消息';

  @override
  String get voiceLabReplyHint => '输入回复内容';

  @override
  String get voiceLabReplyQueued => '消息已排队，将在本轮录音结束后返回手表';

  @override
  String get voiceLabReplySent => '消息已发送到手表';

  @override
  String get voiceLabCapturedData => '采集数据';

  @override
  String get voiceLabDecoder => '解码器';

  @override
  String get voiceLabOpusFrames => 'Opus 帧';

  @override
  String get voiceLabDataSize => '数据量';

  @override
  String get voiceLabPcmSamples => 'PCM 采样';

  @override
  String get voiceLabExportOpus => '导出 Opus';

  @override
  String get voiceLabExportWav => '导出 WAV';

  @override
  String get voiceLabClearCapture => '清空采集数据';

  @override
  String get voiceLabSaveRecording => '保存语音录音';

  @override
  String get voiceLabSaveOpus => '保存 Opus 音频';

  @override
  String get voiceLabAudioProcessingFailedPrefix => '音频处理失败';

  @override
  String voiceLabAudioProcessingFailed(Object error) {
    return '音频处理失败：$error';
  }

  @override
  String voiceLabContinuousCaptureFailed(Object error) {
    return '无法设置连续采集：$error';
  }

  @override
  String voiceLabAssistantSwitchFailed(Object error) {
    return '无法切换语音助手：$error';
  }

  @override
  String voiceLabExportWavFailed(Object error) {
    return '导出 WAV 失败：$error';
  }

  @override
  String voiceLabExportOpusFailed(Object error) {
    return '导出 Opus 失败：$error';
  }

  @override
  String get send => '发送';

  @override
  String sendFailed(Object error) {
    return '发送失败：$error';
  }

  @override
  String get ready => '已就绪';

  @override
  String get initializing => '初始化中';

  @override
  String get zeppOsMapSelectPackage => '选择 Zepp OS 地图包';

  @override
  String get zeppOsMapReadFailed => '无法读取地图包';

  @override
  String get zeppOsMapTransferTitle => '传输离线地图';

  @override
  String zeppOsMapGarminDetected(Object fileName, Object mapName) {
    return '$fileName\n已识别为单文件 Garmin IMG 地图：$mapName';
  }

  @override
  String get zeppOsMapGarminNoPreview =>
      '该地图不包含 Zepp OS 的 11/x/y 瓦片目录，将保留原始 IMG 并作为单文件地图包传输，因此无法提供覆盖范围预览。';

  @override
  String zeppOsMapTileSummary(Object fileName, Object count) {
    return '$fileName · $count 个瓦片\n预览仅表示地图包的覆盖范围，不代表手表上的 Garmin IMG 渲染效果。';
  }

  @override
  String get zeppOsMapStartTransfer => '开始传输';

  @override
  String get zeppOsMapTransferringBluetooth => '正在通过蓝牙传输';

  @override
  String get zeppOsMapTransferComplete => '离线地图传输完成';

  @override
  String get zeppOsMapConversionFailed => '无法安全转换地图';

  @override
  String get zeppOsMapBtClassicHint =>
      '当前使用 BT Classic 大文件通道。开始传输后，请同时在手表上确认安装。';

  @override
  String get zeppOsMapBleHint =>
      'BLE 仅支持不超过 2 MB 的地图包；传输更大的地图前请切换至 BT Classic。开始传输后，请同时在手表上确认安装。';

  @override
  String get zeppOsMapPreviewTooLarge => '地图范围过大，无法完整预览';

  @override
  String zeppOsSettingPageLoadFailed(Object error) {
    return '设置页面加载失败：$error';
  }

  @override
  String zeppOsAppCompatibilitySaved(Object appId) {
    return '$appId 兼容文件已保存';
  }

  @override
  String zeppOsAppStorageSaved(Object appId) {
    return '$appId settingsStorage 已保存';
  }

  @override
  String get zeppOsAppSupplementFiles => '添加 app-side 或 setting 文件';

  @override
  String get zeppOsAppSupplementCompatibility => '添加小程序兼容文件';

  @override
  String get zeppOsAppReplaceCompatibility => '添加或替换兼容文件';

  @override
  String get zeppOsAppSideAvailable => 'app-side ✓';

  @override
  String get zeppOsAppSideMissing => '缺少 app-side';

  @override
  String get zeppOsSettingAvailable => 'setting ✓';

  @override
  String get zeppOsSettingMissing => '缺少 setting';

  @override
  String get zeppOsAppEditStorage => '编辑 settingsStorage';

  @override
  String get zeppOsStorageKeyRequired => '键名不能为空';

  @override
  String zeppOsStorageDuplicateKey(Object key) {
    return '键名重复：$key';
  }

  @override
  String get zeppOsStorageDescription =>
      '这些数据由 setting 页面与 app-side 共享，并按照 Zepp OS 规范以字符串保存。';

  @override
  String get zeppOsStorageEmpty => '暂无存储项';

  @override
  String get zeppOsStorageKey => '键';

  @override
  String get zeppOsStorageValue => '值';

  @override
  String get clear => '清空';

  @override
  String get save => '保存';

  @override
  String get selectedFileReadFailed => '无法读取所选文件';

  @override
  String get zeppOsAppInvalidHexId => '请输入有效的十六进制 App ID';

  @override
  String get zeppOsAppSelectCompatibilityFile =>
      '请至少选择一个 app-side.js 或 setting.js';

  @override
  String get zeppOsAppHexId => 'App ID（十六进制）';

  @override
  String get optionalDisplayName => '显示名称（可选）';

  @override
  String get zeppOsAppSideUnchanged => '保留现有 app-side';

  @override
  String get zeppOsSettingUnchanged => '保留现有 setting';

  @override
  String get selectFile => '选择文件';

  @override
  String get zeppOsAppCompatibilityOverwriteHint =>
      '保存会覆盖该 App ID 下的同名兼容文件，但不会修改手表内的小程序。';

  @override
  String zeppOsDebugRefreshFailed(Object error) {
    return '自动刷新失败：$error';
  }

  @override
  String get zeppOsDebugInvalidHex => 'HEX 只能包含完整字节，以及空格、换行、0x、逗号等分隔符';

  @override
  String get zeppOsDebugClearEventsTitle => '清空当前 App 的事件？';

  @override
  String zeppOsDebugClearEventsDescription(Object appId) {
    return '将清空 $appId 的全部调试事件。';
  }

  @override
  String get zeppOsDebugClearEvents => '清空事件';

  @override
  String get zeppOsDebugRefresh => '刷新状态与事件';

  @override
  String get zeppOsDebugAppList => 'App-side 列表';

  @override
  String get zeppOsDebugNoApps => '暂无缓存脚本，也尚未检测到手表 app-side 会话。';

  @override
  String get zeppOsDebugCached => '已有缓存';

  @override
  String get zeppOsDebugNotCached => '无缓存';

  @override
  String get zeppOsDebugRuntimeRunning => 'runtime 运行中';

  @override
  String get zeppOsDebugRuntimeStopped => 'runtime 未运行';

  @override
  String get zeppOsDebugLocalRuntime => '本地运行';

  @override
  String get zeppOsDebugCannotStart => '此 App ID 没有缓存脚本，无法在本地启动。';

  @override
  String get zeppOsDebugCanStart => '可手动启动缓存脚本；不会伪造手表会话参数。';

  @override
  String get zeppOsDebugScriptRunning => '脚本正在本地 QuickJS 中运行。';

  @override
  String get zeppOsDebugStartQuickJs => '启动 QuickJS';

  @override
  String get stop => '停止';

  @override
  String get zeppOsDebugMessageEditor => '消息编辑器';

  @override
  String get zeppOsDebugUtf8Text => 'UTF-8 文本';

  @override
  String get zeppOsDebugJsonCompact => 'JSON（发送前压缩）';

  @override
  String get zeppOsDebugHexBytes => 'HEX 字节';

  @override
  String get zeppOsDebugEncodingFailed => '无法按所选模式编码当前内容';

  @override
  String get zeppOsDebugByteCountUnavailable => '字节数：--';

  @override
  String zeppOsDebugBytePreview(Object count, Object hex) {
    return '字节数：$count\nHEX：$hex';
  }

  @override
  String get zeppOsDebugInjectLocal => '模拟入站消息到本地 runtime';

  @override
  String get zeppOsDebugSendToWatch => '发送到手表';

  @override
  String get zeppOsDebugWaitingForWatch => '发送到手表（等待真实会话）';

  @override
  String get zeppOsDebugEvents => '调试事件';

  @override
  String get zeppOsDebugClearCurrentApp => '清空当前 App';

  @override
  String get zeppOsDebugSearch => '搜索类型、消息、HEX 或可读文本';

  @override
  String get zeppOsDebugWatchOnly => '仅显示真实手表消息';

  @override
  String get zeppOsDebugNoEvents => '当前筛选条件下暂无事件';

  @override
  String get zeppOsDebugMessageActions => '消息操作';

  @override
  String get zeppOsDebugLoadEditor => '载入编辑器';

  @override
  String get zeppOsDebugCopyHex => '复制 HEX';

  @override
  String get zeppOsDebugCopyText => '复制文本';

  @override
  String get zeppOsDebugSessionStatus => '运行与会话状态';

  @override
  String zeppOsDebugCachedScript(Object status) {
    return '缓存脚本：$status';
  }

  @override
  String zeppOsDebugLocalRuntimeStatus(Object status) {
    return '本地 runtime：$status';
  }

  @override
  String zeppOsDebugWatchSession(Object status) {
    return '手表会话：$status';
  }

  @override
  String get exists => '存在';

  @override
  String get notExists => '不存在';

  @override
  String get running => '运行中';

  @override
  String get notRunning => '未运行';

  @override
  String get notOpen => '未打开';

  @override
  String get zeppOsDebugWatchSessionOpen => '真实会话已打开';

  @override
  String get zeppOsDebugRealHeader => '真实 header';

  @override
  String zeppOsDebugLatestStartup(Object status) {
    return '最近启动状态：$status';
  }

  @override
  String get zeppOsDebugWatchInbound => '手表入站';

  @override
  String get zeppOsDebugWatchOutbound => '发往手表';

  @override
  String get zeppOsDebugLifecycle => '生命周期';

  @override
  String get zeppOsMirrorInterval => '画面间隔';

  @override
  String get zeppOsMirrorIntervalRange => '10–250';

  @override
  String get zeppOsOfflineMaps => '离线地图';

  @override
  String get zeppOsOfflineMapsDescription => '将已有地图包传输至手表';

  @override
  String get zeppOsAppSettings => '应用设置';

  @override
  String get zeppOsAppSettingsDescription => '管理已缓存的 Zepp OS 应用设置';

  @override
  String get zeppOsAppDebug => '应用调试';

  @override
  String get zeppOsAppDebugDescription => '调试应用侧脚本与设备通信';

  @override
  String get deviceMusicSync => '音乐同步';

  @override
  String get deviceHealthTitle => '运动健康';

  @override
  String get deviceHealthDescription => '同步设备上的活动与睡眠数据';

  @override
  String get deviceHealthSyncCardTitle => '健康数据';

  @override
  String get deviceHealthNeverSynced => '还没有同步过运动健康数据';

  @override
  String deviceHealthLastSynced(String time) {
    return '上次同步于 $time';
  }

  @override
  String get deviceHealthSync => '同步运动健康数据';

  @override
  String get deviceHealthSyncing => '正在同步';

  @override
  String get deviceHealthAutoSyncTitle => '自动同步运动健康数据';

  @override
  String get deviceHealthAutoSyncDescription => '在同步设备数据时自动同步运动健康数据';

  @override
  String get deviceHealthConnectFirst => '请先连接设备再同步运动健康数据';

  @override
  String get deviceHealthPartialSync => '部分运动健康数据同步失败';

  @override
  String get deviceHealthToday => '今日活动';

  @override
  String get deviceHealthSteps => '步数';

  @override
  String get deviceHealthDistance => '距离';

  @override
  String get deviceHealthCalories => '卡路里';

  @override
  String get deviceHealthHeartRate => '心率';

  @override
  String get deviceHealthRestingHeartRate => '静息心率';

  @override
  String get deviceHealthAbnormalHeartRate => '异常心率';

  @override
  String get deviceHealthHeartRateHigh => '心率过高';

  @override
  String get deviceHealthHeartRateLow => '心率过低';

  @override
  String get deviceHealthHeartHealth => '心脏健康';

  @override
  String get deviceHealthHeartHealthMonitoring => '心脏健康监测';

  @override
  String get deviceHealthIrregularHeartbeat => '异常心搏';

  @override
  String get deviceHealthLowBloodOxygen => '血氧过低';

  @override
  String get deviceHealthHighStress => '压力过高';

  @override
  String get deviceHealthDetected => '已检测';

  @override
  String get deviceHealthSleep => '最近睡眠';

  @override
  String get deviceHealthSleepCard => '睡眠';

  @override
  String get deviceHealthAllDaySleep => '全天睡眠';

  @override
  String get deviceHealthLongSleep => '长睡眠';

  @override
  String get deviceHealthSleepStructure => '睡眠结构';

  @override
  String get deviceHealthSleepAverageHeartRate => '睡眠平均心率';

  @override
  String get deviceHealthSleepAverageBloodOxygen => '睡眠平均血氧';

  @override
  String deviceHealthAverageHeartRate(int value) {
    return '平均心率 $value bpm';
  }

  @override
  String get deviceHealthNoData => '暂无数据';

  @override
  String get deviceHealthLoadFailed => '无法读取运动健康数据';

  @override
  String get deviceMusicUpload => '传输音乐';

  @override
  String get deviceMusicSyncDescription => '将 MP3 文件同步至设备';

  @override
  String get deviceMusicChooseDialog => '选择要同步至设备的 MP3 文件';

  @override
  String get deviceMusicReadFailed => '无法读取所选 MP3 文件';

  @override
  String deviceMusicSizeInvalid(int maxMb) {
    return 'MP3 文件大小须大于 0 且不超过 $maxMb MB';
  }

  @override
  String get deviceMusicUnknownArtist => '未知艺术家';

  @override
  String get deviceMusicTransferred => '音乐传输完成';

  @override
  String get deviceMusicLibrary => '设备音乐';

  @override
  String get deviceMusicLibraryDescription => '管理设备中的歌曲与歌单';

  @override
  String get deviceMusicSongs => '歌曲';

  @override
  String deviceMusicSongsTotal(int count) {
    return '共 $count 首';
  }

  @override
  String get deviceMusicNoPlaylist => '未加入歌单';

  @override
  String get deviceMusicPlaylists => '歌单';

  @override
  String get deviceMusicEmpty => '设备中暂无歌曲';

  @override
  String get deviceMusicNoPlaylists => '尚未创建歌单';

  @override
  String deviceMusicLoadFailed(String error) {
    return '读取设备音乐失败：$error';
  }

  @override
  String get deviceMusicPlaylistCreate => '新建歌单';

  @override
  String get deviceMusicPlaylistRename => '重命名歌单';

  @override
  String get deviceMusicPlaylistName => '歌单名称';

  @override
  String deviceMusicPlaylistLimit(int count) {
    return '最多可创建 $count 个歌单';
  }

  @override
  String deviceMusicSongCount(int count) {
    return '$count 首歌曲';
  }

  @override
  String get deviceMusicDeleteSong => '从设备删除歌曲？';

  @override
  String get deviceMusicDeletePlaylist => '删除歌单？';

  @override
  String get deviceMusicDeletePlaylistDescription => '歌单中的歌曲不会从设备删除。';

  @override
  String get deviceMusicManagePlaylists => '管理所属歌单';

  @override
  String get deviceMusicPlaylistMembership => '所属歌单';

  @override
  String deviceMusicTransferSpeed(String speed) {
    return '$speed/s';
  }

  @override
  String deviceMusicSelectedFiles(int count) {
    return '已选择 $count 个文件';
  }

  @override
  String deviceMusicQueueProgress(int current, int total, String name) {
    return '正在传输 $current/$total：$name';
  }

  @override
  String get deviceRecordingsTitle => '录音同步';

  @override
  String get deviceRecordingsDescription => '从手表同步并导出录音';

  @override
  String get deviceRecordingsHint => '录音通过设备文件通道逐条接收并校验\n完成后可单独导出原始文件';

  @override
  String get deviceRecordingsSync => '同步录音';

  @override
  String get deviceRecordingsReading => '正在读取录音列表';

  @override
  String deviceRecordingsProgress(int completed, int total, String name) {
    return '已接收 $completed/$total：$name';
  }

  @override
  String deviceRecordingsProgressCount(int completed, int total) {
    return '已接收 $completed/$total';
  }

  @override
  String get deviceRecordingsEmpty => '连接手表后点击“同步录音”';

  @override
  String get deviceRecordingsSave => '导出录音';

  @override
  String get deviceRecordingsNoneOnWatch => '手表中没有新的录音';

  @override
  String deviceRecordingsSynced(int count) {
    return '已同步 $count 条录音';
  }

  @override
  String deviceRecordingsSaveFailed(String error) {
    return '导出录音失败：$error';
  }

  @override
  String get deviceMusicTransferTitle => '传输 MP3 文件';

  @override
  String get deviceMusicVelaDescription => '将 MP3 文件同步至设备，单个文件不得超过 100 MB。';

  @override
  String get deviceMusicZeppDescription =>
      '支持最大 50 MB 的 MP3 文件。建议使用经典蓝牙以获得更快的传输速度；也可使用 BLE，但传输时间较长。';

  @override
  String get deviceMusicChooseMp3 => '选择 MP3 文件';

  @override
  String get deviceMusicSongTitle => '歌曲名称';

  @override
  String get deviceMusicArtist => '艺术家';

  @override
  String deviceMusicFileSize(Object size) {
    return '文件大小：$size';
  }

  @override
  String deviceMusicProgress(Object progress) {
    return '传输进度：$progress%';
  }

  @override
  String get deviceMusicTransferring => '正在传输';

  @override
  String get deviceMusicSend => '开始传输';

  @override
  String get zeppOsFindDevice => '查找设备';

  @override
  String get zeppOsFindDeviceDescription => '让设备持续振动或响铃';

  @override
  String get deviceFeaturesDeviceInfo => '设备信息';

  @override
  String get deviceFeaturesDeviceInfoDesc => '固件、存储空间与详情';

  @override
  String get switchDeviceTitle => '切换设备';

  @override
  String get savedDevices => '已配对设备';

  @override
  String get deviceSwitchAddDevice => '添加设备';

  @override
  String get scanAndAdd => '扫描并添加';

  @override
  String get authkey => '认证密钥';

  @override
  String get authkeyPrompt => '输入设备认证密钥';

  @override
  String get authkeyPlaceholder => '认证密钥';

  @override
  String get connectFailed => '连接失败';

  @override
  String deviceConnectingTo(String deviceName) {
    return '正在连接 $deviceName…';
  }

  @override
  String get deviceConnectionPreparing => '正在准备连接…';

  @override
  String deviceConnectionEstablishing(String transport) {
    return '正在建立 $transport 连接…';
  }

  @override
  String get deviceConnectionInitializing => '正在初始化设备协议…';

  @override
  String get deviceConnectionAuthenticating => '正在认证设备…';

  @override
  String get deviceConnectionFetchingStatus => '正在读取设备信息…';

  @override
  String get deviceTransportBle => 'BLE';

  @override
  String deviceEndpointUnavailable(String transport) {
    return '未发现可用的 $transport 连接通道，请先完成系统蓝牙配对，然后重新扫描。';
  }

  @override
  String get deviceTransportSpp => 'SPP';

  @override
  String get deviceCompatibilityUnknown => '未识别设备';

  @override
  String get webSerialTitle => 'Web Serial';

  @override
  String get webSerialHint =>
      '在网页端，OronBox 通过 Web Serial 连接设备，已保存的设备会保留在当前浏览器中';

  @override
  String get webSerialConnectDialogTitle => '通过 Web Serial 连接';

  @override
  String get webSerialConnectDialogHint =>
      '输入设备认证密钥，并在浏览器弹窗中选择串口，认证密钥会保存在当前浏览器中';

  @override
  String get cancel => '取消';

  @override
  String get deviceActionsDelete => '删除';

  @override
  String get deviceActionsDisconnect => '断开连接';

  @override
  String get deviceActionsShareQR => '分享二维码';

  @override
  String get deviceShareOronBoxCode => '切换为 OronBox 码';

  @override
  String get deviceShareAstroBoxCompatibleCode => '切换 AstroBox 兼容码';

  @override
  String get installTapToSelectFile => '点击选择文件';

  @override
  String get deviceInfoTitle => '设备信息';

  @override
  String get deviceInfoGroupDevice => '设备';

  @override
  String get deviceInfoGroupSystem => '系统';

  @override
  String get deviceInfoGroupStatus => '状态';

  @override
  String get fieldName => '名称';

  @override
  String get fieldAddress => '地址';

  @override
  String get fieldAuthkey => '认证密钥';

  @override
  String get fieldConnectionType => '连接类型';

  @override
  String get fieldCodename => '代号';

  @override
  String get fieldModel => '型号';

  @override
  String get fieldImei => 'IMEI';

  @override
  String get fieldFirmware => '固件';

  @override
  String get fieldSerial => '序列号';

  @override
  String get fieldBattery => '电量';

  @override
  String get fieldChargeStatus => '充电状态';

  @override
  String get fieldStorage => '存储空间';

  @override
  String get appManagementTitle => '应用管理';

  @override
  String get appManagementNone => '没有已安装的应用';

  @override
  String get appManagementShowSystemApps => '显示系统应用';

  @override
  String get watchfaceManagementTitle => '表盘管理';

  @override
  String get watchfaceManagementNone => '没有已安装的表盘';

  @override
  String get open => '打开';

  @override
  String get externalLinkTitle => '跳转外部链接';

  @override
  String externalLinkDescription(String url) {
    return '即将跳转到 $url\n\n该网站由第三方运营，与 OronBox 没有从属关系，安全性未知，请注意辨别，是否继续访问？';
  }

  @override
  String get externalLinkAstroBoxResourceHint =>
      '这似乎是一个 AstroBox 资源，您也可以在 OronBox内访问并安装';

  @override
  String get continueToWebsite => '继续访问';

  @override
  String get viewInOronBox => '在 OronBox 中查看';

  @override
  String get uninstall => '卸载';

  @override
  String get enable => '设为当前';

  @override
  String get show => '显示';

  @override
  String get hide => '隐藏';

  @override
  String get copy => '复制';

  @override
  String get copied => '已复制';

  @override
  String get close => '关闭';

  @override
  String get desktopTrayShow => '显示窗口';

  @override
  String get desktopTrayExit => '退出 OronBox';

  @override
  String get desktopCloseTitle => '退出确认';

  @override
  String get desktopCloseMessage => '您想要退出 OronBox 吗？';

  @override
  String get desktopCloseRemember => '下次不再询问';

  @override
  String get desktopCloseToTray => '最小化到托盘';

  @override
  String get desktopCloseExit => '退出 OronBox';

  @override
  String get settingsDesktopCloseBehavior => '窗口关闭';

  @override
  String get settingsDesktopCloseBehaviorDesc => '选择关闭主窗口时执行的操作';

  @override
  String get settingsRemoveBondBeforeSpp => '连接时重新配对';

  @override
  String get settingsRemoveBondBeforeSppDesc =>
      '开启有助于提升连接稳定性，防止官方运动健康抢走设备连接，关闭后有助于加快连接速度';

  @override
  String get desktopCloseBehaviorAsk => '每次询问';

  @override
  String get desktopCloseBehaviorExit => '直接退出';

  @override
  String get desktopCloseBehaviorTray => '最小化到托盘';

  @override
  String get quickApp => '快应用';

  @override
  String get miniprogram => '小程序';

  @override
  String get miniprograms => '小程序';

  @override
  String get watchface => '表盘';

  @override
  String get firmwareTool => '固件 / 工具';

  @override
  String get free => '免费';

  @override
  String get paid => '付费';

  @override
  String get forcePaid => '强制付费';

  @override
  String get version => '版本';

  @override
  String get noContent => '暂无内容';

  @override
  String get preview => '预览';

  @override
  String get productDeviceRequirements => '系统要求';

  @override
  String get productOtherVersions => '其他版本';

  @override
  String get productInQueue => '已在队列';

  @override
  String get settingsAccount => '账号';

  @override
  String get settingsGeneral => '通用';

  @override
  String get settingsQueue => '队列';

  @override
  String get settingsAbout => '关于';

  @override
  String get settingsAccountLoginBBSDesc => '登录以访问米坛资源';

  @override
  String get settingsAccountBandBbsSigningIn => '正在登录';

  @override
  String get settingsAccountBandBbsOpenedBrowser => '已打开浏览器，请完成 BandBBS 授权';

  @override
  String get settingsAccountBandBbsSignedIn => 'BandBBS 登录成功';

  @override
  String get settingsAccountBandBbsLoginFailed => 'BandBBS 登录失败';

  @override
  String get settingsBandBbsAccountRequired => '请先在设置中登录米坛账号';

  @override
  String get settingsAccountBBSAccount => '米坛账号';

  @override
  String get bandBbsAccountTitle => '米坛账号';

  @override
  String get bandBbsResourceId => '资源 ID';

  @override
  String get bandBbsResourceIdHint => '输入米坛资源 ID';

  @override
  String get bandBbsQueryResource => '查询';

  @override
  String get bandBbsLogout => '退出登录';

  @override
  String get bandBbsLoggedOut => '已退出登录';

  @override
  String accountSignOutTitle(Object accountName) {
    return '退出 $accountName？';
  }

  @override
  String get accountSignOutMessage => '退出后，如需继续使用相关功能，需要重新登录。';

  @override
  String get bandBbsLoadPreviews => '加载资源帖预览图';

  @override
  String get bandBbsLoadPreviewsDesc => '在资源列表中自动加载帖子附件预览图';

  @override
  String get bandBbsShowAllCategories => '显示所有资源分区';

  @override
  String get bandBbsShowAllCategoriesDesc => '包含默认隐藏的未适配设备分区';

  @override
  String get settingsMiAccount => '小米账号';

  @override
  String get settingsMiAccountDesc => '登录并同步已绑定设备 authkey';

  @override
  String get deviceSwitchMiAccountImport => '登录小米账号同步绑定的设备';

  @override
  String get deviceSwitchWearableLogImport => '从小米运动健康日志导入设备';

  @override
  String get settingsMiAccountLoginTitle => '小米账号登录';

  @override
  String get settingsMiAccountUsername => '账号';

  @override
  String get settingsMiAccountPassword => '密码';

  @override
  String get settingsMiAccountRememberCredentials => '记住账号密码';

  @override
  String get settingsMiAccountLoginAndSync => '登录并同步';

  @override
  String get settingsMiAccountLogInvalid => '无法读取该小米运动健康日志';

  @override
  String get settingsMiAccountLogNoDevices => '日志中未找到包含完整 MAC 和 authkey 的设备';

  @override
  String get settingsWearableLogSync => '读取运动健康日志';

  @override
  String get settingsWearableLogGuide =>
      '打开 小米运动健康\n“我的”页面底部“关于”\n连续狂点橙色圆环 logo 图标\n在弹出的对话框点击“确认”\n等待 toast 提示 log has been...\n回到此处点击扫描';

  @override
  String settingsWearableLogFound(int count) {
    return '识别到 $count 个设备，点击以导入';
  }

  @override
  String settingsWearableLogImportedDevice(Object name) {
    return '已导入 $name';
  }

  @override
  String get settingsMiAccountMissingCredentials => '请输入小米账号和密码';

  @override
  String get settingsMiAccountTwoFactorPrompt => '请在验证页面完成小米账号二次验证';

  @override
  String get settingsMiAccountLoginWindowClosed => '登录窗口已关闭';

  @override
  String settingsMiAccountSyncedDevices(int count) {
    return '已同步 $count 台小米设备';
  }

  @override
  String get xiaomiAccountRequiredForEphemeris => '未登录小米账号，请先登录后再同步星历';

  @override
  String get settingsHuamiAccount => '华米账号';

  @override
  String get settingsHuamiAccountDesc => '登录并保存访问 Zepp 商店所需凭据';

  @override
  String get settingsHuamiAccountSigningIn => '正在登录';

  @override
  String get settingsHuamiAccountSignedIn => '华米账号登录成功';

  @override
  String get settingsHuamiAccountLoginTitle => '华米账号登录';

  @override
  String get settingsHuamiAccountUsername => '账号';

  @override
  String get settingsHuamiAccountPassword => '密码';

  @override
  String get settingsHuamiAccountRememberCredentials => '记住密码';

  @override
  String get settingsHuamiAccountLoginAndSave => '登录并保存';

  @override
  String get settingsHuamiAccountMissingCredentials => '请输入华米账号和密码';

  @override
  String get settingsHuamiAccountRequired => '请先在设置中登录华米账号';

  @override
  String get understood => '我知道了';

  @override
  String get settingsGeneralLanguage => '语言';

  @override
  String get settingsGeneralLanguageDesc => '更改应用显示语言';

  @override
  String get settingsWideNavigationPosition => '导航位置';

  @override
  String get settingsWideNavigationPositionDesc => '调整宽屏状态下侧边标签的位置';

  @override
  String get settingsWideNavigationPositionBottom => '置底';

  @override
  String get settingsWideNavigationPositionCenter => '居中';

  @override
  String get settingsWideNavigationPositionSplit => '分离';

  @override
  String get settingsAutoReconnectTitle => '自动回连';

  @override
  String get settingsAutoReconnectDesc => '启动时自动连接上次配对的设备';

  @override
  String get settingsAutoReconnectOnDisconnectTitle => '自动重连';

  @override
  String get settingsAutoReconnectOnDisconnectDesc => '被动与设备断开连接时尝试重连设备';

  @override
  String get deviceReconnectAttempting => '设备连接异常，尝试重连中';

  @override
  String get deviceReconnectSucceeded => '重连成功';

  @override
  String get deviceReconnectFailedPrefix => '重连失败，请检查：';

  @override
  String get settingsSourceOfficialCdn => 'GitHub 源 CDN';

  @override
  String get settingsSourceOfficialCdnDesc => '获取托管在 GitHub 上的社区索引使用的 CDN';

  @override
  String get settingsQueueAutoInstall => '自动安装';

  @override
  String get settingsQueueAutoInstallDesc => '下载完成后自动开始安装';

  @override
  String get settingsQueueDontClear => '不清除安装队列';

  @override
  String get settingsQueueDontClearDesc => '保留已完成的安装队列项';

  @override
  String get settingsRealtimeActivityNotification => '实时活动通知';

  @override
  String get settingsRealtimeActivityNotificationDesc => '使用实时活动通知展示队列进度';

  @override
  String get settingsAboutWebsite => '官方网站';

  @override
  String get settingsTapToSignIn => '点击登录';

  @override
  String get settingsConnected => '已连接';

  @override
  String get settingsSystem => '跟随系统';

  @override
  String get settingsLight => '浅色';

  @override
  String get settingsDark => '深色';

  @override
  String get settingsOledDark => 'OLED 深色';

  @override
  String get settingsThemeMode => '主题模式';

  @override
  String get settingsThemeModeDesc => '更改应用主题外观';

  @override
  String get settingsDynamicColor => '动态取色';

  @override
  String get settingsDynamicColorDesc => '使用系统主题色调整应用配色';

  @override
  String get settingsColorScheme => '配色方案';

  @override
  String get settingsColorSchemeDesc => '选择应用主题色';

  @override
  String get settingsColorSchemePink => '粉色';

  @override
  String get settingsColorSchemePurple => '紫色';

  @override
  String get settingsColorSchemeTeal => '青色';

  @override
  String get settingsColorSchemeGreen => '绿色';

  @override
  String get settingsColorSchemeRed => '红色';

  @override
  String get settingsColorSchemeAmber => '琥珀色';

  @override
  String get settingsDesktopAccentSource => 'Linux 主题色来源';

  @override
  String get settingsDesktopAccentSourceDesc => '选择从 GTK 或 Qt 读取主题色';

  @override
  String get settingsDesktopAccentSourceSystem => '自动';

  @override
  String get settingsDesktopAccentSourceGtk => 'GTK';

  @override
  String get settingsDesktopAccentSourceQt => 'Qt';

  @override
  String get settingsCancel => '取消';

  @override
  String get settingsTeamRoleMain => '主开发 / 设计';

  @override
  String get settingsTeamRoleZeppOS => 'ZeppOS 实现';

  @override
  String get settingsAboutSoftware => '关于软件';

  @override
  String get settingsAboutSoftwareDesc => '版本、更新日志与开发团队';

  @override
  String get settingsAboutSoftwareTagline =>
      '一个又好看又快的 VelaOS / ZeppOS 可穿戴设备管理软件，使用 Flutter 构建';

  @override
  String get settingsAboutSoftwareRepository => '打开 GitHub 仓库';

  @override
  String get settingsAboutSoftwareTeam => '开发团队';

  @override
  String get settingsAboutSoftwareBuildInfo => '构建信息';

  @override
  String get settingsAboutSoftwareCopyright => 'Copyright © 2026 OrPudding';

  @override
  String get acknowledgementsKazumi => 'Material Design 组件与界面设计参考';

  @override
  String get acknowledgementsAstroBoxPublic => '界面结构、资源流程与交互设计参考';

  @override
  String get acknowledgementsAstroBoxNgCore => '小米设备协议、安装流程与传输行为参考';

  @override
  String get acknowledgementsAstroBoxNgBluetooth => '蓝牙连接行为参考';

  @override
  String get acknowledgementsAstroBoxNgAccount => '小米账号登录、设备同步与 authkey 获取流程参考';

  @override
  String get acknowledgementsAstroBoxNgProvider => '社区资源索引、CDN 与清单解析流程参考';

  @override
  String get acknowledgementsAstroBoxNgAppWasm => 'Web Serial 与浏览器端连接流程参考';

  @override
  String get acknowledgementsGadgetbridge => 'ZeppOS 与可穿戴设备协议研究参考';

  @override
  String get acknowledgementsBreezyWeather => '中国天气源实现参考';

  @override
  String get acknowledgementsOpenMeteo => '天气预报、空气质量与地点搜索数据，遵循 CC BY 4.0';

  @override
  String get resourceHomeRecommended => '每日推荐';

  @override
  String get resourceHomeFeatured => '每日精选';

  @override
  String get resourceHomeUpdates => '最新动态';

  @override
  String get blogTypeAnnouncement => '公告';

  @override
  String get blogTypeRecommendation => '推荐';

  @override
  String get blogTypeDocs => '文档';

  @override
  String get resourceHomeEmptyTitle => '暂无推荐内容';

  @override
  String get resourceLibraryEndOfList => '到底了，看看来自其他源的资源？';

  @override
  String get resourceHomeEmptySubtitle => '您可以在资源库获取资源';

  @override
  String get openResourceLibrary => '打开资源库';

  @override
  String get downloadQueueTitle => '下载队列';

  @override
  String get installQueueTitle => '安装队列';

  @override
  String get queueClear => '清空';

  @override
  String get queueStart => '开始';

  @override
  String get queuePause => '暂停';

  @override
  String get downloadQueueEmpty => '暂无下载任务';

  @override
  String get installQueueEmpty => '暂无安装任务';

  @override
  String get localAppInstall => '本地应用安装';

  @override
  String get localWatchfaceInstall => '本地表盘安装';

  @override
  String get localFirmwareInstall => '本地固件安装';

  @override
  String get queueStatusPending => '等待中';

  @override
  String queueStatusDownloading(String percent) {
    return '下载中 $percent%';
  }

  @override
  String queueStatusInstalling(String percent) {
    return '安装中 $percent%';
  }

  @override
  String get queueStatusCompleted => '已完成';

  @override
  String get queueStatusFailed => '失败';

  @override
  String get queueDragToInstall => '松开以安装应用/表盘/插件';

  @override
  String queueAddedFiles(int count) {
    return '已加入安装队列：$count 个文件';
  }

  @override
  String get installQueueReadFailed => '读取失败';

  @override
  String get installQueueUnsupportedFile => '不支持的文件';

  @override
  String timeTodayAt(Object time) {
    return '今天 $time';
  }

  @override
  String timeYesterdayAt(Object time) {
    return '昨天 $time';
  }

  @override
  String get settingsAccountBandBbsAccount => '米坛账号';

  @override
  String get settingsAccountGitHub => 'GitHub 账号';

  @override
  String get settingsAccountGitHubDesc => '连接以用自己的账号发布 AstroBox 资源';

  @override
  String get githubAccountNeedsBandBbs => '登录米坛账号后可连接';

  @override
  String get bandBbsPublishAuthTitle => '发布授权';

  @override
  String get bandBbsResourceQueryTitle => '安装已购付费资源';

  @override
  String get settingsAboutLogs => '运行日志';

  @override
  String get settingsAboutLogsDescription => '查看、导出和管理应用与设备的运行日志';

  @override
  String settingsAboutLogsSize(Object size) {
    return '当前占用 $size';
  }

  @override
  String get settingsAboutLogsExport => '导出';

  @override
  String settingsAboutLogsExported(Object path) {
    return '已导出到 $path';
  }

  @override
  String get settingsAboutLogsEmpty => '暂无日志文件';

  @override
  String get settingsAboutLogsClear => '清理';

  @override
  String get settingsDeviceLogsPull => '拉取设备日志';

  @override
  String get settingsDeviceLogsTip =>
      '开始后将从当前连接的小米穿戴设备拉取日志，过程可能需要较长时间\n请勿将应用切换到后台或关闭屏幕，以免操作中断';

  @override
  String get settingsDeviceLogsStart => '开始';

  @override
  String get settingsDeviceLogsPulling => '正在拉取设备日志';

  @override
  String get settingsDeviceLogsWaiting => '等待设备回传';

  @override
  String settingsDeviceLogsProgress(Object progress) {
    return '已接收 $progress%';
  }

  @override
  String settingsDeviceLogsSaved(Object name) {
    return '设备日志已保存为 $name';
  }

  @override
  String settingsDeviceLogsFailed(Object error) {
    return '设备日志拉取失败：$error';
  }

  @override
  String get settingsAboutLogsClearConfirm => '将删除当前会话之外的全部日志文件';

  @override
  String get settingsAboutLogsOpen => '打开日志文件夹';

  @override
  String get settingsAboutLogsOpenFailed => '无法打开日志文件夹';

  @override
  String get settingsLogsFileList => '日志文件';

  @override
  String get settingsAboutLogsWarningTitle => '敏感信息警告';

  @override
  String get settingsAboutLogsWarningMessage =>
      '日志可能包含米坛/小米/华米登录凭证等敏感信息，请勿随意分享给除 OronBox 官方维护者以外的其他人！';

  @override
  String get pluginPermissionRequestTitle => '插件权限请求';

  @override
  String pluginPermissionRequestMessage(Object plugin, Object operation) {
    return '“$plugin”希望$operation。';
  }

  @override
  String get pluginPermissionOnce => '允许本次';

  @override
  String get pluginPermissionSession => '本次运行中允许';

  @override
  String get pluginPermissionAlways => '始终允许';

  @override
  String get pluginPermissionDeny => '拒绝';

  @override
  String get pluginPermissionOpenExternal => '打开外部链接';

  @override
  String get pluginPermissionPickFile => '访问宿主文件';

  @override
  String get pluginPermissionExportFile => '将文件导出到宿主环境';

  @override
  String get pluginPermissionNetwork => '访问网络';

  @override
  String get pluginPermissionInterconnect => '与设备应用通信';

  @override
  String get pluginPermissionProvider => '注册资源源';

  @override
  String get pluginPermissionReadDevice => '读取设备信息';

  @override
  String get pluginPermissionOperateDevice => '操作设备';

  @override
  String get pluginPermissionObserveProtocol => '读取设备原始协议数据';

  @override
  String get pluginPermissionSendProtocol => '向设备发送原始协议数据';

  @override
  String get pluginPermissionReadAppSide => '读取 AppSide 脚本与事件';

  @override
  String get pluginPermissionOperateAppSide => '管理 AppSide 会话';

  @override
  String get pluginErrorTitle => '插件损坏';

  @override
  String pluginErrorMessage(Object plugin, Object error) {
    return '“$plugin”无法正常运行，可能已损坏。\n\n错误：$error\n\n是否卸载此插件？';
  }

  @override
  String get pluginPackageCorruptedMessage => '所选插件包无法读取，可能已损坏。请重新获取后再导入。';

  @override
  String get pluginErrorClearData => '清除插件数据';

  @override
  String get pluginErrorUninstall => '卸载插件';

  @override
  String get pluginErrorSafeMode => '进入安全模式';

  @override
  String get pluginSafeModeTitle => '插件安全模式已启用';

  @override
  String get pluginSafeModeDescription => '所有插件均已停止，退出安全模式后才会重新加载。';

  @override
  String get pluginSafeModeExit => '退出安全模式';

  @override
  String get devTools => 'DevTools';

  @override
  String get devToolsDescriptionDesktop => '启用独立的 DevTools 窗口';

  @override
  String get devToolsDescriptionEntry => '在页面顶栏显示 DevTools 入口';

  @override
  String get devToolsOperationFailed => '无法更改 DevTools 状态';

  @override
  String get resourceTypeErrorTitle => '错误的资源类型';

  @override
  String get resourceTypeUnknownTitle => '无法识别的资源类型';

  @override
  String get resourceTypeUnknownNoType => 'OronBox 无法识别此文件的资源类型，该文件似乎已损坏';

  @override
  String get resourceTypeUnknownCancel => '取消';

  @override
  String resourceTypeMismatchMessage(Object detectedType, Object selectedType) {
    return '这似乎是一个$detectedType资源，但您选择的资源类型为$selectedType，请选择安装方式';
  }

  @override
  String resourcePlatformMismatchMessage(
    Object resourcePlatform,
    Object resourceType,
    Object deviceName,
    Object devicePlatform,
  ) {
    return '这似乎是一个 $resourcePlatform 设备的$resourceType资源，当前连接的设备为 $deviceName（$devicePlatform），不支持安装，强行安装可能引发不可预知的问题';
  }

  @override
  String resourceTypeUnknownMessage(Object selectedType) {
    return 'OronBox 无法识别此文件的实际资源类型，是否仍以$selectedType安装？';
  }

  @override
  String get resourceInstallCancel => '取消安装';

  @override
  String get resourceInstallAcknowledge => '我知道了';

  @override
  String get resourceInstallForce => '强制安装';

  @override
  String resourceInstallForceCountdown(int seconds) {
    return '强制安装 (${seconds}s)';
  }

  @override
  String resourceInstallAsSelected(Object type) {
    return '继续以$type安装';
  }

  @override
  String resourceInstallAsSelectedCountdown(Object type, int seconds) {
    return '继续以$type安装 (${seconds}s)';
  }

  @override
  String resourceInstallAsDetected(Object type) {
    return '以$type安装';
  }

  @override
  String get resourceTypeApp => '小程序';

  @override
  String get resourceTypeQuickApp => '快应用';

  @override
  String get resourceTypeWatchface => '表盘';

  @override
  String get resourceTypeFirmware => '固件';

  @override
  String resourceInstallConfirmTitle(Object type) {
    return '安装$type';
  }

  @override
  String resourceInstallConfirmMessage(Object fileName, Object fileSize) {
    return '确认要安装 $fileName（$fileSize）吗？';
  }

  @override
  String get resourceInstallConfirm => '确认安装';

  @override
  String get previewImages => '预览图';

  @override
  String get add => '添加';

  @override
  String get submit => '提交';

  @override
  String get creatorConfirmTitle => '确认提交';

  @override
  String get creatorConfirmOronBox => '提交至 OronBox';

  @override
  String creatorConfirmBandBbs(Object category) {
    return '同步至米坛：$category';
  }

  @override
  String creatorConfirmAstroBox(Object owner, Object repository) {
    return '同步至 AstroBox：$owner/$repository';
  }

  @override
  String get creatorBandBbsDirectPublish => '同步到米坛';

  @override
  String get creatorBandBbsBoundUpdate => '已关联 · 同步到米坛';

  @override
  String get creatorBandBbsVersionTitle => '版本标题';

  @override
  String get creatorBandBbsVersionMessage => '更新说明';

  @override
  String get creatorBandBbsVersionPairRequired => '版本标题和更新说明需要同时填写，或同时留空';

  @override
  String creatorLinkedSections(int count) {
    return '已关联 $count 个分区';
  }

  @override
  String creatorBandBbsBindingIds(Object categoryId, Object resourceId) {
    return '分区 $categoryId · 资源 $resourceId';
  }

  @override
  String get creatorAstroBoxBoundSync => '已关联 · 同步到 AstroBox';

  @override
  String get creatorThisCommit => '本次提交';

  @override
  String creatorAstroBoxPrPublish(Object repository) {
    return '同步到 AstroBox · $repository';
  }

  @override
  String get creatorOronBoxRequired => '必选，资源需经过 OronBox 审核';

  @override
  String get creatorOpenInOronBox => '在 OronBox 中查看';

  @override
  String get creatorAstroTagsHint => '多个标签使用英文分号 ; 分隔';

  @override
  String get retry => '重试';

  @override
  String get reviewNote => '审核意见';

  @override
  String get creatorReviewRejected => '资源已被打回';

  @override
  String creatorReviewState(Object state) {
    return '审核状态：$state';
  }

  @override
  String get creatorOperationWorking => '正在处理';

  @override
  String get creatorProcessingImage => '正在处理图片';

  @override
  String get creatorOperationRefreshing => '正在刷新创作者数据';

  @override
  String get creatorOperationCreating => '正在创建资源';

  @override
  String get creatorOperationCreatingCollection => '正在创建合集';

  @override
  String get creatorOperationSaving => '正在保存更改';

  @override
  String get creatorOperationDeleting => '正在删除';

  @override
  String get creatorOperationSubmitting => '正在提交审核';

  @override
  String get creatorOperationAuthorizing => '正在等待授权';

  @override
  String get creatorResolvingPublicationTarget => '正在识别发布分区';

  @override
  String get creatorStateApproved => '审核通过';

  @override
  String get creatorStateExternalReview => '外部审核中';

  @override
  String get creatorStateFailed => '发布失败';

  @override
  String get creatorStateSuperseded => '已被新版本取代';

  @override
  String get creatorStateCancelled => '已取消';

  @override
  String get creatorNoResources => '还没有创建资源';

  @override
  String get creatorLoginRequiredTitle => '登录后使用创作者中心';

  @override
  String get creatorLoginRequiredDescription =>
      '需要登录米坛并连接 OronBox 账号，才能创建、编辑和提交资源';

  @override
  String get creatorLoginAction => '登录米坛';

  @override
  String get creatorBandBbsWriteReady => '米坛发布已授权';

  @override
  String get creatorBandBbsWriteMissing => '未授权米坛发布';

  @override
  String get creatorGitHubOwnPublishReady => '已连接 GitHub';

  @override
  String get creatorGitHubOwnPublishMissing => '未连接 GitHub';

  @override
  String get creatorAuthorize => '授权';

  @override
  String get installQueueFixWatchfaceId => '修改表盘 ID';

  @override
  String get installQueueFixWatchfaceIdHint => '输入12位以内数字';

  @override
  String get authorize => '授权';

  @override
  String get creatorBandBbsAuthorized => '已获得米坛资源发布授权';

  @override
  String get creatorBandBbsAuthorizationRequired => '需要单独授权 OronBox 代表您发布米坛资源';

  @override
  String get connect => '连接';

  @override
  String get legalAndPrivacy => '协议与隐私';

  @override
  String get termsTitle => '用户协议与免责声明';

  @override
  String get privacyTitle => '隐私说明';

  @override
  String get resourcePublishingTitle => '资源发布协议';

  @override
  String get reviewRulesTitle => '资源审核规则';

  @override
  String get joinQqGroup => '加入 QQ 群';

  @override
  String get joinQqGroupDesc => '与开发者和其他用户交流，获取帮助';

  @override
  String get feedbackTitle => '意见反馈';

  @override
  String get feedbackDesc => '提交问题、建议并查看答复';

  @override
  String get reportResource => '举报资源';

  @override
  String get reportComment => '举报评论';

  @override
  String get report => '举报';

  @override
  String get feedbackSubject => '标题';

  @override
  String get feedbackMessage => '意见或问题';

  @override
  String get reportReason => '举报理由';

  @override
  String get noFeedback => '暂无记录';

  @override
  String get feedbackProcessing => '处理中';

  @override
  String get feedbackReplied => '已答复';

  @override
  String get feedbackOpen => '待处理';

  @override
  String get feedbackResolved => '已解决';

  @override
  String get feedbackDismissed => '已驳回';

  @override
  String get feedbackClosed => '已关闭';

  @override
  String get feedbackLoading => '正在加载工单';

  @override
  String get feedbackNewTicket => '新建工单';

  @override
  String get feedbackYou => '我';

  @override
  String get feedbackResolution => '处理结论';

  @override
  String get feedbackReplyHint => '回复此工单';

  @override
  String get feedbackConversationClosed => '该工单已关闭，无法继续回复';

  @override
  String get checkUpdates => '检查更新';

  @override
  String get updateChecking => '正在检查更新…';

  @override
  String get updateCheckFailed => '暂时无法检查更新';

  @override
  String get latestVersionInstalled => '当前已是最新版本';

  @override
  String newVersionAvailable(Object version) {
    return '发现新版本 $version';
  }

  @override
  String get oobeWelcomeSlogan =>
      '一个又好看又快的 VelaOS / ZeppOS 可穿戴设备管理软件，使用 Flutter 构建';

  @override
  String get oobeNext => '下一步';

  @override
  String get oobeBack => '上一步';

  @override
  String get oobeFeatureDevicesTitle => '设备连接';

  @override
  String get oobeFeatureDevicesBody => '连接并管理 VelaOS 与 ZeppOS 可穿戴设备';

  @override
  String get oobeFeatureResourcesTitle => '资源中心';

  @override
  String get oobeFeatureResourcesBody =>
      '支持 OronBox 官方源、AstroBox-Repo、米坛社区与华米应用商店';

  @override
  String get oobeFeaturePluginsTitle => 'JavaScript 插件';

  @override
  String get oobeFeaturePluginsBody => '高性能、高扩展性的 JavaScript 插件系统，支持插件与设备交互';

  @override
  String get oobeFeaturePlatformsTitle => '多端适配';

  @override
  String get oobeFeaturePlatformsBody => '支持 Android、Windows、macOS、Linux 与 Web';

  @override
  String get oobeOpenSourceTitle => '完全开源';

  @override
  String get oobeOpenSourceBody => 'OronBox 客户端与服务端均遵循 AGPL-3.0 开放完整源代码';

  @override
  String get oobeAgreementHint => '请阅读并滚动到底部';

  @override
  String get oobeAgreeCheckbox => '我已阅读并同意';

  @override
  String get oobeDeclineExit => '退出';

  @override
  String get oobeDeclineWebHint => '不接受协议将无法继续使用，请关闭本页面';

  @override
  String get oobeLoginTitle => '登录账号';

  @override
  String get oobeLoginBandBbsDesc => '登录米坛账号以访问米坛资源并准备使用创作者服务';

  @override
  String get oobeLoginLocalNote => '小米和华米账号登录均在本地完成，相关数据不会被发送给小米/华米以外的第三方';

  @override
  String get oobeLoginXiaomiDesc => '登录小米账号以同步已绑定的小米设备';

  @override
  String get oobeLoginHuamiDesc => '登录华米账号以访问华米应用商店资源';

  @override
  String get oobeCdnTesting => '测速中…';

  @override
  String get oobeCdnSelected => '已选择最佳 CDN';

  @override
  String get oobeCdnTitle => 'GitHub CDN 测速';

  @override
  String get oobeDoneTitle => '一切就绪';

  @override
  String get oobeDoneBody => '开始探索 OronBox 吧';

  @override
  String get oobeFinish => '完成';

  @override
  String get settingsReplayOobe => '重新引导';

  @override
  String get settingsReplayOobeDesc => '再次查看欢迎向导与初始设置';

  @override
  String get creatorConnect => '连接';

  @override
  String get comments => '评论';

  @override
  String get commentEmpty => '还没有评论';

  @override
  String get commentHint => '写下评论';

  @override
  String get commentLoginRequired => '登录米坛账号后参与评论';

  @override
  String get commentPending => '待审核';

  @override
  String get commentBlocked => '评论未通过社区规范';

  @override
  String get commentModerationUnavailable => '审核服务暂不可用';

  @override
  String get commentRateLimited => '评论过于频繁，请稍后再试';

  @override
  String get commentReplying => '回复评论';

  @override
  String get loadMore => '加载更多';

  @override
  String get more => '更多';

  @override
  String get reply => '回复';

  @override
  String get inbox => '消息箱';

  @override
  String get inboxLoading => '正在加载消息';

  @override
  String get inboxEmpty => '暂无消息';

  @override
  String get inboxClear => '清空消息';

  @override
  String get inboxClearFailed => '清空消息失败，请稍后重试';

  @override
  String get cleanMode => '功能开关';

  @override
  String get cleanModeDescription => '管理主导航、社区功能与资源源';

  @override
  String get cleanPluginsEntry => '插件主入口';

  @override
  String get cleanSourceHuamiAppStore => '华米应用商店';

  @override
  String get announcementAcknowledge => '知道了';

  @override
  String get cleanHomeFeed => '首页信息流';

  @override
  String get cleanExplore => '资源库';

  @override
  String get cleanInbox => '消息箱';

  @override
  String get cleanAnnouncements => '公告弹窗';

  @override
  String get cleanComments => '评论区';

  @override
  String get cleanCreator => '创作者中心';

  @override
  String get cleanBandBbsLogin => '米坛登录';

  @override
  String get cleanGitHubLogin => 'GitHub 登录';

  @override
  String get cleanSourceOronBox => 'OronBox 资源源';

  @override
  String get cleanSourceBandBbs => '米坛资源源';

  @override
  String get cleanSourceAstroBox => 'AstroBox 资源源';

  @override
  String get cleanExploreEntry => '探索主入口';

  @override
  String get cleanNavigationGroup => '主导航';

  @override
  String get cleanExploreContentGroup => '探索内容';

  @override
  String get cleanHomeSectionsGroup => '首页板块';

  @override
  String get cleanHomeBanner => 'Banner 轮播';

  @override
  String get cleanHomeEditorSections => '编辑分区';

  @override
  String get cleanResourceSourcesGroup => '资源源';

  @override
  String get cleanCommunityGroup => '社区能力';

  @override
  String get settingsCategoryAccounts => '账号与授权';

  @override
  String get settingsCategoryAppearance => '外观与导航';

  @override
  String get settingsCategoryConnection => '连接与下载';

  @override
  String get settingsCategorySupport => '支持与信息';

  @override
  String get settingsCategoryAdvanced => '高级设置';

  @override
  String get settingsAdvancedDescription => '查看日志与开发者工具';

  @override
  String get debugServerTitle => '调试服务';

  @override
  String get debugServerDescription => '为可信开发工具提供本地调试接口';

  @override
  String get debugServerEnable => '启用调试服务';

  @override
  String get debugServerEnableDescription => '允许局域网内已批准的客户端检查和控制 OronBox';

  @override
  String get debugServerEndpoint => '访问地址';

  @override
  String get debugServerFingerprint => '服务指纹';

  @override
  String get debugServerPendingClients => '待批准客户端';

  @override
  String get debugServerAuthorizedClients => '已批准客户端';

  @override
  String get debugServerApprove => '批准';

  @override
  String get debugServerReject => '拒绝';

  @override
  String get debugServerRevoke => '撤销访问';

  @override
  String get debugServerNoPendingClients => '没有等待批准的客户端';

  @override
  String get debugServerNoAuthorizedClients => '暂无已批准客户端';

  @override
  String get debugServerSecurityNotice => '请只在可信网络中启用此服务';

  @override
  String get debugServerStartFailed => '调试服务启动失败';

  @override
  String get debugServerStopFailed => '调试服务停止失败';

  @override
  String get xmsDeveloperMode => 'XMS 开发模式';

  @override
  String get xmsDeveloperModeDescription => '允许不一致的安卓应用签名';

  @override
  String get oronBoxCoinsTitle => '资源投币';

  @override
  String oronBoxCoinsBalance(String balance) {
    return '硬币余额：$balance';
  }

  @override
  String get oronBoxCoinsCheckin => '签到';

  @override
  String get oronBoxCoinsCheckedIn => '已签到';

  @override
  String oronBoxCoinsCheckinReward(int count) {
    return '签到获得 $count 枚硬币';
  }

  @override
  String get oronBoxCoinsDescription => '每日签到可获得 1～5 枚硬币，硬币可投给资源以支持创作者';

  @override
  String resourceFromCollection(String name) {
    return '来自合集 $name';
  }

  @override
  String get resourceCoin => '投币';

  @override
  String get resourceCoinNotSignedIn => '未登录';

  @override
  String get resourceCoinDialogTitle => '投币资源';

  @override
  String get resourceCoinDialogMessage =>
      '确认要为这个资源投币吗？\n投币后无法撤回\n\n投币有助于资源获得更多展示机会\n创作者将获得投币数量 10% 的硬币收益\n您可以在 设置-米坛账号 签到获得硬币';

  @override
  String get resourceCoinOne => '投 1 颗';

  @override
  String get resourceCoinTwo => '投 2 颗';

  @override
  String resourceCoinCount(int count) {
    return '$count 次投币';
  }

  @override
  String get resourceCoinSuccess => '投币成功';

  @override
  String get resourceCoinVoted => '已投币';

  @override
  String get resourceFeatured => '精选';

  @override
  String get resourceCollection => '合集';

  @override
  String resourceCollectionType(String type) {
    return '$type合集';
  }

  @override
  String get creatorCollections => '资源合集';

  @override
  String get creatorCollectionTag => '合集';

  @override
  String get creatorNewCollection => '新建合集';

  @override
  String get creatorMoveToCollection => '移入合集';

  @override
  String creatorMoveToCollectionConfirm(int count) {
    return '确认将选中的 $count 个资源移入这个合集吗';
  }

  @override
  String get creatorDissolveCollection => '拆散合集';

  @override
  String get creatorResourceList => '资源列表';

  @override
  String get creatorAdditionalLinks => '附加链接';

  @override
  String get creatorAddLink => '添加链接';

  @override
  String get creatorLinkTitle => '链接名称';

  @override
  String get creatorLinkUrl => '链接地址';

  @override
  String get creatorCollectionName => '合集名称';

  @override
  String get creatorCollectionSummary => '合集简介';

  @override
  String get creatorCollectionRepresentative => '代表资源';

  @override
  String get creatorCollectionDeleteConfirm => '删除合集？资源不会被删除，只会解除归属。';

  @override
  String get creatorContentAttributes => '内容属性';

  @override
  String get creatorConfirm => '确定';

  @override
  String get creatorCollectionAddResource => '加入合集';

  @override
  String creatorCollectionResourceCount(int count) {
    return '$count 个资源';
  }

  @override
  String communityImportSelected(int count) {
    return '已选择 $count 项';
  }

  @override
  String get communityImportResultCreated => '已创建草稿';

  @override
  String get communityImportResultFailed => '失败';

  @override
  String get communityImportUnsupported => '该类型暂不支持导入';

  @override
  String get communityImportDuplicate => '创作者中心已存在同名资源';

  @override
  String get communityImportNoArtifacts => '没有可导入的资源文件';

  @override
  String get creatorImportExternal => '导入外部平台已有资源';

  @override
  String get creatorNewResourceDescription => '从 OronBox 开始创建并维护一个资源';

  @override
  String get creatorNewCollectionDescription => '创建合集并集中整理同类资源';

  @override
  String get creatorImportExternalDescription =>
      '实验性，从 米坛社区/ AstroBox-Repo 导入您的已有资源';

  @override
  String get creatorImportAlreadyImported => '已导入并绑定';

  @override
  String get creatorImportReviewNotice =>
      '导入内容可能存在缺失或识别偏差\n请逐项检查并手动调整，确认无误后再提交';

  @override
  String get creatorImportLogTitle => '处理日志';

  @override
  String get communityImportPickerEmpty => '暂无资源';

  @override
  String get creatorWizardChooseAction => '新建';

  @override
  String get creatorImportSelectTitle => '选择资源';

  @override
  String get creatorImportProgressTitle => '正在导入';

  @override
  String get creatorImportResultTitle => '导入结果';

  @override
  String get creatorImportGitHubHint => '连接 GitHub 后列出你在 AstroBox 的资源';

  @override
  String get creatorImportGitHubConnect => '连接 GitHub';

  @override
  String get creatorImportStageDetails => '获取详情';

  @override
  String get creatorImportStageDownloading => '下载文件';

  @override
  String get creatorImportStageMedia => '处理图片';

  @override
  String get creatorImportStageUploading => '创建草稿';

  @override
  String get creatorImportContinue => '继续导入';

  @override
  String get creatorImportPartialFailureTitle => '部分资源读取失败';

  @override
  String creatorImportPartialFailureMessage(int count) {
    return '有 $count 个资源读取失败\n可以重试失败项，也可以继续导入已成功读取的资源';
  }

  @override
  String get creatorImportRetryFailed => '重试失败项';

  @override
  String get creatorImportContinuePartial => '仍然继续';

  @override
  String creatorImportWarnings(int count) {
    return '$count 条警告';
  }

  @override
  String get creatorDeleteExternalBandbbs => '同时删除米坛资源';

  @override
  String get creatorDeleteExternalAstrobox => '同时向 AstroBox-Repo 提交资源删除 PR';

  @override
  String get creatorDeleteExternalWarning => '外部平台的删除操作不可撤销';

  @override
  String get creatorDeletePrSubmitted => '删除 PR 已提交';

  @override
  String githubCdnFallback(Object cdn) {
    return 'GitHub 连接失败，正在切换至 $cdn';
  }

  @override
  String get deviceConnectBle => '使用 BLE 连接';

  @override
  String get deviceConnectBtClassic => '使用 BT Classic 连接';

  @override
  String bandBbsIdLabel(Object id) {
    return '米坛 ID $id';
  }

  @override
  String get oobeCdnTestFailed => '失败';

  @override
  String get settingsGithubCdnAuto => '自动';

  @override
  String get updateDownloading => '正在下载更新';

  @override
  String get updateInstalling => '正在安装更新';

  @override
  String get updateFailed => '更新失败';

  @override
  String updateNoApkForAbi(String abi) {
    return '没有适用于 ABI $abi 的 APK';
  }

  @override
  String get cleanUpdateGroup => '更新';

  @override
  String get cleanCheckUpdates => '启动时检查更新';

  @override
  String get updateLater => '稍后';

  @override
  String get updateNow => '立即更新';

  @override
  String get updateGoToPage => '前往下载';

  @override
  String get updateDownloadFromCloud => '网盘下载';

  @override
  String get updateDownloadFromOfficial => '官网下载';

  @override
  String get creatorImportNoticeTitle => '导入已有资源';

  @override
  String get creatorImportNoticeMessage =>
      '考虑到多设备适配的资源可能被发布到米坛的多个分区\n导入时支持多选米坛资源项，但请只选择同一个资源\n选择完毕后点击导入会把这些资源合并为同一个\n如果导入出错，可以进入对应草稿进行删除\n删除草稿不会删除关联的其它平台资源';

  @override
  String get creatorImportNoticeConfirm => '继续导入';

  @override
  String get creatorImportSameResourceHint => '每次导入请只选择同一个资源';

  @override
  String get creatorFullVersionExternalPurchase => '需要外部购买';

  @override
  String get creatorExternalPurchaseDescription =>
      '在 OronBox 和 AstroBox 将会发布资源文件作为试用版并显示购买按钮，在 BandBBS 发布为“第三方购买”资源，您需自行处理支付相关事务';

  @override
  String get creatorExternalPurchaseLink => '购买链接';

  @override
  String get creatorExternalPurchaseAmount => '金额（CNY）';

  @override
  String get creatorExternalPurchaseLinkRequired => '请输入有效的外部购买链接';

  @override
  String get creatorExternalPurchaseAmountRequired => '请输入有效的 CNY 金额';

  @override
  String get resourcePurchaseFullVersion => '外部购买';

  @override
  String get creatorBandBbsOverwritePrevious => '覆盖上次提交';

  @override
  String get creatorBandBbsOverwritePreviousDescription => '创建新版本后删除米坛上一次提交的版本';

  @override
  String get deviceAboutTitle => '关于设备';

  @override
  String get deviceValueUnavailable => '未提供';

  @override
  String get deviceHealthActivityOverview => '活动概览';

  @override
  String get deviceHealthActiveCalories => '消耗';

  @override
  String get deviceHealthStanding => '站立';

  @override
  String get deviceHealthBloodOxygen => '血氧';

  @override
  String get deviceHealthStress => '压力';

  @override
  String get deviceHealthVitality => '元气值';

  @override
  String get deviceHealthWorkout => '运动记录';

  @override
  String get deviceHealthTodayTotal => '今日累计';

  @override
  String get deviceHealthRecordCount => '条记录';

  @override
  String get deviceHealthNoDetailedRange => '暂无详细范围';

  @override
  String get deviceHealthActivityTrend => '活动趋势';

  @override
  String get deviceHealthTrend => '趋势';

  @override
  String get deviceHealthDayView => '日';

  @override
  String get deviceHealthWeekView => '周';

  @override
  String get deviceHealthMonthView => '月';

  @override
  String get deviceHealthLatest => '最新';

  @override
  String get deviceHealthAverage => '平均';

  @override
  String get deviceHealthRange => '范围';

  @override
  String get deviceHealthNoSamples => '暂无详细采样数据';

  @override
  String get deviceHealthCurrentVitality => '当前元气值';

  @override
  String get deviceHealthLightIntensity => '低强度';

  @override
  String get deviceHealthModerateHighIntensity => '中高强度';

  @override
  String get deviceHealthNoSleep => '暂无睡眠数据';

  @override
  String get deviceHealthNoWorkouts => '暂无运动记录';

  @override
  String get deviceHealthSleepStages => '睡眠阶段';

  @override
  String get deviceHealthSleepHrv => '睡眠 HRV';

  @override
  String get deviceHealthSleepAwake => '清醒';

  @override
  String get deviceHealthSleepLight => '浅睡';

  @override
  String get deviceHealthSleepDeep => '深睡';

  @override
  String get deviceHealthSleepRem => 'REM';

  @override
  String get deviceHealthSleepNoStages => '暂无睡眠阶段数据';

  @override
  String deviceHealthStepValue(Object value) {
    return '$value 步';
  }

  @override
  String get deviceHealthFeatureDescription => '查看活动、心率、血氧、压力和睡眠数据';

  @override
  String get weatherSyncTitle => '天气同步';

  @override
  String get weatherSyncDescription => '选择城市并同步当前天气与预报';

  @override
  String get weatherAutoSyncTitle => '自动同步天气数据';

  @override
  String get weatherAutoSyncDescription => '在同步设备数据时自动同步天气数据';

  @override
  String get alarmManagementTitle => '闹钟管理';

  @override
  String get alarmManagementDescription => '添加、编辑、启用或删除设备闹钟';

  @override
  String get findDeviceDescription => '让设备持续振动或响铃';

  @override
  String get appOrderTitle => '应用顺序管理';

  @override
  String get appOrderDescription => '拖动调整设备启动器中的应用顺序';

  @override
  String get appOrderSaved => '应用顺序已保存';

  @override
  String get appOrderReload => '重新读取';

  @override
  String get appOrderUndo => '撤销更改';

  @override
  String get appOrderSaving => '保存中…';

  @override
  String get appOrderSave => '保存更改';

  @override
  String get appOrderEmpty => '设备没有返回可排序的应用';

  @override
  String get appLayoutTitle => '应用布局设置';

  @override
  String get appLayoutDescription => '选择设备应用列表的显示方式';

  @override
  String get appLayoutLoadFailed => '无法读取应用布局';

  @override
  String get appLayoutList => '列表';

  @override
  String get appLayoutGrid => '网格';

  @override
  String get appLayoutTextGrid => '带文字网格';

  @override
  String get firmwareUpdateDescription => '检查更新或安装本地固件';

  @override
  String get deviceAboutDescription => '查看型号、系统版本、存储空间和设备标识';

  @override
  String get alarmAdd => '添加闹钟';

  @override
  String get alarmEdit => '编辑闹钟';

  @override
  String get alarmHour => '小时';

  @override
  String get alarmMinute => '分钟';

  @override
  String get alarmRepeat => '重复';

  @override
  String get alarmOnce => '仅一次';

  @override
  String get alarmEveryDay => '每天';

  @override
  String get alarmWorkdays => '工作日';

  @override
  String get alarmHolidays => '节假日';

  @override
  String get alarmCustom => '自定义';

  @override
  String get alarmLabel => '标签';

  @override
  String get alarmDeleteTitle => '删除闹钟？';

  @override
  String get alarmWeekly => '每周';

  @override
  String get alarmMonthly => '每月';

  @override
  String get alarmYearly => '每年';

  @override
  String get alarmNoRepeat => '不重复';

  @override
  String alarmCustomDays(Object days) {
    return '周$days';
  }

  @override
  String get weekdayMonShort => '一';

  @override
  String get weekdayTueShort => '二';

  @override
  String get weekdayWedShort => '三';

  @override
  String get weekdayThuShort => '四';

  @override
  String get weekdayFriShort => '五';

  @override
  String get weekdaySatShort => '六';

  @override
  String get weekdaySunShort => '日';

  @override
  String get weatherCityLabel => '同步城市';

  @override
  String get weatherCityHint => '输入城市名称';

  @override
  String get weatherSyncAction => '同步天气';

  @override
  String get weatherSyncing => '同步中…';

  @override
  String get weatherHumidity => '相对湿度';

  @override
  String get weatherWind => '风力';

  @override
  String get weatherAirQuality => '空气质量';

  @override
  String get weatherAqiGood => '优';

  @override
  String get weatherAqiModerate => '良';

  @override
  String get weatherAqiSensitive => '轻度污染';

  @override
  String get weatherAqiUnhealthy => '中度污染';

  @override
  String get weatherAqiVeryUnhealthy => '重度污染';

  @override
  String get weatherAqiHazardous => '严重污染';

  @override
  String get weatherUv => '紫外线';

  @override
  String get weatherPressure => '气压';

  @override
  String get weatherNext24Hours => '未来 24 小时';

  @override
  String get weatherNext7Days => '未来 7 天';

  @override
  String weatherDataSource(Object source) {
    return '数据来源：$source';
  }

  @override
  String weatherLevelDirection(Object level, Object direction) {
    return '$level 级 · $direction';
  }

  @override
  String weatherLevelDirectionCompact(Object level, Object direction) {
    return '$level 级 $direction';
  }

  @override
  String weatherForecastSummary(
    Object condition,
    Object sunrise,
    Object sunset,
  ) {
    return '$condition · 日出 $sunrise · 日落 $sunset';
  }

  @override
  String get weatherClear => '晴';

  @override
  String get weatherPartlyCloudy => '少云';

  @override
  String get weatherCloudy => '阴';

  @override
  String get weatherLightRain => '小雨';

  @override
  String get weatherHeavyRain => '大雨';

  @override
  String get weatherThunderstorm => '雷雨';

  @override
  String get weatherSnow => '降雪';

  @override
  String get weatherFog => '雾';

  @override
  String get weatherUnknown => '未知';

  @override
  String get weatherUnknownDate => '未知日期';

  @override
  String weatherUpdatedAt(Object time) {
    return '$time 更新';
  }

  @override
  String get windNorth => '北';

  @override
  String get windNorthEast => '东北';

  @override
  String get windEast => '东';

  @override
  String get windSouthEast => '东南';

  @override
  String get windSouth => '南';

  @override
  String get windSouthWest => '西南';

  @override
  String get windWest => '西';

  @override
  String get windNorthWest => '西北';

  @override
  String get xiaomiScreenshotTitle => '设备截图';

  @override
  String get xiaomiScreenshotDescription => '在设备上使用组合键截图，截图会自动同步到这里';

  @override
  String get xiaomiScreenshotAction => '获取截图';

  @override
  String get xiaomiScreenshotLoading => '获取中…';

  @override
  String get xiaomiScreenshotEmpty => '暂无截图';

  @override
  String get xiaomiScreenshotFailed => '获取截图失败';

  @override
  String xiaomiScreenshotSaved(Object path) {
    return '手表截图已保存至：$path';
  }
}

/// The translations for Chinese, as used in Taiwan (`zh_TW`).
class AppLocalizationsZhTw extends AppLocalizationsZh {
  AppLocalizationsZhTw() : super('zh_TW');

  @override
  String get homeTab => '首頁';

  @override
  String get exploreTab => '探索';

  @override
  String get devicesTab => '裝置';

  @override
  String get pluginsTab => '外掛程式';

  @override
  String get pluginImport => '匯入外掛程式';

  @override
  String get pluginInstalled => '已安裝';

  @override
  String get pluginMarket => '外掛程式市場';

  @override
  String get pluginMarketUnavailable => '外掛程式市場尚未開放';

  @override
  String get pluginEmpty => '尚未安裝外掛程式';

  @override
  String get pluginSelectHint => '選擇外掛程式以查看功能';

  @override
  String get pluginFeatures => '功能';

  @override
  String get pluginDetails => '詳細資料';

  @override
  String get pluginNoFeatures => '沒有可用功能';

  @override
  String get pluginAuthor => '作者';

  @override
  String get pluginVersion => '版本';

  @override
  String get pluginApiLevel => 'API 等級';

  @override
  String get pluginWebsite => '網站';

  @override
  String get pluginPermissions => '權限';

  @override
  String get pluginInstallConfirmTitle => '確認安裝外掛程式';

  @override
  String get pluginUpdateConfirmTitle => '確認更新外掛程式';

  @override
  String get pluginDeclaredPermissions => '此外掛程式宣告了以下權限：';

  @override
  String get pluginNoPermissions => '未宣告任何權限';

  @override
  String get pluginUpToDate => '已安裝最新版本';

  @override
  String get pluginUninstallTitle => '解除安裝外掛程式';

  @override
  String get pluginUninstallMessage => '外掛程式資料也會一併刪除';

  @override
  String get pluginUpload => '上傳外掛程式';

  @override
  String get pluginPublishTitle => '發佈外掛程式';

  @override
  String get pluginPublishNew => '作為新外掛程式發佈';

  @override
  String get pluginPublishUpdate => '更新相同 ID 的已發佈外掛程式';

  @override
  String get pluginTakedown => '下架';

  @override
  String get pluginTakedownConfirm => '此外掛程式將永久從市場移除';

  @override
  String get pluginLoginRequired => '登入後才能上傳外掛程式';

  @override
  String get pluginSubmittedForReview => '已提交審核，審核通過後才會上架';

  @override
  String get pluginStatePending => '審核中';

  @override
  String get pluginStateRejected => '未通過審核';

  @override
  String get pluginStateDelisted => '已下架';

  @override
  String get pluginLegacyWarningTitle => '舊版外掛程式';

  @override
  String get pluginLegacyWarningMessage =>
      '這是 AstroBox v1 外掛程式。OronBox 會嘗試以相容模式執行，但可能遇到問題。\n請檢查是否有更新的 OronBox 原生外掛程式，或聯絡作者進行移植';

  @override
  String get settingsTab => '設定';

  @override
  String get search => '搜尋';

  @override
  String get resourceListView => '清單檢視';

  @override
  String get resourceGridView => '卡片檢視';

  @override
  String get refresh => '重新整理';

  @override
  String get refreshing => '重新整理中';

  @override
  String get notifications => '通知';

  @override
  String get newlyPublished => '最新發佈';

  @override
  String get resourceLibrary => '資源庫';

  @override
  String get resourceDetails => '資源詳情';

  @override
  String get resourceCollectionDetails => '合集詳情';

  @override
  String get resourceArticleDetails => '文章詳情';

  @override
  String get creatorCenter => '創作者中心';

  @override
  String get creatorNewResource => '新增資源';

  @override
  String get creatorResourceName => '資源名稱';

  @override
  String get creatorResourceSummary => '資源簡介';

  @override
  String get creatorResourceMetadataRequired => '資源名稱和簡介為必填項目';

  @override
  String get creatorSubmitValidationFailed => '提交前請先處理以下問題';

  @override
  String get creatorPaidType => '付費類型';

  @override
  String get creatorSaveDraft => '儲存草稿';

  @override
  String get creatorAddArtifact => '新增資源檔案';

  @override
  String get creatorBindDevices => '繫結裝置';

  @override
  String get creatorDeleteResource => '刪除';

  @override
  String get creatorIconCover => '圖示與封面';

  @override
  String get creatorInvalidImage => '無法讀取圖片，請使用 PNG/JPEG/WebP';

  @override
  String get creatorInvalidPackage => '此檔案不是 Vela 快應用或錶盤';

  @override
  String creatorPublishPreparing(Object done, Object total) {
    return '正在處理檔案 $done/$total';
  }

  @override
  String creatorPublishUploading(Object percent) {
    return '正在上傳 $percent%';
  }

  @override
  String get creatorPublishServer => '伺服器處理中…';

  @override
  String get creatorAstroBoxItemId => '項目 ID';

  @override
  String get creatorAstroBoxRepository => '儲存庫名稱';

  @override
  String get creatorAstroBoxTags => '標籤（以逗號分隔）';

  @override
  String get creatorAstroBoxAuthor => '作者（需與 AstroBox 使用者名稱相同）';

  @override
  String get creatorAstroBoxBindAccount => '繫結 AstroBox 帳戶';

  @override
  String get replace => '取代';

  @override
  String get delete => '刪除';

  @override
  String get creatorSubmitReview => '提交';

  @override
  String get creatorArchiveAction => '下架';

  @override
  String get creatorArchiveConfirm => '下架後，這項資源會從商店隱藏。你可以隨時重新上架';

  @override
  String get creatorRestoreAction => '重新上架';

  @override
  String get creatorDeleteConfirm => '這項草稿資源將永久刪除';

  @override
  String get creatorDeletePublishedConfirm =>
      '這會永久刪除 OronBox 資源及對應的 BandBBS 資源，且無法復原。已發佈至 AstroBox 的內容不受影響；如需下架，請聯絡 AstroBox-Repo 維護者';

  @override
  String creatorArtifactCount(Object count) {
    return '$count 個套件';
  }

  @override
  String creatorKindMismatchMessage(Object detected, Object expected) {
    return '此檔案看起來是 $detected，但這項資源設定為 $expected。你可以保留檔案，但提交審核前請確認類型正確';
  }

  @override
  String creatorDeviceMoveBlocked(Object name) {
    return '「$name」只繫結了這部裝置，無法移動';
  }

  @override
  String get creatorSelectDevices => '選擇支援的裝置';

  @override
  String creatorSelectedDeviceCount(Object count) {
    return '已選擇 $count 部裝置';
  }

  @override
  String get creatorNoDevicesSelected => '尚未選擇裝置';

  @override
  String get creatorDeviceSelectionDone => '完成';

  @override
  String get creatorAtLeastOneDevice => '每個資源檔案至少要繫結一部裝置';

  @override
  String get resourceAstroBoxEncryptedTitle => 'OronBox 無法處理此 AstroBox 資源';

  @override
  String get resourceAstroBoxEncryptedMessage =>
      '此資源使用 AstroBox Creator Console 的私有加密上傳格式。OronBox 無法解密、下載或安裝，請改用 AstroBox 開啟';

  @override
  String get resourceAstroBoxEncryptedAction => '知道了';

  @override
  String get filter => '篩選';

  @override
  String get resourceTypeFilter => '資源類型';

  @override
  String get resourceCompatibleDevicesFilter => '相容裝置';

  @override
  String get currentDevice => '目前裝置';

  @override
  String get currentWatchface => '目前錶盤';

  @override
  String get all => '全部';

  @override
  String get watchfaces => '錶盤';

  @override
  String get module => '模組';

  @override
  String get quickApps => '快應用';

  @override
  String get firmwareTools => '韌體 / 工具';

  @override
  String get oronBox => 'OronBox';

  @override
  String get bandbbs => 'BandBBS';

  @override
  String get astroBox => 'AstroBox';

  @override
  String get local => '本機';

  @override
  String get install => '安裝';

  @override
  String get update => '更新';

  @override
  String get description => '描述';

  @override
  String get supportedDevices => '支援的裝置';

  @override
  String get downloads => '下載次數';

  @override
  String downloadTimes(int count) {
    return '$count 次下載';
  }

  @override
  String get changelog => '更新日誌';

  @override
  String get changelogUnavailable => '尚無更新日誌';

  @override
  String get notFound => '找不到';

  @override
  String get downloadStarted => '已開始下載';

  @override
  String get compatible => '相容於';

  @override
  String get incompatible => '不相容於';

  @override
  String get incompatibleSuffix => '';

  @override
  String get myResources => '我的資源';

  @override
  String get drafts => '草稿';

  @override
  String get pendingReview => '審核中';

  @override
  String get published => '已發佈';

  @override
  String get creatorStateSuspended => '已下架';

  @override
  String get creatorStateFrozen => '已凍結';

  @override
  String get creatorSuspendedByOwnerNotice => '此資源已下架。你可以繼續編輯並重新提交審核，也可以直接重新上架';

  @override
  String get creatorSuspendedByAdminNotice =>
      '管理員已將此資源下架。編輯後重新提交審核，審核通過後即可重新上架';

  @override
  String get creatorFrozenNotice => '管理員已凍結此資源。你目前無法繼續編輯，只有管理員可以解除凍結';

  @override
  String creatorModerationReason(Object reason) {
    return '原因：$reason';
  }

  @override
  String get creatorBannedTitle => '帳號已被封禁';

  @override
  String get creatorBannedDescription =>
      '你的帳號已被管理員封禁，創作者中心目前無法使用。如果你認為這是誤判，請透過支援工單聯絡團隊';

  @override
  String get creatorFrozenTitle => '創作者功能已凍結';

  @override
  String get creatorFrozenDescription =>
      '管理員已凍結你的創作者功能，目前無法提交或管理資源。帳號的其他功能不受影響';

  @override
  String get creatorBandBbsNoDevices => '請先為資源檔案選擇支援的裝置';

  @override
  String creatorBandBbsUnmappedDevices(Object devices) {
    return '找不到對應的 BandBBS 分類：$devices';
  }

  @override
  String get creatorBandBbsSharedCategory =>
      '同一 BandBBS 分類對應了多個套件。請為每個分類繫結一個套件';

  @override
  String get creatorBandBbsUnresolved => '找不到對應的 BandBBS 分類';

  @override
  String get creatorOptionalIcon => '圖示（選填，1:1）';

  @override
  String get creatorOptionalCover => '封面（選填，3:2）';

  @override
  String get creatorRequiredIcon => '圖示（AstroBox 必填，1:1）';

  @override
  String get creatorRequiredCover => '封面（AstroBox 必填，3:2）';

  @override
  String get creatorIconShapeHint => '圖示不是正方形，在 AstroBox 中可能顯示異常';

  @override
  String get creatorCoverShapeHint => '封面不是 3:2，在 AstroBox 中可能顯示異常';

  @override
  String get creatorTermsBandBbs => 'BandBBS 社群條款與規則';

  @override
  String get creatorTermsAstroBox => 'AstroBox-Repo 提交規範';

  @override
  String get creatorTermsAccept => '我已閱讀並接受以上發佈協議';

  @override
  String get creatorTermsContinue => '進入創作者中心';

  @override
  String get agree => '同意';

  @override
  String get creatorRulesAccept => '我已閱讀並同意以上審核規則';

  @override
  String get creatorBandBbsTermsNotice =>
      'OronBox 審核通過後，資源會直接發佈至對應的 BandBBS 分類。刪除 OronBox 資源也會刪除對應的 BandBBS 資源';

  @override
  String get creatorBandBbsLimitsNotice =>
      '一鍵發佈至 BandBBS 有以下限制，發佈後需要手動處理：\n1. BandBBS 沒有提供上傳資源圖示的 API，因此資源圖示在 BandBBS 上會留白，請前往 BandBBS 網站手動更新\n2. BandBBS 沒有提供討論區標籤的 API，因此資源的討論區屬性不會自動設定，可能導致資源被移除，請前往 BandBBS 網站手動設定正確的討論區';

  @override
  String get creatorAstroBoxTermsNotice =>
      'OronBox 審核通過後，系統會建立資源儲存庫並向官方 AstroBox 儲存庫提交 PR，由 AstroBox 維護者獨立審核。資源公開後如需下架，請聯絡 AstroBox-Repo 維護者';

  @override
  String get creatorAstroBoxReviewNotice =>
      '提交至 AstroBox 的資源必須符合以下審核要求：\n1. 不得包含色情、政治敏感或其他違法內容\n2. 資源品質不得過低，例如僅替換範本製作的錶盤或過於簡單的快應用\n3. 封面應美觀且具吸引力，比例為 3:2（建議 1200x800）；圖示建議為 192x192\n4. 資源必須能在支援的裝置上正常執行基本功能\n5. 禁止未經授權上傳他人的資源\n6. 使用知名 IP 素材時，預覽圖必須包含版權聲明圖片（說明素材與 AstroBox 及 Xiaomi 無關）';

  @override
  String get failed => '失敗 / 需要處理';

  @override
  String get basicInfo => '基本資訊';

  @override
  String get packageFiles => '資源檔案';

  @override
  String get publishTargets => '發佈目標';

  @override
  String get scan => '掃描';

  @override
  String get logs => '日誌';

  @override
  String get pairedDevices => '已配對裝置';

  @override
  String get apps => '應用程式';

  @override
  String get deviceAppCount => '應用程式數量';

  @override
  String get deviceWatchfaceCount => '錶盤數量';

  @override
  String get connection => '連線';

  @override
  String get protocol => '通訊協定';

  @override
  String get error => '錯誤';

  @override
  String get errorBluetoothUnavailable =>
      '無法使用 Bluetooth。請確認 Bluetooth 已開啟，且 OronBox 已獲得使用權限';

  @override
  String get errorBluetoothConnectFailed =>
      '連線失敗。請確認 Bluetooth 權限，讓裝置保持在附近且未被使用，在裝置上開啟「連線新手機」後再試一次';

  @override
  String get errorBluetoothDisconnected => 'Bluetooth 連線已中斷。請重新連線裝置後再試';

  @override
  String get errorOperationTimeout => '操作逾時。請確認裝置仍在附近後再試';

  @override
  String get errorDeviceNotReady => '裝置尚未就緒。請先連線並完成裝置驗證';

  @override
  String get errorBleCharacteristicsMissing =>
      '找不到必要的 BLE 通道。請重新連線裝置，或確認裝置是否支援此功能';

  @override
  String get errorWebSerialUnavailable =>
      '此瀏覽器不支援 Web Serial。請使用 Chrome、Edge 或其他相容 Web Serial 的瀏覽器';

  @override
  String get errorAccountPasswordIncorrect => 'Xiaomi 帳號或密碼錯誤';

  @override
  String get errorAccountTwoFactorIncomplete => 'Xiaomi 帳號雙重驗證尚未完成，請重新登入';

  @override
  String get errorOronBoxSessionExpired => '你的 OronBox 工作階段已過期，請重新登入 BandBBS';

  @override
  String get errorNetworkUnavailable => '無法連線至服務，請檢查網路後再試';

  @override
  String get errorServiceUnavailable => '服務暫時無法使用，請稍後再試';

  @override
  String get errorPermissionDenied => '你沒有執行此操作的權限';

  @override
  String get errorContentNotFound => '要求的內容已不存在或無法使用';

  @override
  String get errorRequestConflict => '內容已變更，請重新整理後再試';

  @override
  String get errorCoinBalanceInsufficient => '硬幣餘額不足';

  @override
  String get errorCoinResourceLimit => '每項資源最多只能投 2 枚硬幣';

  @override
  String get errorCoinOwnResource => '不能為自己的資源投幣';

  @override
  String get errorCoinVotingFrozen => '投幣功能目前已暫停';

  @override
  String get errorCoinAccountTooNew => '帳號必須註冊滿 24 小時才能投幣';

  @override
  String get errorCoinOperationFailed => '投幣失敗，請再試一次';

  @override
  String get errorCoinStatusUnavailable => '無法取得投幣狀態，點擊以重試';

  @override
  String get errorOperationFailed => '操作失敗，請再試一次';

  @override
  String get errorUnknown => '發生未知錯誤，請再試一次';

  @override
  String get errorDownloadQuotaExceeded => '今日下載次數已達上限';

  @override
  String get errorGitHubNotConfigured => '尚未設定 GitHub 發佈功能';

  @override
  String get errorRateLimited => '請求過於頻繁，請稍候再試';

  @override
  String get errorFileTooLarge => '選取的檔案過大';

  @override
  String get errorInvalidRequest => '提交的部分資訊無效，請檢查後再試';

  @override
  String get errorOperationCancelled => '操作已取消';

  @override
  String get errorUnsupportedFileType => '不支援或無法辨識的檔案類型';

  @override
  String get errorCertificateVerificationFailed =>
      '憑證驗證失敗。如果你正在使用代理伺服器，請停用此應用程式的 HTTPS 攔截，或確認代理憑證受到信任';

  @override
  String errorUnknownWithDetail(Object detail) {
    return '操作失敗：$detail';
  }

  @override
  String get appearance => '外觀';

  @override
  String get resources => '資源';

  @override
  String get communitySourceAstroBoxRepo => 'AstroBox Repo';

  @override
  String get communitySourceBandBbs => 'BandBBS 社群';

  @override
  String get communitySourceHuamiAppStore => 'Amazfit 應用程式商店';

  @override
  String get devices => '裝置';

  @override
  String creatorCompatibleDeviceCount(int count) {
    return '$count 部裝置';
  }

  @override
  String get categories => '分類';

  @override
  String get advanced => '進階';

  @override
  String get openSourceLicenses => '開放原始碼授權';

  @override
  String get acknowledgements => '特別致謝';

  @override
  String get deviceNotConnected => '未連線';

  @override
  String get deviceConnected => '已連線';

  @override
  String get deviceDisconnected => '已中斷連線';

  @override
  String get deviceReconnect => '重新連線';

  @override
  String get deviceConnect => '連線';

  @override
  String get deviceSwitch => '切換';

  @override
  String get deviceSyncTime => '同步';

  @override
  String get deviceCharging => '充電中';

  @override
  String get deviceLastChargedNow => '剛剛充電';

  @override
  String deviceLastChargedMinutes(int count) {
    return '$count 分鐘前充電';
  }

  @override
  String deviceLastChargedHours(int count) {
    return '$count 小時前充電';
  }

  @override
  String deviceLastChargedDays(int count) {
    return '$count 天前充電';
  }

  @override
  String get deviceFeaturesInstallApp => '安裝應用程式';

  @override
  String get deviceFeaturesInstallWatchface => '安裝錶盤';

  @override
  String get deviceFeaturesInstallFirmware => '更新韌體';

  @override
  String get deviceFeaturesInstallFirmwareDesc => '檢查裝置更新或安裝本機韌體';

  @override
  String get firmwareCheckingUpdates => '正在檢查韌體更新';

  @override
  String get firmwareNoUpdatesFound => '找不到此裝置的較新韌體';

  @override
  String get firmwareSourceUnavailable => '此裝置類型目前沒有可用的線上韌體來源';

  @override
  String get firmwareVersionUnknown => '無法取得目前韌體版本';

  @override
  String get firmwareCurrentVersion => '目前版本';

  @override
  String get firmwareLatestRelease => '最新韌體';

  @override
  String get firmwareHistoricalReleases => '歷史韌體';

  @override
  String get firmwareUpToDate => '你的韌體已是最新版本';

  @override
  String get firmwareUpdateAvailable => '有可用的更新';

  @override
  String get firmwareDownloadLatestFull => '下載最新完整套件';

  @override
  String get firmwareUpdateNow => '更新';

  @override
  String get firmwareReleaseNotes => '版本更新說明';

  @override
  String get firmwareReleaseNotesUnavailable => '沒有可用的版本更新說明';

  @override
  String get download => '下載';

  @override
  String get downloadTaskAdded => '已加入下載佇列';

  @override
  String get zeppOsMoreFeatures => '特殊功能';

  @override
  String get zeppOsMoreFeaturesDescription => '管理 Zepp OS 裝置的其他功能';

  @override
  String get zeppOsDeviceFeaturesSection => '裝置功能';

  @override
  String get zeppOsAppsAndDevelopmentSection => '應用程式與開發';

  @override
  String get zeppOsAssistant => '語音實驗室';

  @override
  String get zeppOsAssistantDescription => '擷取、監聽及回覆手錶的語音助理工作階段';

  @override
  String get zeppOsScreenMirror => '螢幕鏡像';

  @override
  String get zeppOsScreenMirrorDescription => '在此裝置上查看手錶畫面';

  @override
  String get zeppOsScreenMirrorSemantics => 'Zepp OS 手錶螢幕鏡像';

  @override
  String zeppOsScreenMirrorUnsupported(Object error) {
    return '無法顯示此螢幕格式：$error';
  }

  @override
  String get expand => '展開';

  @override
  String get collapse => '收合';

  @override
  String get voiceLabTitle => '語音實驗室';

  @override
  String get voiceLabXiaoAi => 'XiaoAI';

  @override
  String get voiceLabReceivingAudio => '正在接收手錶音訊';

  @override
  String get voiceLabWaiting => '等待語音工作階段';

  @override
  String get voiceLabContinuousCapture => '連續擷取';

  @override
  String get voiceLabContinuousCaptureDescription => '目前錄音結束後要求下一段錄音';

  @override
  String get voiceLabDisableMonitoring => '停用即時監聽';

  @override
  String get voiceLabEnableMonitoring => '啟用即時監聽';

  @override
  String get voiceLabReplyLabel => '已將回覆傳送至手錶';

  @override
  String get voiceLabReplyHint => '輸入回覆';

  @override
  String get voiceLabReplyQueued => '目前錄音結束前，回覆會留在佇列中';

  @override
  String get voiceLabReplySent => '已將回覆傳送至手錶';

  @override
  String get voiceLabCapturedData => '擷取的資料';

  @override
  String get voiceLabDecoder => '解碼器';

  @override
  String get voiceLabOpusFrames => 'Opus 幀';

  @override
  String get voiceLabDataSize => '資料大小';

  @override
  String get voiceLabPcmSamples => 'PCM 取樣';

  @override
  String get voiceLabExportOpus => '匯出 Opus';

  @override
  String get voiceLabExportWav => '匯出 WAV';

  @override
  String get voiceLabClearCapture => '清除擷取資料';

  @override
  String get voiceLabSaveRecording => '儲存語音錄音';

  @override
  String get voiceLabSaveOpus => '儲存 Opus 音訊';

  @override
  String get voiceLabAudioProcessingFailedPrefix => '音訊處理失敗';

  @override
  String voiceLabAudioProcessingFailed(Object error) {
    return '音訊處理失敗：$error';
  }

  @override
  String voiceLabContinuousCaptureFailed(Object error) {
    return '無法設定連續擷取：$error';
  }

  @override
  String voiceLabAssistantSwitchFailed(Object error) {
    return '無法切換語音助理：$error';
  }

  @override
  String voiceLabExportWavFailed(Object error) {
    return '無法匯出 WAV：$error';
  }

  @override
  String voiceLabExportOpusFailed(Object error) {
    return '無法匯出 Opus：$error';
  }

  @override
  String get send => '傳送';

  @override
  String sendFailed(Object error) {
    return '傳送失敗：$error';
  }

  @override
  String get ready => '就緒';

  @override
  String get initializing => '初始化中';

  @override
  String get zeppOsMapSelectPackage => '選擇 Zepp OS 地圖套件';

  @override
  String get zeppOsMapReadFailed => '無法讀取地圖套件';

  @override
  String get zeppOsMapTransferTitle => '傳輸離線地圖';

  @override
  String zeppOsMapGarminDetected(Object fileName, Object mapName) {
    return '$fileName\n偵測到單檔 Garmin IMG 地圖：$mapName';
  }

  @override
  String get zeppOsMapGarminNoPreview =>
      '此地圖不包含 Zepp OS 11/x/y 瓦片樹。原始 IMG 將以單檔地圖套件傳輸，因此無法預覽涵蓋範圍';

  @override
  String zeppOsMapTileSummary(Object fileName, Object count) {
    return '$fileName · $count 個瓦片\n預覽顯示套件涵蓋範圍，不代表 Garmin IMG 在手錶上的實際呈現';
  }

  @override
  String get zeppOsMapStartTransfer => '開始傳輸';

  @override
  String get zeppOsMapTransferringBluetooth => '正在透過 Bluetooth 傳輸';

  @override
  String get zeppOsMapTransferComplete => '離線地圖傳輸完成';

  @override
  String get zeppOsMapConversionFailed => '無法安全轉換地圖';

  @override
  String get zeppOsMapBtClassicHint =>
      'Bluetooth Classic 大量傳輸已啟用。開始傳輸後，請在手錶上確認安裝';

  @override
  String get zeppOsMapBleHint =>
      'BLE 支援最大 2 MB 的地圖套件。傳輸較大地圖前請切換至 Bluetooth Classic。開始傳輸後，請在手錶上確認安裝';

  @override
  String get zeppOsMapPreviewTooLarge => '地圖範圍過大，無法完整預覽';

  @override
  String zeppOsSettingPageLoadFailed(Object error) {
    return '無法載入設定頁面：$error';
  }

  @override
  String zeppOsAppCompatibilitySaved(Object appId) {
    return '已為 $appId 儲存相容性檔案';
  }

  @override
  String zeppOsAppStorageSaved(Object appId) {
    return '已為 $appId 儲存 settingsStorage';
  }

  @override
  String get zeppOsAppSupplementFiles => '新增應用程式端或設定檔案';

  @override
  String get zeppOsAppSupplementCompatibility => '新增迷你應用程式相容性檔案';

  @override
  String get zeppOsAppReplaceCompatibility => '新增或取代相容性檔案';

  @override
  String get zeppOsAppSideAvailable => '應用程式端 ✓';

  @override
  String get zeppOsAppSideMissing => '缺少應用程式端';

  @override
  String get zeppOsSettingAvailable => '設定 ✓';

  @override
  String get zeppOsSettingMissing => '缺少設定';

  @override
  String get zeppOsAppEditStorage => '編輯設定儲存空間';

  @override
  String get zeppOsStorageKeyRequired => '必須輸入索引鍵';

  @override
  String zeppOsStorageDuplicateKey(Object key) {
    return '索引鍵重複：$key';
  }

  @override
  String get zeppOsStorageDescription => '此資料由設定頁面與應用程式端共用，並依 Zepp OS 規範以字串儲存';

  @override
  String get zeppOsStorageEmpty => '沒有已儲存的項目';

  @override
  String get zeppOsStorageKey => '索引鍵';

  @override
  String get zeppOsStorageValue => '值';

  @override
  String get clear => '清除';

  @override
  String get save => '儲存';

  @override
  String get selectedFileReadFailed => '無法讀取選取的檔案';

  @override
  String get zeppOsAppInvalidHexId => '輸入有效的十六進位 App ID';

  @override
  String get zeppOsAppSelectCompatibilityFile => '至少選擇一個應用程式端 .js 或設定 .js 檔案';

  @override
  String get zeppOsAppHexId => 'App ID（十六進位）';

  @override
  String get optionalDisplayName => '顯示名稱（選填）';

  @override
  String get zeppOsAppSideUnchanged => '保留現有應用程式端';

  @override
  String get zeppOsSettingUnchanged => '保留現有設定';

  @override
  String get selectFile => '選擇檔案';

  @override
  String get zeppOsAppCompatibilityOverwriteHint =>
      '儲存會取代此 App ID 下同名的相容性檔案，但不會修改手錶上的迷你應用程式';

  @override
  String zeppOsDebugRefreshFailed(Object error) {
    return '自動重新整理失敗：$error';
  }

  @override
  String get zeppOsDebugInvalidHex => 'HEX 必須包含完整位元組，可用空格、換行、0x、逗號或類似分隔符分隔';

  @override
  String get zeppOsDebugClearEventsTitle => '清除目前應用程式的事件？';

  @override
  String zeppOsDebugClearEventsDescription(Object appId) {
    return '$appId 的所有除錯事件都將被清除';
  }

  @override
  String get zeppOsDebugClearEvents => '清除事件s';

  @override
  String get zeppOsDebugRefresh => '重新整理狀態與事件';

  @override
  String get zeppOsDebugAppList => '應用程式端清單';

  @override
  String get zeppOsDebugNoApps => '尚未偵測到快取指令碼或手錶應用程式端工作階段';

  @override
  String get zeppOsDebugCached => '已快取';

  @override
  String get zeppOsDebugNotCached => '未快取';

  @override
  String get zeppOsDebugRuntimeRunning => '執行環境執行中';

  @override
  String get zeppOsDebugRuntimeStopped => '執行環境已停止';

  @override
  String get zeppOsDebugLocalRuntime => '本機執行環境';

  @override
  String get zeppOsDebugCannotStart => '此 App ID 沒有快取指令碼，無法在本機啟動';

  @override
  String get zeppOsDebugCanStart => '可以手動啟動快取指令碼，不會偽造手錶工作階段參數';

  @override
  String get zeppOsDebugScriptRunning => '指令碼正在本機 QuickJS 中執行';

  @override
  String get zeppOsDebugStartQuickJs => '開始 QuickJS';

  @override
  String get stop => '停止';

  @override
  String get zeppOsDebugMessageEditor => '訊息編輯器';

  @override
  String get zeppOsDebugUtf8Text => 'UTF-8 文字';

  @override
  String get zeppOsDebugJsonCompact => 'JSON（傳送前壓縮）';

  @override
  String get zeppOsDebugHexBytes => 'HEX位元組';

  @override
  String get zeppOsDebugEncodingFailed => '目前內容無法以選取的模式編碼';

  @override
  String get zeppOsDebugByteCountUnavailable => '位元組：--';

  @override
  String zeppOsDebugBytePreview(Object count, Object hex) {
    return '位元組：$count\nHEX：$hex';
  }

  @override
  String get zeppOsDebugInjectLocal => '將傳入訊息注入本機執行環境';

  @override
  String get zeppOsDebugSendToWatch => '傳送至手錶';

  @override
  String get zeppOsDebugWaitingForWatch => '傳送至手錶（等待實際工作階段）';

  @override
  String get zeppOsDebugEvents => '除錯事件';

  @override
  String get zeppOsDebugClearCurrentApp => '清除目前應用程式';

  @override
  String get zeppOsDebugSearch => '搜尋類型、訊息、HEX 或可讀文字';

  @override
  String get zeppOsDebugWatchOnly => '僅顯示實際手錶訊息';

  @override
  String get zeppOsDebugNoEvents => '沒有事件符合目前篩選條件';

  @override
  String get zeppOsDebugMessageActions => '訊息操作';

  @override
  String get zeppOsDebugLoadEditor => '載入至編輯器';

  @override
  String get zeppOsDebugCopyHex => '複製 HEX';

  @override
  String get zeppOsDebugCopyText => '複製文字';

  @override
  String get zeppOsDebugSessionStatus => '執行環境與工作階段狀態';

  @override
  String zeppOsDebugCachedScript(Object status) {
    return '快取指令碼：$status';
  }

  @override
  String zeppOsDebugLocalRuntimeStatus(Object status) {
    return '本機執行環境：$status';
  }

  @override
  String zeppOsDebugWatchSession(Object status) {
    return '手錶工作階段：$status';
  }

  @override
  String get exists => '可用';

  @override
  String get notExists => '不可用';

  @override
  String get running => '執行中';

  @override
  String get notRunning => '未執行';

  @override
  String get notOpen => '未開啟';

  @override
  String get zeppOsDebugWatchSessionOpen => '實際工作階段已開啟';

  @override
  String get zeppOsDebugRealHeader => '實際標頭';

  @override
  String zeppOsDebugLatestStartup(Object status) {
    return '最近啟動狀態：$status';
  }

  @override
  String get zeppOsDebugWatchInbound => '來自手錶';

  @override
  String get zeppOsDebugWatchOutbound => '傳送至手錶';

  @override
  String get zeppOsDebugLifecycle => '生命週期';

  @override
  String get zeppOsMirrorInterval => '畫面間隔';

  @override
  String get zeppOsMirrorIntervalRange => '10–250';

  @override
  String get zeppOsOfflineMaps => '離線地圖';

  @override
  String get zeppOsOfflineMapsDescription => '將現有地圖套件傳輸至手錶';

  @override
  String get zeppOsAppSettings => 'App設定';

  @override
  String get zeppOsAppSettingsDescription => '管理 Zepp OS 應用程式的快取設定';

  @override
  String get zeppOsAppDebug => '應用程式除錯';

  @override
  String get zeppOsAppDebugDescription => '除錯應用程式端指令碼與裝置通訊';

  @override
  String get deviceMusicSync => '音樂同步';

  @override
  String get deviceHealthTitle => '運動健康';

  @override
  String get deviceHealthDescription => '同步裝置上的活動與睡眠資料';

  @override
  String get deviceHealthSyncCardTitle => '健康資料';

  @override
  String get deviceHealthNeverSynced => '尚未同步運動健康資料';

  @override
  String deviceHealthLastSynced(String time) {
    return '上次同步於 $time';
  }

  @override
  String get deviceHealthSync => '同步運動健康資料';

  @override
  String get deviceHealthSyncing => '正在同步';

  @override
  String get deviceHealthAutoSyncTitle => '自動同步運動健康資料';

  @override
  String get deviceHealthAutoSyncDescription => '同步裝置資料時自動同步運動健康資料';

  @override
  String get deviceHealthConnectFirst => '請先連線裝置再同步運動健康資料';

  @override
  String get deviceHealthPartialSync => '部分運動健康資料同步失敗';

  @override
  String get deviceHealthToday => '今日活動';

  @override
  String get deviceHealthSteps => '步數';

  @override
  String get deviceHealthDistance => '距離';

  @override
  String get deviceHealthCalories => '卡路里';

  @override
  String get deviceHealthHeartRate => '心率';

  @override
  String get deviceHealthRestingHeartRate => '靜息心率';

  @override
  String get deviceHealthAbnormalHeartRate => '異常心率';

  @override
  String get deviceHealthHeartRateHigh => '心率過高';

  @override
  String get deviceHealthHeartRateLow => '心率過低';

  @override
  String get deviceHealthHeartHealth => '心臟健康';

  @override
  String get deviceHealthHeartHealthMonitoring => '心臟健康監測';

  @override
  String get deviceHealthIrregularHeartbeat => '異常心搏';

  @override
  String get deviceHealthLowBloodOxygen => '血氧過低';

  @override
  String get deviceHealthHighStress => '壓力過高';

  @override
  String get deviceHealthDetected => '已偵測';

  @override
  String get deviceHealthSleep => '最近睡眠';

  @override
  String get deviceHealthSleepCard => '睡眠';

  @override
  String get deviceHealthAllDaySleep => '全天睡眠';

  @override
  String get deviceHealthLongSleep => '長睡眠';

  @override
  String get deviceHealthSleepStructure => '睡眠結構';

  @override
  String get deviceHealthSleepAverageHeartRate => '睡眠平均心率';

  @override
  String get deviceHealthSleepAverageBloodOxygen => '睡眠平均血氧';

  @override
  String deviceHealthAverageHeartRate(int value) {
    return '平均心率 $value bpm';
  }

  @override
  String get deviceHealthNoData => '暫無資料';

  @override
  String get deviceHealthLoadFailed => '無法讀取運動健康資料';

  @override
  String get deviceMusicUpload => '傳輸音樂';

  @override
  String get deviceMusicSyncDescription => '將 MP3 檔案同步至裝置';

  @override
  String get deviceMusicChooseDialog => '選擇要同步至裝置的 MP3 檔案';

  @override
  String get deviceMusicReadFailed => '無法讀取選取的 MP3 檔案';

  @override
  String deviceMusicSizeInvalid(int maxMb) {
    return 'MP3 檔案大小必須大於 0 位元組且不得超過 $maxMb MB';
  }

  @override
  String get deviceMusicUnknownArtist => '未知演出者';

  @override
  String get deviceMusicTransferred => '音樂傳輸完成';

  @override
  String get deviceMusicLibrary => '裝置音樂';

  @override
  String get deviceMusicLibraryDescription => '管理裝置上的歌曲與播放清單';

  @override
  String get deviceMusicSongs => '歌曲';

  @override
  String deviceMusicSongsTotal(int count) {
    return '共 $count 首';
  }

  @override
  String get deviceMusicNoPlaylist => '不在播放清單中';

  @override
  String get deviceMusicPlaylists => '播放清單';

  @override
  String get deviceMusicEmpty => '裝置上沒有歌曲';

  @override
  String get deviceMusicNoPlaylists => '尚無播放清單';

  @override
  String deviceMusicLoadFailed(String error) {
    return '載入裝置音樂失敗：$error';
  }

  @override
  String get deviceMusicPlaylistCreate => '新增播放清單';

  @override
  String get deviceMusicPlaylistRename => '重新命名播放清單';

  @override
  String get deviceMusicPlaylistName => '播放清單名稱';

  @override
  String deviceMusicPlaylistLimit(int count) {
    return '最多 $count 個播放清單';
  }

  @override
  String deviceMusicSongCount(int count) {
    return '$count 首歌曲';
  }

  @override
  String get deviceMusicDeleteSong => '要從裝置刪除此歌曲嗎？';

  @override
  String get deviceMusicDeletePlaylist => '要刪除此播放清單嗎？';

  @override
  String get deviceMusicDeletePlaylistDescription => '播放清單中的歌曲會保留在裝置上';

  @override
  String get deviceMusicManagePlaylists => '管理播放清單';

  @override
  String get deviceMusicPlaylistMembership => '播放清單';

  @override
  String deviceMusicTransferSpeed(String speed) {
    return '$speed/s';
  }

  @override
  String deviceMusicSelectedFiles(int count) {
    return '已選取 $count 個檔案';
  }

  @override
  String deviceMusicQueueProgress(int current, int total, String name) {
    return '正在傳輸 $current/$total：$name';
  }

  @override
  String get deviceRecordingsTitle => '錄音同步';

  @override
  String get deviceRecordingsDescription => '同步並匯出手錶錄音';

  @override
  String get deviceRecordingsHint => '錄音會逐一接收並驗證\n同步後請分別匯出每個原始檔案';

  @override
  String get deviceRecordingsSync => '同步錄音';

  @override
  String get deviceRecordingsReading => '正在讀取錄音清單';

  @override
  String deviceRecordingsProgress(int completed, int total, String name) {
    return '已接收 $completed/$total：$name';
  }

  @override
  String deviceRecordingsProgressCount(int completed, int total) {
    return '已接收 $completed/$total';
  }

  @override
  String get deviceRecordingsEmpty => '連線手錶後選擇「同步錄音」';

  @override
  String get deviceRecordingsSave => '匯出錄音';

  @override
  String get deviceRecordingsNoneOnWatch => '手錶上沒有新的錄音';

  @override
  String deviceRecordingsSynced(int count) {
    return '已同步 $count 個錄音';
  }

  @override
  String deviceRecordingsSaveFailed(String error) {
    return '無法匯出錄音：$error';
  }

  @override
  String get deviceMusicTransferTitle => '傳輸 MP3 檔案';

  @override
  String get deviceMusicVelaDescription => '將 MP3 檔案同步至裝置。每個檔案不得超過 100 MB';

  @override
  String get deviceMusicZeppDescription =>
      '支援最大 50 MB 的 MP3 檔案。建議使用 Bluetooth Classic 以加快傳輸；BLE 也可使用，但需要較長時間';

  @override
  String get deviceMusicChooseMp3 => '選擇 MP3 檔案';

  @override
  String get deviceMusicSongTitle => '曲目標題';

  @override
  String get deviceMusicArtist => '演出者';

  @override
  String deviceMusicFileSize(Object size) {
    return '檔案大小：$size';
  }

  @override
  String deviceMusicProgress(Object progress) {
    return '傳輸進度：$progress%';
  }

  @override
  String get deviceMusicTransferring => '傳輸中';

  @override
  String get deviceMusicSend => '開始傳輸';

  @override
  String get zeppOsFindDevice => '尋找裝置';

  @override
  String get zeppOsFindDeviceDescription => '讓裝置持續震動或響鈴';

  @override
  String get deviceFeaturesDeviceInfo => '裝置資訊';

  @override
  String get deviceFeaturesDeviceInfoDesc => '韌體、儲存空間與詳細資料';

  @override
  String get switchDeviceTitle => '切換裝置';

  @override
  String get savedDevices => '已儲存的裝置';

  @override
  String get deviceSwitchAddDevice => '新增裝置';

  @override
  String get scanAndAdd => '掃描並新增';

  @override
  String get authkey => '認證密鑰';

  @override
  String get authkeyPrompt => '輸入裝置 Auth key';

  @override
  String get authkeyPlaceholder => '認證密鑰';

  @override
  String get connectFailed => '連線失敗';

  @override
  String deviceConnectingTo(String deviceName) {
    return '正在連線至 $deviceName…';
  }

  @override
  String get deviceConnectionPreparing => '正在準備連線…';

  @override
  String deviceConnectionEstablishing(String transport) {
    return '正在建立 $transport 連線…';
  }

  @override
  String get deviceConnectionInitializing => '正在初始化裝置通訊協定…';

  @override
  String get deviceConnectionAuthenticating => '正在驗證裝置…';

  @override
  String get deviceConnectionFetchingStatus => '正在讀取裝置資訊…';

  @override
  String get deviceTransportBle => 'BLE';

  @override
  String deviceEndpointUnavailable(String transport) {
    return '沒有可用的 $transport 端點。請先在系統 Bluetooth 設定中配對裝置，再重新掃描';
  }

  @override
  String get deviceTransportSpp => 'SPP';

  @override
  String get deviceCompatibilityUnknown => '無法辨識的裝置';

  @override
  String get webSerialTitle => 'Web Serial';

  @override
  String get webSerialHint => '在網頁上，OronBox 透過 Web Serial 連線裝置。儲存的裝置會保留在此瀏覽器中';

  @override
  String get webSerialConnectDialogTitle => '透過 Web Serial 連線';

  @override
  String get webSerialConnectDialogHint =>
      '輸入裝置 Auth key，然後在瀏覽器提示中選擇序列埠。Auth key 會儲存在此瀏覽器中';

  @override
  String get cancel => '取消';

  @override
  String get deviceActionsDelete => '刪除';

  @override
  String get deviceActionsDisconnect => '中斷連線';

  @override
  String get deviceActionsShareQR => '分享 QR Code';

  @override
  String get deviceShareOronBoxCode => '切換至 OronBox Code';

  @override
  String get deviceShareAstroBoxCompatibleCode => '切換至 AstroBox 相容 Code';

  @override
  String get installTapToSelectFile => '點擊以選擇檔案';

  @override
  String get deviceInfoTitle => '裝置資訊';

  @override
  String get deviceInfoGroupDevice => '裝置';

  @override
  String get deviceInfoGroupSystem => '系統';

  @override
  String get deviceInfoGroupStatus => '狀態';

  @override
  String get fieldName => '名稱';

  @override
  String get fieldAddress => '位址';

  @override
  String get fieldAuthkey => '認證密鑰';

  @override
  String get fieldConnectionType => '連線類型';

  @override
  String get fieldCodename => '代號';

  @override
  String get fieldModel => '型號';

  @override
  String get fieldImei => 'IMEI';

  @override
  String get fieldFirmware => '韌體';

  @override
  String get fieldSerial => '序號';

  @override
  String get fieldBattery => '電池';

  @override
  String get fieldChargeStatus => '充電狀態';

  @override
  String get fieldStorage => '儲存空間';

  @override
  String get appManagementTitle => '應用程式管理';

  @override
  String get appManagementNone => '沒有已安裝的應用程式';

  @override
  String get appManagementShowSystemApps => '顯示系統應用程式';

  @override
  String get watchfaceManagementTitle => '錶盤管理';

  @override
  String get watchfaceManagementNone => '沒有已安裝的錶盤';

  @override
  String get open => '開啟';

  @override
  String get externalLinkTitle => '開啟外部連結';

  @override
  String externalLinkDescription(String url) {
    return '你即將前往 $url\n\n此網站由第三方營運，與 OronBox 無關，安全性未知。請謹慎操作。要繼續嗎？';
  }

  @override
  String get externalLinkAstroBoxResourceHint =>
      '這看起來是 AstroBox 資源。你也可以在 OronBox 中查看並安裝';

  @override
  String get continueToWebsite => '繼續';

  @override
  String get viewInOronBox => '在 OronBox 中查看';

  @override
  String get uninstall => '解除安裝';

  @override
  String get enable => '啟用';

  @override
  String get show => '顯示';

  @override
  String get hide => '隱藏';

  @override
  String get copy => '複製';

  @override
  String get copied => '已複製';

  @override
  String get close => '關閉';

  @override
  String get desktopTrayShow => '顯示視窗';

  @override
  String get desktopTrayExit => '結束 OronBox';

  @override
  String get desktopCloseTitle => '結束確認';

  @override
  String get desktopCloseMessage => '要結束 OronBox 嗎？';

  @override
  String get desktopCloseRemember => '不再詢問';

  @override
  String get desktopCloseToTray => '縮小至系統匣';

  @override
  String get desktopCloseExit => '結束 OronBox';

  @override
  String get settingsDesktopCloseBehavior => '視窗關閉';

  @override
  String get settingsDesktopCloseBehaviorDesc => '選擇關閉主視窗時的行為';

  @override
  String get settingsRemoveBondBeforeSpp => '連線時重新配對';

  @override
  String get settingsRemoveBondBeforeSppDesc =>
      '開啟有助於提升連線穩定性，防止官方運動健康搶走裝置連線，關閉後有助於加快連線速度';

  @override
  String get desktopCloseBehaviorAsk => '每次詢問';

  @override
  String get desktopCloseBehaviorExit => '立即結束';

  @override
  String get desktopCloseBehaviorTray => '縮小至系統匣';

  @override
  String get quickApp => '快應用';

  @override
  String get miniprogram => '小程式';

  @override
  String get miniprograms => '小程式';

  @override
  String get watchface => '錶盤';

  @override
  String get firmwareTool => '韌體／工具';

  @override
  String get free => '免費';

  @override
  String get paid => '付費';

  @override
  String get forcePaid => '強制付費';

  @override
  String get version => '版本';

  @override
  String get noContent => '沒有內容';

  @override
  String get preview => '預覽';

  @override
  String get productDeviceRequirements => '裝置需求';

  @override
  String get productOtherVersions => '其他版本';

  @override
  String get productInQueue => '佇列中';

  @override
  String get settingsAccount => '帳號';

  @override
  String get settingsGeneral => '一般';

  @override
  String get settingsQueue => '佇列';

  @override
  String get settingsAbout => '關於';

  @override
  String get settingsAccountLoginBBSDesc => '登入以存取 BandBBS 資源';

  @override
  String get settingsAccountBandBbsSigningIn => '登入中';

  @override
  String get settingsAccountBandBbsOpenedBrowser =>
      '已開啟瀏覽器，請在瀏覽器中完成 BandBBS 授權';

  @override
  String get settingsAccountBandBbsSignedIn => '已登入 BandBBS';

  @override
  String get settingsAccountBandBbsLoginFailed => 'BandBBS 登入失敗';

  @override
  String get settingsBandBbsAccountRequired => '請先在設定中登入 BandBBS 帳號';

  @override
  String get settingsAccountBBSAccount => 'BandBBS帳號';

  @override
  String get bandBbsAccountTitle => 'BandBBS帳號';

  @override
  String get bandBbsResourceId => '資源 ID';

  @override
  String get bandBbsResourceIdHint => '輸入 BandBBS 資源 ID';

  @override
  String get bandBbsQueryResource => '查詢';

  @override
  String get bandBbsLogout => '登出';

  @override
  String get bandBbsLoggedOut => '已登出';

  @override
  String accountSignOutTitle(Object accountName) {
    return '要登出 $accountName 嗎？';
  }

  @override
  String get accountSignOutMessage => '你需要重新登入才能使用相關功能';

  @override
  String get bandBbsLoadPreviews => '載入文章預覽';

  @override
  String get bandBbsLoadPreviewsDesc => '自動載入資源清單中的附件預覽';

  @override
  String get bandBbsShowAllCategories => '顯示全部分類';

  @override
  String get bandBbsShowAllCategoriesDesc => '包含預設隱藏的不支援裝置分類';

  @override
  String get settingsMiAccount => 'Xiaomi帳號';

  @override
  String get settingsMiAccountDesc => '登入並同步已繫結裝置的 Auth key';

  @override
  String get deviceSwitchMiAccountImport => '登入 Xiaomi 帳號並同步已繫結裝置';

  @override
  String get deviceSwitchWearableLogImport => '從 Xiaomi Fitness 日誌匯入裝置';

  @override
  String get settingsMiAccountLoginTitle => 'Xiaomi帳號登入';

  @override
  String get settingsMiAccountUsername => '帳號';

  @override
  String get settingsMiAccountPassword => '密碼';

  @override
  String get settingsMiAccountRememberCredentials => '記住帳號與密碼';

  @override
  String get settingsMiAccountLoginAndSync => '登入並同步';

  @override
  String get settingsMiAccountLogInvalid => '無法讀取此 Xiaomi Fitness 日誌';

  @override
  String get settingsMiAccountLogNoDevices => '日誌中找不到包含完整 MAC 位址與 Auth key 的裝置';

  @override
  String get settingsWearableLogSync => '讀取 Xiaomi Fitness 日誌';

  @override
  String get settingsWearableLogGuide =>
      '開啟 Xiaomi Fitness\n前往「我的」頁面底部的「關於」\n連續點擊橙色圓環標誌\n在彈出的對話框中點擊「確認」\n等待出現「log has been...」提示\n返回此處並點擊「掃描」';

  @override
  String settingsWearableLogFound(int count) {
    return '偵測到 $count 部裝置，點擊以匯入';
  }

  @override
  String settingsWearableLogImportedDevice(Object name) {
    return '已匯入 $name';
  }

  @override
  String get settingsMiAccountMissingCredentials => '輸入你的 Xiaomi 帳號與密碼';

  @override
  String get settingsMiAccountTwoFactorPrompt => '請在驗證頁面完成 Xiaomi 帳號雙重驗證';

  @override
  String get settingsMiAccountLoginWindowClosed => '登入視窗已關閉';

  @override
  String settingsMiAccountSyncedDevices(int count) {
    return '已同步 $count 部 Mi 裝置';
  }

  @override
  String get xiaomiAccountRequiredForEphemeris => '尚未登入 Xiaomi 帳號，請先登入後再同步星曆';

  @override
  String get settingsHuamiAccount => 'Amazfit帳號';

  @override
  String get settingsHuamiAccountDesc => '登入並儲存存取 Zepp 商店所需的憑證';

  @override
  String get settingsHuamiAccountSigningIn => '登入中';

  @override
  String get settingsHuamiAccountSignedIn => '已登入 Amazfit 帳號';

  @override
  String get settingsHuamiAccountLoginTitle => 'Amazfit帳號登入';

  @override
  String get settingsHuamiAccountUsername => '帳號';

  @override
  String get settingsHuamiAccountPassword => '密碼';

  @override
  String get settingsHuamiAccountRememberCredentials => '記住密碼';

  @override
  String get settingsHuamiAccountLoginAndSave => '登入並儲存';

  @override
  String get settingsHuamiAccountMissingCredentials => '輸入你的 Amazfit 帳號與密碼';

  @override
  String get settingsHuamiAccountRequired => '請先在設定中登入 Amazfit 帳號';

  @override
  String get understood => '我明白';

  @override
  String get settingsGeneralLanguage => '語言';

  @override
  String get settingsGeneralLanguageDesc => '變更應用程式顯示語言';

  @override
  String get settingsWideNavigationPosition => '導覽列位置';

  @override
  String get settingsWideNavigationPositionDesc => '調整寬螢幕模式下側邊分頁的位置';

  @override
  String get settingsWideNavigationPositionBottom => '底部';

  @override
  String get settingsWideNavigationPositionCenter => '中央';

  @override
  String get settingsWideNavigationPositionSplit => '分割';

  @override
  String get settingsAutoReconnectTitle => '自動重新連線';

  @override
  String get settingsAutoReconnectDesc => '啟動時自動重新連線上次配對的裝置';

  @override
  String get settingsAutoReconnectOnDisconnectTitle => '自動重新連線';

  @override
  String get settingsAutoReconnectOnDisconnectDesc => '與裝置的連線被動中斷時嘗試重新連線';

  @override
  String get deviceReconnectAttempting => '裝置連線異常，正在嘗試重新連線';

  @override
  String get deviceReconnectSucceeded => '重新連線成功';

  @override
  String get deviceReconnectFailedPrefix => '重新連線失敗，請檢查：';

  @override
  String get settingsSourceOfficialCdn => 'GitHub 來源 CDN';

  @override
  String get settingsSourceOfficialCdnDesc => '用於取得 GitHub 社群索引的 CDN';

  @override
  String get settingsQueueAutoInstall => '自動安裝';

  @override
  String get settingsQueueAutoInstallDesc => '下載後自動開始安裝';

  @override
  String get settingsQueueDontClear => '不要清除安裝佇列';

  @override
  String get settingsQueueDontClearDesc => '保留安裝佇列中的已完成項目';

  @override
  String get settingsRealtimeActivityNotification => '即時活動通知';

  @override
  String get settingsRealtimeActivityNotificationDesc => '使用即時活動通知顯示佇列進度';

  @override
  String get settingsAboutWebsite => '官方網站';

  @override
  String get settingsTapToSignIn => '點擊以登入';

  @override
  String get settingsConnected => '已連線';

  @override
  String get settingsSystem => '系統';

  @override
  String get settingsLight => '淺色';

  @override
  String get settingsDark => '深色';

  @override
  String get settingsOledDark => 'OLED 深色';

  @override
  String get settingsThemeMode => '主題模式';

  @override
  String get settingsThemeModeDesc => '變更應用程式主題外觀';

  @override
  String get settingsDynamicColor => '動態色彩';

  @override
  String get settingsDynamicColorDesc => '使用系統強調色作為應用程式主題色';

  @override
  String get settingsColorScheme => '色彩配置';

  @override
  String get settingsColorSchemeDesc => '選擇應用程式強調色';

  @override
  String get settingsColorSchemePink => '粉紅';

  @override
  String get settingsColorSchemePurple => '紫色';

  @override
  String get settingsColorSchemeTeal => '藍綠';

  @override
  String get settingsColorSchemeGreen => '綠色';

  @override
  String get settingsColorSchemeRed => '紅色';

  @override
  String get settingsColorSchemeAmber => '琥珀';

  @override
  String get settingsDesktopAccentSource => 'Linux 強調色來源';

  @override
  String get settingsDesktopAccentSourceDesc => '選擇從 GTK 或 Qt 讀取強調色';

  @override
  String get settingsDesktopAccentSourceSystem => '自動';

  @override
  String get settingsDesktopAccentSourceGtk => 'GTK';

  @override
  String get settingsDesktopAccentSourceQt => 'Qt';

  @override
  String get settingsCancel => '取消';

  @override
  String get settingsTeamRoleMain => '主要開發者／設計師';

  @override
  String get settingsTeamRoleZeppOS => 'ZeppOS 實作';

  @override
  String get settingsAboutSoftware => '關於軟體';

  @override
  String get settingsAboutSoftwareDesc => '版本、更新日誌與開發團隊';

  @override
  String get settingsAboutSoftwareTagline =>
      '一款以 Flutter 打造、快速美觀的 VelaOS 與 ZeppOS 穿戴式裝置管理工具';

  @override
  String get settingsAboutSoftwareRepository => '開啟 GitHub 儲存庫';

  @override
  String get settingsAboutSoftwareTeam => '開發團隊';

  @override
  String get settingsAboutSoftwareBuildInfo => '建置資訊';

  @override
  String get settingsAboutSoftwareCopyright => 'Copyright © 2026 OrPudding';

  @override
  String get acknowledgementsKazumi => '參考 Material Design 元件與 UI 模式';

  @override
  String get acknowledgementsAstroBoxPublic => '參考 UI 結構、資源流程與互動設計';

  @override
  String get acknowledgementsAstroBoxNgCore => '參考 Xiaomi 裝置通訊協定、安裝流程與傳輸行為';

  @override
  String get acknowledgementsAstroBoxNgBluetooth => '參考 Bluetooth 連線行為';

  @override
  String get acknowledgementsAstroBoxNgAccount =>
      '參考 Xiaomi 帳號登入、裝置同步與 Auth key 取得流程';

  @override
  String get acknowledgementsAstroBoxNgProvider =>
      '參考社群資源索引、CDN 處理與 manifest 解析流程';

  @override
  String get acknowledgementsAstroBoxNgAppWasm => '參考 Web Serial 與瀏覽器端連線流程';

  @override
  String get acknowledgementsGadgetbridge => '參考 ZeppOS 與穿戴式裝置通訊協定研究';

  @override
  String get acknowledgementsBreezyWeather => '中國天氣來源實作參考';

  @override
  String get acknowledgementsOpenMeteo => '依 CC BY 4.0 提供的天氣預報、空氣品質與地點搜尋資料';

  @override
  String get resourceHomeRecommended => '推薦';

  @override
  String get resourceHomeFeatured => '精選';

  @override
  String get resourceHomeUpdates => '更新';

  @override
  String get blogTypeAnnouncement => '公告';

  @override
  String get blogTypeRecommendation => '推薦';

  @override
  String get blogTypeDocs => '文件';

  @override
  String get resourceHomeEmptyTitle => '目前沒有推薦內容';

  @override
  String get resourceLibraryEndOfList => '已到達清單底部——要查看其他來源的資源嗎？';

  @override
  String get resourceHomeEmptySubtitle => '你可以從資源庫取得資源';

  @override
  String get openResourceLibrary => '開啟資源庫';

  @override
  String get downloadQueueTitle => '下載佇列';

  @override
  String get installQueueTitle => '安裝佇列';

  @override
  String get queueClear => '清除';

  @override
  String get queueStart => '開始';

  @override
  String get queuePause => '暫停';

  @override
  String get downloadQueueEmpty => '沒有下載工作';

  @override
  String get installQueueEmpty => '沒有安裝工作';

  @override
  String get localAppInstall => '本機應用程式安裝';

  @override
  String get localWatchfaceInstall => '本機 錶盤安裝';

  @override
  String get localFirmwareInstall => '本機 韌體安裝';

  @override
  String get queueStatusPending => '等待中';

  @override
  String queueStatusDownloading(String percent) {
    return '下載中 $percent%';
  }

  @override
  String queueStatusInstalling(String percent) {
    return '安裝中 $percent%';
  }

  @override
  String get queueStatusCompleted => '已完成';

  @override
  String get queueStatusFailed => '失敗';

  @override
  String get queueDragToInstall => '放開以安裝應用程式、錶盤或外掛程式';

  @override
  String queueAddedFiles(int count) {
    return '已將 $count 個檔案加入安裝佇列';
  }

  @override
  String get installQueueReadFailed => '讀取失敗';

  @override
  String get installQueueUnsupportedFile => '不支援的檔案';

  @override
  String timeTodayAt(Object time) {
    return '今天 $time';
  }

  @override
  String timeYesterdayAt(Object time) {
    return '昨天 $time';
  }

  @override
  String get settingsAccountBandBbsAccount => 'BandBBS帳號';

  @override
  String get settingsAccountGitHub => 'GitHub帳號';

  @override
  String get settingsAccountGitHubDesc => '連線 GitHub，以你的身分發佈 AstroBox 資源';

  @override
  String get githubAccountNeedsBandBbs => '請先登入 BandBBS';

  @override
  String get bandBbsPublishAuthTitle => '發佈授權';

  @override
  String get bandBbsResourceQueryTitle => '安裝已購買的資源';

  @override
  String get settingsAboutLogs => '執行環境日誌';

  @override
  String get settingsAboutLogsDescription => '檢視、匯出並管理應用程式與已連線裝置的執行環境日誌';

  @override
  String settingsAboutLogsSize(Object size) {
    return '目前使用 $size';
  }

  @override
  String get settingsAboutLogsExport => '匯出';

  @override
  String settingsAboutLogsExported(Object path) {
    return '已匯出至 $path';
  }

  @override
  String get settingsAboutLogsEmpty => '沒有日誌檔案';

  @override
  String get settingsAboutLogsClear => '清除';

  @override
  String get settingsDeviceLogsPull => '取得裝置日誌';

  @override
  String get settingsDeviceLogsTip =>
      '此功能會從已連線的 Xiaomi 穿戴式裝置取得日誌，可能需要一段時間。處理期間請讓應用程式保持在前景，並保持裝置畫面亮起';

  @override
  String get settingsDeviceLogsStart => '開始';

  @override
  String get settingsDeviceLogsPulling => '正在取得裝置日誌';

  @override
  String get settingsDeviceLogsWaiting => '等待裝置回傳';

  @override
  String settingsDeviceLogsProgress(Object progress) {
    return '已接收 $progress%';
  }

  @override
  String settingsDeviceLogsSaved(Object name) {
    return '裝置日誌已儲存為 $name';
  }

  @override
  String settingsDeviceLogsFailed(Object error) {
    return '無法取得裝置日誌：$error';
  }

  @override
  String get settingsAboutLogsClearConfirm => '除了目前工作階段外，所有日誌檔案都將被刪除';

  @override
  String get settingsAboutLogsOpen => '開啟日誌資料夾';

  @override
  String get settingsAboutLogsOpenFailed => '無法開啟日誌資料夾';

  @override
  String get settingsLogsFileList => '日誌檔案';

  @override
  String get settingsAboutLogsWarningTitle => '敏感資訊警告';

  @override
  String get settingsAboutLogsWarningMessage =>
      '日誌可能包含 BandBBS、Xiaomi 或 Amazfit 登入憑證及其他敏感資訊。請勿與 OronBox 官方維護者以外的任何人分享！';

  @override
  String get pluginPermissionRequestTitle => '外掛程式權限請求';

  @override
  String pluginPermissionRequestMessage(Object plugin, Object operation) {
    return '「$plugin」想要$operation。';
  }

  @override
  String get pluginPermissionOnce => '僅允許一次';

  @override
  String get pluginPermissionSession => '允許本次執行';

  @override
  String get pluginPermissionAlways => '一律允許';

  @override
  String get pluginPermissionDeny => '拒絕';

  @override
  String get pluginPermissionOpenExternal => '開啟外部連結';

  @override
  String get pluginPermissionPickFile => '存取主機檔案';

  @override
  String get pluginPermissionExportFile => '將檔案匯出至主機';

  @override
  String get pluginPermissionNetwork => '存取網路';

  @override
  String get pluginPermissionInterconnect => '與裝置應用程式通訊';

  @override
  String get pluginPermissionProvider => '註冊資源提供者';

  @override
  String get pluginPermissionReadDevice => '讀取裝置資訊';

  @override
  String get pluginPermissionOperateDevice => '操作裝置';

  @override
  String get pluginPermissionObserveProtocol => '讀取原始裝置通訊協定資料';

  @override
  String get pluginPermissionSendProtocol => '向裝置傳送原始通訊協定資料';

  @override
  String get pluginPermissionReadAppSide => '讀取 AppSide 指令碼與事件';

  @override
  String get pluginPermissionOperateAppSide => '管理 AppSide 工作階段';

  @override
  String get pluginErrorTitle => '外掛程式已損壞';

  @override
  String pluginErrorMessage(Object plugin, Object error) {
    return '「$plugin」無法正常執行，可能已損壞。\n\n錯誤：$error\n\n是否解除安裝此外掛程式？';
  }

  @override
  String get pluginPackageCorruptedMessage => '無法讀取選取的外掛程式套件，可能已損壞。請重新取得後再匯入。';

  @override
  String get pluginErrorClearData => '清除插件資料';

  @override
  String get pluginErrorUninstall => '解除安裝外掛程式';

  @override
  String get pluginErrorSafeMode => '進入安全模式';

  @override
  String get pluginSafeModeTitle => '外掛程式安全模式已啟用';

  @override
  String get pluginSafeModeDescription => '所有外掛程式都已停止，停用安全模式後會重新載入';

  @override
  String get pluginSafeModeExit => '離開安全模式';

  @override
  String get devTools => '開發者工具';

  @override
  String get devToolsDescriptionDesktop => '在獨立視窗中開啟 DevTools';

  @override
  String get devToolsDescriptionEntry => '在應用程式列顯示 DevTools 入口按鈕';

  @override
  String get devToolsOperationFailed => '無法變更 DevTools 狀態';

  @override
  String get resourceTypeErrorTitle => '資源類型錯誤';

  @override
  String get resourceTypeUnknownTitle => '無法辨識的資源類型';

  @override
  String get resourceTypeUnknownNoType => 'OronBox 無法辨識此檔案的資源類型，此檔案似乎已損壞';

  @override
  String get resourceTypeUnknownCancel => '取消';

  @override
  String resourceTypeMismatchMessage(Object detectedType, Object selectedType) {
    return '此檔案看起來是 $detectedType 資源，但你選取了 $selectedType。請選擇安裝方式';
  }

  @override
  String resourcePlatformMismatchMessage(
    Object resourcePlatform,
    Object resourceType,
    Object deviceName,
    Object devicePlatform,
  ) {
    return '此檔案看起來是適用於 $resourcePlatform 裝置的 $resourceType 資源，但目前連線的裝置是 $deviceName（$devicePlatform）。不支援此資源，強制安裝可能造成問題';
  }

  @override
  String resourceTypeUnknownMessage(Object selectedType) {
    return 'OronBox 無法辨識實際的資源類型。仍要以 $selectedType 安裝嗎？';
  }

  @override
  String get resourceInstallCancel => '取消安裝';

  @override
  String get resourceInstallAcknowledge => '我明白';

  @override
  String get resourceInstallForce => '強制安裝';

  @override
  String resourceInstallForceCountdown(int seconds) {
    return '強制安裝（$seconds 秒）';
  }

  @override
  String resourceInstallAsSelected(Object type) {
    return '以$type繼續';
  }

  @override
  String resourceInstallAsSelectedCountdown(Object type, int seconds) {
    return '以$type繼續（$seconds 秒）';
  }

  @override
  String resourceInstallAsDetected(Object type) {
    return '以$type安裝';
  }

  @override
  String get resourceTypeApp => '小程式';

  @override
  String get resourceTypeQuickApp => '快應用';

  @override
  String get resourceTypeWatchface => '錶盤';

  @override
  String get resourceTypeFirmware => '韌體';

  @override
  String resourceInstallConfirmTitle(Object type) {
    return '安裝 $type';
  }

  @override
  String resourceInstallConfirmMessage(Object fileName, Object fileSize) {
    return '要安裝 $fileName（$fileSize）嗎？';
  }

  @override
  String get resourceInstallConfirm => '安裝';

  @override
  String get previewImages => '預覽圖片';

  @override
  String get add => '新增';

  @override
  String get submit => '提交';

  @override
  String get creatorConfirmTitle => '確認提交';

  @override
  String get creatorConfirmOronBox => '提交至 OronBox';

  @override
  String creatorConfirmBandBbs(Object category) {
    return '同步至 BandBBS：$category';
  }

  @override
  String creatorConfirmAstroBox(Object owner, Object repository) {
    return '同步至 AstroBox：$owner/$repository';
  }

  @override
  String get creatorBandBbsDirectPublish => '同步至 BandBBS';

  @override
  String get creatorBandBbsBoundUpdate => '已繫結 · 同步至 BandBBS';

  @override
  String get creatorBandBbsVersionTitle => '版本標題';

  @override
  String get creatorBandBbsVersionMessage => '更新說明';

  @override
  String get creatorBandBbsVersionPairRequired => '版本標題和更新說明需要同時填寫，或同時留白';

  @override
  String creatorLinkedSections(int count) {
    return '已繫結 $count 個分區';
  }

  @override
  String creatorBandBbsBindingIds(Object categoryId, Object resourceId) {
    return '分區 $categoryId · 資源 $resourceId';
  }

  @override
  String get creatorAstroBoxBoundSync => '已繫結 · 同步至 AstroBox';

  @override
  String get creatorThisCommit => '此次提交';

  @override
  String creatorAstroBoxPrPublish(Object repository) {
    return '同步至 AstroBox · $repository';
  }

  @override
  String get creatorOronBoxRequired => '必填。資源會由 OronBox 審核';

  @override
  String get creatorOpenInOronBox => '在 OronBox 中查看';

  @override
  String get creatorAstroTagsHint => '請使用英文分號 ; 分隔標籤';

  @override
  String get retry => '重試';

  @override
  String get reviewNote => '審核備註';

  @override
  String get creatorReviewRejected => '資源變更已被退回';

  @override
  String creatorReviewState(Object state) {
    return '審核狀態：$state';
  }

  @override
  String get creatorOperationWorking => '處理中';

  @override
  String get creatorProcessingImage => '正在處理圖片';

  @override
  String get creatorOperationRefreshing => '正在重新整理創作者資料';

  @override
  String get creatorOperationCreating => '正在建立資源';

  @override
  String get creatorOperationCreatingCollection => '正在建立合集';

  @override
  String get creatorOperationSaving => '正在儲存變更';

  @override
  String get creatorOperationDeleting => '正在刪除';

  @override
  String get creatorOperationSubmitting => '正在提交審核';

  @override
  String get creatorOperationAuthorizing => '等待授權';

  @override
  String get creatorResolvingPublicationTarget => '正在解析發佈分類';

  @override
  String get creatorStateApproved => '已通過';

  @override
  String get creatorStateExternalReview => '外部審核中';

  @override
  String get creatorStateFailed => '發佈失敗';

  @override
  String get creatorStateSuperseded => '已由較新的修訂取代';

  @override
  String get creatorStateCancelled => '已取消';

  @override
  String get creatorNoResources => '尚未建立資源';

  @override
  String get creatorLoginRequiredTitle => '登入以使用創作者中心';

  @override
  String get creatorLoginRequiredDescription =>
      '請登入 BandBBS 並連線 OronBox 帳號，才能建立、編輯或提交資源';

  @override
  String get creatorLoginAction => '登入 BandBBS';

  @override
  String get creatorBandBbsWriteReady => 'BandBBS 發佈已授權';

  @override
  String get creatorBandBbsWriteMissing => 'BandBBS 發佈尚未授權';

  @override
  String get creatorGitHubOwnPublishReady => 'GitHub 已連線';

  @override
  String get creatorGitHubOwnPublishMissing => 'GitHub 尚未連線';

  @override
  String get creatorAuthorize => '授權';

  @override
  String get installQueueFixWatchfaceId => '修正錶盤 ID';

  @override
  String get installQueueFixWatchfaceIdHint => '輸入 12 位以內的數字';

  @override
  String get authorize => '授權';

  @override
  String get creatorBandBbsAuthorized => 'BandBBS 資源發佈已授權';

  @override
  String get creatorBandBbsAuthorizationRequired =>
      '請另外授權 OronBox 代表你發佈 BandBBS 資源';

  @override
  String get connect => '連線';

  @override
  String get legalAndPrivacy => '法律與隱私';

  @override
  String get termsTitle => '條款與免責聲明';

  @override
  String get privacyTitle => '隱私權聲明';

  @override
  String get resourcePublishingTitle => '資源發布協議';

  @override
  String get reviewRulesTitle => '資源審核規則';

  @override
  String get joinQqGroup => '加入 QQ 群';

  @override
  String get joinQqGroupDesc => '與開發者及其他使用者交流並取得協助';

  @override
  String get feedbackTitle => '回饋';

  @override
  String get feedbackDesc => '提交回饋並查看回覆';

  @override
  String get reportResource => '檢舉資源';

  @override
  String get reportComment => '檢舉留言';

  @override
  String get report => '檢舉';

  @override
  String get feedbackSubject => '主旨';

  @override
  String get feedbackMessage => '回饋或問題';

  @override
  String get reportReason => '檢舉原因';

  @override
  String get noFeedback => '尚無回饋';

  @override
  String get feedbackProcessing => '處理中';

  @override
  String get feedbackReplied => '已回覆';

  @override
  String get feedbackOpen => '開啟';

  @override
  String get feedbackResolved => '已解決';

  @override
  String get feedbackDismissed => '已忽略';

  @override
  String get feedbackClosed => '關閉d';

  @override
  String get feedbackLoading => '正在載入工單';

  @override
  String get feedbackNewTicket => '新增工單';

  @override
  String get feedbackYou => '你';

  @override
  String get feedbackResolution => '處理結果';

  @override
  String get feedbackReplyHint => '回覆此工單';

  @override
  String get feedbackConversationClosed => '此工單已關閉，無法回覆';

  @override
  String get checkUpdates => '檢查更新';

  @override
  String get updateChecking => '正在檢查更新…';

  @override
  String get updateCheckFailed => '無法檢查更新';

  @override
  String get latestVersionInstalled => '目前已是最新版本';

  @override
  String newVersionAvailable(Object version) {
    return '有新版本 $version 可用';
  }

  @override
  String get oobeWelcomeSlogan =>
      '一款美觀快速的 VelaOS／ZeppOS 穿戴式裝置管理工具，以 Flutter 打造';

  @override
  String get oobeNext => '下一步';

  @override
  String get oobeBack => '返回';

  @override
  String get oobeFeatureDevicesTitle => '裝置連線';

  @override
  String get oobeFeatureDevicesBody => '連線並管理 VelaOS 與 ZeppOS 穿戴式裝置';

  @override
  String get oobeFeatureResourcesTitle => '資源中心';

  @override
  String get oobeFeatureResourcesBody =>
      '支援官方 OronBox 來源、AstroBox-Repo、BandBBS 與 Amazfit 應用程式商店';

  @override
  String get oobeFeaturePluginsTitle => 'JavaScript 外掛程式';

  @override
  String get oobeFeaturePluginsBody => '高效能且高度可擴充的 JavaScript 外掛程式系統，支援裝置互動';

  @override
  String get oobeFeaturePlatformsTitle => '多平台';

  @override
  String get oobeFeaturePlatformsBody =>
      '可在 Android、Windows、macOS、Linux 與 Web 上使用';

  @override
  String get oobeOpenSourceTitle => '完全開放原始碼';

  @override
  String get oobeOpenSourceBody => 'OronBox 用戶端與伺服器均採用 GNU AGPL-3.0，完整原始碼公開';

  @override
  String get oobeAgreementHint => '請閱讀並捲動至底部';

  @override
  String get oobeAgreeCheckbox => '我已閱讀並同意';

  @override
  String get oobeDeclineExit => '離開';

  @override
  String get oobeDeclineWebHint => '你必須接受協議才能繼續；請關閉此頁面';

  @override
  String get oobeLoginTitle => '連線你的帳號';

  @override
  String get oobeLoginBandBbsDesc => '登入 BandBBS 帳號以存取 BandBBS 資源並準備創作者服務';

  @override
  String get oobeLoginLocalNote =>
      'Xiaomi 與 Amazfit 登入完全在此裝置上進行；除 Xiaomi／Amazfit 外，相關資料不會傳送給任何第三方';

  @override
  String get oobeLoginXiaomiDesc => '登入 Xiaomi 帳號以同步已繫結的 Xiaomi 裝置';

  @override
  String get oobeLoginHuamiDesc => '登入 Amazfit 帳號以存取 Amazfit 應用程式商店資源';

  @override
  String get oobeCdnTesting => '測試中…';

  @override
  String get oobeCdnSelected => '已選取最快 CDN';

  @override
  String get oobeCdnTitle => 'GitHub CDN 速度測試';

  @override
  String get oobeDoneTitle => '設定完成';

  @override
  String get oobeDoneBody => '開始探索 OronBox';

  @override
  String get oobeFinish => '完成';

  @override
  String get settingsReplayOobe => '重新開始導覽';

  @override
  String get settingsReplayOobeDesc => '再次查看歡迎導覽與初始設定';

  @override
  String get creatorConnect => '連線';

  @override
  String get comments => '留言';

  @override
  String get commentEmpty => '目前沒有留言';

  @override
  String get commentHint => '撰寫留言';

  @override
  String get commentLoginRequired => '登入 BandBBS 後才能留言';

  @override
  String get commentPending => '審核中';

  @override
  String get commentBlocked => '此留言不符合社群規範';

  @override
  String get commentModerationUnavailable => '留言審核暫時無法使用';

  @override
  String get commentRateLimited => '留言速度過快';

  @override
  String get commentReplying => '回覆留言';

  @override
  String get loadMore => '載入更多';

  @override
  String get more => '更多';

  @override
  String get reply => '回覆';

  @override
  String get inbox => '收件匣';

  @override
  String get inboxLoading => '正在載入訊息';

  @override
  String get inboxEmpty => '沒有訊息';

  @override
  String get inboxClear => '清除訊息';

  @override
  String get inboxClearFailed => '無法清除訊息，請稍後再試';

  @override
  String get cleanMode => '功能開關';

  @override
  String get cleanModeDescription => '管理主要導覽、社群功能與資源來源';

  @override
  String get cleanPluginsEntry => '外掛程式入口';

  @override
  String get cleanSourceHuamiAppStore => 'Amazfit 應用程式商店';

  @override
  String get announcementAcknowledge => '知道了';

  @override
  String get cleanHomeFeed => '首頁動態';

  @override
  String get cleanExplore => '資源庫';

  @override
  String get cleanInbox => '收件匣';

  @override
  String get cleanAnnouncements => '公告彈窗';

  @override
  String get cleanComments => '留言';

  @override
  String get cleanCreator => '創作者中心';

  @override
  String get cleanBandBbsLogin => 'BandBBS 登入';

  @override
  String get cleanGitHubLogin => 'GitHub 登入';

  @override
  String get cleanSourceOronBox => 'OronBox 來源';

  @override
  String get cleanSourceBandBbs => 'BandBBS 來源';

  @override
  String get cleanSourceAstroBox => 'AstroBox 來源';

  @override
  String get cleanExploreEntry => '探索入口';

  @override
  String get cleanNavigationGroup => '主要導覽';

  @override
  String get cleanExploreContentGroup => '探索內容';

  @override
  String get cleanHomeSectionsGroup => '首頁區塊';

  @override
  String get cleanHomeBanner => '橫幅輪播';

  @override
  String get cleanHomeEditorSections => '編輯推薦區塊';

  @override
  String get cleanResourceSourcesGroup => '資源來源';

  @override
  String get cleanCommunityGroup => '社群功能';

  @override
  String get settingsCategoryAccounts => '帳戶與授權';

  @override
  String get settingsCategoryAppearance => '外觀與導覽';

  @override
  String get settingsCategoryConnection => '連線與下載';

  @override
  String get settingsCategorySupport => '支援與資訊';

  @override
  String get settingsCategoryAdvanced => '進階設定';

  @override
  String get settingsAdvancedDescription => '檢視日誌與開發者工具';

  @override
  String get debugServerTitle => '除錯服務';

  @override
  String get debugServerDescription => '為可信任的開發工具提供本機 API';

  @override
  String get debugServerEnable => '啟用除錯服務';

  @override
  String get debugServerEnableDescription => '允許區域網路中已核准的用戶端檢視及控制 OronBox';

  @override
  String get debugServerEndpoint => '連線位址';

  @override
  String get debugServerFingerprint => '服務指紋';

  @override
  String get debugServerPendingClients => '待核准用戶端';

  @override
  String get debugServerAuthorizedClients => '已核准用戶端';

  @override
  String get debugServerApprove => '核准';

  @override
  String get debugServerReject => '拒絕';

  @override
  String get debugServerRevoke => '撤銷存取權';

  @override
  String get debugServerNoPendingClients => '沒有等待核准的用戶端';

  @override
  String get debugServerNoAuthorizedClients => '目前沒有已核准的用戶端';

  @override
  String get debugServerSecurityNotice => '請只在可信任的網路中啟用此服務';

  @override
  String get debugServerStartFailed => '無法啟動除錯服務';

  @override
  String get debugServerStopFailed => '無法停止除錯服務';

  @override
  String get xmsDeveloperMode => 'XMS 開發者模式';

  @override
  String get xmsDeveloperModeDescription => '允許 Android 應用程式簽章差異';

  @override
  String get oronBoxCoinsTitle => '資源硬幣';

  @override
  String oronBoxCoinsBalance(String balance) {
    return '硬幣餘額：$balance';
  }

  @override
  String get oronBoxCoinsCheckin => '簽到';

  @override
  String get oronBoxCoinsCheckedIn => '已簽到';

  @override
  String oronBoxCoinsCheckinReward(int count) {
    return '已獲得 $count 枚硬幣';
  }

  @override
  String get oronBoxCoinsDescription => '每日簽到可獲得 1–5 枚硬幣，用來支持創作者';

  @override
  String resourceFromCollection(String name) {
    return '來自合集 $name';
  }

  @override
  String get resourceCoin => '投幣';

  @override
  String get resourceCoinNotSignedIn => '尚未登入';

  @override
  String get resourceCoinDialogTitle => '為此資源投幣';

  @override
  String get resourceCoinDialogMessage =>
      '要為此資源投幣嗎？\n此操作無法復原\n\n投幣可以增加資源曝光\n創作者將獲得所投硬幣的 10%\n前往「設定－BandBBS 帳號」簽到即可獲得硬幣';

  @override
  String get resourceCoinOne => '投 1 枚硬幣';

  @override
  String get resourceCoinTwo => '投 2 枚硬幣';

  @override
  String resourceCoinCount(int count) {
    return '$count 枚硬幣';
  }

  @override
  String get resourceCoinSuccess => '投幣成功';

  @override
  String get resourceCoinVoted => '已投幣';

  @override
  String get resourceFeatured => '精選';

  @override
  String get resourceCollection => '合集';

  @override
  String resourceCollectionType(String type) {
    return '$type合集';
  }

  @override
  String get creatorCollections => '資源合集';

  @override
  String get creatorCollectionTag => '合集';

  @override
  String get creatorNewCollection => '新增合集';

  @override
  String get creatorMoveToCollection => '移至合集';

  @override
  String creatorMoveToCollectionConfirm(int count) {
    return '要將選取的 $count 項資源移至此合集嗎？';
  }

  @override
  String get creatorDissolveCollection => '解散合集';

  @override
  String get creatorResourceList => '資源';

  @override
  String get creatorAdditionalLinks => '其他連結';

  @override
  String get creatorAddLink => '新增連結';

  @override
  String get creatorLinkTitle => '連結名稱';

  @override
  String get creatorLinkUrl => '連結 URL';

  @override
  String get creatorCollectionName => '合集名稱';

  @override
  String get creatorCollectionSummary => '合集簡介';

  @override
  String get creatorCollectionRepresentative => '代表資源';

  @override
  String get creatorCollectionDeleteConfirm => '要刪除此合集嗎？其中的資源只會解除繫結';

  @override
  String get creatorContentAttributes => '內容屬性';

  @override
  String get creatorConfirm => '確認';

  @override
  String get creatorCollectionAddResource => '加入合集';

  @override
  String creatorCollectionResourceCount(int count) {
    return '$count 項資源';
  }

  @override
  String communityImportSelected(int count) {
    return '已選取 $count 項';
  }

  @override
  String get communityImportResultCreated => '已建立草稿';

  @override
  String get communityImportResultFailed => '失敗';

  @override
  String get communityImportUnsupported => '目前尚未支援匯入此類型';

  @override
  String get communityImportDuplicate => '創作者中心中已存在此資源';

  @override
  String get communityImportNoArtifacts => '沒有可匯入的資源檔案';

  @override
  String get creatorImportExternal => '從其他平台匯入現有資源';

  @override
  String get creatorNewResourceDescription => '從 OronBox 建立並維護資源';

  @override
  String get creatorNewCollectionDescription => '建立合集以整理相關資源';

  @override
  String get creatorImportExternalDescription =>
      '實驗功能：從 BandBBS 或 AstroBox-Repo 匯入現有資源';

  @override
  String get creatorImportAlreadyImported => '已匯入並繫結';

  @override
  String get creatorImportReviewNotice => '匯入內容可能不完整或辨識錯誤。提交前請逐一檢查並調整所有欄位';

  @override
  String get creatorImportLogTitle => '處理日誌';

  @override
  String get communityImportPickerEmpty => '沒有資源';

  @override
  String get creatorWizardChooseAction => '建立';

  @override
  String get creatorImportSelectTitle => '選擇資源';

  @override
  String get creatorImportProgressTitle => '正在匯入';

  @override
  String get creatorImportResultTitle => '匯入結果';

  @override
  String get creatorImportGitHubHint => '連線 GitHub 以列出你的 AstroBox 資源';

  @override
  String get creatorImportGitHubConnect => '連線 GitHub';

  @override
  String get creatorImportStageDetails => '正在取得詳細資料';

  @override
  String get creatorImportStageDownloading => '正在下載檔案';

  @override
  String get creatorImportStageMedia => '正在處理圖片';

  @override
  String get creatorImportStageUploading => '正在建立草稿';

  @override
  String get creatorImportContinue => '匯入其他資源';

  @override
  String get creatorImportPartialFailureTitle => '部分資源讀取失敗';

  @override
  String creatorImportPartialFailureMessage(int count) {
    return '$count 項資源讀取失敗\n你可以重試失敗項目，或繼續匯入已成功讀取的資源';
  }

  @override
  String get creatorImportRetryFailed => '重試失敗項目';

  @override
  String get creatorImportContinuePartial => '仍然繼續';

  @override
  String creatorImportWarnings(int count) {
    return '$count 個警告';
  }

  @override
  String get creatorDeleteExternalBandbbs => '同時刪除 BandBBS 資源';

  @override
  String get creatorDeleteExternalAstrobox => '同時向 AstroBox-Repo 提交刪除 PR';

  @override
  String get creatorDeleteExternalWarning => '外部刪除無法復原';

  @override
  String get creatorDeletePrSubmitted => '已提交刪除 PR';

  @override
  String githubCdnFallback(Object cdn) {
    return 'GitHub 請求失敗，正在透過 $cdn 重試';
  }

  @override
  String get deviceConnectBle => '透過 BLE 連線';

  @override
  String get deviceConnectBtClassic => '透過 Bluetooth Classic 連線';

  @override
  String bandBbsIdLabel(Object id) {
    return 'BandBBS ID $id';
  }

  @override
  String get oobeCdnTestFailed => '失敗';

  @override
  String get settingsGithubCdnAuto => '自動';

  @override
  String get updateDownloading => '正在下載更新';

  @override
  String get updateInstalling => '正在安裝更新';

  @override
  String get updateFailed => '更新失敗';

  @override
  String updateNoApkForAbi(String abi) {
    return '沒有適用於 ABI $abi 的 APK';
  }

  @override
  String get cleanUpdateGroup => '更新';

  @override
  String get cleanCheckUpdates => '啟動時檢查更新';

  @override
  String get updateLater => '稍後';

  @override
  String get updateNow => '立即更新';

  @override
  String get updateGoToPage => '前往下載頁面';

  @override
  String get updateDownloadFromCloud => '從網盤下載';

  @override
  String get updateDownloadFromOfficial => '從官方網站下載';

  @override
  String get creatorImportNoticeTitle => '匯入現有資源';

  @override
  String get creatorImportNoticeMessage =>
      '支援多部裝置的資源可能已發佈至 BandBBS 的多個分區\n匯入時可以選取多個 BandBBS 項目，但請只選擇同一項資源\n點擊「匯入」會將選取的項目合併為一項資源\n如果匯入失敗，可以開啟對應草稿並刪除\n刪除草稿不會刪除其他平台上已繫結的資源';

  @override
  String get creatorImportNoticeConfirm => '繼續匯入';

  @override
  String get creatorImportSameResourceHint => '每次匯入請只選擇同一項資源';

  @override
  String get creatorFullVersionExternalPurchase => '需要外部購買';

  @override
  String get creatorExternalPurchaseDescription =>
      '在 OronBox 和 AstroBox 將會發布資源檔案作為試用版並顯示購買按鈕，在 BandBBS 發布為「第三方購買」資源，您需自行處理付款相關事務';

  @override
  String get creatorExternalPurchaseLink => '購買連結';

  @override
  String get creatorExternalPurchaseAmount => '金額（CNY）';

  @override
  String get creatorExternalPurchaseLinkRequired => '請輸入有效的外部購買連結';

  @override
  String get creatorExternalPurchaseAmountRequired => '請輸入有效的 CNY 金額';

  @override
  String get resourcePurchaseFullVersion => '外部購買';

  @override
  String get creatorBandBbsOverwritePrevious => '覆蓋上次提交';

  @override
  String get creatorBandBbsOverwritePreviousDescription => '建立新版本後刪除米壇上一次提交的版本';

  @override
  String get deviceHealthDayView => '日';

  @override
  String get deviceHealthWeekView => '週';

  @override
  String get deviceHealthMonthView => '月';

  @override
  String get deviceHealthSleepStages => '睡眠階段';

  @override
  String get deviceHealthSleepHrv => '睡眠 HRV';

  @override
  String get deviceHealthSleepAwake => '清醒';

  @override
  String get deviceHealthSleepLight => '淺睡';

  @override
  String get deviceHealthSleepDeep => '深睡';

  @override
  String get deviceHealthSleepRem => 'REM';

  @override
  String get deviceHealthSleepNoStages => '暫無睡眠階段資料';

  @override
  String get weatherAutoSyncTitle => '自動同步天氣資料';

  @override
  String get weatherAutoSyncDescription => '同步裝置資料時自動同步天氣資料';

  @override
  String get weatherAqiGood => '優';

  @override
  String get weatherAqiModerate => '良';

  @override
  String get weatherAqiSensitive => '對敏感族群不健康';

  @override
  String get weatherAqiUnhealthy => '不健康';

  @override
  String get weatherAqiVeryUnhealthy => '非常不健康';

  @override
  String get weatherAqiHazardous => '危險';

  @override
  String weatherDataSource(Object source) {
    return '資料來源：$source';
  }

  @override
  String get xiaomiScreenshotTitle => '裝置截圖';

  @override
  String get xiaomiScreenshotDescription => '在裝置上使用組合鍵截圖，截圖會自動同步到這裡';

  @override
  String get xiaomiScreenshotAction => '取得截圖';

  @override
  String get xiaomiScreenshotLoading => '取得中…';

  @override
  String get xiaomiScreenshotEmpty => '尚無截圖';

  @override
  String get xiaomiScreenshotFailed => '取得截圖失敗';

  @override
  String xiaomiScreenshotSaved(Object path) {
    return '手錶截圖已儲存至：$path';
  }
}
