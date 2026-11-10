import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oronbox/src/commands/command_protocol.dart';
import 'package:oronbox/src/core/ai/ai_settings_store.dart';
import 'package:oronbox/src/core/ai/openai_compatible_client.dart';
import 'package:oronbox/src/core/providers/theme_locale_providers.dart';
import 'package:oronbox/src/features/ai/application/ai_tool_registry.dart';
import 'package:oronbox/src/features/ai/application/ai_confirmation_parser.dart';
import 'package:oronbox/src/host/application_host_provider.dart';

/// Routes AI operations through the same command bus used by the UI.
class GlobalAiScheduler {
  GlobalAiScheduler(this._ref);

  final Ref _ref;

  OronBoxCommandBus get _host => _ref.read(applicationHostProvider);

  List<AiToolDefinition> getAvailableTools() {
    if (AiSettingsStore.toolPolicy == AiToolPolicy.disabled) {
      return const [];
    }
    final tools = AiToolRegistry().getAvailableTools();
    if (AiSettingsStore.toolHealthData) {
      tools.addAll([
        const AiToolDefinition(
          name: 'sync_health',
          description: '同步运动健康数据',
          parameters: {'type': 'object', 'properties': {}},
        ),
        const AiToolDefinition(
          name: 'get_health_series',
          description: '读取指定时间范围内的运动健康指标序列',
          parameters: {
            'type': 'object',
            'properties': {
              'metric': {
                'type': 'string',
                'enum': [
                  'activity',
                  'activeCalories',
                  'heartRate',
                  'restingHeartRate',
                  'bloodOxygen',
                  'stress',
                  'vitality',
                ],
              },
              'start': {'type': 'string'},
              'end': {'type': 'string'},
              'limit': {'type': 'integer', 'minimum': 1, 'maximum': 2000},
            },
            'required': ['metric', 'start', 'end'],
          },
        ),
        const AiToolDefinition(
          name: 'get_sleep_details',
          description: '读取指定日期的睡眠详情',
          parameters: {
            'type': 'object',
            'properties': {
              'date': {'type': 'string'},
            },
            'required': ['date'],
          },
        ),
        const AiToolDefinition(
          name: 'list_workouts',
          description: '按时间范围列出运动记录',
          parameters: {
            'type': 'object',
            'properties': {
              'start': {'type': 'string'},
              'end': {'type': 'string'},
              'limit': {'type': 'integer', 'minimum': 1, 'maximum': 100},
              'offset': {'type': 'integer', 'minimum': 0},
            },
            'required': ['start', 'end'],
          },
        ),
        const AiToolDefinition(
          name: 'get_workout_details',
          description: '读取指定运动记录的详细数据',
          parameters: {
            'type': 'object',
            'properties': {
              'workoutId': {
                'type': 'string',
                'description': '由 list_workouts 返回的 workoutId',
              },
            },
            'required': ['workoutId'],
          },
        ),
        const AiToolDefinition(
          name: 'get_health_alerts',
          description: '读取指定范围内的异常健康记录',
          parameters: {
            'type': 'object',
            'properties': {
              'start': {'type': 'string'},
              'end': {'type': 'string'},
            },
            'required': ['start', 'end'],
          },
        ),
      ]);
    }
    if (AiSettingsStore.toolDeviceStatus) {
      tools.addAll([
        const AiToolDefinition(
          name: 'refresh_device_status',
          description: '刷新设备状态、电量、存储和系统信息',
          parameters: {'type': 'object', 'properties': {}},
        ),
        const AiToolDefinition(
          name: 'list_device_apps',
          description: '列出设备上已安装的应用',
          parameters: {'type': 'object', 'properties': {}},
        ),
        const AiToolDefinition(
          name: 'list_watchfaces',
          description: '列出设备上的表盘',
          parameters: {'type': 'object', 'properties': {}},
        ),
        const AiToolDefinition(
          name: 'refresh_battery',
          description: '刷新设备电量信息',
          parameters: {'type': 'object', 'properties': {}},
        ),
        const AiToolDefinition(
          name: 'refresh_storage',
          description: '刷新设备存储信息',
          parameters: {'type': 'object', 'properties': {}},
        ),
        const AiToolDefinition(
          name: 'refresh_system_info',
          description: '刷新设备系统信息',
          parameters: {'type': 'object', 'properties': {}},
        ),
      ]);
    }
    if (AiSettingsStore.toolManageAlarms) {
      tools.addAll([
        const AiToolDefinition(
          name: 'list_alarms',
          description: '列出设备上的闹钟',
          parameters: {'type': 'object', 'properties': {}},
        ),
        if (AiSettingsStore.toolPolicy == AiToolPolicy.readWrite)
          const AiToolDefinition(
            name: 'update_alarm',
            description: '修改设备闹钟，需要用户确认',
            parameters: {
              'type': 'object',
              'properties': {
                'id': {'type': 'integer'},
                'hour': {'type': 'integer', 'minimum': 0, 'maximum': 23},
                'minute': {'type': 'integer', 'minimum': 0, 'maximum': 59},
                'clockMode': {'type': 'integer'},
                'weekDays': {'type': 'integer', 'minimum': 0},
                'enabled': {'type': 'boolean'},
                'label': {'type': 'string'},
              },
              'required': ['id', 'hour', 'minute'],
            },
          ),
        if (AiSettingsStore.toolPolicy == AiToolPolicy.readWrite)
          const AiToolDefinition(
            name: 'remove_alarm',
            description: '删除设备闹钟，需要用户确认',
            parameters: {
              'type': 'object',
              'properties': {
                'id': {'type': 'integer'},
              },
              'required': ['id'],
            },
          ),
        if (AiSettingsStore.toolPolicy == AiToolPolicy.readWrite)
          const AiToolDefinition(
            name: 'set_alarm_enabled',
            description: '启用或停用设备闹钟，需要用户确认',
            parameters: {
              'type': 'object',
              'properties': {
                'id': {'type': 'integer'},
                'enabled': {'type': 'boolean'},
              },
              'required': ['id', 'enabled'],
            },
          ),
      ]);
    }
    return tools;
  }

