import 'app_release_platform_stub.dart'
    if (dart.library.io) 'app_release_platform_io.dart'
    as runtime;

import 'package:dio/dio.dart';
import 'package:oronbox/src/core/constants/app_constants.dart';
import 'package:oronbox/src/core/network/github_release.dart';

/// A missing asset in this tag never falls back to another release.
Future<String?> resolveAppReleaseAsset(
  Dio dio, {
  required String tag,
  required String platform,
  required String arch,
}) async {
  if (tag.isEmpty || arch.isEmpty) return null;
  final response = await dio.get<Object?>(
    '${AppConstants.githubRepoApiUrl}/releases/tags/${Uri.encodeComponent(tag)}',
    options: Options(headers: {'Accept': 'application/vnd.github+json'}),
  );
  final release = GitHubRelease.fromJson(
    (response.data as Map).cast<String, Object?>(),
  );
  if (release.tagName != tag) return null;
  final suffixes = switch (platform) {
    'android' => ['-android-$arch.apk'],
    'windows' => ['-windows-$arch-setup.exe', '-windows-$arch.zip'],
    'macos' => ['-macos-universal.dmg', '-macos-universal.zip'],
    'linux' => ['-linux-$arch.AppImage'],
    _ => <String>[],
  };
  var matches = release.assets.where((_) => false).toList();
  for (final suffix in suffixes) {
    matches = release.assets.where((a) => a.name.endsWith(suffix)).toList();
    if (matches.isNotEmpty) break;
  }
  if (matches.length != 1) return null;
  final uri = Uri.tryParse(matches.single.downloadUrl);
  if (uri?.scheme != 'https' ||
      uri?.host != 'github.com' ||
      !uri!.path.startsWith(
            '/zxor-org/OronBox/releases/download/${Uri.encodeComponent(tag)}/',
          ) &&
          !uri.path.startsWith(
            '/zxor-org/oronbox/releases/download/${Uri.encodeComponent(tag)}/',
          )) {
    return null;
  }
  return uri.toString();
}

Future<String?> resolveCurrentDesktopAppReleaseAsset(Dio dio, String tag) =>
    resolveAppReleaseAsset(
      dio,
      tag: tag,
      platform: runtime.releasePlatform(),
      arch: runtime.releaseArchitecture(),
    );
