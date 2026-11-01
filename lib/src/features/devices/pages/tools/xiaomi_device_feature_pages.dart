import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:segmented_list/segmented_list.dart';
import 'package:segmented_list/tile/segmented_tile_info.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/theme/app_theme.dart';
import 'package:oronbox/src/app/utils/error_localization.dart';
import 'package:oronbox/src/app/widgets/app_state_view.dart';
import 'package:oronbox/src/app/widgets/page_container.dart';
import 'package:oronbox/src/app/widgets/sys_app_bar.dart';
import 'package:oronbox/src/app/widgets/stable_fab.dart';
import 'package:oronbox/src/core/constants/style_constants.dart';
import 'package:oronbox/src/core/models/bt_models.dart';
import 'package:oronbox/src/features/devices/controllers/device_manager.dart';
import 'package:oronbox/src/features/devices/models/xiaomi_device_features.dart';
import 'package:oronbox/src/features/devices/services/xiaomi_sync_preferences.dart';
import 'package:oronbox/src/features/devices/services/xiaomi_weather_sync_service.dart';
import 'package:oronbox/src/device/core/device_state.dart' as proto;

class XiaomiAppOrderPage extends ConsumerStatefulWidget {
  const XiaomiAppOrderPage({super.key});

  @override
  ConsumerState<XiaomiAppOrderPage> createState() => _XiaomiAppOrderPageState();
}

