import 'dart:convert';

import 'package:oronbox/src/core/ai/ai_settings_store.dart';
import 'package:oronbox/src/core/ai/openai_compatible_client.dart';

import 'ai_confirmation_parser.dart';

enum AiToolResultStatus {
  success('success'),
  needsInput('needs_input'),
  confirmationRequired('confirmation_required'),
  denied('denied'),
  failed('failed'),
  retryable('retryable'),
  staleTarget('stale_target');

  const AiToolResultStatus(this.wireName);
  final String wireName;
}

/// 工具执行结果
class AiToolExecutionResult {
  final bool success;
  final String output;
  final AiToolResultStatus status;
  final bool requiresConfirmation;
  final PendingAiConfirmation? pendingConfirmation;

  const AiToolExecutionResult({
    required this.success,
    required this.output,
    this.status = AiToolResultStatus.success,
    this.requiresConfirmation = false,
    this.pendingConfirmation,
  });

  factory AiToolExecutionResult.ok(Map<String, dynamic> data) =>
      AiToolExecutionResult(
        success: true,
        status: AiToolResultStatus.success,
        output: jsonEncode({'status': 'success', ...data}),
      );

  factory AiToolExecutionResult.error(
    String message, {
    AiToolResultStatus status = AiToolResultStatus.failed,
  }) => AiToolExecutionResult(
    success: false,
    status: status,
    output: jsonEncode({'status': status.wireName, 'error': message}),
  );

  factory AiToolExecutionResult.needsInput(String message) =>
      AiToolExecutionResult.error(
        message,
        status: AiToolResultStatus.needsInput,
      );

  factory AiToolExecutionResult.confirmation({
    required PendingAiConfirmation pending,
    required String prompt,
  }) => AiToolExecutionResult(
    success: true,
    status: AiToolResultStatus.confirmationRequired,
    requiresConfirmation: true,
    pendingConfirmation: pending,
    output: jsonEncode({
      'status': AiToolResultStatus.confirmationRequired.wireName,
      'prompt': prompt,
      'tool': pending.toolName,
    }),
  );
}

/// 全局 AI 工具注册中心
class AiToolRegistry {
  const AiToolRegistry();