  Future<AiToolExecutionResult> executeTool({
    required String toolName,
    required Map<String, dynamic> arguments,
    bool isConfirmed = false,
    String deviceId = '',
    String? conversationId,
    String originalUserText = '',
    String? toolCallId,
  }) async {
    final enabled = getAvailableTools().any((tool) => tool.name == toolName);
    if (!enabled) {
      return AiToolExecutionResult.error('该工具当前未启用');
    }
    final targetError = await _validateDeviceTarget(toolName, deviceId);
    if (targetError != null) return targetError;
    switch (toolName) {
      case 'get_device_status':
        return _command(const OronBoxCommand(method: 'device.status'));
      case 'refresh_device_status':
        return _command(const OronBoxCommand(method: 'device.refresh.all'));
      case 'refresh_battery':
        return _command(const OronBoxCommand(method: 'device.refresh.battery'));
      case 'refresh_storage':
        return _command(const OronBoxCommand(method: 'device.refresh.storage'));
      case 'refresh_system_info':
        return _command(const OronBoxCommand(method: 'device.refresh.system'));
      case 'list_device_apps':
        return _command(const OronBoxCommand(method: 'app.list'));
      case 'list_watchfaces':
        return _command(
          const OronBoxCommand(method: 'watchface.list'),
          listKey: 'items',
        );
      case 'list_alarms':
        return _command(
          const OronBoxCommand(method: 'device.xiaomi.alarm.list'),
          listKey: 'items',
        );
      case 'get_health_summary':
        return _healthSummary(arguments);
      case 'sync_health':
        return _command(
          const OronBoxCommand(method: 'device.xiaomi.health.sync'),
        );
      case 'get_health_series':
        return _healthData(arguments, 'samples');
      case 'get_sleep_details':
        return _healthData(arguments, 'sleep');
      case 'list_workouts':
        return _healthData(arguments, 'workouts');
      case 'get_workout_details':
        return _healthData(arguments, 'workouts');
      case 'get_health_alerts':
        return _healthData(arguments, 'abnormalHealthRecords');
      case 'get_weather':
        return _command(
          const OronBoxCommand(method: 'device.xiaomi.weather.cached'),
        );
      case 'search_resources':
        return _command(
          OronBoxCommand(method: 'resource.search', params: arguments),
        );
      case 'get_resource':
        return _command(
          OronBoxCommand(
            method: 'resource.info',
            params: {'ref': '${arguments['source']}:${arguments['id']}'},
          ),
        );
      case 'get_app_arrangement':
        return _command(
          const OronBoxCommand(method: 'device.xiaomi.appOrder.list'),
          listKey: 'apps',
        );
      case 'get_phone_location':
        return _command(const OronBoxCommand(method: 'device.phone.location'));
      case 'set_app_arrangement':
        return _setAppArrangement(
          arguments: arguments,
          isConfirmed: isConfirmed,
          deviceId: deviceId,
          conversationId: conversationId,
          originalUserText: originalUserText,
          toolCallId: toolCallId,
        );
      case 'install_resource':
        return _confirmThenCommand(
          toolName: toolName,
          deviceId: deviceId,
          arguments: arguments,
          isConfirmed: isConfirmed,
          conversationId: conversationId,
          originalUserText: originalUserText,
          toolCallId: toolCallId,
          prompt: _localized(
            '准备下载并安装资源 ${arguments['id']}，请回复“允许执行”或“拒绝执行”（可附带理由）',
            'The resource ${arguments['id']} is ready to download and install. Reply “allow execution” or “reject execution” (optional reason)',
          ),
          command: OronBoxCommand(
            method: 'task.enqueue',
            params: {
              'command': OronBoxCommand(
                method: 'resource.install',
                params: arguments,
              ).toJson(),
            },
          ),
        );
      case 'delete_resource':
        return _confirmThenCommand(
          toolName: toolName,
          deviceId: deviceId,
          arguments: arguments,
          isConfirmed: isConfirmed,
          conversationId: conversationId,
          originalUserText: originalUserText,
          toolCallId: toolCallId,
          prompt: _localized(
            '准备删除设备资源 ${arguments['id']}，请回复“允许执行”或“拒绝执行”（可附带理由）',
            'The device resource ${arguments['id']} is ready to be deleted. Reply “allow execution” or “reject execution” (optional reason)',
          ),
          command: OronBoxCommand(
            method: arguments['kind'] == 'watchface'
                ? 'watchface.remove'
                : 'app.uninstall',
            params: {
              arguments['kind'] == 'watchface' ? 'id' : 'package':
                  arguments['id'],
            },
          ),
        );
      case 'find_device':
        return _command(
          OronBoxCommand(
            method: arguments['target'] == 'phone'
                ? 'device.xiaomi.findPhone'
                : 'device.xiaomi.findWearable',
            params: {'finding': arguments['enabled'] == true},
          ),
        );
      case 'set_alarm':
        return _confirmThenCommand(
          toolName: toolName,
          deviceId: deviceId,
          arguments: arguments,
          isConfirmed: isConfirmed,
          conversationId: conversationId,
          originalUserText: originalUserText,
          toolCallId: toolCallId,
          prompt: _localized(
            '准备设置设备闹钟，请回复“允许执行”或“拒绝执行”（可附带理由）',
            'The device alarm is ready to be set. Reply “allow execution” or “reject execution” (optional reason)',
          ),
          command: OronBoxCommand(
            method: 'device.xiaomi.alarm.add',
            params: arguments,
          ),
        );
      case 'update_alarm':
        return _confirmThenCommand(
          toolName: toolName,
          deviceId: deviceId,
          arguments: arguments,
          isConfirmed: isConfirmed,
          conversationId: conversationId,
          originalUserText: originalUserText,
          toolCallId: toolCallId,
          prompt: _localized(
            '准备修改设备闹钟，请回复“允许执行”或“拒绝执行”（可附带理由）',
            'The device alarm is ready to be updated. Reply “allow execution” or “reject execution” (optional reason)',
          ),
          command: OronBoxCommand(
            method: 'device.xiaomi.alarm.update',
            params: arguments,
          ),
        );
      case 'remove_alarm':
        return _confirmThenCommand(
          toolName: toolName,
          deviceId: deviceId,
          arguments: arguments,
          isConfirmed: isConfirmed,
          conversationId: conversationId,
          originalUserText: originalUserText,
          toolCallId: toolCallId,
          prompt: _localized(
            '准备删除设备闹钟，请回复“允许执行”或“拒绝执行”（可附带理由）',
            'The device alarm is ready to be deleted. Reply “allow execution” or “reject execution” (optional reason)',
          ),
          command: OronBoxCommand(
            method: 'device.xiaomi.alarm.remove',
            params: arguments,
          ),
        );
      case 'set_alarm_enabled':
        return _confirmThenCommand(
          toolName: toolName,
          deviceId: deviceId,
          arguments: arguments,
          isConfirmed: isConfirmed,
          conversationId: conversationId,
          originalUserText: originalUserText,
          toolCallId: toolCallId,
          prompt: _localized(
            '准备修改设备闹钟状态，请回复“允许执行”或“拒绝执行”（可附带理由）',
            'The device alarm state is ready to be changed. Reply “allow execution” or “reject execution” (optional reason)',
          ),
          command: OronBoxCommand(
            method: 'device.xiaomi.alarm.enable',
            params: arguments,
          ),
        );
      default:
        return AiToolExecutionResult.error('未知工具');
    }
  }