class _XiaomiAppOrderPageState extends ConsumerState<XiaomiAppOrderPage> {
  List<AppInfo> _apps = const [];
  List<AppInfo> _savedApps = const [];
  bool _loading = true;
  bool _saving = false;
  bool _dirty = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    if (_saving) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final apps = await ref
          .read(deviceManagerProvider.notifier)
          .loadXiaomiAppOrder();
      if (mounted) {
        setState(() {
          _apps = List.unmodifiable(apps);
          _savedApps = List.unmodifiable(apps);
          _dirty = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = localizedErrorMessage(
            AppLocalizations.of(context)!,
            error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reorder(int oldIndex, int newIndex) async {
    if (_saving || oldIndex == newIndex) return;
    final next = [..._apps];
    final item = next.removeAt(oldIndex);
    final targetIndex = newIndex.clamp(0, next.length);
    next.insert(targetIndex, item);
    setState(() {
      _apps = next;
      _dirty = true;
    });
  }

  Future<void> _save() async {
    if (_saving || !_dirty) return;
    setState(() => _saving = true);
    try {
      await ref.read(deviceManagerProvider.notifier).setXiaomiAppOrder(_apps);
      if (mounted) {
        setState(() {
          _savedApps = List.unmodifiable(_apps);
          _dirty = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.appOrderSaved)),
        );
      }
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _reset() {
    if (_saving || !_dirty) return;
    setState(() {
      _apps = List.unmodifiable(_savedApps);
      _dirty = false;
    });
  }

  void _showError(Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          localizedErrorMessage(AppLocalizations.of(context)!, error),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(deviceManagerProvider);
    final ready = state.protocolState == proto.ProtocolState.ready;
    return Scaffold(
      appBar: SysAppBar(
        secondary: true,
        title: Text(l10n.appOrderTitle),
        actions: [
          IconButton(
            onPressed: !_loading && !_saving && !_dirty ? _load : null,
            tooltip: l10n.appOrderReload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButtonAnimator: FloatingActionButtonAnimator.noAnimation,
      floatingActionButton: StableFabSwitcher(
        child: _dirty
            ? Column(
                key: const ValueKey('app-order-actions'),
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  StableExtendedFab(
                    heroTag: 'xiaomi-app-order-reset',
                    onPressed: _saving ? null : _reset,
                    icon: const Icon(Icons.undo),
                    label: Text(l10n.appOrderUndo),
                    secondary: true,
                  ),
                  const SizedBox(height: 12),
                  StableExtendedFab(
                    heroTag: 'xiaomi-app-order-save',
                    onPressed: _saving ? null : _save,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(
                      _saving ? l10n.appOrderSaving : l10n.appOrderSave,
                    ),
                    animationKey: _saving,
                  ),
                ],
              )
            : const SizedBox.shrink(key: ValueKey('app-order-actions-empty')),
      ),
      body: !ready
          ? EmptyStateView(
              icon: Icons.bluetooth_disabled_outlined,
              title: l10n.deviceNotConnected,
            )
          : _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? ErrorStateView(
              message: localizedErrorMessage(l10n, _error),
              onRetry: _load,
            )
          : _apps.isEmpty
          ? EmptyStateView(icon: Icons.apps_outlined, title: l10n.appOrderEmpty)
          : Column(
              children: [
                Expanded(
                  child: ReorderableListView.builder(
                    padding: EdgeInsets.only(
                      top: 8,
                      bottom: bottomContentPadding(context, extra: 24),
                    ),
                    itemCount: _apps.length,
                    onReorderItem: _reorder,
                    buildDefaultDragHandles: false,
                    proxyDecorator: (child, _, _) => child,
                    itemBuilder: (context, index) {
                      final app = _apps[index];
                      final title = app.appName.trim().isEmpty
                          ? app.packageName
                          : app.appName;
                      return Center(
                        key: ValueKey(app.packageName),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: StyleConstants.pageMaxWidth,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: SegmentedTileInfo(
                              isTopTile: index == 0,
                              isBottomTile: index == _apps.length - 1,
                              needDivider: index != _apps.length - 1,
                              child: _ReorderableAppTile(
                                index: index,
                                title: title,
                                enabled: !_saving,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

class _ReorderableAppTile extends StatelessWidget {
  const _ReorderableAppTile({
    required this.index,
    required this.title,
    required this.enabled,
  });

  final int index;
  final String title;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final tileInfo = SegmentedTileInfo.of(context);
    final theme = Theme.of(context);
    final radius = cardRadiusFor(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(tileInfo.isTopTile ? radius : 3),
            bottom: Radius.circular(tileInfo.isBottomTile ? radius : 3),
          ),
          child: Material(
            color:
                theme.cardTheme.color ??
                theme.colorScheme.surfaceContainerHighest,
            child: Row(
              children: [
                SizedBox(
                  width: 52,
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: enabled
                            ? theme.colorScheme.primary
                            : theme.disabledColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 22),
                    child: Text(
                      title,
                      style: TextStyle(
                        color: enabled
                            ? theme.colorScheme.onSurface
                            : theme.disabledColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                ReorderableDragStartListener(
                  index: index,
                  enabled: enabled,
                  child: const SizedBox(
                    width: 56,
                    height: 64,
                    child: Center(child: Icon(Icons.drag_handle)),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (tileInfo.needDivider) const SizedBox(height: 2),
      ],
    );
  }
}

class XiaomiAlarmsPage extends ConsumerStatefulWidget {
  const XiaomiAlarmsPage({super.key});

  @override
  ConsumerState<XiaomiAlarmsPage> createState() => _XiaomiAlarmsPageState();
}

class _XiaomiAlarmsPageState extends ConsumerState<XiaomiAlarmsPage> {
  List<XiaomiAlarm> _alarms = const [];
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final alarms = await ref
          .read(deviceManagerProvider.notifier)
          .loadXiaomiAlarms();
      if (mounted) setState(() => _alarms = alarms);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = localizedErrorMessage(
            AppLocalizations.of(context)!,
            error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _add() async {
    final draft = await _editAlarm(
      XiaomiAlarm(
        id: 0,
        hour: TimeOfDay.now().hour,
        minute: TimeOfDay.now().minute,
        clockMode: 0,
        weekDays: 0,
        enabled: true,
        label: '',
      ),
      adding: true,
    );
    if (draft == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(deviceManagerProvider.notifier).addXiaomiAlarm(draft);
      await _load();
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit(XiaomiAlarm alarm) async {
    final edited = await _editAlarm(alarm);
    if (edited == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(deviceManagerProvider.notifier).updateXiaomiAlarm(edited);
      await _load();
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<XiaomiAlarm?> _editAlarm(
    XiaomiAlarm? initial, {
    bool adding = false,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    var label = initial?.label ?? '';
    final originalClockMode = initial?.clockMode ?? 0;
    var clockMode = originalClockMode;
    if (clockMode == 4) clockMode = 2;
    if (![0, 1, 2, 3, 5].contains(clockMode)) clockMode = 0;
    var repeatChanged = false;
    var weekDays = initial?.weekDays ?? 0;
    final selectedTime = TimeOfDay(
      hour: initial?.hour ?? TimeOfDay.now().hour,
      minute: initial?.minute ?? TimeOfDay.now().minute,
    );
    var hourText = selectedTime.hour.toString().padLeft(2, '0');
    var minuteText = selectedTime.minute.toString().padLeft(2, '0');
    final formKey = GlobalKey<FormState>();
    final details = await showDialog<(String, int, int, TimeOfDay)>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(adding ? l10n.alarmAdd : l10n.alarmEdit),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: hourText,
                        onChanged: (value) => hourText = value,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(labelText: l10n.alarmHour),
                        validator: (value) {
                          final hour = int.tryParse(value ?? '');
                          return hour == null || hour < 0 || hour > 23
                              ? '0–23'
                              : null;
                        },
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Text(':'),
                    ),
                    Expanded(
                      child: TextFormField(
                        initialValue: minuteText,
                        onChanged: (value) => minuteText = value,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          labelText: l10n.alarmMinute,
                        ),
                        validator: (value) {
                          final minute = int.tryParse(value ?? '');
                          return minute == null || minute < 0 || minute > 59
                              ? '0–59'
                              : null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  initialValue: clockMode,
                  decoration: InputDecoration(labelText: l10n.alarmRepeat),
                  items: [
                    DropdownMenuItem(value: 0, child: Text(l10n.alarmOnce)),
                    DropdownMenuItem(value: 1, child: Text(l10n.alarmEveryDay)),
                    DropdownMenuItem(value: 2, child: Text(l10n.alarmWorkdays)),
                    DropdownMenuItem(value: 3, child: Text(l10n.alarmHolidays)),
                    DropdownMenuItem(value: 5, child: Text(l10n.alarmCustom)),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() {
                        clockMode = value;
                        repeatChanged = true;
                      });
                    }
                  },
                ),
                if (clockMode == 5) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      for (final (index, label) in [
                        l10n.weekdayMonShort,
                        l10n.weekdayTueShort,
                        l10n.weekdayWedShort,
                        l10n.weekdayThuShort,
                        l10n.weekdayFriShort,
                        l10n.weekdaySatShort,
                        l10n.weekdaySunShort,
                      ].indexed)
                        Expanded(
                          child: Center(
                            child: _AlarmWeekDayButton(
                              label: label,
                              selected: weekDays & (1 << index) != 0,
                              onPressed: () {
                                setDialogState(() {
                                  weekDays ^= 1 << index;
                                });
                              },
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: label,
                  onChanged: (value) => label = value,
                  decoration: InputDecoration(labelText: l10n.alarmLabel),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: clockMode == 5 && weekDays == 0
                  ? null
                  : () {
                      if (!(formKey.currentState?.validate() ?? false)) return;
                      formKey.currentState!.save();
                      Navigator.pop(context, (
                        label.trim(),
                        clockMode,
                        weekDays,
                        TimeOfDay(
                          hour: int.parse(hourText),
                          minute: int.parse(minuteText),
                        ),
                      ));
                    },
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );
    if (details == null) return null;
    final savedClockMode = repeatChanged ? details.$2 : originalClockMode;
    return XiaomiAlarm(
      id: initial?.id ?? 1,
      hour: details.$4.hour,
      minute: details.$4.minute,
      clockMode: savedClockMode,
      weekDays: repeatChanged
          ? switch (savedClockMode) {
              1 => 127,
              2 => 31,
              5 => details.$3,
              _ => 0,
            }
          : initial?.weekDays ?? details.$3,
      enabled: initial?.enabled ?? true,
      label: details.$1,
    );
  }

  Future<void> _toggle(XiaomiAlarm alarm, bool enabled) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(deviceManagerProvider.notifier)
          .setXiaomiAlarmEnabled(alarm.id, enabled);
      await _load();
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(XiaomiAlarm alarm) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.alarmDeleteTitle),
        content: Text('${_time(alarm)} ${alarm.label}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppLocalizations.of(context)!.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(deviceManagerProvider.notifier)
          .removeXiaomiAlarm(alarm.id);
      if (mounted) {
        setState(
          () => _alarms = _alarms
              .where((candidate) => candidate.id != alarm.id)
              .toList(growable: false),
        );
      }
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          localizedErrorMessage(AppLocalizations.of(context)!, error),
        ),
      ),
    );
  }

  String _time(XiaomiAlarm alarm) =>
      '${alarm.hour.toString().padLeft(2, '0')}:${alarm.minute.toString().padLeft(2, '0')}';

  String _alarmDescription(XiaomiAlarm alarm) {
    final l10n = AppLocalizations.of(context)!;
    final repeat = switch (alarm.clockMode) {
      0 => l10n.alarmOnce,
      1 => l10n.alarmEveryDay,
      2 => l10n.alarmWorkdays,
      3 => l10n.alarmHolidays,
      4 => l10n.alarmWorkdays,
      5 => _customWeekDays(l10n, alarm.weekDays),
      6 => l10n.alarmWeekly,
      7 => l10n.alarmMonthly,
      8 => l10n.alarmYearly,
      _ => l10n.alarmNoRepeat,
    };
    return alarm.label.isEmpty ? repeat : '$repeat · ${alarm.label}';
  }

  String _customWeekDays(AppLocalizations l10n, int days) {
    final labels = [
      l10n.weekdayMonShort,
      l10n.weekdayTueShort,
      l10n.weekdayWedShort,
      l10n.weekdayThuShort,
      l10n.weekdayFriShort,
      l10n.weekdaySatShort,
      l10n.weekdaySunShort,
    ];
    final selected = <String>[];
    for (var index = 0; index < labels.length; index++) {
      if (days & (1 << index) != 0) selected.add(labels[index]);
    }
    return selected.isEmpty
        ? l10n.alarmCustom
        : l10n.alarmCustomDays(selected.join('、'));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(deviceManagerProvider);
    final ready = state.protocolState == proto.ProtocolState.ready;
    return Scaffold(
      appBar: SysAppBar(
        secondary: true,
        title: Text(l10n.alarmManagementTitle),
      ),
      floatingActionButtonAnimator: FloatingActionButtonAnimator.noAnimation,
      floatingActionButton: StableFabSwitcher(
        child: ready && !_busy
            ? StableExtendedFab(
                key: const ValueKey('add-alarm'),
                heroTag: 'xiaomi-add-alarm',
                onPressed: _add,
                icon: const Icon(Icons.add),
                label: Text(l10n.alarmAdd),
              )
            : const SizedBox.shrink(key: ValueKey('add-alarm-hidden')),
      ),
      body: !ready
          ? EmptyStateView(
              icon: Icons.bluetooth_disabled_outlined,
              title: l10n.deviceNotConnected,
            )
          : _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? ErrorStateView(
              message: localizedErrorMessage(l10n, _error),
              onRetry: _load,
            )
          : _alarms.isEmpty
          ? EmptyStateView(
              icon: Icons.alarm_off_outlined,
              title: l10n.alarmManagementTitle,
              message: l10n.noContent,
            )
          : SegmentedList(
              maxWidth: StyleConstants.pageMaxWidth,
              contentPadding: EdgeInsets.only(
                top: 8,
                bottom: bottomContentPadding(context, extra: 80),
              ),
              sections: [
                SegmentedSection(
                  tiles: [
                    for (final alarm in _alarms)
                      SegmentedTile.switchTile(
                        key: ValueKey(alarm.id),
                        leading: const Icon(Icons.alarm_outlined),
                        title: Text(_time(alarm)),
                        description: Text(_alarmDescription(alarm)),
                        initialValue: alarm.enabled,
                        enabled: !_busy,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: _busy ? null : () => _edit(alarm),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            IconButton(
                              onPressed: _busy ? null : () => _remove(alarm),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                        onToggle: (value) => _toggle(alarm, value ?? false),
                      ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _AlarmWeekDayButton extends StatelessWidget {
  const _AlarmWeekDayButton({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: selected
          ? context.appSelectionContainer
          : colors.surfaceContainerHigh,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: SizedBox.square(
          dimension: 36,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected
                    ? context.appSelectionForeground
                    : colors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class XiaomiWeatherPage extends ConsumerStatefulWidget {
  const XiaomiWeatherPage({super.key});

  @override
  ConsumerState<XiaomiWeatherPage> createState() => _XiaomiWeatherPageState();
}

class _XiaomiWeatherPageState extends ConsumerState<XiaomiWeatherPage> {
  final _cityController = TextEditingController();
  final _weatherService = XiaomiWeatherSyncService();
  XiaomiWeatherData? _weather;
  DateTime? _lastSyncedAt;
  bool _syncing = false;
  bool _autoSync = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cityController.text = XiaomiSyncPreferences.weatherLastCity ?? '';
    _autoSync = XiaomiSyncPreferences.weatherAutoSync;
    _weather = XiaomiSyncPreferences.cachedWeather;
    _lastSyncedAt = XiaomiSyncPreferences.cachedWeatherSyncedAt;
    if (_cityController.text.trim().isEmpty && _weather != null) {
      _cityController.text = _weather!.cityName;
    }
  }

  @override
  void dispose() {
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _sync() async {
    if (_syncing) return;
    setState(() {
      _syncing = true;
      _error = null;
    });
    try {
      final systemInfo = ref.read(deviceManagerProvider).systemInfo;
      final weather = await _weatherService.fetch(
        _cityController.text,
        model: systemInfo?.model,
        firmwareVersion: systemInfo?.firmwareVersion,
      );
      await ref.read(deviceManagerProvider.notifier).syncXiaomiWeather(weather);
      final syncedAt = DateTime.now();
      await XiaomiSyncPreferences.setWeatherLastCity(weather.cityName);
      await XiaomiSyncPreferences.setCachedWeather(weather, syncedAt);
      if (mounted) {
        setState(() {
          _weather = weather;
          _lastSyncedAt = syncedAt;
          _cityController.text = weather.cityName;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = localizedErrorMessage(
            AppLocalizations.of(context)!,
            error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(deviceManagerProvider);
    final ready = state.protocolState == proto.ProtocolState.ready;
    final weather = _weather;
    return Scaffold(
      appBar: SysAppBar(secondary: true, title: Text(l10n.weatherSyncTitle)),
      body: SegmentedList(
        maxWidth: StyleConstants.pageMaxWidth,
        contentPadding: EdgeInsets.only(
          top: 8,
          bottom: bottomContentPadding(context, extra: 16),
        ),
        sections: [
          CustomSegmentedSection(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _cityController,
                        enabled: ready && !_syncing,
                        decoration: InputDecoration(
                          labelText: l10n.weatherCityLabel,
                          hintText: l10n.weatherCityHint,
                          prefixIcon: const Icon(Icons.location_city_outlined),
                          suffixIcon: const Icon(Icons.search),
                        ),
                        onSubmitted: (_) => _sync(),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: ready && !_syncing ? _sync : null,
                          icon: _syncing
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.sync),
                          label: Text(
                            _syncing
                                ? l10n.weatherSyncing
                                : l10n.weatherSyncAction,
                          ),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          SegmentedSection(
            tiles: [
              SegmentedTile.switchTile(
                title: Text(l10n.weatherAutoSyncTitle),
                description: Text(l10n.weatherAutoSyncDescription),
                initialValue: _autoSync,
                onToggle: (value) {
                  final enabled = value ?? false;
                  setState(() => _autoSync = enabled);
                  unawaited(XiaomiSyncPreferences.setWeatherAutoSync(enabled));
                },
              ),
            ],
          ),
          if (weather != null)
            CustomSegmentedSection(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primaryContainer,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _weatherIcon(weather.conditionCode),
                                size: 34,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onPrimaryContainer,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    weather.cityName,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium,
                                  ),
                                  Text(
                                    '${weather.temperature}℃',
                                    style: Theme.of(context)
                                        .textTheme
                                        .displaySmall,
                                  ),
                                  Text(
                                    _weatherCondition(
                                      l10n,
                                      weather.conditionCode,
                                    ),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyLarge,
                                  ),
                                  if (_lastSyncedAt != null)
                                    Text(
                                      l10n.deviceHealthLastSynced(
                                        _weatherDateTime(_lastSyncedAt!),
                                      ),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall,
                                    ),
                                  Text(
                                    l10n.weatherDataSource(
                                      weather.source.displayName,
                                    ),
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              _publishedLabel(l10n, weather.publishedAt),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final columns = constraints.maxWidth >= 640 ? 4 : 2;
                            const spacing = 12.0;
                            final width =
                                (constraints.maxWidth -
                                    spacing * (columns - 1)) /
                                columns;
                            return Wrap(
                              spacing: spacing,
                              runSpacing: spacing,
                              children: [
                                _WeatherMetric(
                                  width: width,
                                  icon: Icons.water_drop_outlined,
                                  label: l10n.weatherHumidity,
                                  value: '${weather.humidity}%',
                                ),
                                _WeatherMetric(
                                  width: width,
                                  icon: Icons.air,
                                  label: l10n.weatherWind,
                                  value: l10n.weatherLevelDirection(
                                    weather.windSpeedBeaufort,
                                    _windDirection(l10n, weather.windDirection),
                                  ),
                                ),
                                _WeatherMetric(
                                  width: width,
                                  icon: Icons.eco_outlined,
                                  label: l10n.weatherAirQuality,
                                  value: weather.aqi == null
                                      ? l10n.deviceHealthNoData
                                      : 'AQI ${weather.aqi}',
                                ),
                                _WeatherMetric(
                                  width: width,
                                  icon: Icons.wb_sunny_outlined,
                                  label: l10n.weatherUv,
                                  value: '${weather.uvIndex}',
                                ),
                                _WeatherMetric(
                                  width: width,
                                  icon: Icons.speed,
                                  label: l10n.weatherPressure,
                                  value: '${weather.pressureHpa.round()} hPa',
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (weather != null && weather.hourly.isNotEmpty)
            CustomSegmentedSection(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.weatherNext24Hours,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 160,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: weather.hourly.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              final hour = weather.hourly[index];
                              return SizedBox(
                                width: 104,
                                child: Card(
                                  margin: EdgeInsets.zero,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 10,
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(_hourLabel(hour.time)),
                                        Icon(
                                          _weatherIcon(hour.conditionCode),
                                          size: 24,
                                        ),
                                        Text(
                                          '${hour.temperature}℃',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          _weatherCondition(
                                            l10n,
                                            hour.conditionCode,
                                          ),
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall,
                                        ),
                                        Text(
                                          l10n.weatherLevelDirectionCompact(
                                            hour.windSpeedBeaufort,
                                            _windDirection(
                                              l10n,
                                              hour.windDirection,
                                            ),
                                          ),
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (weather != null && weather.daily.isNotEmpty)
            CustomSegmentedSection(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.weatherNext7Days,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        for (final day in weather.daily)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(_weatherIcon(day.conditionCode)),
                            title: Text(_dayLabel(l10n, day.date)),
                            subtitle: Text(
                              l10n.weatherForecastSummary(
                                _weatherCondition(l10n, day.conditionCode),
                                _clockLabel(day.sunrise),
                                _clockLabel(day.sunset),
                              ),
                            ),
                            trailing: Text(
                              '${day.maximumTemperature}℃ / ${day.minimumTemperature}℃',
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _WeatherMetric extends StatelessWidget {
  const _WeatherMetric({
    required this.width,
    required this.icon,
    required this.label,
    required this.value,
  });

  final double width;
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyLarge
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

IconData _weatherIcon(int conditionCode) => switch (conditionCode) {
  0 => Icons.wb_sunny_outlined,
  1 => Icons.wb_cloudy_outlined,
  2 => Icons.cloud_outlined,
  3 || 7 => Icons.grain,
  8 || 9 || 11 => Icons.water_drop_outlined,
  4 || 5 => Icons.thunderstorm_outlined,
  14 || 15 || 16 => Icons.ac_unit_outlined,
  18 || 19 => Icons.foggy,
  _ => Icons.cloud_outlined,
};

String _weatherCondition(AppLocalizations l10n, int conditionCode) =>
    switch (conditionCode) {
      0 => l10n.weatherClear,
      1 => l10n.weatherPartlyCloudy,
      2 => l10n.weatherCloudy,
      3 || 7 => l10n.weatherLightRain,
      8 || 9 || 11 => l10n.weatherHeavyRain,
      4 || 5 => l10n.weatherThunderstorm,
      14 || 15 || 16 => l10n.weatherSnow,
      18 || 19 => l10n.weatherFog,
      _ => l10n.weatherUnknown,
    };

String _hourLabel(String value) {
  if (value.length >= 16) return value.substring(11, 16);
  return value;
}

String _dayLabel(AppLocalizations l10n, String value) {
  if (value.length >= 10) return value.substring(5, 10);
  return value.isEmpty ? l10n.weatherUnknownDate : value;
}

String _clockLabel(String value) {
  if (value.length >= 16) return value.substring(11, 16);
  return '--:--';
}

String _publishedLabel(AppLocalizations l10n, String value) {
  final time = _clockLabel(value);
  return time == '--:--' ? '' : l10n.weatherUpdatedAt(time);
}

String _weatherDateTime(DateTime value) {
  final local = value.toLocal();
  final time =
      '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  return '${local.month}/${local.day} $time';
}

String _windDirection(AppLocalizations l10n, int degrees) {
  final names = [
    l10n.windNorth,
    l10n.windNorthEast,
    l10n.windEast,
    l10n.windSouthEast,
    l10n.windSouth,
    l10n.windSouthWest,
    l10n.windWest,
    l10n.windNorthWest,
  ];
  final normalized = ((degrees % 360) + 360) % 360;
  return names[((normalized + 22.5) ~/ 45) % names.length];
}
