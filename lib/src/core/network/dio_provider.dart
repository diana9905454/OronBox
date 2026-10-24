import 'package:dio/dio.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/widgets/app_scaffold_messenger.dart';
import 'package:oronbox/src/core/network/app_http_transport.dart';
import 'package:oronbox/src/core/network/github_cdn.dart';
import 'package:oronbox/src/core/providers/app_settings_providers.dart';

final appDioProvider = Provider<Dio>((ref) {
  return createAppHttpTransport(
    githubCdn: () => ref.read(appSettingsProvider).effectiveCdn,
    onGithubCdnFallback: (fallback) {
      final messenger = appScaffoldMessengerKey.currentState;
      final context = appScaffoldMessengerKey.currentContext;
      if (messenger == null || context == null) return;
      final l10n = AppLocalizations.of(context);
      if (l10n == null) return;
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.githubCdnFallback(fallback.displayName))),
      );
    },
  );
});
