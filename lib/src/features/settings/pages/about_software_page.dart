import 'package:oronbox/src/features/devices/widgets/device_import_dialog.dart';

import 'dart:async';
import 'dart:io';

import 'package:oronbox/src/core/network/app_http_transport.dart';
import 'package:oronbox/src/features/settings/services/app_release_assets.dart';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:segmented_list/segmented_list.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/utils/error_localization.dart';
import 'package:oronbox/src/app/widgets/app_state_view.dart';
import 'package:oronbox/src/app/widgets/page_container.dart';
import 'package:oronbox/src/app/widgets/sys_app_bar.dart';
import 'package:oronbox/src/app/widgets/app_icon.dart';
import 'package:oronbox/src/features/settings/widgets/interactive_3d_icon.dart';
import 'package:oronbox/src/app/widgets/release_notes_view.dart';
import 'package:oronbox/src/app/widgets/smooth_linear_progress_indicator.dart';
import 'package:oronbox/src/core/constants/app_constants.dart';
import 'package:oronbox/src/core/constants/style_constants.dart';
import 'package:oronbox/src/core/logging/file_log_sink.dart';
import 'package:oronbox/src/core/logging/logging_service.dart';
import 'package:oronbox/src/core/services/build_info_service.dart';
import 'package:oronbox/src/commands/command_protocol.dart';
import 'package:oronbox/src/host/application_host.dart';
import 'package:oronbox/src/host/application_host_provider.dart';
import 'package:oronbox/src/features/settings/services/oronbox_support_api.dart';
import 'package:oronbox/src/features/settings/services/update_check_service.dart';

final _aboutLatestReleaseProvider = FutureProvider.autoDispose
    .family<AppReleaseInfo, String>((ref, language) {
      return ref
          .read(oronBoxSupportApiProvider)
          .latestRelease(
            language: language,
            currentVersion: BuildInfoService.appVersion,
          );
    });

