import 'dart:async';

import 'package:dio/dio.dart';

enum GitHubCdn { auto, raw, ghfast, ghproxy }

/// Maximum time allowed for one CDN probe, including connection and response.
const githubCdnProbeTimeout = Duration(seconds: 5);

extension GitHubCdnExtension on GitHubCdn {
  String get displayName {
    return switch (this) {
      GitHubCdn.auto => 'Auto',
      GitHubCdn.raw => 'Raw',
      GitHubCdn.ghfast => 'GHFast',
      GitHubCdn.ghproxy => 'GHProxy',
    };
  }
}

Uri rewriteGithubCdnUri(Uri uri, GitHubCdn cdn) {
  if (cdn == GitHubCdn.auto ||
      cdn == GitHubCdn.raw ||
      !isConvertibleGithubUri(uri)) {
    return uri;
  }

  final origin = uri.toString();
  return switch (cdn) {
    GitHubCdn.auto || GitHubCdn.raw => uri,
    GitHubCdn.ghfast => Uri.parse('https://ghfast.top/$origin'),
    GitHubCdn.ghproxy => Uri.parse('https://gh-proxy.com/$origin'),
  };
}

Future<List<(GitHubCdn cdn, int? milliseconds)>> testGithubCdns({
  Dio? dio,
}) async {
  final client =
      dio ??
      Dio(
        BaseOptions(
          connectTimeout: githubCdnProbeTimeout,
          sendTimeout: githubCdnProbeTimeout,
          receiveTimeout: githubCdnProbeTimeout,
        ),
      );
  const testUrl =
      'https://raw.githubusercontent.com/zxor-org/oronbox/main/README.md';
  final results = await Future.wait(
    GitHubCdn.values.where((cdn) => cdn != GitHubCdn.auto).map((cdn) async {
      return _testGithubCdn(client, testUrl, cdn);
    }),
  );
  if (dio == null) client.close();
  return results;
}

Future<(GitHubCdn cdn, int? milliseconds)> _testGithubCdn(
  Dio client,
  String testUrl,
  GitHubCdn cdn,
) async {
  final uri = rewriteGithubCdnUri(Uri.parse(testUrl), cdn);
  final cancelToken = CancelToken();
  final stopwatch = Stopwatch()..start();
  int? milliseconds;
  try {
    final response = await client
        .headUri(
          uri,
          options: Options(
            connectTimeout: githubCdnProbeTimeout,
            sendTimeout: githubCdnProbeTimeout,
            receiveTimeout: githubCdnProbeTimeout,
          ),
          cancelToken: cancelToken,
        )
        // Dio's phase timeouts do not form a total request deadline.
        .timeout(githubCdnProbeTimeout);
    if (response.statusCode == 200) {
      milliseconds = stopwatch.elapsedMilliseconds;
    }
  } on TimeoutException {
    cancelToken.cancel('GitHub CDN probe timed out');
  } catch (_) {
    // A failed probe is represented by null and excluded from selection.
  } finally {
    stopwatch.stop();
  }
  return (cdn, milliseconds);
}

GitHubCdn? fastestGithubCdn(List<(GitHubCdn cdn, int? milliseconds)> results) {
  final available = results.where((result) => result.$2 != null).toList()
    ..sort((a, b) => a.$2!.compareTo(b.$2!));
  return available.firstOrNull?.$1;
}

String rewriteGithubCdnUrl(String url, GitHubCdn cdn) {
  final uri = Uri.tryParse(url);
  if (uri == null) return url;
  return rewriteGithubCdnUri(uri, cdn).toString();
}

GitHubCdn? githubCdnByName(String name) {
  try {
    return GitHubCdn.values.byName(name);
  } on ArgumentError {
    return null;
  }
}

bool isConvertibleGithubUri(Uri uri) {
  if (uri.scheme != 'https') return false;
  if (uri.host == 'raw.githubusercontent.com' ||
      uri.host == 'gist.githubusercontent.com') {
    return true;
  }
  if (uri.host != 'github.com') return false;

  final path = uri.path;
  return path.contains('/releases/download/') ||
      path.contains('/releases/latest/download/') ||
      path.contains('/archive/');
}
