import 'dart:io';

import 'package:dio/dio.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/utils/error_localization.dart';
import 'package:oronbox/src/app/widgets/smooth_linear_progress_indicator.dart';
import 'package:oronbox/src/features/settings/services/app_release_assets.dart';
import 'package:oronbox/src/core/network/github_cdn.dart';
import 'package:oronbox/src/core/providers/app_settings_providers.dart';
import 'package:oronbox/src/features/settings/services/oronbox_support_api.dart';

/// Android in-app update: resolves the APK for the device ABI, downloads it
/// through the configured GitHub CDN and hands it to the system installer.
class UpdateDownloadDialog extends ConsumerStatefulWidget {
  const UpdateDownloadDialog({super.key, required this.release});

  final AppReleaseInfo release;

  @override
  ConsumerState<UpdateDownloadDialog> createState() =>
      _UpdateDownloadDialogState();
}

class _UpdateDownloadDialogState extends ConsumerState<UpdateDownloadDialog> {
  static const _channel = MethodChannel('oronbox/installer');

  double _progress = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    try {
      final abi = await _channel.invokeMethod<String>('getSupportedAbi');
      final url = await _resolveApkUrl(abi);
      if (url == null) {
        if (mounted) {
          setState(
            () =>
                _error = AppLocalizations.of(context)!
                    .updateNoApkForAbi(abi ?? '-'),
          );
        }
        return;
      }
      final cdn = ref.read(appSettingsProvider).effectiveCdn;
      final downloadUrl = rewriteGithubCdnUrl(url, cdn);
      final dir = await getApplicationSupportDirectory();
      final apkDir = Directory('${dir.path}/apk');
      await apkDir.create(recursive: true);
      final path = '${apkDir.path}/oronbox.apk';
      Future<void> download(String source) async {
        await Dio().download(
          source,
          path,
          onReceiveProgress: (received, total) {
            if (total > 0 && mounted) {
              setState(() => _progress = received / total);
            }
          },
        );
        if (!mounted) return;
        setState(() => _progress = 1);
      }

      try {
        await download(downloadUrl);
      } on DioException {
        if (downloadUrl == url) rethrow;
        await download(url);
      }
      await _channel.invokeMethod('installApk', {'path': path});
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(
          () =>
              _error = localizedErrorMessage(AppLocalizations.of(context)!, e),
        );
      }
    }
  }

  Future<String?> _resolveApkUrl(String? abi) => resolveAppReleaseAsset(
    Dio(),
    tag: widget.release.tag,
    platform: 'android',
    arch: abi ?? '',
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final error = _error;
    return AlertDialog(
      title: Text('v${widget.release.latestVersion}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (error != null) ...[
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 8),
            Text(l10n.updateFailed),
            const SizedBox(height: 4),
            Text(
              error,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ] else ...[
            SmoothLinearProgressIndicator(value: _progress),
            const SizedBox(height: 8),
            Text(
              _progress >= 1 ? l10n.updateInstalling : l10n.updateDownloading,
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.close),
        ),
      ],
    );
  }
}
