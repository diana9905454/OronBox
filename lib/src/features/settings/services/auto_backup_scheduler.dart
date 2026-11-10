import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:oronbox/src/host/application_host_provider.dart';

import '../application/app_data_backup.dart';
import '../application/app_data_maintenance.dart';
import '../application/auto_backup_service.dart';

final _log = Logger('AutoBackupScheduler');

class AutoBackupScheduler extends ConsumerStatefulWidget {
  const AutoBackupScheduler({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AutoBackupScheduler> createState() =>
      _AutoBackupSchedulerState();
}

class _AutoBackupSchedulerState extends ConsumerState<AutoBackupScheduler>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _checking = false;
  late final AutoBackupService _autoBackupService;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final host = ref.read(applicationHostProvider);
    final backupService = AppDataBackupService(
      maintenance: <T>(action) => runWithAppDataMaintenance(host, action),
    );
    _autoBackupService = AutoBackupService(backupService: backupService);

    // Initial check after warm-up delay
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted) _checkAndRun();
    });

    // Hourly background check interval
    _timer = Timer.periodic(const Duration(hours: 1), (_) {
      if (mounted) _checkAndRun();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAndRun();
    }
  }

  void _checkAndRun() {
    if (_checking || !mounted) return;
    _checking = true;
    scheduleMicrotask(() async {
      try {
        if (!AutoBackupPreferences.enabled) return;
        final ran = await _autoBackupService.runAutoBackupIfDue();
        if (ran) {
          _log.info('Auto backup successfully completed');
        }
      } catch (e) {
        _log.warning('Auto backup cycle encountered an error', e);
      } finally {
        if (mounted) _checking = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