  Future<AiToolExecutionResult> _healthSummary(
    Map<String, dynamic> arguments,
  ) async {
    final result = await _host.execute(
      const OronBoxCommand(method: 'device.xiaomi.health.data'),
    );
    if (!result.ok) return _fromResult(result);
    final data = (result.value as Map?)?.cast<String, Object?>() ?? const {};
    final requestedDate = arguments['date']?.toString();
    final dailyRows = (data['daily'] as List?)?.whereType<Map>().toList() ?? [];
    final matchingDaily = dailyRows.where((item) {
      if (requestedDate == null || requestedDate.isEmpty) return true;
      return item['date']?.toString().startsWith(requestedDate) == true;
    }).toList();
    matchingDaily.sort(
      (left, right) => (right['date']?.toString() ?? '').compareTo(
        left['date']?.toString() ?? '',
      ),
    );
    return AiToolExecutionResult.ok({
      'daily': matchingDaily.firstOrNull ?? const {},
      'capabilities': data['capabilities'] ?? const {},
      'lastSyncedAt': data['lastSyncedAt'],
    });
  }

  Future<AiToolExecutionResult> _setAppArrangement({
    required Map<String, dynamic> arguments,
    required bool isConfirmed,
    required String deviceId,
    required String? conversationId,
    required String originalUserText,
    required String? toolCallId,
  }) async {
    final query = arguments['query']?.toString().trim() ?? '';
    final position = (arguments['position'] as num?)?.toInt();
    if (query.isEmpty || position == null || position < 1) {
      return AiToolExecutionResult.needsInput('请提供应用名称和目标位置');
    }
    final listed = await _host.execute(
      const OronBoxCommand(method: 'device.xiaomi.appOrder.list'),
    );
    if (!listed.ok) return _fromResult(listed);
    final apps = (listed.value as List?)?.whereType<Map>().toList() ?? [];
    final needle = query.toLowerCase();
    final matches = apps.where((app) {
      final name = app['name']?.toString().toLowerCase() ?? '';
      final package = app['packageName']?.toString().toLowerCase() ?? '';
      return package == needle || name.contains(needle);
    }).toList();
    if (matches.isEmpty) {
      return AiToolExecutionResult.needsInput('找不到应用 $query');
    }
    if (matches.length > 1) {
      return AiToolExecutionResult.needsInput('找到多个应用，请提供更具体的名称');
    }
    if (position > apps.length) {
      return AiToolExecutionResult.needsInput('目标位置超出应用数量');
    }
    final ordered = [...apps]..remove(matches.single);
    ordered.insert(position - 1, matches.single);
    return _confirmThenCommand(
      toolName: 'set_app_arrangement',
      deviceId: deviceId,
      arguments: arguments,
      isConfirmed: isConfirmed,
      conversationId: conversationId,
      originalUserText: originalUserText,
      toolCallId: toolCallId,
      prompt: _localized(
        '准备把 ${matches.single['name']} 移动到第 $position 位，请回复“允许执行”或“拒绝执行”（可附带理由）',
        'Move ${matches.single['name']} to position $position. Reply “allow execution” or “reject execution” (optional reason)',
      ),
      command: OronBoxCommand(
        method: 'device.xiaomi.appOrder.set',
        params: {'apps': ordered},
      ),
    );
  }

