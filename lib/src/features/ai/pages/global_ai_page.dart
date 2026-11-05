import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/widgets/page_container.dart';
import 'package:oronbox/src/app/widgets/sys_app_bar.dart';
import 'package:oronbox/src/core/ai/ai_models.dart';
import 'package:oronbox/src/core/ai/ai_settings_store.dart';
import 'package:oronbox/src/core/constants/style_constants.dart';
import 'package:oronbox/src/features/ai/widgets/model_selection_dialog.dart';
import 'package:oronbox/src/features/ai/widgets/provider_management_dialog.dart';
import 'package:oronbox/src/features/ai/widgets/test_connection_dialog.dart';
import 'package:oronbox/src/features/ai/widgets/wearable_ai_settings_dialog.dart';
import 'package:oronbox/src/features/ai/widgets/system_prompt_dialog.dart';
import 'package:oronbox/src/features/devices/controllers/device_manager.dart';
import 'package:oronbox/src/features/voice/application/global_voice_assistant_service.dart';
import 'package:segmented_list/segmented_list.dart';

class GlobalAiPage extends ConsumerStatefulWidget {
  const GlobalAiPage({super.key});

  @override
  ConsumerState<GlobalAiPage> createState() => _GlobalAiPageState();
}

class _GlobalAiPageState extends ConsumerState<GlobalAiPage> {
  late bool _globalAiEnabled;
  late bool _streamEnabled;
  late bool _wearableEnabled;

  @override
  void initState() {
    super.initState();
    _loadState();
    ref.read(globalVoiceAssistantServiceProvider);
  }

  void _loadState() {
    setState(() {
      _globalAiEnabled = AiSettingsStore.globalAiEnabled;
      _streamEnabled = AiSettingsStore.streamEnabled;
      _wearableEnabled = AiSettingsStore.wearableEnabled;
    });
  }