class AboutSoftwarePage extends ConsumerWidget {
  const AboutSoftwarePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: SysAppBar(
        secondary: true,
        title: Text(l10n.settingsAboutSoftware),
      ),
      body: SingleChildScrollView(
        child: PageContainer(
          maxWidth: 1000,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _AboutHeader(),
              const SizedBox(height: 12),
              _Section(
                icon: Icons.people_alt_outlined,
                title: l10n.settingsAboutSoftwareTeam,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final member in AppConstants.teamMembers)
                      _TeamMemberTile(member: member),
                  ],
                ),
              ),
              _Section(
                icon: Icons.gavel_outlined,
                title: l10n.legalAndPrivacy,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final document in [
                      ('terms', l10n.termsTitle),
                      ('privacy', l10n.privacyTitle),
                      ('resource-publishing', l10n.resourcePublishingTitle),
                      ('review-rules', l10n.reviewRulesTitle),
                    ])
                      FilledButton.tonalIcon(
                        onPressed: () => context.push(
                          '/settings/legal/${document.$1}',
                          extra: document.$2,
                        ),
                        icon: const Icon(Icons.article_outlined),
                        label: Text(document.$2),
                      ),
                  ],
                ),
              ),
              _Section(
                icon: Icons.article_outlined,
                title: l10n.changelog,
                child: const _ChangelogSection(),
              ),
              _Section(
                icon: Icons.terminal_outlined,
                title: l10n.settingsAboutSoftwareBuildInfo,
                child: FutureBuilder<String>(
                  future: BuildInfoService.resolveCommitHash(),
                  builder: (context, snapshot) {
                    final commit = snapshot.data ?? 'local';
                    return SelectableText(
                      'APP_VERSION: ${BuildInfoService.appVersion}\n'
                      'GIT_COMMIT_HASH: $commit\n'
                      'BUILD_USER: ${BuildInfoService.buildUser}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontFamily: 'monospace',
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  l10n.settingsAboutSoftwareCopyright,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChangelogSection extends ConsumerWidget {
  const _ChangelogSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final language = Localizations.localeOf(context).languageCode == 'en'
        ? 'en'
        : 'zh';
    final release = ref.watch(_aboutLatestReleaseProvider(language));
    return switch (release) {
      AsyncData(:final value) when value.releaseNotes.isNotEmpty => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'v${value.latestVersion}',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          ReleaseNotesView(data: value.releaseNotes),
        ],
      ),
      AsyncData() || AsyncError() => Text(
        l10n.changelogUnavailable,
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
      _ => const SizedBox(
        height: 40,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
    };
  }
}

String _roleLabel(AppLocalizations l10n, TeamRole role) {
  return switch (role) {
    TeamRole.mainDeveloperDesigner => l10n.settingsTeamRoleMain,
    TeamRole.zeppOSImplementation => l10n.settingsTeamRoleZeppOS,
  };
}

Future<void> _openUrl(String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _AboutHeader extends ConsumerWidget {
  const _AboutHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        const SizedBox(height: 8),
        Interactive3dIcon(size: 72, child: const AppIcon(size: 72)),
        const SizedBox(height: 16),
        Text(
          'OronBox',
          style: Theme.of(context).textTheme.headlineMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          l10n.settingsAboutSoftwareTagline,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: colorScheme.onSurfaceVariant, height: 1.35),
        ),
        const SizedBox(height: 16),
        const _UpdatePill(),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            FilledButton.tonalIcon(
              onPressed: () => _openUrl(AppConstants.githubRepoUrl),
              icon: const Icon(Icons.code_outlined),
              label: Text(l10n.settingsAboutSoftwareRepository),
            ),
            OutlinedButton.icon(
              onPressed: () => context.push('/settings/licenses'),
              icon: const Icon(Icons.description_outlined),
              label: Text(l10n.openSourceLicenses),
            ),
            OutlinedButton.icon(
              onPressed: () => context.push('/settings/acknowledgements'),
              icon: const Icon(Icons.favorite_outline),
              label: Text(l10n.acknowledgements),
            ),
            OutlinedButton.icon(
              onPressed: () => _openUrl(AppConstants.websiteUrl),
              icon: const Icon(Icons.language_outlined),
              label: Text(l10n.settingsAboutWebsite),
            ),
          ],
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _UpdatePill extends ConsumerStatefulWidget {
  const _UpdatePill();

  @override
  ConsumerState<_UpdatePill> createState() => _UpdatePillState();
}

class _UpdatePillState extends ConsumerState<_UpdatePill> {
  var _checking = false;
  AppReleaseInfo? _found;
  var _newest = false;

  Future<void> _check() async {
    final l10n = AppLocalizations.of(context)!;
    if (_checking) return;
    if (_found != null) {
      if (kIsWeb) {
        await _openUrl(_found!.sourceUrl);
        return;
      }
      if (Platform.isAndroid) {
        showDialog<void>(
          context: context,
          builder: (_) => UpdateAvailableDialog(release: _found!),
        );
      } else {
        setState(() => _checking = true);
        final dio = createAppHttpTransport();
        try {
          final url = await resolveCurrentDesktopAppReleaseAsset(
            dio,
            _found!.tag,
          );
          if (url == null) throw StateError(l10n.updateAssetUnavailable);
          await _openUrl(url);
        } catch (error) {
          if (mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(error.toString())));
          }
        } finally {
          dio.close(force: true);
          if (mounted) setState(() => _checking = false);
        }
      }
      return;
    }
    setState(() {
      _checking = true;
      _newest = false;
    });
    try {
      final release = await ref
          .read(oronBoxSupportApiProvider)
          .latestRelease(
            language: Localizations.localeOf(context).languageCode == 'en'
                ? 'en'
                : 'zh',
            currentVersion: BuildInfoService.appVersion,
          );
      if (!mounted) return;
      final current = BuildInfoService.appVersion.split('+').first;
      final latest = release.latestVersion
          .replaceFirst(RegExp(r'^v'), '')
          .split('+')
          .first;
      setState(() {
        _checking = false;
        if (_compareVersions(latest, current) > 0) {
          _found = release;
        } else {
          _newest = true;
        }
      });
      if (_newest) {
        Future<void>.delayed(const Duration(seconds: 2), () {
          if (mounted) setState(() => _newest = false);
        });
      }
    } catch (_) {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final found = _found != null;
    final (icon, label) = _checking
        ? (null, l10n.updateChecking)
        : found
        ? (
            Icons.arrow_downward,
            l10n.newVersionAvailable(_found!.latestVersion),
          )
        : _newest
        ? (Icons.check, l10n.latestVersionInstalled)
        : (
            Icons.sync,
            'v${BuildInfoService.appVersion} · ${l10n.checkUpdates}',
          );
    return FilledButton.tonalIcon(
      style: found
          ? FilledButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: colors.onPrimary,
            )
          : null,
      onPressed: _checking ? null : _check,
      icon: icon == null
          ? const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

int _compareVersions(String a, String b) {
  final left = a.split('.').map((e) => int.tryParse(e) ?? 0).toList(),
      right = b.split('.').map((e) => int.tryParse(e) ?? 0).toList();
  for (
    var i = 0;
    i < (left.length > right.length ? left.length : right.length);
    i++
  ) {
    final l = i < left.length ? left[i] : 0,
        r = i < right.length ? right[i] : 0;
    if (l != r) return l.compareTo(r);
  }
  return 0;
}

const _flatButtonStyle = ButtonStyle(
  elevation: WidgetStatePropertyAll(0),
  shadowColor: WidgetStatePropertyAll(Colors.transparent),
);

class RuntimeLogsPage extends ConsumerStatefulWidget {
  const RuntimeLogsPage({super.key});

  @override
  ConsumerState<RuntimeLogsPage> createState() => _RuntimeLogsPageState();
}

class _RuntimeLogsPageState extends ConsumerState<RuntimeLogsPage> {
  final _log = getLogger('RuntimeLogsPage');
  var _size = 0;
  var _busy = false;
  var _files = const <LogFileInfo>[];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final results = await Future.wait<Object>([
      logDirectorySize(),
      listLogFiles(),
    ]);
    if (mounted) {
      setState(() {
        _size = results[0] as int;
        _files = results[1] as List<LogFileInfo>;
      });
    }
  }

  String _fileSizeLabel(int size) {
    if (size >= 1024 * 1024) {
      return '${(size / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(size / 1024).toStringAsFixed(size < 1024 ? 1 : 0)} KB';
  }

  String get _sizeLabel {
    if (_size >= 1024 * 1024) {
      return '${(_size / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(_size / 1024).toStringAsFixed(0)} KB';
  }

  Future<void> _export() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _busy = true);
    final path = await exportLogsZip();
    if (!mounted) return;
    if (path != null) {
      _log.info('Exported runtime logs to $path');
    }
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          path == null
              ? l10n.settingsAboutLogsEmpty
              : l10n.settingsAboutLogsExported(path),
        ),
      ),
    );
  }

  Future<void> _clear() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.settingsAboutLogsClear),
        content: Text(l10n.settingsAboutLogsClearConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.settingsAboutLogsClear),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await clearLogFiles();
    _log.info('Cleared runtime logs');
    await _reload();
  }

  Future<void> _pullDeviceLogs() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.settingsDeviceLogsPull),
        content: Text(l10n.settingsDeviceLogsTip),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: _flatButtonStyle,
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.settingsDeviceLogsStart),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    final progress = ValueNotifier<double>(0);
    final fileName = ValueNotifier<String>('');
    final cancelling = ValueNotifier<bool>(false);
    var cancelRequested = false;
    final dialogReady = Completer<BuildContext>();
    final host = ref.read(applicationHostProvider);
    final subscription = host.events.listen((event) {
      if (event.event != 'device.log.progress') return;
      progress.value = (event.data['progress'] as num?)?.toDouble() ?? 0;
      fileName.value = (event.data['fileName']?.toString() ?? '')
          .split(RegExp(r'[/\\]'))
          .last;
    });
    final dialogClosed = showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        if (!dialogReady.isCompleted) dialogReady.complete(dialogContext);
        return _DeviceLogProgressDialog(
          progress: progress,
          fileName: fileName,
          cancelling: cancelling,
          onCancel: () async {
            if (cancelRequested) return;
            cancelRequested = true;
            cancelling.value = true;
            await host.execute(
              const OronBoxCommand(method: 'device.logs.cancel'),
            );
          },
        );
      },
    );
    final dialogContext = await dialogReady.future;
    try {
      final result = await host.execute(
        const OronBoxCommand(method: 'device.logs.pull'),
      );
      if (!result.ok) {
        throw result.error ??
            const CommandError('internal', 'Unknown command error');
      }
      final value = (result.value as Map).cast<String, Object?>();
      final bytes = (value['bytes'] as List? ?? const [])
          .whereType<num>()
          .map((item) => item.toInt())
          .toList(growable: false);
      // The in-process mobile host has already written the archive into the
      // shared log directory. Desktop receives the archive from its daemon
      // over IPC and must mirror it into the GUI process's log directory.
      final mirrorToGui = host is! ApplicationHost || value['stored'] != true;
      if (bytes.isNotEmpty && mirrorToGui) {
        await saveDeviceLogFile(value['name']?.toString() ?? '', bytes);
        final currentLog = (value['currentLogBytes'] as List? ?? const [])
            .whereType<num>()
            .map((item) => item.toInt())
            .toList(growable: false);
        if (currentLog.isNotEmpty) {
          await saveDeviceLogFile(
            value['currentLogName']?.toString() ?? 'device-tmp.log',
            currentLog,
          );
        }
      }
      await _reload();
      _log.info('Pulled device logs: ${value['name']}');
      if (mounted && !cancelRequested) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.settingsDeviceLogsSaved(value['name']?.toString() ?? ''),
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted && !cancelRequested) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.settingsDeviceLogsFailed(localizedErrorMessage(l10n, error)),
            ),
          ),
        );
      }
    } finally {
      if (dialogContext.mounted) Navigator.pop(dialogContext);
      await dialogClosed;
      await subscription.cancel();
      progress.dispose();
      fileName.dispose();
      cancelling.dispose();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _syncFromWearableLog() =>
      showWearableLogSyncDialog(context, ref);

  Future<void> _openDirectory() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _LogDisclosureDialog(l10n: l10n),
    );
    if (confirmed != true || !mounted) return;
    final opened = await openLogDirectory();
    if (!opened && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.settingsAboutLogsOpenFailed)));
    }
  }

  Future<void> _openFile(LogFileInfo file) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _LogDisclosureDialog(l10n: l10n),
    );
    if (confirmed != true || !mounted) return;
    final opened = await openLogFile(file);
    if (!opened && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.settingsAboutLogsOpenFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: SysAppBar(
        secondary: true,
        title: Text(l10n.settingsAboutLogs),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: l10n.settingsAboutLogsClear,
            onPressed: _busy || _files.isEmpty ? null : _clear,
          ),
        ],
      ),
      body: SegmentedList(
        maxWidth: StyleConstants.pageMaxWidth,
        contentPadding: EdgeInsets.only(
          top: 8,
          bottom: bottomContentPadding(context, extra: 16),
        ),
        sections: [
          SegmentedSection(
            tiles: [
              SegmentedTile(
                leading: const Icon(Icons.archive_outlined),
                title: Text(l10n.settingsAboutLogsExport),
                description: Text(l10n.settingsAboutLogsSize(_sizeLabel)),
                enabled: !_busy && _files.isNotEmpty,
                onPressed: (_) => _export(),
              ),
              SegmentedTile(
                leading: const Icon(Icons.watch_outlined),
                title: Text(l10n.settingsDeviceLogsPull),
                enabled: !_busy,
                onPressed: (_) => _pullDeviceLogs(),
              ),
              if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
                SegmentedTile(
                  leading: const Icon(Icons.folder_zip_outlined),
                  title: Text(l10n.settingsWearableLogSync),
                  enabled: !_busy,
                  onPressed: (_) => _syncFromWearableLog(),
                ),
              if (!kIsWeb)
                SegmentedTile(
                  leading: const Icon(Icons.folder_open_outlined),
                  title: Text(l10n.settingsAboutLogsOpen),
                  enabled: !_busy,
                  onPressed: (_) => _openDirectory(),
                ),
            ],
          ),
          SegmentedSection(
            title: Text(l10n.settingsLogsFileList),
            tiles: _files.isEmpty
                ? [
                    CustomSegmentedTile(
                      child: (_) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: EmptyStateView(
                          compact: true,
                          icon: Icons.article_outlined,
                          title: l10n.settingsAboutLogsEmpty,
                          message: l10n.settingsAboutLogsDescription,
                        ),
                      ),
                    ),
                  ]
                : _files.map(_fileTile).toList(growable: false),
          ),
        ],
      ),
    );
  }

  AbstractSegmentedTile _fileTile(LogFileInfo file) {
    final l10n = AppLocalizations.of(context)!;
    return SegmentedTile(
      leading: const Icon(Icons.description_outlined),
      title: Text(file.name),
      description: Text(
        '${_fileSizeLabel(file.size)} · ${MaterialLocalizations.of(context).formatShortDate(file.modifiedAt)}',
      ),
      trailing: IconButton(
        icon: Icon(
          defaultTargetPlatform == TargetPlatform.android
              ? Icons.share_outlined
              : Icons.open_in_new,
        ),
        tooltip: l10n.open,
        onPressed: () => _openFile(file),
      ),
      onPressed: (_) => _openFile(file),
    );
  }
}

