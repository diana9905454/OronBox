import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oronbox/src/core/constants/oronbox_server.dart';
import 'package:oronbox/src/core/network/dio_provider.dart';
import 'package:oronbox/src/core/services/build_info_service.dart';
import 'package:oronbox/src/core/services/shared_prefs_service.dart';
import 'package:oronbox/src/features/accounts/services/bandbbs_auth_service.dart';
import 'package:oronbox/src/features/accounts/services/oronbox_session_client.dart';

/// Only successful receipts are persisted; lifecycle events never queue history.
class ActivityReporter {
  ActivityReporter({
    required this.read,
    required this.write,
    required this.send,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;

  final String? Function(String) read;
  final Future<void> Function(String, String) write;
  final Future<Map<String, dynamic>> Function(String, String, String) send;
  final DateTime Function() clock;
  final Map<String, Future<void>> _pending = {};

  Future<void> report(String user, String version, String platform) {
    final key = 'activity.receipt.${jsonEncode([user, version, platform])}';
    return _pending
        .putIfAbsent(key, () async {
          try {
            final raw = read(key);
            if (raw != null) {
              try {
                final receipt = jsonDecode(raw) as Map<String, dynamic>;
                final offset = receipt['offset_ms'] as int;
                final next = DateTime.parse(
                  receipt['next_day_start'] as String,
                );
                if (clock()
                    .toUtc()
                    .add(Duration(milliseconds: offset))
                    .isBefore(next)) {
                  return;
                }
              } catch (_) {
                /* Ignore an invalid cached receipt. */
              }
            }
            final receipt = await send(user, version, platform);
            final receivedAt = clock().toUtc();
            final server = DateTime.parse(receipt['server_time'] as String);
            final next = DateTime.parse(receipt['next_day_start'] as String);
            if (!next.isAfter(server)) return;
            await write(
              key,
              jsonEncode({
                'offset_ms': server.difference(receivedAt).inMilliseconds,
                'next_day_start': next.toIso8601String(),
              }),
            );
          } catch (_) {
            // Retry only on the next foreground/login event.
          }
        })
        .whenComplete(() {
          _pending.remove(key);
        });
  }
}

class ActivityReportHandler extends ConsumerStatefulWidget {
  const ActivityReportHandler({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<ActivityReportHandler> createState() =>
      _ActivityReportHandlerState();
}

class _ActivityReportHandlerState extends ConsumerState<ActivityReportHandler>
    with WidgetsBindingObserver {
  late final ActivityReporter _reporter;
  final _requests = CancelToken();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final prefs = SharedPrefsService.instance;
    _reporter = ActivityReporter(
      read: prefs.getString,
      write: (key, value) async {
        await prefs.setString(key, value);
      },
      send: (user, version, platform) async {
        final auth = ref.read(bandBbsAuthProvider.notifier);
        final response = await OronBoxSessionClient(auth)
            .send<Map<String, dynamic>>((options) {
              if (!mounted ||
                  ref.read(bandBbsAuthProvider).session?.user['id'] != user) {
                throw StateError('Account changed');
              }
              return ref
                  .read(appDioProvider)
                  .post<Map<String, dynamic>>(
                    '$oronBoxServerBaseUrl/api/v1/activity',
                    data: {'version': version, 'platform': platform},
                    cancelToken: _requests,
                    options: options.copyWith(
                      sendTimeout: const Duration(seconds: 10),
                      receiveTimeout: const Duration(seconds: 10),
                    ),
                  );
            });
        return response.data!;
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _report());
  }

  void _report() {
    if (!mounted ||
        (WidgetsBinding.instance.lifecycleState != null &&
            WidgetsBinding.instance.lifecycleState !=
                AppLifecycleState.resumed)) {
      return;
    }
    final user = ref.read(bandBbsAuthProvider).session?.user['id']?.toString();
    if (user == null || user.isEmpty) return;
    final platform = kIsWeb ? 'web' : defaultTargetPlatform.name.toLowerCase();
    unawaited(_reporter.report(user, BuildInfoService.appVersion, platform));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _report();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      bandBbsAuthProvider.select((state) => state.session?.user['id']),
      (_, _) => _report(),
    );
    return widget.child;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _requests.cancel('Activity handler disposed');
    super.dispose();
  }
}