  /// 获取当前已启用的工具定义列表
  List<AiToolDefinition> getAvailableTools() {
    final list = <AiToolDefinition>[];

    // 工具调用模式为禁用时不暴露任何工具
    if (AiSettingsStore.toolPolicy == AiToolPolicy.disabled) {
      return list;
    }

    if (AiSettingsStore.toolDeviceStatus) {
      list.add(
        const AiToolDefinition(
          name: 'get_device_status',
          description: '获取穿戴设备的连接状态、电量与设备基本信息',
          parameters: {'type': 'object', 'properties': {}},
        ),
      );
    }

    if (AiSettingsStore.toolHealthData) {
      list.add(
        const AiToolDefinition(
          name: 'get_health_summary',
          description: '获取穿戴设备今日的健康与活动数据概览，包括步数、活动消耗、距离与心率',
          parameters: {
            'type': 'object',
            'properties': {
              'date': {
                'type': 'string',
                'description': '查询日期，格式 YYYY-MM-DD，缺省为今日',
              },
            },
          },
        ),
      );
    }

    if (AiSettingsStore.toolWeather) {
      list.add(
        const AiToolDefinition(
          name: 'get_weather',
          description: '读取最近一次缓存的地区天气信息',
          parameters: {'type': 'object', 'properties': {}},
        ),
      );
    }

    if (AiSettingsStore.toolSearchResources) {
      list.add(
        const AiToolDefinition(
          name: 'search_resources',
          description: '搜索社区资源并返回简要结果',
          parameters: {
            'type': 'object',
            'properties': {
              'query': {'type': 'string'},
              'source': {'type': 'string'},
            },
            'required': ['query'],
          },
        ),
      );
      list.add(
        const AiToolDefinition(
          name: 'get_resource',
          description: '查看社区资源详情',
          parameters: {
            'type': 'object',
            'properties': {
              'source': {'type': 'string'},
              'id': {'type': 'string'},
            },
            'required': ['source', 'id'],
          },
        ),
      );
    }

    if (AiSettingsStore.toolAppArrangement) {
      list.add(
        const AiToolDefinition(
          name: 'get_app_arrangement',
          description: '读取穿戴设备当前应用排布',
          parameters: {'type': 'object', 'properties': {}},
        ),
      );
      if (AiSettingsStore.toolPolicy == AiToolPolicy.readWrite) {
        list.add(
          const AiToolDefinition(
            name: 'set_app_arrangement',
            description: '修改穿戴设备应用排布，需要用户确认',
            parameters: {
              'type': 'object',
              'properties': {
                'query': {'type': 'string', 'description': '应用名称或包名'},
                'position': {
                  'type': 'integer',
                  'minimum': 1,
                  'description': '目标位置，从 1 开始',
                },
              },
              'required': ['query', 'position'],
            },
          ),
        );
      }
    }

    if (AiSettingsStore.toolPhoneLocation) {
      list.add(
        const AiToolDefinition(
          name: 'get_phone_location',
          description: '获取手机当前定位，需要系统定位权限',
          parameters: {'type': 'object', 'properties': {}},
        ),
      );
    }

    if (AiSettingsStore.toolInstallResources &&
        AiSettingsStore.toolPolicy == AiToolPolicy.readWrite) {
      list.add(
        const AiToolDefinition(
          name: 'install_resource',
          description: '下载并安装社区资源，需要用户确认',
          parameters: {
            'type': 'object',
            'properties': {
              'source': {'type': 'string'},
              'id': {'type': 'string'},
              'file': {'type': 'string'},
              'targetDevice': {
                'type': 'string',
                'description': '目标设备地址，缺省使用当前连接设备',
              },
            },
            'required': ['source', 'id'],
          },
        ),
      );
    }

    if (AiSettingsStore.toolDeleteResources &&
        AiSettingsStore.toolPolicy == AiToolPolicy.readWrite) {
      list.add(
        const AiToolDefinition(
          name: 'delete_resource',
          description: '删除设备上的应用或表盘，需要用户确认',
          parameters: {
            'type': 'object',
            'properties': {
              'kind': {
                'type': 'string',
                'enum': ['app', 'watchface'],
              },
              'id': {'type': 'string'},
            },
            'required': ['kind', 'id'],
          },
        ),
      );
    }

    // 仅在读写模式下暴露具备控制或副作用的工具
    if (AiSettingsStore.toolPolicy == AiToolPolicy.readWrite) {
      if (AiSettingsStore.toolFindDevice) {
        list.add(
          const AiToolDefinition(
            name: 'find_device',
            description: '查找穿戴设备，让手表/手环振动或响铃提示',
            parameters: {
              'type': 'object',
              'properties': {
                'target': {
                  'type': 'string',
                  'enum': ['wearable', 'phone'],
                  'description': '要查找的设备',
                },
                'enabled': {
                  'type': 'boolean',
                  'description': 'true 为开始，false 为停止',
                },
              },
              'required': ['target', 'enabled'],
            },
          ),
        );
      }

      if (AiSettingsStore.toolManageAlarms) {
        list.add(
          const AiToolDefinition(
            name: 'set_alarm',
            description: '在穿戴设备上新建或设置闹钟（此操作属于敏感写操作，需要用户授权确认）',
            parameters: {
              'type': 'object',
              'properties': {
                'hour': {
                  'type': 'integer',
                  'minimum': 0,
                  'maximum': 23,
                  'description': '闹钟小时 (0-23)',
                },
                'minute': {
                  'type': 'integer',
                  'minimum': 0,
                  'maximum': 59,
                  'description': '闹钟分钟 (0-59)',
                },
                'label': {'type': 'string', 'description': '闹钟标签说明，缺省为日常提醒'},
              },
              'required': ['hour', 'minute'],
            },
          ),
        );
      }
    }

    return list;
  }
}