class _DeviceLogProgressDialog extends StatelessWidget {
  const _DeviceLogProgressDialog({
    required this.progress,
    required this.fileName,
    required this.cancelling,
    required this.onCancel,
  });

  final ValueListenable<double> progress;
  final ValueListenable<String> fileName;
  final ValueListenable<bool> cancelling;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: Text(l10n.settingsDeviceLogsPulling),
        content: ValueListenableBuilder<double>(
          valueListenable: progress,
          builder: (context, value, _) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SmoothLinearProgressIndicator(value: value > 0 ? value : null),
              const SizedBox(height: 12),
              Text(
                value <= 0
                    ? l10n.settingsDeviceLogsWaiting
                    : l10n.settingsDeviceLogsProgress((value * 100).round()),
              ),
              ValueListenableBuilder<String>(
                valueListenable: fileName,
                builder: (context, name, _) => name.isEmpty
                    ? const SizedBox.shrink()
                    : Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
        actions: [
          ValueListenableBuilder<bool>(
            valueListenable: cancelling,
            builder: (context, value, _) => TextButton.icon(
              onPressed: value ? null : onCancel,
              icon: value
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.close, size: 18),
              label: Text(l10n.cancel),
            ),
          ),
        ],
      ),
    );
  }
}

class _LogDisclosureDialog extends StatelessWidget {
  const _LogDisclosureDialog({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded),
        title: Text(l10n.settingsAboutLogsWarningTitle),
        content: Text(l10n.settingsAboutLogsWarningMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.understood),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 10),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _TeamMemberTile extends StatelessWidget {
  const _TeamMemberTile({required this.member});

  final TeamMember member;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => _openUrl(member.githubUrl),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          children: [
            ClipOval(
              child: Image.asset(
                member.avatarAsset,
                width: 44,
                height: 44,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.name,
                    style: Theme.of(context).textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _roleLabel(l10n, member.role),
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: colors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            SvgPicture.asset(
              'assets/images/brands/github.svg',
              width: 20,
              height: 20,
              colorFilter: ColorFilter.mode(
                colors.onSurfaceVariant,
                BlendMode.srcIn,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