  Future<void> _openProviderManagement(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (_) => const ProviderManagementDialog(),
    );
    if (mounted) _loadState();
  }

  Future<void> _openModelSelection(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => const ModelSelectionDialog(),
    );
    if (result == true && mounted) _loadState();
  }

  Future<void> _openTestConnection(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (_) => const TestConnectionDialog(),
    );
  }

  Future<void> _openWearableSettings(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => const WearableAiSettingsDialog(),
    );
    if (result == true && mounted) _loadState();
  }

  Future<void> _openSystemPrompt(BuildContext context) async {
    await showDialog<bool>(
      context: context,
      builder: (_) => const SystemPromptDialog(),
    );
    if (mounted) _loadState();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final providers = AiSettingsStore.providers;
    final activePId = AiSettingsStore.activeProviderId;
    final activeMId = AiSettingsStore.activeModelId;

    final activeProvider = providers
        .where((p) => p.id == activePId)
        .firstOrNull;
    final activeModel = activeProvider?.models
        .where((m) => m.modelId == activeMId)
        .firstOrNull;

    final protocolName = activeModel?.protocol == AiProtocolType.responses
        ? 'Responses'
        : 'Completions';
    final modelDesc = activeModel != null
        ? '${activeProvider?.name ?? ""} · ${activeModel.modelId} ($protocolName)'
        : l10n.globalAiNoModelSelected;

    return Scaffold(
      appBar: SysAppBar(secondary: true, title: Text(l10n.globalAiTitle)),
      body: SegmentedList(
        maxWidth: StyleConstants.pageMaxWidth,
        contentPadding: EdgeInsets.only(
          top: 8,
          bottom: bottomContentPadding(context, extra: 16),
        ),
        sections: [
          // 1. 全局 AI 主开关
          SegmentedSection(
            tiles: [
              SegmentedTile.switchTile(
                leading: const Icon(Icons.auto_awesome),
                title: Text(l10n.globalAiEnableSwitch),
                description: Text(l10n.globalAiEnableSwitchDesc),
                initialValue: _globalAiEnabled,
                onToggle: (v) {
                  final val = v ?? false;
                  AiSettingsStore.globalAiEnabled = val;
                  setState(() => _globalAiEnabled = val);
                  ref
                      .read(deviceManagerProvider.notifier)
                      .updateVoiceSystemState();
                },
              ),
            ],
          ),

          // 2. 开启全局 AI 时展示：提供商、模型设置、测试连接与工具权限
          if (_globalAiEnabled) ...[
            SegmentedSection(
              title: Text(l10n.globalAiSectionModelAndProvider),
              tiles: [
                SegmentedTile(
                  leading: const Icon(Icons.cloud_outlined),
                  title: Text(l10n.globalAiProviders),
                  description: Text(
                    l10n.globalAiProvidersCount(providers.length),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onPressed: _openProviderManagement,
                ),
                SegmentedTile(
                  leading: const Icon(Icons.tune_outlined),
                  title: Text(l10n.globalAiModelSettings),
                  description: Text(modelDesc),
                  trailing: const Icon(Icons.chevron_right),
                  onPressed: _openModelSelection,
                ),
                SegmentedTile(
                  leading: const Icon(Icons.edit_note_outlined),
                  title: Text(l10n.globalAiSystemPrompt),
                  description: Text(l10n.globalAiSystemPromptDescription),
                  trailing: const Icon(Icons.chevron_right),
                  onPressed: _openSystemPrompt,
                ),
                SegmentedTile(
                  leading: const Icon(Icons.network_check_outlined),
                  title: Text(l10n.globalAiTestConnection),
                  description: Text(l10n.globalAiTestConnectionDesc),
                  trailing: const Icon(Icons.chevron_right),
                  onPressed: _openTestConnection,
                ),
                SegmentedTile.switchTile(
                  leading: const Icon(Icons.stream_outlined),
                  title: Text(l10n.globalAiStreamResponse),
                  description: Text(l10n.globalAiStreamResponseDesc),
                  initialValue: _streamEnabled,
                  onToggle: (v) {
                    final val = v ?? false;
                    AiSettingsStore.streamEnabled = val;
                    setState(() => _streamEnabled = val);
                  },
                ),
              ],
            ),

            // 3. 穿戴设备联动
            SegmentedSection(
              title: Text(l10n.globalAiWearableSection),
              tiles: [
                SegmentedTile.switchTile(
                  leading: const Icon(Icons.watch_outlined),
                  title: Text(l10n.globalAiWearableEnable),
                  description: Text(l10n.globalAiWearableEnableDesc),
                  initialValue: _wearableEnabled,
                  onToggle: (v) {
                    final val = v ?? false;
                    AiSettingsStore.wearableEnabled = val;
                    setState(() => _wearableEnabled = val);
                    ref
                        .read(deviceManagerProvider.notifier)
                        .updateVoiceSystemState();
                  },
                ),
                if (_wearableEnabled)
                  SegmentedTile(
                    leading: const Icon(Icons.settings_suggest_outlined),
                    title: Text(l10n.globalAiWearableAdvancedSettings),
                    description: Text(l10n.globalAiWearableAdvancedDesc),
                    trailing: const Icon(Icons.chevron_right),
                    onPressed: _openWearableSettings,
                  ),
              ],
            ),

            // 4. 工具权限范围（只要全局 AI 开启即展示，不受穿戴侧启用开关限制）
            SegmentedSection(
              title: Text(l10n.globalAiToolsScope),
              tiles: [
                SegmentedTile.switchTile(
                  leading: const Icon(Icons.info_outline),
                  title: Text(l10n.globalAiToolDeviceStatus),
                  description: Text(l10n.globalAiToolDeviceStatusDesc),
                  initialValue: AiSettingsStore.toolDeviceStatus,
                  onToggle: (v) {
                    AiSettingsStore.toolDeviceStatus = v ?? true;
                    setState(() {});
                  },
                ),
                SegmentedTile.switchTile(
                  leading: const Icon(Icons.favorite_outline),
                  title: Text(l10n.globalAiToolHealthData),
                  description: Text(l10n.globalAiToolHealthDataDesc),
                  initialValue: AiSettingsStore.toolHealthData,
                  onToggle: (v) {
                    AiSettingsStore.toolHealthData = v ?? true;
                    setState(() {});
                  },
                ),
                SegmentedTile.switchTile(
                  leading: const Icon(Icons.wb_sunny_outlined),
                  title: Text(l10n.globalAiToolWeather),
                  description: Text(l10n.globalAiToolWeatherDesc),
                  initialValue: AiSettingsStore.toolWeather,
                  onToggle: (v) {
                    AiSettingsStore.toolWeather = v ?? true;
                    setState(() {});
                  },
                ),
                SegmentedTile.switchTile(
                  leading: const Icon(Icons.search_outlined),
                  title: Text(l10n.globalAiToolSearchResources),
                  description: Text(l10n.globalAiToolSearchResourcesDesc),
                  initialValue: AiSettingsStore.toolSearchResources,
                  onToggle: (v) {
                    AiSettingsStore.toolSearchResources = v ?? true;
                    setState(() {});
                  },
                ),
                SegmentedTile.switchTile(
                  leading: const Icon(Icons.download_outlined),
                  title: Text(l10n.globalAiToolInstallResources),
                  description: Text(l10n.globalAiToolInstallResourcesDesc),
                  initialValue: AiSettingsStore.toolInstallResources,
                  onToggle: (v) {
                    AiSettingsStore.toolInstallResources = v ?? false;
                    setState(() {});
                  },
                ),
                SegmentedTile.switchTile(
                  leading: const Icon(Icons.delete_outline),
                  title: Text(l10n.globalAiToolDeleteResources),
                  description: Text(l10n.globalAiToolDeleteResourcesDesc),
                  initialValue: AiSettingsStore.toolDeleteResources,
                  onToggle: (v) {
                    AiSettingsStore.toolDeleteResources = v ?? false;
                    setState(() {});
                  },
                ),
                SegmentedTile.switchTile(
                  leading: const Icon(Icons.alarm_outlined),
                  title: Text(l10n.globalAiToolManageAlarms),
                  description: Text(l10n.globalAiToolManageAlarmsDesc),
                  initialValue: AiSettingsStore.toolManageAlarms,
                  onToggle: (v) {
                    AiSettingsStore.toolManageAlarms = v ?? true;
                    setState(() {});
                  },
                ),
                SegmentedTile.switchTile(
                  leading: const Icon(Icons.vibration_outlined),
                  title: Text(l10n.globalAiToolFindDevice),
                  description: Text(l10n.globalAiToolFindDeviceDesc),
                  initialValue: AiSettingsStore.toolFindDevice,
                  onToggle: (v) {
                    AiSettingsStore.toolFindDevice = v ?? true;
                    setState(() {});
                  },
                ),
                SegmentedTile.switchTile(
                  leading: const Icon(Icons.grid_view_outlined),
                  title: Text(l10n.globalAiToolAppArrangement),
                  description: Text(l10n.globalAiToolAppArrangementDesc),
                  initialValue: AiSettingsStore.toolAppArrangement,
                  onToggle: (v) {
                    AiSettingsStore.toolAppArrangement = v ?? false;
                    setState(() {});
                  },
                ),
                SegmentedTile.switchTile(
                  leading: const Icon(Icons.my_location_outlined),
                  title: Text(l10n.globalAiToolPhoneLocation),
                  description: Text(l10n.globalAiToolPhoneLocationDesc),
                  initialValue: AiSettingsStore.toolPhoneLocation,
                  onToggle: (v) {
                    AiSettingsStore.toolPhoneLocation = v ?? false;
                    setState(() {});
                  },
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
