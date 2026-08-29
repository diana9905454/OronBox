// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get homeTab => 'Главная';

  @override
  String get exploreTab => 'Обзор';

  @override
  String get devicesTab => 'Устройства';

  @override
  String get pluginsTab => 'Плагины';

  @override
  String get pluginImport => 'Импортировать плагин';

  @override
  String get pluginInstalled => 'Установленные';

  @override
  String get pluginMarket => 'Магазин плагинов';

  @override
  String get pluginMarketUnavailable => 'Магазин плагинов пока недоступен';

  @override
  String get pluginEmpty => 'Нет установленных плагинов';

  @override
  String get pluginSelectHint => 'Выберите плагин, чтобы увидеть его функции';

  @override
  String get pluginFeatures => 'Функции';

  @override
  String get pluginDetails => 'Подробности';

  @override
  String get pluginNoFeatures => 'Нет доступных функций';

  @override
  String get pluginAuthor => 'Автор';

  @override
  String get pluginVersion => 'Версия';

  @override
  String get pluginApiLevel => 'Уровень API';

  @override
  String get pluginWebsite => 'Веб-сайт';

  @override
  String get pluginPermissions => 'Разрешения';

  @override
  String get pluginInstallConfirmTitle => 'Подтвердите установку плагина';

  @override
  String get pluginUpdateConfirmTitle => 'Подтвердите обновление плагина';

  @override
  String get pluginDeclaredPermissions =>
      'Плагин запрашивает следующие разрешения:';

  @override
  String get pluginNoPermissions => 'Разрешения не заявлены';

  @override
  String get pluginUpToDate => 'Установлена последняя версия';

  @override
  String get pluginUninstallTitle => 'Удалить плагин';

  @override
  String get pluginUninstallMessage => 'Данные плагина также будут удалены';

  @override
  String get pluginUpload => 'Загрузить плагин';

  @override
  String get pluginPublishTitle => 'Опубликовать плагин';

  @override
  String get pluginPublishNew => 'Опубликовать как новый плагин';

  @override
  String get pluginPublishUpdate =>
      'Обновить опубликованный плагин с тем же ID';

  @override
  String get pluginTakedown => 'Снять с публикации';

  @override
  String get pluginTakedownConfirm =>
      'Плагин будет навсегда удалён из магазина';

  @override
  String get pluginLoginRequired => 'Войдите, чтобы загружать плагины';

  @override
  String get pluginSubmittedForReview =>
      'Отправлено на проверку. После одобрения плагин появится в списке';

  @override
  String get pluginStatePending => 'На проверке';

  @override
  String get pluginStateRejected => 'Отклонён';

  @override
  String get pluginStateDelisted => 'Снят с публикации';

  @override
  String get pluginLegacyWarningTitle => 'Устаревший плагин';

  @override
  String get pluginLegacyWarningMessage =>
      'Это плагин AstroBox v1. OronBox попробует запустить его в режиме совместимости, но возможны ошибки.\\nПроверьте наличие нативного плагина OronBox или попросите автора адаптировать плагин';

  @override
  String get settingsTab => 'Настройки';

  @override
  String get search => 'Поиск';

  @override
  String get resourceListView => 'Список';

  @override
  String get resourceGridView => 'Карточки';

  @override
  String get refresh => 'Обновить';

  @override
  String get refreshing => 'Обновление';

  @override
  String get notifications => 'Уведомления';

  @override
  String get newlyPublished => 'Новые публикации';

  @override
  String get resourceLibrary => 'Библиотека ресурсов';

  @override
  String get resourceDetails => 'Сведения о ресурсе';

  @override
  String get resourceCollectionDetails => 'Сведения о коллекции';

  @override
  String get resourceArticleDetails => 'Сведения о статье';

  @override
  String get creatorCenter => 'Центр автора';

  @override
  String get creatorNewResource => 'Новый ресурс';

  @override
  String get creatorResourceName => 'Название ресурса';

  @override
  String get creatorResourceSummary => 'Описание ресурса';

  @override
  String get creatorResourceMetadataRequired =>
      'Название и описание ресурса обязательны';

  @override
  String get creatorSubmitValidationFailed =>
      'Перед отправкой исправьте следующие пункты';

  @override
  String get creatorPaidType => 'Тип оплаты';

  @override
  String get creatorSaveDraft => 'Сохранить черновик';

  @override
  String get creatorAddArtifact => 'Добавить файл ресурса';

  @override
  String get creatorBindDevices => 'Привязать устройства';

  @override
  String get creatorDeleteResource => 'Удалить';

  @override
  String get creatorIconCover => 'Иконка и обложка';

  @override
  String get creatorInvalidImage =>
      'Не удалось прочитать изображение. Используйте PNG/JPEG/WebP';

  @override
  String get creatorInvalidPackage =>
      'Это не быстрое приложение Vela и не циферблат';

  @override
  String creatorPublishPreparing(Object done, Object total) {
    return 'Обработка файла $done/$total';
  }

  @override
  String creatorPublishUploading(Object percent) {
    return 'Загрузка $percent%';
  }

  @override
  String get creatorPublishServer => 'Обработка на сервере…';

  @override
  String get creatorAstroBoxItemId => 'ID элемента';

  @override
  String get creatorAstroBoxRepository => 'Название репозитория';

  @override
  String get creatorAstroBoxTags => 'Теги (через запятую)';

  @override
  String get creatorAstroBoxAuthor =>
      'Автор (должен совпадать с именем пользователя AstroBox)';

  @override
  String get creatorAstroBoxBindAccount => 'Подключить аккаунт AstroBox';

  @override
  String get replace => 'Заменить';

  @override
  String get delete => 'Удалить';

  @override
  String get creatorSubmitReview => 'Отправить';

  @override
  String get creatorArchiveAction => 'Снять с публикации';

  @override
  String get creatorArchiveConfirm =>
      'Снятие с публикации скрывает ресурс в магазине. Его можно восстановить в любое время';

  @override
  String get creatorRestoreAction => 'Опубликовать снова';

  @override
  String get creatorDeleteConfirm =>
      'Этот черновик ресурса будет удалён навсегда';

  @override
  String get creatorDeletePublishedConfirm =>
      'Ресурс OronBox и связанные ресурсы BandBBS будут удалены навсегда. Отменить это действие нельзя. Опубликованный в AstroBox контент не изменится; для его снятия обратитесь к сопровождающим AstroBox-Repo';

  @override
  String creatorArtifactCount(Object count) {
    return 'Пакетов: $count';
  }

  @override
  String creatorKindMismatchMessage(Object detected, Object expected) {
    return 'Файл похож на ресурс типа $detected, но выбран тип $expected. Его можно оставить, однако перед отправкой на проверку подтвердите выбор';
  }

  @override
  String creatorDeviceMoveBlocked(Object name) {
    return 'Для «$name» привязано только это устройство, поэтому перемещение невозможно';
  }

  @override
  String get creatorSelectDevices => 'Выберите поддерживаемые устройства';

  @override
  String creatorSelectedDeviceCount(Object count) {
    return 'Выбрано устройств: $count';
  }

  @override
  String get creatorNoDevicesSelected => 'Устройства не выбраны';

  @override
  String get creatorDeviceSelectionDone => 'Готово';

  @override
  String get creatorAtLeastOneDevice =>
      'Для каждого файла ресурса нужно выбрать хотя бы одно устройство';

  @override
  String get resourceAstroBoxEncryptedTitle =>
      'OronBox не может обработать этот ресурс AstroBox';

  @override
  String get resourceAstroBoxEncryptedMessage =>
      'Этот ресурс использует закрытую зашифрованную загрузку AstroBox Creator Console. OronBox не может расшифровать, скачать или установить его. Откройте его в AstroBox';

  @override
  String get resourceAstroBoxEncryptedAction => 'Понятно';

  @override
  String get filter => 'Фильтр';

  @override
  String get resourceTypeFilter => 'Тип ресурса';

  @override
  String get resourceCompatibleDevicesFilter => 'Совместимые устройства';

  @override
  String get currentDevice => 'Текущее устройство';

  @override
  String get currentWatchface => 'Текущий циферблат';

  @override
  String get all => 'Все';

  @override
  String get watchfaces => 'Циферблаты';

  @override
  String get module => 'Модуль';

  @override
  String get quickApps => 'Быстрые приложения';

  @override
  String get firmwareTools => 'Прошивка / инструменты';

  @override
  String get oronBox => 'OronBox';

  @override
  String get bandbbs => 'BandBBS';

  @override
  String get astroBox => 'AstroBox';

  @override
  String get local => 'Локальные';

  @override
  String get install => 'Установить';

  @override
  String get update => 'Обновить';

  @override
  String get description => 'Описание';

  @override
  String get supportedDevices => 'Поддерживаемые устройства';

  @override
  String get downloads => 'Загрузки';

  @override
  String downloadTimes(int count) {
    return 'Загрузок: $count';
  }

  @override
  String get changelog => 'Список изменений';

  @override
  String get changelogUnavailable => 'Список изменений пока отсутствует';

  @override
  String get notFound => 'Не найдено';

  @override
  String get downloadStarted => 'Загрузка начата';

  @override
  String get compatible => 'Совместимо с';

  @override
  String get incompatible => 'Несовместимо с';

  @override
  String get incompatibleSuffix => '';

  @override
  String get myResources => 'Мои ресурсы';

  @override
  String get drafts => 'Черновики';

  @override
  String get pendingReview => 'На проверке';

  @override
  String get published => 'Опубликовано';

  @override
  String get creatorStateSuspended => 'Снято с публикации';

  @override
  String get creatorStateFrozen => 'Заморожено';

  @override
  String get creatorSuspendedByOwnerNotice =>
      'Ресурс снят с публикации. Продолжите редактирование и отправьте его на проверку или восстановите напрямую';

  @override
  String get creatorSuspendedByAdminNotice =>
      'Администратор снял ресурс с публикации. Отредактируйте его и отправьте на проверку; после одобрения публикация восстановится';

  @override
  String get creatorFrozenNotice =>
      'Администратор заморозил ресурс. Редактирование запрещено, снять заморозку может только администратор';

  @override
  String creatorModerationReason(Object reason) {
    return 'Причина: $reason';
  }

  @override
  String get creatorBannedTitle => 'Аккаунт заблокирован';

  @override
  String get creatorBannedDescription =>
      'Администратор заблокировал ваш аккаунт, поэтому центр автора недоступен. Если это ошибка, обратитесь в поддержку';

  @override
  String get creatorFrozenTitle => 'Возможности автора заморожены';

  @override
  String get creatorFrozenDescription =>
      'Администратор заморозил возможности автора, поэтому сейчас нельзя отправлять и управлять ресурсами. Остальные функции аккаунта не затронуты';

  @override
  String get creatorBandBbsNoDevices =>
      'Сначала выберите поддерживаемые устройства для файла ресурса';

  @override
  String creatorBandBbsUnmappedDevices(Object devices) {
    return 'Не удалось определить категорию BandBBS для: $devices';
  }

  @override
  String get creatorBandBbsSharedCategory =>
      'Устройства одной категории BandBBS привязаны к нескольким пакетам. Привяжите к каждой категории один пакет';

  @override
  String get creatorBandBbsUnresolved =>
      'Не удалось определить категорию BandBBS';

  @override
  String get creatorOptionalIcon => 'Иконка (необязательно, 1:1)';

  @override
  String get creatorOptionalCover => 'Обложка (необязательно, 3:2)';

  @override
  String get creatorRequiredIcon => 'Иконка (обязательна для AstroBox, 1:1)';

  @override
  String get creatorRequiredCover => 'Обложка (обязательна для AstroBox, 3:2)';

  @override
  String get creatorIconShapeHint =>
      'Иконка не квадратная и может выглядеть неправильно в AstroBox';

  @override
  String get creatorCoverShapeHint =>
      'Обложка не имеет соотношение 3:2 и может выглядеть неправильно в AstroBox';

  @override
  String get creatorTermsBandBbs => 'Условия и правила сообщества BandBBS';

  @override
  String get creatorTermsAstroBox => 'Правила отправки в AstroBox-Repo';

  @override
  String get creatorTermsAccept =>
      'Я прочитал и принимаю указанные соглашения о публикации';

  @override
  String get creatorTermsContinue => 'Перейти в центр автора';

  @override
  String get agree => 'Согласен';

  @override
  String get creatorRulesAccept =>
      'Я прочитал и принимаю указанные правила проверки';

  @override
  String get creatorBandBbsTermsNotice =>
      'После проверки OronBox ресурс будет опубликован непосредственно в соответствующих категориях BandBBS. Удаление ресурса OronBox также удалит связанные ресурсы BandBBS';

  @override
  String get creatorBandBbsLimitsNotice =>
      'Публикация в BandBBS одним нажатием имеет ограничения, которые нужно исправить вручную после публикации:\n1. BandBBS не предоставляет API для загрузки иконки ресурса, поэтому на BandBBS иконка будет пустой; обновите её вручную на сайте BandBBS\n2. BandBBS не предоставляет API для тегов раздела обсуждений, поэтому атрибуты раздела не будут установлены, и ресурс могут удалить; укажите правильный раздел вручную на сайте BandBBS';

  @override
  String get creatorAstroBoxTermsNotice =>
      'После проверки OronBox будет создан репозиторий ресурса и отправлен PR в официальный репозиторий AstroBox. PR независимо проверяют сопровождающие AstroBox. Чтобы снять опубликованный ресурс с публикации, обратитесь к сопровождающим AstroBox-Repo';

  @override
  String get creatorAstroBoxReviewNotice =>
      'Ресурсы, публикуемые в AstroBox, должны соответствовать требованиям проверки:\n1. Ресурс не должен содержать непристойных, политически чувствительных или иных незаконных материалов\n2. Качество ресурса не должно быть слишком низким: например, циферблатом, где просто заменён шаблон, или чрезмерно простым быстрым приложением\n3. Обложка должна быть привлекательной и эстетичной, с соотношением 3:2 (рекомендуется 1200×800); для иконки рекомендуется 192×192\n4. Ресурс должен корректно выполнять основные функции на поддерживаемых устройствах\n5. Запрещено загружать чужие ресурсы без разрешения\n6. При использовании известных IP-материалов в предпросмотре должно быть изображение с уведомлением об авторских правах (с указанием, что материалы не связаны с AstroBox и Xiaomi)';

  @override
  String get failed => 'Ошибка / требуется действие';

  @override
  String get basicInfo => 'Основная информация';

  @override
  String get packageFiles => 'Файлы ресурса';

  @override
  String get publishTargets => 'Цели публикации';

  @override
  String get scan => 'Сканировать';

  @override
  String get logs => 'Журналы';

  @override
  String get pairedDevices => 'Сопряжённые устройства';

  @override
  String get apps => 'Приложения';

  @override
  String get deviceAppCount => 'Количество приложений';

  @override
  String get deviceWatchfaceCount => 'Количество циферблатов';

  @override
  String get connection => 'Подключение';

  @override
  String get protocol => 'Протокол';

  @override
  String get error => 'Ошибка';

  @override
  String get errorBluetoothUnavailable =>
      'Bluetooth недоступен. Убедитесь, что он включён и OronBox разрешено его использовать';

  @override
  String get errorBluetoothConnectFailed =>
      'Не удалось подключиться по Bluetooth. Проверьте разрешение Bluetooth, держите устройство рядом и свободным, включите на нём «Подключить новый телефон» и повторите попытку';

  @override
  String get errorBluetoothDisconnected =>
      'Bluetooth отключён. Подключите устройство снова';

  @override
  String get errorOperationTimeout =>
      'Время операции истекло. Убедитесь, что устройство рядом, и повторите попытку';

  @override
  String get errorDeviceNotReady =>
      'Устройство не готово. Сначала подключите и авторизуйте его';

  @override
  String get errorBleCharacteristicsMissing =>
      'Не найдены необходимые характеристики BLE. Подключите устройство снова или проверьте поддержку этой функции';

  @override
  String get errorWebSerialUnavailable =>
      'Этот браузер не поддерживает Web Serial. Используйте Chrome, Edge или другой совместимый браузер';

  @override
  String get errorAccountPasswordIncorrect =>
      'Неверное имя пользователя или пароль аккаунта Xiaomi';

  @override
  String get errorAccountTwoFactorIncomplete =>
      'Двухфакторная проверка аккаунта Xiaomi не завершена. Войдите снова';

  @override
  String get errorOronBoxSessionExpired =>
      'Сеанс OronBox истёк. Войдите в BandBBS снова';

  @override
  String get errorNetworkUnavailable =>
      'Не удалось связаться с сервисом. Проверьте сеть и повторите попытку';

  @override
  String get errorServiceUnavailable =>
      'Сервис временно недоступен. Повторите попытку позже';

  @override
  String get errorPermissionDenied =>
      'У вас нет разрешения на выполнение этой операции';

  @override
  String get errorContentNotFound =>
      'Запрошенный материал больше не существует или недоступен';

  @override
  String get errorRequestConflict =>
      'Материал изменился. Обновите его и повторите попытку';

  @override
  String get errorCoinBalanceInsufficient => 'Недостаточно монет';

  @override
  String get errorCoinResourceLimit =>
      'Этому ресурсу можно отправить не более 2 монет';

  @override
  String get errorCoinOwnResource =>
      'Нельзя отправлять монеты собственному ресурсу';

  @override
  String get errorCoinVotingFrozen =>
      'Голосование монетами временно заморожено';

  @override
  String get errorCoinAccountTooNew =>
      'Для отправки монет аккаунту должно быть не менее 24 часов';

  @override
  String get errorCoinOperationFailed =>
      'Не удалось отправить монету. Повторите попытку';

  @override
  String get errorCoinStatusUnavailable =>
      'Состояние монет недоступно. Нажмите, чтобы повторить';

  @override
  String get errorOperationFailed => 'Операция не выполнена. Повторите попытку';

  @override
  String get errorUnknown => 'Что-то пошло не так. Повторите попытку';

  @override
  String get errorDownloadQuotaExceeded => 'Достигнут дневной лимит загрузок';

  @override
  String get errorGitHubNotConfigured => 'GitHub не настроен';

  @override
  String get errorRateLimited =>
      'Слишком много запросов. Подождите немного и повторите';

  @override
  String get errorFileTooLarge => 'Выбранный файл слишком большой';

  @override
  String get errorInvalidRequest =>
      'Некоторые отправленные данные недействительны. Проверьте их и повторите';

  @override
  String get errorOperationCancelled => 'Операция отменена';

  @override
  String get errorUnsupportedFileType =>
      'Неподдерживаемый или неизвестный тип файла';

  @override
  String get errorCertificateVerificationFailed =>
      'Проверка сертификата не пройдена. При использовании прокси отключите перехват HTTPS или убедитесь, что сертификат доверенный';

  @override
  String errorUnknownWithDetail(Object detail) {
    return 'Операция не выполнена: $detail';
  }

  @override
  String get appearance => 'Внешний вид';

  @override
  String get resources => 'Ресурсы';

  @override
  String get communitySourceAstroBoxRepo => 'AstroBox-Repo';

  @override
  String get communitySourceBandBbs => 'Сообщество BandBBS';

  @override
  String get communitySourceHuamiAppStore => 'Магазин приложений Amazfit';

  @override
  String get devices => 'Устройства';

  @override
  String creatorCompatibleDeviceCount(int count) {
    return 'Устройств: $count';
  }

  @override
  String get categories => 'Категории';

  @override
  String get advanced => 'Дополнительно';

  @override
  String get openSourceLicenses => 'Лицензии открытого кода';

  @override
  String get acknowledgements => 'Особые благодарности';

  @override
  String get deviceNotConnected => 'Не подключено';

  @override
  String get deviceConnected => 'Подключено';

  @override
  String get deviceDisconnected => 'Отключено';

  @override
  String get deviceReconnect => 'Переподключить';

  @override
  String get deviceConnect => 'Подключить';

  @override
  String get deviceSwitch => 'Переключить';

  @override
  String get deviceSyncTime => 'Синхронизировать';

  @override
  String get deviceCharging => 'Заряжается';

  @override
  String get deviceLastChargedNow => 'Заряжено только что';

  @override
  String deviceLastChargedMinutes(int count) {
    return 'Заряжено $count мин назад';
  }

  @override
  String deviceLastChargedHours(int count) {
    return 'Заряжено $count ч назад';
  }

  @override
  String deviceLastChargedDays(int count) {
    return 'Заряжено $count дн. назад';
  }

  @override
  String get deviceFeaturesInstallApp => 'Установить приложение';

  @override
  String get deviceFeaturesInstallWatchface => 'Установить циферблат';

  @override
  String get deviceFeaturesInstallFirmware => 'Обновить прошивку';

  @override
  String get deviceFeaturesInstallFirmwareDesc =>
      'Проверить обновления устройства или установить прошивку из файла';

  @override
  String get firmwareCheckingUpdates => 'Проверка обновлений прошивки';

  @override
  String get firmwareNoUpdatesFound =>
      'Новая прошивка для этого устройства не найдена';

  @override
  String get firmwareSourceUnavailable =>
      'Онлайн-источник прошивок для этого типа устройства пока недоступен';

  @override
  String get firmwareVersionUnknown => 'Текущая версия прошивки недоступна';

  @override
  String get firmwareCurrentVersion => 'Текущая версия';

  @override
  String get firmwareLatestRelease => 'Последняя прошивка';

  @override
  String get firmwareHistoricalReleases => 'Предыдущие версии прошивки';

  @override
  String get firmwareUpToDate => 'Прошивка обновлена до последней версии';

  @override
  String get firmwareUpdateAvailable => 'Доступно обновление';

  @override
  String get firmwareDownloadLatestFull => 'Скачать последний полный пакет';

  @override
  String get firmwareUpdateNow => 'Обновить';

  @override
  String get firmwareReleaseNotes => 'Примечания к выпуску';

  @override
  String get firmwareReleaseNotesUnavailable =>
      'Примечания к выпуску недоступны';

  @override
  String get download => 'Скачать';

  @override
  String get downloadTaskAdded => 'Добавлено в очередь загрузки';

  @override
  String get zeppOsMoreFeatures => 'Специальные функции';

  @override
  String get zeppOsMoreFeaturesDescription =>
      'Управление дополнительными функциями устройств Zepp OS';

  @override
  String get zeppOsDeviceFeaturesSection => 'Функции устройства';

  @override
  String get zeppOsAppsAndDevelopmentSection => 'Приложения и разработка';

  @override
  String get zeppOsAssistant => 'Голосовая лаборатория';

  @override
  String get zeppOsAssistantDescription =>
      'Захват, наблюдение и ответы в сеансах голосового помощника часов';

  @override
  String get zeppOsScreenMirror => 'Зеркальное отображение экрана';

  @override
  String get zeppOsScreenMirrorDescription =>
      'Просмотр экрана часов на этом устройстве';

  @override
  String get zeppOsScreenMirrorSemantics =>
      'Зеркальное отображение экрана часов Zepp OS';

  @override
  String zeppOsScreenMirrorUnsupported(Object error) {
    return 'Невозможно показать этот формат экрана: $error';
  }

  @override
  String get expand => 'Разворачивание';

  @override
  String get collapse => 'Сворачивание';

  @override
  String get voiceLabTitle => 'Голосовая лаборатория';

  @override
  String get voiceLabXiaoAi => 'XiaoAI';

  @override
  String get voiceLabReceivingAudio => 'Получение аудио с часов';

  @override
  String get voiceLabWaiting => 'Ожидание голосового сеанса';

  @override
  String get voiceLabContinuousCapture => 'Непрерывный захват';

  @override
  String get voiceLabContinuousCaptureDescription =>
      'Запрашивать следующую запись после завершения текущей';

  @override
  String get voiceLabDisableMonitoring =>
      'Отключить наблюдение в реальном времени';

  @override
  String get voiceLabEnableMonitoring =>
      'Включить наблюдение в реальном времени';

  @override
  String get voiceLabReplyLabel => 'Ответ отправлен на часы';

  @override
  String get voiceLabReplyHint => 'Введите ответ';

  @override
  String get voiceLabReplyQueued =>
      'Ответ будет отправлен после завершения текущей записи';

  @override
  String get voiceLabReplySent => 'Ответ отправлен на часы';

  @override
  String get voiceLabCapturedData => 'Захваченные данные';

  @override
  String get voiceLabDecoder => 'Декодер';

  @override
  String get voiceLabOpusFrames => 'Кадры Opus';

  @override
  String get voiceLabDataSize => 'Размер данных';

  @override
  String get voiceLabPcmSamples => 'Сэмплы PCM';

  @override
  String get voiceLabExportOpus => 'Экспортировать Opus';

  @override
  String get voiceLabExportWav => 'Экспортировать WAV';

  @override
  String get voiceLabClearCapture => 'Очистить захваченные данные';

  @override
  String get voiceLabSaveRecording => 'Сохранить голосовую запись';

  @override
  String get voiceLabSaveOpus => 'Сохранить аудио Opus';

  @override
  String get voiceLabAudioProcessingFailedPrefix => 'Ошибка обработки аудио';

  @override
  String voiceLabAudioProcessingFailed(Object error) {
    return 'Ошибка обработки аудио: $error';
  }

  @override
  String voiceLabContinuousCaptureFailed(Object error) {
    return 'Не удалось настроить непрерывный захват: $error';
  }

  @override
  String voiceLabAssistantSwitchFailed(Object error) {
    return 'Не удалось сменить голосового помощника: $error';
  }

  @override
  String voiceLabExportWavFailed(Object error) {
    return 'Не удалось экспортировать WAV: $error';
  }

  @override
  String voiceLabExportOpusFailed(Object error) {
    return 'Не удалось экспортировать Opus: $error';
  }

  @override
  String get send => 'Отправить';

  @override
  String sendFailed(Object error) {
    return 'Не удалось отправить: $error';
  }

  @override
  String get ready => 'Готово';

  @override
  String get initializing => 'Инициализация';

  @override
  String get zeppOsMapSelectPackage => 'Выберите пакет карты Zepp OS';

  @override
  String get zeppOsMapReadFailed => 'Не удалось прочитать пакет карты';

  @override
  String get zeppOsMapTransferTitle => 'Передача офлайн-карты';

  @override
  String zeppOsMapGarminDetected(Object fileName, Object mapName) {
    return '$fileName\\nОбнаружена карта Garmin IMG в одном файле: $mapName';
  }

  @override
  String get zeppOsMapGarminNoPreview =>
      'В этой карте нет дерева тайлов Zepp OS 11/x/y. Исходный IMG будет передан одним пакетом, поэтому предпросмотр покрытия недоступен';

  @override
  String zeppOsMapTileSummary(Object fileName, Object count) {
    return '$fileName · $count тайлов\\nПредпросмотр показывает покрытие пакета, а не отрисовку Garmin IMG на часах';
  }

  @override
  String get zeppOsMapStartTransfer => 'Начать передачу';

  @override
  String get zeppOsMapTransferringBluetooth => 'Передача по Bluetooth';

  @override
  String get zeppOsMapTransferComplete => 'Передача офлайн-карты завершена';

  @override
  String get zeppOsMapConversionFailed =>
      'Не удалось безопасно преобразовать карту';

  @override
  String get zeppOsMapBtClassicHint =>
      'Идёт массовая передача по BT Classic. После начала передачи подтвердите установку на часах';

  @override
  String get zeppOsMapBleHint =>
      'BLE поддерживает пакеты карт до 2 МБ. Перед передачей большего пакета переключитесь на BT Classic и подтвердите установку на часах';

  @override
  String get zeppOsMapPreviewTooLarge =>
      'Область карты слишком велика для полного предпросмотра';

  @override
  String zeppOsSettingPageLoadFailed(Object error) {
    return 'Не удалось загрузить страницу настроек: $error';
  }

  @override
  String zeppOsAppCompatibilitySaved(Object appId) {
    return 'Файлы совместимости сохранены для $appId';
  }

  @override
  String zeppOsAppStorageSaved(Object appId) {
    return 'settingsStorage сохранён для $appId';
  }

  @override
  String get zeppOsAppSupplementFiles => 'Добавить файлы AppSide или настроек';

  @override
  String get zeppOsAppSupplementCompatibility =>
      'Добавить файлы совместимости мини-приложения';

  @override
  String get zeppOsAppReplaceCompatibility =>
      'Добавить или заменить файлы совместимости';

  @override
  String get zeppOsAppSideAvailable => 'AppSide ✓';

  @override
  String get zeppOsAppSideMissing => 'AppSide отсутствует';

  @override
  String get zeppOsSettingAvailable => 'Настройка ✓';

  @override
  String get zeppOsSettingMissing => 'Настройка отсутствует';

  @override
  String get zeppOsAppEditStorage => 'Изменить settingsStorage';

  @override
  String get zeppOsStorageKeyRequired => 'Ключ обязателен';

  @override
  String zeppOsStorageDuplicateKey(Object key) {
    return 'Дублирующийся ключ: $key';
  }

  @override
  String get zeppOsStorageDescription =>
      'Эти данные используются страницей настроек и AppSide и хранятся в виде строк согласно спецификации Zepp OS';

  @override
  String get zeppOsStorageEmpty => 'Сохранённых записей нет';

  @override
  String get zeppOsStorageKey => 'Ключ';

  @override
  String get zeppOsStorageValue => 'Значение';

  @override
  String get clear => 'Очистить';

  @override
  String get save => 'Сохранить';

  @override
  String get selectedFileReadFailed => 'Не удалось прочитать выбранный файл';

  @override
  String get zeppOsAppInvalidHexId =>
      'Введите корректный шестнадцатеричный ID приложения';

  @override
  String get zeppOsAppSelectCompatibilityFile =>
      'Выберите хотя бы один файл app-side.js или setting.js';

  @override
  String get zeppOsAppHexId => 'ID приложения (шестнадцатеричный)';

  @override
  String get optionalDisplayName => 'Отображаемое имя (необязательно)';

  @override
  String get zeppOsAppSideUnchanged => 'Оставить текущий AppSide';

  @override
  String get zeppOsSettingUnchanged => 'Оставить текущую настройку';

  @override
  String get selectFile => 'Выбрать файл';

  @override
  String get zeppOsAppCompatibilityOverwriteHint =>
      'Сохранение заменяет файлы совместимости с теми же именами для этого ID приложения, но не изменяет мини-приложение на часах';

  @override
  String zeppOsDebugRefreshFailed(Object error) {
    return 'Не удалось автоматически обновить данные: $error';
  }

  @override
  String get zeppOsDebugInvalidHex =>
      'HEX должен содержать полные байты, разделённые пробелами, переносами строк, 0x, запятыми или похожими разделителями';

  @override
  String get zeppOsDebugClearEventsTitle =>
      'Очистить события текущего приложения?';

  @override
  String zeppOsDebugClearEventsDescription(Object appId) {
    return 'Все отладочные события для $appId будут очищены';
  }

  @override
  String get zeppOsDebugClearEvents => 'Очистить события';

  @override
  String get zeppOsDebugRefresh => 'Обновить состояние и события';

  @override
  String get zeppOsDebugAppList => 'Список AppSide';

  @override
  String get zeppOsDebugNoApps =>
      'Кэшированные скрипты и сеансы AppSide часов не обнаружены';

  @override
  String get zeppOsDebugCached => 'В кэше';

  @override
  String get zeppOsDebugNotCached => 'Нет в кэше';

  @override
  String get zeppOsDebugRuntimeRunning => 'Среда выполнения запущена';

  @override
  String get zeppOsDebugRuntimeStopped => 'Среда выполнения остановлена';

  @override
  String get zeppOsDebugLocalRuntime => 'Локальная среда выполнения';

  @override
  String get zeppOsDebugCannotStart =>
      'Для этого ID приложения нет кэшированного скрипта, запуск локально невозможен';

  @override
  String get zeppOsDebugCanStart =>
      'Кэшированный скрипт можно запустить вручную без поддельных параметров сеанса часов';

  @override
  String get zeppOsDebugScriptRunning =>
      'Скрипт выполняется в локальном QuickJS';

  @override
  String get zeppOsDebugStartQuickJs => 'Запустить QuickJS';

  @override
  String get stop => 'Остановить';

  @override
  String get zeppOsDebugMessageEditor => 'Редактор сообщений';

  @override
  String get zeppOsDebugUtf8Text => 'Текст UTF-8';

  @override
  String get zeppOsDebugJsonCompact => 'JSON (сжатый перед отправкой)';

  @override
  String get zeppOsDebugHexBytes => 'Байты HEX';

  @override
  String get zeppOsDebugEncodingFailed =>
      'Текущее содержимое нельзя закодировать в выбранном режиме';

  @override
  String get zeppOsDebugByteCountUnavailable => 'Байты: —';

  @override
  String zeppOsDebugBytePreview(Object count, Object hex) {
    return 'Байты: $count\\nHEX: $hex';
  }

  @override
  String get zeppOsDebugInjectLocal =>
      'Вставить входящее сообщение в локальную среду';

  @override
  String get zeppOsDebugSendToWatch => 'Отправить на часы';

  @override
  String get zeppOsDebugWaitingForWatch =>
      'Отправить на часы (ожидание реального сеанса)';

  @override
  String get zeppOsDebugEvents => 'Отладочные события';

  @override
  String get zeppOsDebugClearCurrentApp => 'Очистить текущее приложение';

  @override
  String get zeppOsDebugSearch =>
      'Поиск по типу, сообщению, HEX или читаемому тексту';

  @override
  String get zeppOsDebugWatchOnly => 'Только реальные сообщения часов';

  @override
  String get zeppOsDebugNoEvents => 'Нет событий, соответствующих фильтрам';

  @override
  String get zeppOsDebugMessageActions => 'Действия с сообщением';

  @override
  String get zeppOsDebugLoadEditor => 'Загрузить в редактор';

  @override
  String get zeppOsDebugCopyHex => 'Копировать HEX';

  @override
  String get zeppOsDebugCopyText => 'Копировать текст';

  @override
  String get zeppOsDebugSessionStatus => 'Состояние среды и сеанса';

  @override
  String zeppOsDebugCachedScript(Object status) {
    return 'Кэшированный скрипт: $status';
  }

  @override
  String zeppOsDebugLocalRuntimeStatus(Object status) {
    return 'Локальная среда: $status';
  }

  @override
  String zeppOsDebugWatchSession(Object status) {
    return 'Сеанс часов: $status';
  }

  @override
  String get exists => 'Доступно';

  @override
  String get notExists => 'Недоступно';

  @override
  String get running => 'Запущено';

  @override
  String get notRunning => 'Не запущено';

  @override
  String get notOpen => 'Не открыто';

  @override
  String get zeppOsDebugWatchSessionOpen => 'Реальный сеанс открыт';

  @override
  String get zeppOsDebugRealHeader => 'Заголовок реального сеанса';

  @override
  String zeppOsDebugLatestStartup(Object status) {
    return 'Последнее состояние запуска: $status';
  }

  @override
  String get zeppOsDebugWatchInbound => 'От часов';

  @override
  String get zeppOsDebugWatchOutbound => 'На часы';

  @override
  String get zeppOsDebugLifecycle => 'Жизненный цикл';

  @override
  String get zeppOsMirrorInterval => 'Интервал зеркального отображения';

  @override
  String get zeppOsMirrorIntervalRange =>
      'Диапазон интервала зеркального отображения';

  @override
  String get zeppOsOfflineMaps => 'Офлайн-карты';

  @override
  String get zeppOsOfflineMapsDescription =>
      'Передача готовых пакетов карт на часы';

  @override
  String get zeppOsAppSettings => 'Настройки приложения Zepp OS';

  @override
  String get zeppOsAppSettingsDescription =>
      'Изменение настроек приложения Zepp OS';

  @override
  String get zeppOsAppDebug => 'Отладка приложения Zepp OS';

  @override
  String get zeppOsAppDebugDescription =>
      'Просмотр событий и запуск локального скрипта приложения';

  @override
  String get deviceMusicSync => 'Синхронизация музыки';

  @override
  String get deviceHealthTitle => 'Здоровье';

  @override
  String get deviceHealthDescription =>
      'Синхронизация активности и сна с устройством';

  @override
  String get deviceHealthSyncCardTitle => 'Данные о здоровье';

  @override
  String get deviceHealthNeverSynced =>
      'Данные о здоровье ещё не синхронизировались';

  @override
  String deviceHealthLastSynced(String time) {
    return 'Последняя синхронизация: $time';
  }

  @override
  String get deviceHealthSync => 'Синхронизировать данные о здоровье';

  @override
  String get deviceHealthSyncing => 'Синхронизация';

  @override
  String get deviceHealthAutoSyncTitle =>
      'Автоматически синхронизировать данные о здоровье';

  @override
  String get deviceHealthAutoSyncDescription =>
      'Автоматически синхронизировать данные о здоровье при синхронизации данных устройства';

  @override
  String get deviceHealthConnectFirst =>
      'Подключите устройство, чтобы синхронизировать данные о здоровье';

  @override
  String get deviceHealthPartialSync =>
      'Не удалось синхронизировать часть данных о здоровье';

  @override
  String get deviceHealthToday => 'Сегодня';

  @override
  String get deviceHealthSteps => 'Шаги';

  @override
  String get deviceHealthDistance => 'Расстояние';

  @override
  String get deviceHealthCalories => 'Калории';

  @override
  String get deviceHealthHeartRate => 'Пульс';

  @override
  String get deviceHealthRestingHeartRate => 'Пульс в покое';

  @override
  String get deviceHealthAbnormalHeartRate => 'Аномальный пульс';

  @override
  String get deviceHealthHeartRateHigh => 'Высокий пульс';

  @override
  String get deviceHealthHeartRateLow => 'Низкий пульс';

  @override
  String get deviceHealthHeartHealth => 'Здоровье сердца';

  @override
  String get deviceHealthHeartHealthMonitoring => 'Мониторинг здоровья сердца';

  @override
  String get deviceHealthIrregularHeartbeat => 'Нерегулярное сердцебиение';

  @override
  String get deviceHealthLowBloodOxygen => 'Низкий уровень кислорода';

  @override
  String get deviceHealthHighStress => 'Высокий стресс';

  @override
  String get deviceHealthDetected => 'Обнаружено';

  @override
  String get deviceHealthSleep => 'Последний сон';

  @override
  String get deviceHealthSleepCard => 'Сон';

  @override
  String get deviceHealthAllDaySleep => 'Сон за весь день';

  @override
  String get deviceHealthLongSleep => 'Длительный сон';

  @override
  String get deviceHealthSleepStructure => 'Структура сна';

  @override
  String get deviceHealthSleepAverageHeartRate =>
      'Средняя частота пульса во сне';

  @override
  String get deviceHealthSleepAverageBloodOxygen =>
      'Средний уровень кислорода во сне';

  @override
  String deviceHealthAverageHeartRate(int value) {
    return 'Средний пульс: $value уд/мин';
  }

  @override
  String get deviceHealthNoData => 'Нет данных';

  @override
  String get deviceHealthLoadFailed => 'Не удалось загрузить данные о здоровье';

  @override
  String get deviceMusicUpload => 'Загрузка музыки на устройство';

  @override
  String get deviceMusicSyncDescription =>
      'Синхронизация MP3-файлов с устройством';

  @override
  String get deviceMusicChooseDialog =>
      'Выберите MP3-файлы для синхронизации с устройством';

  @override
  String get deviceMusicReadFailed => 'Не удалось прочитать выбранный MP3-файл';

  @override
  String deviceMusicSizeInvalid(int maxMb) {
    return 'Недопустимый размер файла (максимум $maxMb МБ)';
  }

  @override
  String get deviceMusicUnknownArtist => 'Неизвестный исполнитель';

  @override
  String get deviceMusicTransferred => 'Передано';

  @override
  String get deviceMusicLibrary => 'Музыкальная библиотека';

  @override
  String get deviceMusicLibraryDescription =>
      'Управление песнями и плейлистами на устройстве';

  @override
  String get deviceMusicSongs => 'Песни';

  @override
  String deviceMusicSongsTotal(int count) {
    return 'Всего песен: $count';
  }

  @override
  String get deviceMusicNoPlaylist => 'Не входит в плейлист';

  @override
  String get deviceMusicPlaylists => 'Плейлисты';

  @override
  String get deviceMusicEmpty => 'На устройстве нет песен';

  @override
  String get deviceMusicNoPlaylists => 'Плейлистов нет';

  @override
  String deviceMusicLoadFailed(String error) {
    return 'Не удалось загрузить музыку: $error';
  }

  @override
  String get deviceMusicPlaylistCreate => 'Создать плейлист';

  @override
  String get deviceMusicPlaylistRename => 'Переименовать плейлист';

  @override
  String get deviceMusicPlaylistName => 'Название плейлиста';

  @override
  String deviceMusicPlaylistLimit(int count) {
    return 'Максимум плейлистов: $count';
  }

  @override
  String deviceMusicSongCount(int count) {
    return 'Песен: $count';
  }

  @override
  String get deviceMusicDeleteSong => 'Удалить эту песню с устройства?';

  @override
  String get deviceMusicDeletePlaylist => 'Удалить этот плейлист?';

  @override
  String get deviceMusicDeletePlaylistDescription =>
      'Песни останутся на устройстве';

  @override
  String get deviceMusicManagePlaylists => 'Управление плейлистами';

  @override
  String get deviceMusicPlaylistMembership => 'Состав плейлиста';

  @override
  String deviceMusicTransferSpeed(String speed) {
    return 'Скорость передачи: $speed';
  }

  @override
  String deviceMusicSelectedFiles(int count) {
    return 'Выбрано файлов: $count';
  }

  @override
  String deviceMusicQueueProgress(int current, int total, String name) {
    return '$current/$total: $name';
  }

  @override
  String get deviceRecordingsTitle => 'Записи с устройства';

  @override
  String get deviceRecordingsDescription =>
      'Синхронизация и экспорт записей с часов';

  @override
  String get deviceRecordingsHint =>
      'Записи принимаются и проверяются по одной. После синхронизации экспортируйте каждый исходный файл';

  @override
  String get deviceRecordingsSync => 'Синхронизировать записи';

  @override
  String get deviceRecordingsReading => 'Чтение записей';

  @override
  String deviceRecordingsProgress(int completed, int total, String name) {
    return '$completed/$total: $name';
  }

  @override
  String deviceRecordingsProgressCount(int completed, int total) {
    return 'Обработано записей: $completed/$total';
  }

  @override
  String get deviceRecordingsEmpty =>
      'Подключите часы и выберите «Синхронизировать записи»';

  @override
  String get deviceRecordingsSave => 'Сохранить записи';

  @override
  String get deviceRecordingsNoneOnWatch => 'На часах новые записи не найдены';

  @override
  String deviceRecordingsSynced(int count) {
    return 'Синхронизировано записей: $count';
  }

  @override
  String deviceRecordingsSaveFailed(String error) {
    return 'Не удалось сохранить запись: $error';
  }

  @override
  String get deviceMusicTransferTitle => 'Передача музыки';

  @override
  String get deviceMusicVelaDescription =>
      'Синхронизация MP3-файлов с устройством. Размер одного файла не должен превышать 100 МБ';

  @override
  String get deviceMusicZeppDescription =>
      'Поддерживаются MP3-файлы до 50 МБ. Для быстрой передачи рекомендуется Bluetooth Classic; BLE также поддерживается, но работает медленнее';

  @override
  String get deviceMusicChooseMp3 => 'Выберите MP3-файлы';

  @override
  String get deviceMusicSongTitle => 'Название песни';

  @override
  String get deviceMusicArtist => 'Исполнитель';

  @override
  String deviceMusicFileSize(Object size) {
    return 'Размер файла: $size';
  }

  @override
  String deviceMusicProgress(Object progress) {
    return 'Прогресс: $progress';
  }

  @override
  String get deviceMusicTransferring => 'Передача';

  @override
  String get deviceMusicSend => 'Отправить на устройство';

  @override
  String get zeppOsFindDevice => 'Найти устройство';

  @override
  String get zeppOsFindDeviceDescription =>
      'Заставить устройство непрерывно вибрировать или звонить';

  @override
  String get deviceFeaturesDeviceInfo => 'Информация об устройстве';

  @override
  String get deviceFeaturesDeviceInfoDesc => 'Просмотр сведений об устройстве';

  @override
  String get switchDeviceTitle => 'Переключить устройство';

  @override
  String get savedDevices => 'Сохранённые устройства';

  @override
  String get deviceSwitchAddDevice => 'Добавить устройство';

  @override
  String get scanAndAdd => 'Сканировать и добавить';

  @override
  String get authkey => 'Ключ авторизации';

  @override
  String get authkeyPrompt => 'Введите ключ авторизации устройства';

  @override
  String get authkeyPlaceholder => 'Ключ authkey';

  @override
  String get connectFailed => 'Не удалось подключиться';

  @override
  String deviceConnectingTo(String deviceName) {
    return 'Подключение к устройству $deviceName';
  }

  @override
  String get deviceConnectionPreparing => 'Подготовка подключения';

  @override
  String deviceConnectionEstablishing(String transport) {
    return 'Установка подключения ($transport)';
  }

  @override
  String get deviceConnectionInitializing => 'Инициализация подключения';

  @override
  String get deviceConnectionAuthenticating => 'Авторизация устройства';

  @override
  String get deviceConnectionFetchingStatus => 'Получение состояния устройства';

  @override
  String get deviceTransportBle => 'BLE';

  @override
  String deviceEndpointUnavailable(String transport) {
    return 'Конечная точка $transport недоступна. Сопрягите устройство в системных настройках Bluetooth и просканируйте снова';
  }

  @override
  String get deviceTransportSpp => 'SPP';

  @override
  String get deviceCompatibilityUnknown =>
      'Совместимость устройства неизвестна';

  @override
  String get webSerialTitle => 'Web Serial';

  @override
  String get webSerialHint =>
      'В веб-версии OronBox подключается к устройствам через Web Serial. Сохранённые устройства остаются в этом браузере';

  @override
  String get webSerialConnectDialogTitle => 'Подключение через Web Serial';

  @override
  String get webSerialConnectDialogHint =>
      'Введите authkey устройства и выберите последовательный порт в запросе браузера. Authkey сохраняется в этом браузере';

  @override
  String get cancel => 'Отмена';

  @override
  String get deviceActionsDelete => 'Удалить устройство';

  @override
  String get deviceActionsDisconnect => 'Отключить устройство';

  @override
  String get deviceActionsShareQR => 'Поделиться QR-кодом';

  @override
  String get deviceShareOronBoxCode => 'Код OronBox';

  @override
  String get deviceShareAstroBoxCompatibleCode => 'Совместимый код AstroBox';

  @override
  String get installTapToSelectFile => 'Нажмите, чтобы выбрать файл';

  @override
  String get deviceInfoTitle => 'Информация об устройстве';

  @override
  String get deviceInfoGroupDevice => 'Устройство';

  @override
  String get deviceInfoGroupSystem => 'Система';

  @override
  String get deviceInfoGroupStatus => 'Состояние';

  @override
  String get fieldName => 'Имя';

  @override
  String get fieldAddress => 'Адрес';

  @override
  String get fieldAuthkey => 'Authkey';

  @override
  String get fieldConnectionType => 'Тип подключения';

  @override
  String get fieldCodename => 'Кодовое имя';

  @override
  String get fieldModel => 'Модель';

  @override
  String get fieldImei => 'IMEI';

  @override
  String get fieldFirmware => 'Прошивка';

  @override
  String get fieldSerial => 'Серийный номер';

  @override
  String get fieldBattery => 'Батарея';

  @override
  String get fieldChargeStatus => 'Состояние зарядки';

  @override
  String get fieldStorage => 'Хранилище';

  @override
  String get appManagementTitle => 'Управление приложениями';

  @override
  String get appManagementNone => 'Приложений нет';

  @override
  String get appManagementShowSystemApps => 'Показывать системные приложения';

  @override
  String get watchfaceManagementTitle => 'Управление циферблатами';

  @override
  String get watchfaceManagementNone => 'Циферблатов нет';

  @override
  String get open => 'Открытие';

  @override
  String get externalLinkTitle => 'Внешняя ссылка';

  @override
  String externalLinkDescription(String url) {
    return 'Вы собираетесь открыть $url\\n\\nСайт принадлежит третьей стороне, не связан с OronBox, а его безопасность неизвестна. Будьте осторожны. Продолжить?';
  }

  @override
  String get externalLinkAstroBoxResourceHint =>
      'Похоже, это ресурс AstroBox. Его также можно открыть и установить в OronBox';

  @override
  String get continueToWebsite => 'Перейти на сайт';

  @override
  String get viewInOronBox => 'Открыть в OronBox';

  @override
  String get uninstall => 'Удалить';

  @override
  String get enable => 'Включить';

  @override
  String get show => 'Показать';

  @override
  String get hide => 'Скрыть';

  @override
  String get copy => 'Копировать';

  @override
  String get copied => 'Скопировано';

  @override
  String get close => 'Закрыть';

  @override
  String get desktopTrayShow => 'Показать OronBox';

  @override
  String get desktopTrayExit => 'Выйти из OronBox';

  @override
  String get desktopCloseTitle => 'Закрытие приложения';

  @override
  String get desktopCloseMessage => 'Выйти из OronBox?';

  @override
  String get desktopCloseRemember => 'Запомнить выбор';

  @override
  String get desktopCloseToTray => 'Свернуть в область уведомлений';

  @override
  String get desktopCloseExit => 'Выйти';

  @override
  String get settingsDesktopCloseBehavior => 'Закрытие окна';

  @override
  String get settingsDesktopCloseBehaviorDesc =>
      'Выберите действие при закрытии главного окна';

  @override
  String get settingsRemoveBondBeforeSpp =>
      'Повторное сопряжение при подключении';

  @override
  String get settingsRemoveBondBeforeSppDesc =>
      'Повышает стабильность соединения и не позволяет Xiaomi Fitness занять подключение; отключение может ускорить соединение';

  @override
  String get desktopCloseBehaviorAsk => 'Спрашивать';

  @override
  String get desktopCloseBehaviorExit => 'Выход';

  @override
  String get desktopCloseBehaviorTray => 'Свернуть в область уведомлений';

  @override
  String get quickApp => 'Быстрое приложение';

  @override
  String get miniprogram => 'Мини-программа';

  @override
  String get miniprograms => 'Мини-программы';

  @override
  String get watchface => 'Циферблат';

  @override
  String get firmwareTool => 'Прошивка / инструмент';

  @override
  String get free => 'Бесплатно';

  @override
  String get paid => 'Платные';

  @override
  String get forcePaid => 'Принудительно платный';

  @override
  String get version => 'Версия';

  @override
  String get noContent => 'Нет содержимого';

  @override
  String get preview => 'Предпросмотр';

  @override
  String get productDeviceRequirements => 'Требования к устройству';

  @override
  String get productOtherVersions => 'Другие версии';

  @override
  String get productInQueue => 'В очереди';

  @override
  String get settingsAccount => 'Аккаунты';

  @override
  String get settingsGeneral => 'Общие';

  @override
  String get settingsQueue => 'Очередь';

  @override
  String get settingsAbout => 'О программе';

  @override
  String get settingsAccountLoginBBSDesc =>
      'Войдите в аккаунт BandBBS, чтобы пользоваться ресурсами сообщества';

  @override
  String get settingsAccountBandBbsSigningIn => 'Выполняется вход в BandBBS';

  @override
  String get settingsAccountBandBbsOpenedBrowser =>
      'Страница входа BandBBS открыта в браузере';

  @override
  String get settingsAccountBandBbsSignedIn => 'Вход в BandBBS выполнен';

  @override
  String get settingsAccountBandBbsLoginFailed => 'Не удалось войти в BandBBS';

  @override
  String get settingsBandBbsAccountRequired =>
      'Сначала войдите в аккаунт BandBBS в настройках';

  @override
  String get settingsAccountBBSAccount => 'Аккаунт BandBBS';

  @override
  String get bandBbsAccountTitle => 'Аккаунт BandBBS';

  @override
  String get bandBbsResourceId => 'ID ресурса BandBBS';

  @override
  String get bandBbsResourceIdHint => 'Введите ID ресурса BandBBS';

  @override
  String get bandBbsQueryResource => 'Найти ресурс BandBBS';

  @override
  String get bandBbsLogout => 'Выйти из BandBBS';

  @override
  String get bandBbsLoggedOut => 'Выход из BandBBS выполнен';

  @override
  String accountSignOutTitle(Object accountName) {
    return 'Выйти из аккаунта $accountName?';
  }

  @override
  String get accountSignOutMessage =>
      'Сохранённые данные этого аккаунта будут удалены';

  @override
  String get bandBbsLoadPreviews => 'Загружать предпросмотры BandBBS';

  @override
  String get bandBbsLoadPreviewsDesc =>
      'Автоматически загружать предпросмотры вложений в списке ресурсов';

  @override
  String get bandBbsShowAllCategories => 'Показывать все категории BandBBS';

  @override
  String get bandBbsShowAllCategoriesDesc =>
      'Показывать категории без ресурсов';

  @override
  String get settingsMiAccount => 'Аккаунт Xiaomi';

  @override
  String get settingsMiAccountDesc =>
      'Войти в аккаунт Xiaomi и синхронизировать привязанные устройства';

  @override
  String get deviceSwitchMiAccountImport =>
      'Импортировать устройства из аккаунта Xiaomi';

  @override
  String get deviceSwitchWearableLogImport =>
      'Импортировать устройства из журнала Xiaomi Fitness';

  @override
  String get settingsMiAccountLoginTitle => 'Вход в аккаунт Xiaomi';

  @override
  String get settingsMiAccountUsername => 'Имя пользователя Xiaomi';

  @override
  String get settingsMiAccountPassword => 'Пароль Xiaomi';

  @override
  String get settingsMiAccountRememberCredentials => 'Запомнить данные входа';

  @override
  String get settingsMiAccountLoginAndSync => 'Войти и синхронизировать';

  @override
  String get settingsMiAccountLogInvalid =>
      'Не удалось прочитать журнал Xiaomi Fitness';

  @override
  String get settingsMiAccountLogNoDevices =>
      'В журнале не найдено устройств с полным MAC-адресом и authkey';

  @override
  String get settingsWearableLogSync =>
      'Синхронизация из журнала Xiaomi Fitness';

  @override
  String get settingsWearableLogGuide =>
      'Откройте Xiaomi Fitness\\nПерейдите в раздел «Профиль» → «О приложении»\\nНесколько раз нажмите оранжевый логотип-кольцо\\nВ появившемся окне нажмите «Подтвердить»\\nДождитесь уведомления «log has been...»\\nВернитесь сюда и нажмите «Сканировать»';

  @override
  String settingsWearableLogFound(int count) {
    return 'Найдено устройств: $count';
  }

  @override
  String settingsWearableLogImportedDevice(Object name) {
    return 'Импортировано устройство: $name';
  }

  @override
  String get settingsMiAccountMissingCredentials =>
      'Введите имя пользователя и пароль Xiaomi';

  @override
  String get settingsMiAccountTwoFactorPrompt =>
      'Завершите двухфакторную проверку Xiaomi на странице проверки';

  @override
  String get settingsMiAccountLoginWindowClosed => 'Окно входа Xiaomi закрыто';

  @override
  String settingsMiAccountSyncedDevices(int count) {
    return 'Синхронизировано устройств: $count';
  }

  @override
  String get xiaomiAccountRequiredForEphemeris =>
      'Войдите в аккаунт Xiaomi перед синхронизацией эфемеридных данных';

  @override
  String get settingsHuamiAccount => 'Аккаунт Amazfit';

  @override
  String get settingsHuamiAccountDesc =>
      'Войти и сохранить данные для доступа к магазину Zepp';

  @override
  String get settingsHuamiAccountSigningIn => 'Выполняется вход в Amazfit';

  @override
  String get settingsHuamiAccountSignedIn => 'Вход в Amazfit выполнен';

  @override
  String get settingsHuamiAccountLoginTitle => 'Вход в аккаунт Amazfit';

  @override
  String get settingsHuamiAccountUsername => 'Имя пользователя Amazfit';

  @override
  String get settingsHuamiAccountPassword => 'Пароль Amazfit';

  @override
  String get settingsHuamiAccountRememberCredentials =>
      'Запомнить данные входа';

  @override
  String get settingsHuamiAccountLoginAndSave => 'Войти и сохранить';

  @override
  String get settingsHuamiAccountMissingCredentials =>
      'Введите имя пользователя и пароль Amazfit';

  @override
  String get settingsHuamiAccountRequired =>
      'Сначала войдите в аккаунт Amazfit в настройках';

  @override
  String get understood => 'Понятно';

  @override
  String get settingsGeneralLanguage => 'Язык';

  @override
  String get settingsGeneralLanguageDesc => 'Выберите язык приложения';

  @override
  String get settingsWideNavigationPosition => 'Положение боковой навигации';

  @override
  String get settingsWideNavigationPositionDesc =>
      'Настройте положение вкладок в широком режиме';

  @override
  String get settingsWideNavigationPositionBottom => 'Снизу';

  @override
  String get settingsWideNavigationPositionCenter => 'По центру';

  @override
  String get settingsWideNavigationPositionSplit => 'Раздельно';

  @override
  String get settingsAutoReconnectTitle => 'Автоподключение';

  @override
  String get settingsAutoReconnectDesc =>
      'Автоматически подключаться к последнему сопряжённому устройству при запуске';

  @override
  String get settingsAutoReconnectOnDisconnectTitle => 'Автоподключение';

  @override
  String get settingsAutoReconnectOnDisconnectDesc =>
      'Пытаться повторно подключиться при неожиданном отключении устройства';

  @override
  String get deviceReconnectAttempting =>
      'Соединение с устройством потеряно, выполняется переподключение';

  @override
  String get deviceReconnectSucceeded => 'Подключение восстановлено';

  @override
  String get deviceReconnectFailedPrefix =>
      'Не удалось переподключиться. Проверьте: ';

  @override
  String get settingsSourceOfficialCdn => 'Официальный CDN';

  @override
  String get settingsSourceOfficialCdnDesc =>
      'CDN для загрузки индекса сообщества из GitHub';

  @override
  String get settingsQueueAutoInstall => 'Автоустановка';

  @override
  String get settingsQueueAutoInstallDesc =>
      'Начинать установку автоматически после загрузки';

  @override
  String get settingsQueueDontClear => 'Не очищать очередь установки';

  @override
  String get settingsQueueDontClearDesc =>
      'Сохранять завершённые элементы в очереди установки';

  @override
  String get settingsRealtimeActivityNotification =>
      'Уведомление о ходе выполнения';

  @override
  String get settingsRealtimeActivityNotificationDesc =>
      'Показывать ход очереди в уведомлении в реальном времени';

  @override
  String get settingsAboutWebsite => 'Официальный сайт';

  @override
  String get settingsTapToSignIn => 'Нажмите для входа';

  @override
  String get settingsConnected => 'Подключено';

  @override
  String get settingsSystem => 'Системная';

  @override
  String get settingsLight => 'Светлая';

  @override
  String get settingsDark => 'Тёмная';

  @override
  String get settingsOledDark => 'Тёмная OLED';

  @override
  String get settingsThemeMode => 'Тема';

  @override
  String get settingsThemeModeDesc => 'Изменить оформление приложения';

  @override
  String get settingsDynamicColor => 'Динамический цвет';

  @override
  String get settingsDynamicColorDesc =>
      'Использовать системный акцентный цвет';

  @override
  String get settingsColorScheme => 'Цветовая схема';

  @override
  String get settingsColorSchemeDesc => 'Выберите акцентный цвет приложения';

  @override
  String get settingsColorSchemePink => 'Розовая';

  @override
  String get settingsColorSchemePurple => 'Фиолетовая';

  @override
  String get settingsColorSchemeTeal => 'Бирюзовая';

  @override
  String get settingsColorSchemeGreen => 'Зелёная';

  @override
  String get settingsColorSchemeRed => 'Красная';

  @override
  String get settingsColorSchemeAmber => 'Янтарная';

  @override
  String get settingsDesktopAccentSource => 'Источник акцентного цвета Linux';

  @override
  String get settingsDesktopAccentSourceDesc =>
      'Выберите источник акцентного цвета: GTK или Qt';

  @override
  String get settingsDesktopAccentSourceSystem => 'Автоматически';

  @override
  String get settingsDesktopAccentSourceGtk => 'GTK';

  @override
  String get settingsDesktopAccentSourceQt => 'Qt';

  @override
  String get settingsCancel => 'Отмена';

  @override
  String get settingsTeamRoleMain => 'Основной разработчик / дизайнер';

  @override
  String get settingsTeamRoleZeppOS => 'Разработка ZeppOS';

  @override
  String get settingsAboutSoftware => 'О программе';

  @override
  String get settingsAboutSoftwareDesc =>
      'Версия, список изменений и команда разработки';

  @override
  String get settingsAboutSoftwareTagline =>
      'Быстрый менеджер носимых устройств VelaOS и ZeppOS на Flutter';

  @override
  String get settingsAboutSoftwareRepository => 'Открыть репозиторий GitHub';

  @override
  String get settingsAboutSoftwareTeam => 'Команда разработки';

  @override
  String get settingsAboutSoftwareBuildInfo => 'Сведения о сборке';

  @override
  String get settingsAboutSoftwareCopyright => 'Copyright © 2026 OrPudding';

  @override
  String get acknowledgementsKazumi => 'Благодарности Kazumi';

  @override
  String get acknowledgementsAstroBoxPublic =>
      'Благодарности AstroBox публичный';

  @override
  String get acknowledgementsAstroBoxNgCore =>
      'Ссылки на исходный код ядра AstroBox NG';

  @override
  String get acknowledgementsAstroBoxNgBluetooth =>
      'Ссылки на реализацию Bluetooth в AstroBox NG';

  @override
  String get acknowledgementsAstroBoxNgAccount =>
      'Ссылки на работу с аккаунтами в AstroBox NG';

  @override
  String get acknowledgementsAstroBoxNgProvider =>
      'Ссылки на провайдер ресурсов AstroBox NG';

  @override
  String get acknowledgementsAstroBoxNgAppWasm =>
      'Ссылки на WebAssembly-приложение AstroBox NG';

  @override
  String get acknowledgementsGadgetbridge => 'Благодарности Gadgetbridge';

  @override
  String get acknowledgementsBreezyWeather =>
      '参考 реализации китайского источника погоды';

  @override
  String get acknowledgementsOpenMeteo =>
      'Данные о погоде, качестве воздуха и геокодировании по CC BY 4.0';

  @override
  String get resourceHomeRecommended => 'Рекомендуемые';

  @override
  String get resourceHomeFeatured => 'Избранные';

  @override
  String get resourceHomeUpdates => 'Обновления';

  @override
  String get blogTypeAnnouncement => 'блог тип объявление';

  @override
  String get blogTypeRecommendation => 'блог тип рекомендация';

  @override
  String get blogTypeDocs => 'блог тип документация';

  @override
  String get resourceHomeEmptyTitle => 'Пока нечего рекомендовать';

  @override
  String get resourceLibraryEndOfList =>
      'Вы достигли конца списка — посмотреть ресурсы из других источников?';

  @override
  String get resourceHomeEmptySubtitle => 'Ресурсы можно найти в библиотеке';

  @override
  String get openResourceLibrary => 'Открыть библиотеку ресурсов';

  @override
  String get downloadQueueTitle => 'Очередь загрузки';

  @override
  String get installQueueTitle => 'Очередь установки';

  @override
  String get queueClear => 'Очистить';

  @override
  String get queueStart => 'Запустить';

  @override
  String get queuePause => 'Приостановить';

  @override
  String get downloadQueueEmpty => 'Нет задач загрузки';

  @override
  String get installQueueEmpty => 'Нет задач установки';

  @override
  String get localAppInstall => 'Установка локального приложения';

  @override
  String get localWatchfaceInstall => 'Установка локального циферблата';

  @override
  String get localFirmwareInstall => 'Установка локальной прошивки';

  @override
  String get queueStatusPending => 'Ожидание';

  @override
  String queueStatusDownloading(String percent) {
    return 'Загрузка: $percent%';
  }

  @override
  String queueStatusInstalling(String percent) {
    return 'Установка: $percent%';
  }

  @override
  String get queueStatusCompleted => 'Завершено';

  @override
  String get queueStatusFailed => 'Ошибка';

  @override
  String get queueDragToInstall =>
      'Отпустите, чтобы установить приложение, циферблат или плагин';

  @override
  String queueAddedFiles(int count) {
    return 'Добавлено файлов в очередь: $count';
  }

  @override
  String get installQueueReadFailed => 'Не удалось прочитать';

  @override
  String get installQueueUnsupportedFile => 'Неподдерживаемый файл';

  @override
  String timeTodayAt(Object time) {
    return 'Сегодня в $time';
  }

  @override
  String timeYesterdayAt(Object time) {
    return 'Вчера в $time';
  }

  @override
  String get settingsAccountBandBbsAccount => 'Аккаунт BandBBS';

  @override
  String get settingsAccountGitHub => 'Аккаунт GitHub';

  @override
  String get settingsAccountGitHubDesc =>
      'Подключите аккаунт, чтобы публиковать ресурсы AstroBox от своего имени';

  @override
  String get githubAccountNeedsBandBbs => 'Сначала войдите в BandBBS';

  @override
  String get bandBbsPublishAuthTitle => 'Авторизация публикации';

  @override
  String get bandBbsResourceQueryTitle => 'Установка купленных ресурсов';

  @override
  String get settingsAboutLogs => 'Журналы работы';

  @override
  String get settingsAboutLogsDescription =>
      'Просмотр, экспорт и управление журналами приложения и подключённых устройств';

  @override
  String settingsAboutLogsSize(Object size) {
    return 'Используется: $size';
  }

  @override
  String get settingsAboutLogsExport => 'Экспортировать';

  @override
  String settingsAboutLogsExported(Object path) {
    return 'Экспортировано в $path';
  }

  @override
  String get settingsAboutLogsEmpty => 'Файлов журналов нет';

  @override
  String get settingsAboutLogsClear => 'Очистить';

  @override
  String get settingsDeviceLogsPull => 'Получить журналы устройства';

  @override
  String get settingsDeviceLogsTip =>
      'Получение журналов подключённых часов Xiaomi может занять время. Держите приложение на переднем плане, а экран устройства включённым до завершения';

  @override
  String get settingsDeviceLogsStart => 'Начать';

  @override
  String get settingsDeviceLogsPulling => 'Получение журналов устройства';

  @override
  String get settingsDeviceLogsWaiting => 'Ожидание передачи с устройства';

  @override
  String settingsDeviceLogsProgress(Object progress) {
    return 'Получено: $progress%';
  }

  @override
  String settingsDeviceLogsSaved(Object name) {
    return 'Журналы сохранены как $name';
  }

  @override
  String settingsDeviceLogsFailed(Object error) {
    return 'Не удалось получить журналы устройства: $error';
  }

  @override
  String get settingsAboutLogsClearConfirm =>
      'Будут удалены все журналы, кроме текущего сеанса';

  @override
  String get settingsAboutLogsOpen => 'Открыть папку журналов';

  @override
  String get settingsAboutLogsOpenFailed => 'Не удалось открыть папку журналов';

  @override
  String get settingsLogsFileList => 'Файлы журналов';

  @override
  String get settingsAboutLogsWarningTitle =>
      'Предупреждение о конфиденциальных данных';

  @override
  String get settingsAboutLogsWarningMessage =>
      'Журналы могут содержать данные входа BandBBS, Xiaomi или Amazfit и другую конфиденциальную информацию. Не передавайте их никому, кроме официальных сопровождающих OronBox';

  @override
  String get pluginPermissionRequestTitle => 'Запрос разрешения плагина';

  @override
  String pluginPermissionRequestMessage(Object plugin, Object operation) {
    return 'Плагин «$plugin» хочет выполнить действие: $operation';
  }

  @override
  String get pluginPermissionOnce => 'Разрешить один раз';

  @override
  String get pluginPermissionSession => 'Разрешить на время запуска';

  @override
  String get pluginPermissionAlways => 'Разрешать всегда';

  @override
  String get pluginPermissionDeny => 'Запретить';

  @override
  String get pluginPermissionOpenExternal => 'открывать внешние ссылки';

  @override
  String get pluginPermissionPickFile => 'получать доступ к файлам компьютера';

  @override
  String get pluginPermissionExportFile => 'экспортировать файл на компьютер';

  @override
  String get pluginPermissionNetwork => 'получать доступ к сети';

  @override
  String get pluginPermissionInterconnect =>
      'обмениваться данными с приложениями устройства';

  @override
  String get pluginPermissionProvider => 'регистрировать поставщик ресурсов';

  @override
  String get pluginPermissionReadDevice => 'читать сведения об устройстве';

  @override
  String get pluginPermissionOperateDevice => 'управлять устройством';

  @override
  String get pluginPermissionObserveProtocol =>
      'читать необработанные данные протокола';

  @override
  String get pluginPermissionSendProtocol =>
      'отправлять необработанные данные протокола на устройство';

  @override
  String get pluginPermissionReadAppSide => 'читать скрипты и события AppSide';

  @override
  String get pluginPermissionOperateAppSide => 'управлять сеансами AppSide';

  @override
  String get pluginErrorTitle => 'Плагин повреждён';

  @override
  String pluginErrorMessage(Object plugin, Object error) {
    return 'Плагин «$plugin» не удаётся запустить. Возможно, он повреждён.\\n\\nОшибка: $error\\n\\nУдалить этот плагин?';
  }

  @override
  String get pluginPackageCorruptedMessage =>
      'Не удалось прочитать выбранный пакет плагина. Возможно, он повреждён. Получите пакет заново и повторите импорт.';

  @override
  String get pluginErrorClearData => 'Очистить данные плагина';

  @override
  String get pluginErrorUninstall => 'Удалить плагин';

  @override
  String get pluginErrorSafeMode => 'Включить безопасный режим';

  @override
  String get pluginSafeModeTitle => 'Безопасный режим плагинов включён';

  @override
  String get pluginSafeModeDescription =>
      'Все плагины остановлены и перезапустятся после отключения безопасного режима';

  @override
  String get pluginSafeModeExit => 'Выйти из безопасного режима';

  @override
  String get devTools => 'Инструменты разработчика';

  @override
  String get devToolsDescriptionDesktop =>
      'Открыть инструменты разработчика в отдельном окне';

  @override
  String get devToolsDescriptionEntry =>
      'Показывать кнопку инструментов разработчика в панелях приложения';

  @override
  String get devToolsOperationFailed =>
      'Не удалось изменить состояние инструментов разработчика';

  @override
  String get resourceTypeErrorTitle => 'Неверный тип ресурса';

  @override
  String get resourceTypeUnknownTitle => 'Неизвестный тип ресурса';

  @override
  String get resourceTypeUnknownNoType =>
      'OronBox не может определить тип этого файла; возможно, файл повреждён';

  @override
  String get resourceTypeUnknownCancel => 'Отмена';

  @override
  String resourceTypeMismatchMessage(Object detectedType, Object selectedType) {
    return 'Похоже, это ресурс типа $detectedType, но выбран тип $selectedType. Выберите способ установки';
  }

  @override
  String resourcePlatformMismatchMessage(
    Object resourcePlatform,
    Object resourceType,
    Object deviceName,
    Object devicePlatform,
  ) {
    return 'Похоже, это ресурс $resourceType для устройств $resourcePlatform, но подключено устройство $deviceName ($devicePlatform). Ресурс не поддерживается, принудительная установка может вызвать проблемы';
  }

  @override
  String resourceTypeUnknownMessage(Object selectedType) {
    return 'OronBox не может определить фактический тип ресурса. Всё равно установить его как $selectedType?';
  }

  @override
  String get resourceInstallCancel => 'Отменить установку';

  @override
  String get resourceInstallAcknowledge => 'Я понимаю';

  @override
  String get resourceInstallForce => 'Установить принудительно';

  @override
  String resourceInstallForceCountdown(int seconds) {
    return 'Установить принудительно ($seconds с)';
  }

  @override
  String resourceInstallAsSelected(Object type) {
    return 'Продолжить как $type';
  }

  @override
  String resourceInstallAsSelectedCountdown(Object type, int seconds) {
    return 'Продолжить как $type ($seconds с)';
  }

  @override
  String resourceInstallAsDetected(Object type) {
    return 'Установить как $type';
  }

  @override
  String get resourceTypeApp => 'мини-программа';

  @override
  String get resourceTypeQuickApp => 'быстрое приложение';

  @override
  String get resourceTypeWatchface => 'циферблат';

  @override
  String get resourceTypeFirmware => 'прошивка';

  @override
  String resourceInstallConfirmTitle(Object type) {
    return 'Установить: $type';
  }

  @override
  String resourceInstallConfirmMessage(Object fileName, Object fileSize) {
    return 'Установить $fileName ($fileSize)?';
  }

  @override
  String get resourceInstallConfirm => 'Установить';

  @override
  String get previewImages => 'Предпросмотр изображений';

  @override
  String get add => 'Добавить';

  @override
  String get submit => 'Отправить';

  @override
  String get creatorConfirmTitle => 'Подтвердить публикацию';

  @override
  String get creatorConfirmOronBox => 'Опубликовать в OronBox';

  @override
  String creatorConfirmBandBbs(Object category) {
    return 'Синхронизировать с BandBBS: $category';
  }

  @override
  String creatorConfirmAstroBox(Object owner, Object repository) {
    return 'Синхронизировать с AstroBox: $owner/$repository';
  }

  @override
  String get creatorBandBbsDirectPublish => 'Синхронизировать с BandBBS';

  @override
  String get creatorBandBbsBoundUpdate =>
      'Связано · синхронизировать с BandBBS';

  @override
  String get creatorBandBbsVersionTitle => 'Название версии';

  @override
  String get creatorBandBbsVersionMessage => 'Описание обновления';

  @override
  String get creatorBandBbsVersionPairRequired =>
      'Укажите и название версии, и описание обновления или оставьте оба поля пустыми';

  @override
  String creatorLinkedSections(int count) {
    return 'Связанных разделов: $count';
  }

  @override
  String creatorBandBbsBindingIds(Object categoryId, Object resourceId) {
    return 'Раздел $categoryId · ресурс $resourceId';
  }

  @override
  String get creatorAstroBoxBoundSync =>
      'Связано · синхронизировать с AstroBox';

  @override
  String get creatorThisCommit => 'Этот коммит';

  @override
  String creatorAstroBoxPrPublish(Object repository) {
    return 'Синхронизировать с AstroBox · $repository';
  }

  @override
  String get creatorOronBoxRequired =>
      'Обязательно. Ресурсы проверяются OronBox';

  @override
  String get creatorOpenInOronBox => 'Открыть в OronBox';

  @override
  String get creatorAstroTagsHint =>
      'Разделяйте теги английской точкой с запятой ;';

  @override
  String get retry => 'Повторить';

  @override
  String get reviewNote => 'Примечание проверки';

  @override
  String get creatorReviewRejected => 'Запрошены изменения ресурса';

  @override
  String creatorReviewState(Object state) {
    return 'Состояние проверки: $state';
  }

  @override
  String get creatorOperationWorking => 'Выполняется';

  @override
  String get creatorProcessingImage => 'Обработка изображения';

  @override
  String get creatorOperationRefreshing => 'Обновление данных автора';

  @override
  String get creatorOperationCreating => 'Создание ресурса';

  @override
  String get creatorOperationCreatingCollection => 'Создание подборки';

  @override
  String get creatorOperationSaving => 'Сохранение изменений';

  @override
  String get creatorOperationDeleting => 'Удаление';

  @override
  String get creatorOperationSubmitting => 'Отправка на проверку';

  @override
  String get creatorOperationAuthorizing => 'Ожидание авторизации';

  @override
  String get creatorResolvingPublicationTarget =>
      'Определение категории публикации';

  @override
  String get creatorStateApproved => 'Одобрено';

  @override
  String get creatorStateExternalReview => 'Внешняя проверка';

  @override
  String get creatorStateFailed => 'Публикация не выполнена';

  @override
  String get creatorStateSuperseded => 'Заменено новой редакцией';

  @override
  String get creatorStateCancelled => 'Отменено';

  @override
  String get creatorNoResources => 'Ресурсы ещё не созданы';

  @override
  String get creatorLoginRequiredTitle =>
      'Войдите, чтобы использовать центр автора';

  @override
  String get creatorLoginRequiredDescription =>
      'Войдите в BandBBS и подключите аккаунт OronBox перед созданием, редактированием и отправкой ресурсов';

  @override
  String get creatorLoginAction => 'Войти в BandBBS';

  @override
  String get creatorBandBbsWriteReady => 'Публикация в BandBBS разрешена';

  @override
  String get creatorBandBbsWriteMissing =>
      'Публикация в BandBBS не авторизована';

  @override
  String get creatorGitHubOwnPublishReady => 'GitHub подключён';

  @override
  String get creatorGitHubOwnPublishMissing => 'GitHub не подключён';

  @override
  String get creatorAuthorize => 'Авторизовать';

  @override
  String get installQueueFixWatchfaceId => 'Исправить ID циферблата';

  @override
  String get installQueueFixWatchfaceIdHint => 'Введите не более 12 цифр';

  @override
  String get authorize => 'Авторизовать';

  @override
  String get creatorBandBbsAuthorized =>
      'Публикация ресурсов BandBBS авторизована';

  @override
  String get creatorBandBbsAuthorizationRequired =>
      'Отдельно авторизуйте OronBox для публикации ресурсов BandBBS от вашего имени';

  @override
  String get connect => 'Подключить';

  @override
  String get legalAndPrivacy => 'Правовые вопросы и конфиденциальность';

  @override
  String get termsTitle => 'Условия и отказ от ответственности';

  @override
  String get privacyTitle => 'Уведомление о конфиденциальности';

  @override
  String get resourcePublishingTitle => 'Соглашение о публикации ресурсов';

  @override
  String get reviewRulesTitle => 'Правила проверки ресурсов';

  @override
  String get joinQqGroup => 'Вступить в группу QQ';

  @override
  String get joinQqGroupDesc =>
      'Общайтесь с разработчиками и пользователями и получайте помощь';

  @override
  String get feedbackTitle => 'Обратная связь';

  @override
  String get feedbackDesc => 'Отправить отзыв и посмотреть ответы';

  @override
  String get reportResource => 'Пожаловаться на ресурс';

  @override
  String get reportComment => 'Пожаловаться на комментарий';

  @override
  String get report => 'Пожаловаться';

  @override
  String get feedbackSubject => 'Тема';

  @override
  String get feedbackMessage => 'Отзыв или описание проблемы';

  @override
  String get reportReason => 'Причина жалобы';

  @override
  String get noFeedback => 'Обращений пока нет';

  @override
  String get feedbackProcessing => 'Обработка';

  @override
  String get feedbackReplied => 'Есть ответ';

  @override
  String get feedbackOpen => 'Открыто';

  @override
  String get feedbackResolved => 'Решено';

  @override
  String get feedbackDismissed => 'Отклонено';

  @override
  String get feedbackClosed => 'Закрыто';

  @override
  String get feedbackLoading => 'Загрузка обращений';

  @override
  String get feedbackNewTicket => 'Новое обращение';

  @override
  String get feedbackYou => 'Вы';

  @override
  String get feedbackResolution => 'Решение';

  @override
  String get feedbackReplyHint => 'Ответить на обращение';

  @override
  String get feedbackConversationClosed =>
      'Это обращение закрыто, ответить нельзя';

  @override
  String get checkUpdates => 'Проверить обновления';

  @override
  String get updateChecking => 'Проверка обновлений…';

  @override
  String get updateCheckFailed => 'Не удалось проверить обновления';

  @override
  String get latestVersionInstalled => 'Установлена последняя версия';

  @override
  String newVersionAvailable(Object version) {
    return 'Доступна версия $version';
  }

  @override
  String get oobeWelcomeSlogan =>
      'Красивый и быстрый менеджер носимых устройств VelaOS и ZeppOS на Flutter';

  @override
  String get oobeNext => 'Далее';

  @override
  String get oobeBack => 'Назад';

  @override
  String get oobeFeatureDevicesTitle => 'Подключение устройств';

  @override
  String get oobeFeatureDevicesBody =>
      'Подключайте и управляйте устройствами VelaOS и ZeppOS';

  @override
  String get oobeFeatureResourcesTitle => 'Центр ресурсов';

  @override
  String get oobeFeatureResourcesBody =>
      'Поддерживаются источники OronBox, AstroBox-Repo, BandBBS и магазин приложений Amazfit';

  @override
  String get oobeFeaturePluginsTitle => 'Плагины JavaScript';

  @override
  String get oobeFeaturePluginsBody =>
      'Быстрая и расширяемая система плагинов JavaScript с управлением устройствами';

  @override
  String get oobeFeaturePlatformsTitle => 'Несколько платформ';

  @override
  String get oobeFeaturePlatformsBody =>
      'Доступно на Android, Windows, macOS, Linux и в веб-версии';

  @override
  String get oobeOpenSourceTitle => 'Полностью открытый код';

  @override
  String get oobeOpenSourceBody =>
      'Клиент и сервер OronBox распространяются по GNU AGPL-3.0 с полностью открытым исходным кодом';

  @override
  String get oobeAgreementHint => 'Прочитайте текст и прокрутите его до конца';

  @override
  String get oobeAgreeCheckbox => 'Я прочитал и согласен';

  @override
  String get oobeDeclineExit => 'Выйти';

  @override
  String get oobeDeclineWebHint =>
      'Для продолжения примите соглашения и закройте эту страницу';

  @override
  String get oobeLoginTitle => 'Подключите аккаунты';

  @override
  String get oobeLoginBandBbsDesc =>
      'Войдите в BandBBS, чтобы пользоваться ресурсами сообщества и функциями автора';

  @override
  String get oobeLoginLocalNote =>
      'Вход в Xiaomi и Amazfit выполняется только на этом устройстве; соответствующие данные не передаются третьим сторонам, кроме Xiaomi/Amazfit';

  @override
  String get oobeLoginXiaomiDesc =>
      'Войдите в Xiaomi, чтобы синхронизировать привязанные устройства';

  @override
  String get oobeLoginHuamiDesc =>
      'Войдите в Amazfit, чтобы пользоваться ресурсами магазина приложений Amazfit';

  @override
  String get oobeCdnTesting => 'Проверка…';

  @override
  String get oobeCdnSelected => 'Выбран лучший CDN';

  @override
  String get oobeCdnTitle => 'Тест скорости GitHub CDN';

  @override
  String get oobeDoneTitle => 'Всё готово';

  @override
  String get oobeDoneBody => 'Начните знакомство с OronBox';

  @override
  String get oobeFinish => 'Готово';

  @override
  String get settingsReplayOobe => 'Повторить знакомство';

  @override
  String get settingsReplayOobeDesc =>
      'Снова открыть приветственное руководство и первоначальную настройку';

  @override
  String get creatorConnect => 'Подключить';

  @override
  String get comments => 'Комментарии';

  @override
  String get commentEmpty => 'Комментариев пока нет';

  @override
  String get commentHint => 'Напишите комментарий';

  @override
  String get commentLoginRequired => 'Войдите в BandBBS, чтобы комментировать';

  @override
  String get commentPending => 'На проверке';

  @override
  String get commentBlocked =>
      'Комментарий не соответствует правилам сообщества';

  @override
  String get commentModerationUnavailable =>
      'Проверка комментариев временно недоступна';

  @override
  String get commentRateLimited => 'Вы комментируете слишком часто';

  @override
  String get commentReplying => 'Ответить на комментарий';

  @override
  String get loadMore => 'Загрузить ещё';

  @override
  String get more => 'Ещё';

  @override
  String get reply => 'Ответить';

  @override
  String get inbox => 'Входящие';

  @override
  String get inboxLoading => 'Загрузка сообщений';

  @override
  String get inboxEmpty => 'Сообщений нет';

  @override
  String get inboxClear => 'Очистить сообщения';

  @override
  String get inboxClearFailed =>
      'Не удалось очистить сообщения. Повторите позже';

  @override
  String get cleanMode => 'Переключатели функций';

  @override
  String get cleanModeDescription =>
      'Управление навигацией, функциями сообщества и источниками ресурсов';

  @override
  String get cleanPluginsEntry => 'Раздел плагинов';

  @override
  String get cleanSourceHuamiAppStore => 'Магазин приложений Amazfit';

  @override
  String get announcementAcknowledge => 'Понятно';

  @override
  String get cleanHomeFeed => 'Лента главной';

  @override
  String get cleanExplore => 'Библиотека ресурсов';

  @override
  String get cleanInbox => 'Входящие';

  @override
  String get cleanAnnouncements => 'Всплывающие объявления';

  @override
  String get cleanComments => 'Комментарии';

  @override
  String get cleanCreator => 'Центр автора';

  @override
  String get cleanBandBbsLogin => 'Вход BandBBS';

  @override
  String get cleanGitHubLogin => 'Вход GitHub';

  @override
  String get cleanSourceOronBox => 'Источник OronBox';

  @override
  String get cleanSourceBandBbs => 'Источник BandBBS';

  @override
  String get cleanSourceAstroBox => 'Источник AstroBox';

  @override
  String get cleanExploreEntry => 'Раздел библиотеки';

  @override
  String get cleanNavigationGroup => 'Основная навигация';

  @override
  String get cleanExploreContentGroup => 'Содержимое библиотеки';

  @override
  String get cleanHomeSectionsGroup => 'Разделы главной';

  @override
  String get cleanHomeBanner => 'Баннеры';

  @override
  String get cleanHomeEditorSections => 'Редакторские разделы';

  @override
  String get cleanResourceSourcesGroup => 'Источники ресурсов';

  @override
  String get cleanCommunityGroup => 'Функции сообщества';

  @override
  String get settingsCategoryAccounts => 'Аккаунты и авторизация';

  @override
  String get settingsCategoryAppearance => 'Внешний вид и навигация';

  @override
  String get settingsCategoryConnection => 'Подключения и загрузки';

  @override
  String get settingsCategorySupport => 'Поддержка и информация';

  @override
  String get settingsCategoryAdvanced => 'Расширенные настройки';

  @override
  String get settingsAdvancedDescription =>
      'Журналы и инструменты разработчика';

  @override
  String get debugServerTitle => 'Сервис отладки';

  @override
  String get debugServerDescription =>
      'Локальный API для доверенных инструментов разработки';

  @override
  String get debugServerEnable => 'Включить сервис отладки';

  @override
  String get debugServerEnableDescription =>
      'Разрешить одобренным клиентам в локальной сети просматривать и управлять OronBox';

  @override
  String get debugServerEndpoint => 'Адрес';

  @override
  String get debugServerFingerprint => 'Отпечаток сервера';

  @override
  String get debugServerPendingClients => 'Ожидают одобрения';

  @override
  String get debugServerAuthorizedClients => 'Одобренные клиенты';

  @override
  String get debugServerApprove => 'Одобрить';

  @override
  String get debugServerReject => 'Отклонить';

  @override
  String get debugServerRevoke => 'Отозвать доступ';

  @override
  String get debugServerNoPendingClients => 'Нет клиентов, ожидающих одобрения';

  @override
  String get debugServerNoAuthorizedClients => 'Нет одобренных клиентов';

  @override
  String get debugServerSecurityNotice =>
      'Включайте сервис только в доверенной сети';

  @override
  String get debugServerStartFailed => 'Не удалось запустить сервис отладки';

  @override
  String get debugServerStopFailed => 'Не удалось остановить сервис отладки';

  @override
  String get xmsDeveloperMode => 'Режим разработчика XMS';

  @override
  String get xmsDeveloperModeDescription =>
      'Разрешить Android-подписям приложений отличаться';

  @override
  String get oronBoxCoinsTitle => 'Монеты ресурсов';

  @override
  String oronBoxCoinsBalance(String balance) {
    return 'Баланс монет: $balance';
  }

  @override
  String get oronBoxCoinsCheckin => 'Отметиться';

  @override
  String get oronBoxCoinsCheckedIn => 'Отметка выполнена';

  @override
  String oronBoxCoinsCheckinReward(int count) {
    return 'Получено монет: $count';
  }

  @override
  String get oronBoxCoinsDescription =>
      'Отмечайтесь каждый день и получайте 1–5 монет для поддержки авторов';

  @override
  String resourceFromCollection(String name) {
    return 'Из подборки $name';
  }

  @override
  String get resourceCoin => 'Монета';

  @override
  String get resourceCoinNotSignedIn => 'Вход не выполнен';

  @override
  String get resourceCoinDialogTitle => 'Отправить монеты ресурсу';

  @override
  String get resourceCoinDialogMessage =>
      'Отправить монеты этому ресурсу?\\nОтменить действие нельзя\\n\\nМонеты помогают ресурсу получить больше внимания\\nАвтор получает 10% внесённой суммы\\nОтметьтесь в Настройки → аккаунт BandBBS, чтобы получать монеты';

  @override
  String get resourceCoinOne => 'Отправить 1 монету';

  @override
  String get resourceCoinTwo => 'Отправить 2 монеты';

  @override
  String resourceCoinCount(int count) {
    return 'Монет: $count';
  }

  @override
  String get resourceCoinSuccess => 'Монета отправлена';

  @override
  String get resourceCoinVoted => 'Монета отправлена';

  @override
  String get resourceFeatured => 'Рекомендуемое';

  @override
  String get resourceCollection => 'Подборка';

  @override
  String resourceCollectionType(String type) {
    return 'Подборка: $type';
  }

  @override
  String get creatorCollections => 'Подборки ресурсов';

  @override
  String get creatorCollectionTag => 'Подборка';

  @override
  String get creatorNewCollection => 'Новая подборка';

  @override
  String get creatorMoveToCollection => 'Переместить в подборку';

  @override
  String creatorMoveToCollectionConfirm(int count) {
    return 'Переместить выбранные ресурсы ($count) в эту подборку?';
  }

  @override
  String get creatorDissolveCollection => 'Расформировать подборку';

  @override
  String get creatorResourceList => 'Ресурсы';

  @override
  String get creatorAdditionalLinks => 'Дополнительные ссылки';

  @override
  String get creatorAddLink => 'Добавить ссылку';

  @override
  String get creatorLinkTitle => 'Название ссылки';

  @override
  String get creatorLinkUrl => 'URL ссылки';

  @override
  String get creatorCollectionName => 'Название подборки';

  @override
  String get creatorCollectionSummary => 'Описание подборки';

  @override
  String get creatorCollectionRepresentative => 'Представительный ресурс';

  @override
  String get creatorCollectionDeleteConfirm =>
      'Удалить эту подборку? Ресурсы будут только отвязаны';

  @override
  String get creatorContentAttributes => 'Атрибуты содержимого';

  @override
  String get creatorConfirm => 'Подтвердить';

  @override
  String get creatorCollectionAddResource => 'Добавить в подборку';

  @override
  String creatorCollectionResourceCount(int count) {
    return 'Ресурсов: $count';
  }

  @override
  String communityImportSelected(int count) {
    return 'Выбрано: $count';
  }

  @override
  String get communityImportResultCreated => 'Черновик создан';

  @override
  String get communityImportResultFailed => 'Ошибка';

  @override
  String get communityImportUnsupported => 'Этот тип пока нельзя импортировать';

  @override
  String get communityImportDuplicate => 'Уже существует в центре автора';

  @override
  String get communityImportNoArtifacts => 'Нет файлов ресурсов для импорта';

  @override
  String get creatorImportExternal =>
      'Импортировать существующие ресурсы с других платформ';

  @override
  String get creatorNewResourceDescription =>
      'Создайте и поддерживайте ресурс в OronBox';

  @override
  String get creatorNewCollectionDescription =>
      'Создайте подборку связанных ресурсов';

  @override
  String get creatorImportExternalDescription =>
      'Эксперимент: импорт существующих ресурсов из BandBBS или AstroBox-Repo';

  @override
  String get creatorImportAlreadyImported => 'Импортировано и связано';

  @override
  String get creatorImportReviewNotice =>
      'Импортированное содержимое может быть неполным или распознано неверно. Проверьте и исправьте каждое поле перед отправкой';

  @override
  String get creatorImportLogTitle => 'Журнал обработки';

  @override
  String get communityImportPickerEmpty => 'Ресурсов нет';

  @override
  String get creatorWizardChooseAction => 'Создать';

  @override
  String get creatorImportSelectTitle => 'Выберите ресурсы';

  @override
  String get creatorImportProgressTitle => 'Импорт';

  @override
  String get creatorImportResultTitle => 'Результат импорта';

  @override
  String get creatorImportGitHubHint =>
      'Подключите GitHub, чтобы увидеть ресурсы AstroBox';

  @override
  String get creatorImportGitHubConnect => 'Подключить GitHub';

  @override
  String get creatorImportStageDetails => 'Получение сведений';

  @override
  String get creatorImportStageDownloading => 'Загрузка файлов';

  @override
  String get creatorImportStageMedia => 'Обработка изображений';

  @override
  String get creatorImportStageUploading => 'Создание черновика';

  @override
  String get creatorImportContinue => 'Импортировать ещё';

  @override
  String get creatorImportPartialFailureTitle =>
      'Некоторые ресурсы не удалось прочитать';

  @override
  String creatorImportPartialFailureMessage(int count) {
    return 'Не удалось прочитать ресурсов: $count\\nМожно повторить для неудачных элементов или продолжить с успешно прочитанными';
  }

  @override
  String get creatorImportRetryFailed => 'Повторить неудачные элементы';

  @override
  String get creatorImportContinuePartial => 'Продолжить всё равно';

  @override
  String creatorImportWarnings(int count) {
    return 'Предупреждений: $count';
  }

  @override
  String get creatorDeleteExternalBandbbs => 'Также удалить ресурсы BandBBS';

  @override
  String get creatorDeleteExternalAstrobox =>
      'Также отправить PR на удаление в AstroBox-Repo';

  @override
  String get creatorDeleteExternalWarning =>
      'Удаление на внешних платформах нельзя отменить';

  @override
  String get creatorDeletePrSubmitted => 'PR на удаление отправлен';

  @override
  String githubCdnFallback(Object cdn) {
    return 'Запрос GitHub не выполнен, повтор через $cdn';
  }

  @override
  String get deviceConnectBle => 'Подключить по BLE';

  @override
  String get deviceConnectBtClassic => 'Подключить по BT Classic';

  @override
  String bandBbsIdLabel(Object id) {
    return 'ID BandBBS: $id';
  }

  @override
  String get oobeCdnTestFailed => 'Ошибка';

  @override
  String get settingsGithubCdnAuto => 'Автоматически';

  @override
  String get updateDownloading => 'Загрузка обновления';

  @override
  String get updateInstalling => 'Установка обновления';

  @override
  String get updateFailed => 'Обновление не выполнено';

  @override
  String updateNoApkForAbi(String abi) {
    return 'Для ABI $abi нет APK';
  }

  @override
  String get cleanUpdateGroup => 'Обновления';

  @override
  String get cleanCheckUpdates => 'Проверять обновления при запуске';

  @override
  String get updateLater => 'Позже';

  @override
  String get updateNow => 'Обновить сейчас';

  @override
  String get updateGoToPage => 'Открыть страницу загрузки';

  @override
  String get updateDownloadFromCloud => 'Скачать с облачного диска';

  @override
  String get updateDownloadFromOfficial => 'Скачать с официального сайта';

  @override
  String get creatorImportNoticeTitle => 'Импорт существующих ресурсов';

  @override
  String get creatorImportNoticeMessage =>
      'Ресурсы для нескольких устройств могут публиковаться в нескольких разделах BandBBS\\nПри импорте можно выбрать несколько записей BandBBS, но выбирайте записи одного ресурса\\nНажмите «Импортировать», чтобы объединить их в один ресурс\\nЕсли импорт завершится ошибкой, откройте соответствующий черновик и удалите его\\nУдаление черновика не удаляет связанные ресурсы на других платформах';

  @override
  String get creatorImportNoticeConfirm => 'Продолжить импорт';

  @override
  String get creatorImportSameResourceHint =>
      'При каждом импорте выбирайте только один ресурс';

  @override
  String get creatorFullVersionExternalPurchase => 'Требуется внешняя покупка';

  @override
  String get creatorExternalPurchaseDescription =>
      'OronBox и AstroBox опубликуют файлы ресурса как пробную версию с кнопкой покупки, а BandBBS — как ресурс «Покупка у третьей стороны». Все вопросы, связанные с оплатой, вы решаете самостоятельно';

  @override
  String get creatorExternalPurchaseLink => 'Ссылка для покупки';

  @override
  String get creatorExternalPurchaseAmount => 'Сумма (CNY)';

  @override
  String get creatorExternalPurchaseLinkRequired =>
      'Введите действительную ссылку на внешнюю покупку';

  @override
  String get creatorExternalPurchaseAmountRequired =>
      'Введите действительную сумму в CNY';

  @override
  String get resourcePurchaseFullVersion => 'Внешняя покупка';

  @override
  String get creatorBandBbsOverwritePrevious =>
      'Перезаписать предыдущую публикацию';

  @override
  String get creatorBandBbsOverwritePreviousDescription =>
      'Сначала создать новую версию, затем удалить предыдущую публикацию на BandBBS';

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
  String get deviceHealthDayView => 'День';

  @override
  String get deviceHealthWeekView => 'Неделя';

  @override
  String get deviceHealthMonthView => 'Месяц';

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
  String get deviceHealthSleepStages => 'Фазы сна';

  @override
  String get deviceHealthSleepHrv => 'HRV сна';

  @override
  String get deviceHealthSleepAwake => 'Бодрствование';

  @override
  String get deviceHealthSleepLight => 'Лёгкий сон';

  @override
  String get deviceHealthSleepDeep => 'Глубокий сон';

  @override
  String get deviceHealthSleepRem => 'REM';

  @override
  String get deviceHealthSleepNoStages => 'Нет данных о фазах сна';

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
  String get weatherAutoSyncTitle =>
      'Автоматически синхронизировать данные о погоде';

  @override
  String get weatherAutoSyncDescription =>
      'Автоматически синхронизировать данные о погоде при синхронизации данных устройства';

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
  String get weatherAqiGood => 'Хорошо';

  @override
  String get weatherAqiModerate => 'Умеренно';

  @override
  String get weatherAqiSensitive => 'Вредно для чувствительных групп';

  @override
  String get weatherAqiUnhealthy => 'Вредно';

  @override
  String get weatherAqiVeryUnhealthy => 'Очень вредно';

  @override
  String get weatherAqiHazardous => 'Опасно';

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
    return 'Источник данных: $source';
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
  String get xiaomiScreenshotTitle => 'Снимок экрана устройства';

  @override
  String get xiaomiScreenshotDescription =>
      'Сделайте снимок сочетанием клавиш на устройстве, и он автоматически появится здесь';

  @override
  String get xiaomiScreenshotAction => 'Сделать снимок экрана';

  @override
  String get xiaomiScreenshotLoading => 'Получение…';

  @override
  String get xiaomiScreenshotEmpty => 'Снимков экрана пока нет';

  @override
  String get xiaomiScreenshotFailed => 'Не удалось получить снимок экрана';

  @override
  String xiaomiScreenshotSaved(Object path) {
    return 'Снимок экрана часов сохранён в: $path';
  }
}