  Future<AiToolExecutionResult> _confirmThenCommand({
    required String toolName,
    required String deviceId,
    required Map<String, dynamic> arguments,
    required bool isConfirmed,
    required String? conversationId,
    required String originalUserText,
    required String? toolCallId,
    required String prompt,
    required OronBoxCommand command,
  }) async {
    if (!isConfirmed) {
      final pending = PendingAiConfirmation(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        deviceId: deviceId,
        toolName: toolName,
        arguments: arguments,
        conversationId: conversationId,
        toolCallId: toolCallId,
        originalUserText: originalUserText,
        description: prompt,
      );
      AiConfirmationManager.instance.addPending(pending);
      return AiToolExecutionResult.confirmation(
        pending: pending,
        prompt: prompt,
      );
    }
    return _command(command);
  }

  Future<AiToolExecutionResult> _healthData(
    Map<String, dynamic> arguments,
    String key,
  ) async {
    final result = await _host.execute(
      const OronBoxCommand(method: 'device.xiaomi.health.data'),
    );
    if (!result.ok) return _fromResult(result);
    final data = (result.value as Map?)?.cast<String, Object?>() ?? const {};
    final value = data[key] ?? const [];
    if (key == 'samples' && arguments['metric'] != null) {
      final metric = arguments['metric'].toString();
      final start = DateTime.tryParse(arguments['start']?.toString() ?? '');
      final end = DateTime.tryParse(arguments['end']?.toString() ?? '');
      final limit = (arguments['limit'] as num?)?.toInt() ?? 2000;
      return AiToolExecutionResult.ok({
        'metric': metric,
        'points': (value as List)
            .whereType<Map>()
            .where((point) {
              final timestamp = DateTime.tryParse(
                point['timestamp']?.toString() ?? '',
              );
              return timestamp != null &&
                  (start == null || !timestamp.isBefore(start)) &&
                  (end == null || timestamp.isBefore(end));
            })
            .where((point) => point['metric']?.toString() == metric)
            .map(
              (point) => {
                'timestamp': point['timestamp'],
                'value': point['value'],
              },
            )
            .take(limit)
            .toList(),
      });
    }
    if (key == 'workouts' &&
        (arguments['workoutId'] != null || arguments['routeId'] != null)) {
      final workoutId =
          arguments['workoutId']?.toString() ?? arguments['routeId'].toString();
      final workout = (value as List).whereType<Map>().firstWhere(
        (item) => _workoutId(item) == workoutId,
        orElse: () => <String, Object?>{},
      );
      if (workout.isEmpty) {
        return AiToolExecutionResult.error(
          '找不到指定运动记录',
          status: AiToolResultStatus.staleTarget,
        );
      }
      return AiToolExecutionResult.ok({
        'workout': {...workout, 'workoutId': workoutId},
      });
    }
    if (key == 'workouts') {
      final start = DateTime.tryParse(arguments['start']?.toString() ?? '');
      final end = DateTime.tryParse(arguments['end']?.toString() ?? '');
      final offset = (arguments['offset'] as num?)?.toInt() ?? 0;
      final limit = (arguments['limit'] as num?)?.toInt() ?? 100;
      final workouts = (value as List).whereType<Map>().where((item) {
        final timestamp = DateTime.tryParse(
          item['startedAt']?.toString() ?? '',
        );
        return timestamp != null &&
            (start == null || !timestamp.isBefore(start)) &&
            (end == null || timestamp.isBefore(end));
      }).toList();
      return AiToolExecutionResult.ok({
        'items': workouts
            .skip(offset)
            .take(limit)
            .map((item) => {...item, 'workoutId': _workoutId(item)})
            .toList(),
        'hasMore': workouts.length > offset + limit,
      });
    }
    if (key == 'sleep') {
      final date = arguments['date']?.toString();
      final items = (value as List).whereType<Map>().where((item) {
        if (date == null || date.isEmpty) return true;
        final started = item['startedAt']?.toString() ?? '';
        final ended = item['endedAt']?.toString() ?? '';
        return started.startsWith(date) || ended.startsWith(date);
      }).toList();
      return AiToolExecutionResult.ok({'items': items});
    }
    if (key == 'abnormalHealthRecords') {
      final start = DateTime.tryParse(arguments['start']?.toString() ?? '');
      final end = DateTime.tryParse(arguments['end']?.toString() ?? '');
      final items = (value as List).whereType<Map>().where((item) {
        final timestamp = DateTime.tryParse(
          item['timestamp']?.toString() ?? '',
        );
        return timestamp != null &&
            (start == null || !timestamp.isBefore(start)) &&
            (end == null || timestamp.isBefore(end));
      }).toList();
      return AiToolExecutionResult.ok({'items': items});
    }
    return AiToolExecutionResult.ok({key: value});
  }

  String _workoutId(Map item) {
    final startedAt = DateTime.tryParse(item['startedAt']?.toString() ?? '');
    final activityType = item['activityType']?.toString() ?? '';
    if (startedAt == null || activityType.isEmpty) return '';
    return '${startedAt.toUtc().millisecondsSinceEpoch}-$activityType';
  }

  Future<AiToolExecutionResult?> _validateDeviceTarget(
    String toolName,
    String deviceId,
  ) async {
    if (deviceId.isEmpty || !_usesWearable(toolName)) return null;
    final result = await _host.execute(
      const OronBoxCommand(method: 'device.status'),
    );
    if (!result.ok) return _fromResult(result);
    final value = (result.value as Map?)?.cast<String, Object?>() ?? const {};
    final device = (value['device'] as Map?)?.cast<String, Object?>();
    final currentId = device?['address']?.toString();
    if (currentId == null || currentId.isEmpty) {
      return AiToolExecutionResult.error(
        '当前没有连接目标设备',
        status: AiToolResultStatus.staleTarget,
      );
    }
    if (currentId.toUpperCase() != deviceId.toUpperCase()) {
      return AiToolExecutionResult.error(
        '当前连接设备已变化，请重新发起操作',
        status: AiToolResultStatus.staleTarget,
      );
    }
    return null;
  }

  bool _usesWearable(String toolName) => switch (toolName) {
    'get_device_status' ||
    'refresh_device_status' ||
    'refresh_battery' ||
    'refresh_storage' ||
    'refresh_system_info' ||
    'list_device_apps' ||
    'list_watchfaces' ||
    'list_alarms' ||
    'get_health_summary' ||
    'sync_health' ||
    'get_health_series' ||
    'get_sleep_details' ||
    'list_workouts' ||
    'get_workout_details' ||
    'get_health_alerts' ||
    'get_app_arrangement' ||
    'set_app_arrangement' ||
    'install_resource' ||
    'delete_resource' ||
    'find_device' ||
    'set_alarm' ||
    'update_alarm' ||
    'remove_alarm' ||
    'set_alarm_enabled' => true,
    _ => false,
  };

  Future<AiToolExecutionResult> _command(
    OronBoxCommand command, {
    String? listKey,
  }) async {
    final result = await _host.execute(command);
    return _fromResult(result, listKey: listKey);
  }

  AiToolExecutionResult _fromResult(CommandResult result, {String? listKey}) {
    if (!result.ok) {
      final code = result.error?.code;
      final status = switch (code) {
        'connection' ||
        'timeout' ||
        'busy' ||
        'download' => AiToolResultStatus.retryable,
        'not_found' ||
        'no_device' ||
        'stale_target' => AiToolResultStatus.staleTarget,
        'permission' || 'forbidden' => AiToolResultStatus.denied,
        _ => AiToolResultStatus.failed,
      };
      return AiToolExecutionResult.error(
        result.error?.message ?? '命令执行失败',
        status: status,
      );
    }
    if (listKey != null) {
      return AiToolExecutionResult.ok({
        listKey: result.value is List ? result.value : const [],
      });
    }
    final value = result.value;
    if (value is Map) {
      return AiToolExecutionResult.ok(value.cast<String, dynamic>());
    }
    return AiToolExecutionResult.ok({'data': value});
  }

  String _localized(String zh, String en) {
    return _ref.read(localeSettingsProvider).materialLocale?.languageCode ==
            'zh'
        ? zh
        : en;
  }
}
