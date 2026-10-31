import 'dart:async';

import 'package:segmented_list/segmented_list.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/utils/error_localization.dart';
import 'package:oronbox/src/app/widgets/sys_app_bar.dart';
import 'package:oronbox/src/app/widgets/page_container.dart';
import 'package:oronbox/src/core/constants/style_constants.dart';
import 'package:oronbox/src/core/services/shared_prefs_service.dart';
import 'package:oronbox/src/features/devices/controllers/device_manager.dart';
import 'package:oronbox/src/features/devices/pages/tools/zeppos_map_transfer.dart';
import 'package:oronbox/src/device/core/device_state.dart' as proto;

class ZeppOsMoreFeaturesPage extends ConsumerStatefulWidget {
  const ZeppOsMoreFeaturesPage({super.key});

  @override
  ConsumerState<ZeppOsMoreFeaturesPage> createState() =>
      _ZeppOsMoreFeaturesPageState();
}

class _ZeppOsMoreFeaturesPageState
    extends ConsumerState<ZeppOsMoreFeaturesPage> {
  static const _mirrorIntervalPreferenceKey = 'zeppos.mirror.frame_interval_ms';

  bool _finding = false;
  bool _busy = false;
  bool _mirrorSettingsExpanded = false;
  int _mirrorIntervalMs = 10;
  late final TextEditingController _mirrorIntervalController;
  late final FocusNode _mirrorIntervalFocusNode;

  @override
  void initState() {
    super.initState();
    _mirrorIntervalMs =
        (SharedPrefsService.instance.getInt(_mirrorIntervalPreferenceKey) ?? 10)
            .clamp(10, 250)
            .toInt();
    _mirrorIntervalController = TextEditingController(
      text: '$_mirrorIntervalMs',
    );
    _mirrorIntervalFocusNode = FocusNode()
      ..addListener(_handleMirrorIntervalFocus);
  }

  @override
  void dispose() {
    _mirrorIntervalFocusNode
      ..removeListener(_handleMirrorIntervalFocus)
      ..dispose();
    _mirrorIntervalController.dispose();
    super.dispose();
  }

  Future<void> _showMirror() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (_) => _WatchMirrorSheet(frameIntervalMs: _mirrorIntervalMs),
    );
  }

  void _setMirrorInterval(int interval) {
    setState(() => _mirrorIntervalMs = interval);
    unawaited(
      SharedPrefsService.instance.setInt(
        _mirrorIntervalPreferenceKey,
        interval,
      ),
    );
  }

  void _handleMirrorIntervalFocus() {
    if (!_mirrorIntervalFocusNode.hasFocus) {
      _commitMirrorInterval();
    }
  }

  void _commitMirrorInterval() {
    final parsed = int.tryParse(_mirrorIntervalController.text);
    final interval = (parsed ?? _mirrorIntervalMs).clamp(10, 250).toInt();
    _mirrorIntervalController
      ..text = '$interval'
      ..selection = TextSelection.collapsed(offset: '$interval'.length);
    if (interval != _mirrorIntervalMs) {
      _setMirrorInterval(interval);
    }
  }

  Future<void> _setFinding(bool finding) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(deviceManagerProvider.notifier)
          .setFindingZeppOsDevice(finding);
      if (mounted) setState(() => _finding = finding);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            localizedErrorMessage(AppLocalizations.of(context)!, error),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(deviceManagerProvider);
    final ready = state.protocolState == proto.ProtocolState.ready;

    return Scaffold(
      appBar: SysAppBar(secondary: true, title: Text(l10n.zeppOsMoreFeatures)),
      body: SegmentedList(
        maxWidth: StyleConstants.pageMaxWidth,
        contentPadding: EdgeInsets.only(
          top: 8,
          bottom: bottomContentPadding(context, extra: 16),
        ),
        sections: [
          SegmentedSection(
            title: Text(l10n.zeppOsDeviceFeaturesSection),
            tiles: [
              SegmentedTile.navigation(
                leading: const Icon(Icons.watch_outlined),
                title: Text(l10n.zeppOsScreenMirror),
                description: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.zeppOsScreenMirrorDescription),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 180),
                      alignment: Alignment.topCenter,
                      child: !_mirrorSettingsExpanded
                          ? const SizedBox.shrink()
                          : Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Row(
                                children: [
                                  Text(l10n.zeppOsMirrorInterval),
                                  const Spacer(),
                                  SizedBox(
                                    width: 112,
                                    child: TextField(
                                      controller: _mirrorIntervalController,
                                      focusNode: _mirrorIntervalFocusNode,
                                      enabled: ready,
                                      keyboardType: TextInputType.number,
                                      textInputAction: TextInputAction.done,
                                      textAlign: TextAlign.end,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                        TextInputFormatter.withFunction((
                                          oldValue,
                                          newValue,
                                        ) {
                                          if (newValue.text.isEmpty) {
                                            return newValue;
                                          }
                                          final value = int.tryParse(
                                            newValue.text,
                                          );
                                          return value != null && value <= 250
                                              ? newValue
                                              : oldValue;
                                        }),
                                      ],
                                      decoration: InputDecoration(
                                        isDense: true,
                                        suffixText: 'ms',
                                        helperText:
                                            l10n.zeppOsMirrorIntervalRange,
                                      ),
                                      onChanged: (text) {
                                        final value = int.tryParse(text);
                                        if (value != null &&
                                            value >= 10 &&
                                            value <= 250) {
                                          _setMirrorInterval(value);
                                        }
                                      },
                                      onEditingComplete: () {
                                        _commitMirrorInterval();
                                        _mirrorIntervalFocusNode.unfocus();
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ],
                ),
                trailing: IconButton(
                  tooltip: _mirrorSettingsExpanded
                      ? l10n.collapse
                      : l10n.expand,
                  onPressed: () => setState(
                    () => _mirrorSettingsExpanded = !_mirrorSettingsExpanded,
                  ),
                  icon: AnimatedRotation(
                    turns: _mirrorSettingsExpanded ? .5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: const Icon(Icons.keyboard_arrow_down),
                  ),
                ),
                enabled: ready,
                onPressed: (_) => _showMirror(),
              ),
              SegmentedTile.navigation(
                leading: const Icon(Icons.map_outlined),
                title: Text(l10n.zeppOsOfflineMaps),
                description: Text(l10n.zeppOsOfflineMapsDescription),
                enabled: ready,
                onPressed: (_) => showZeppOsMapTransfer(context),
              ),
            ],
          ),
          SegmentedSection(
            title: Text(l10n.zeppOsAppsAndDevelopmentSection),
            tiles: [
              SegmentedTile.navigation(
                leading: const Icon(Icons.tune),
                title: Text(l10n.zeppOsAppSettings),
                description: Text(l10n.zeppOsAppSettingsDescription),
                enabled: !kIsWeb,
                onPressed: (_) => context.push('/devices/zeppos-more/settings'),
              ),
              SegmentedTile.navigation(
                leading: const Icon(Icons.code),
                title: Text(l10n.zeppOsAppDebug),
                description: Text(l10n.zeppOsAppDebugDescription),
                enabled: ready,
                onPressed: (_) => context.push('/devices/zeppos-more/app-side'),
              ),
            ],
          ),
          SegmentedSection(
            title: Text(l10n.deviceInfoGroupDevice),
            tiles: [
              SegmentedTile.switchTile(
                leading: _busy
                    ? const SizedBox.square(
                        dimension: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.vibration),
                title: Text(l10n.zeppOsFindDevice),
                description: Text(l10n.zeppOsFindDeviceDescription),
                initialValue: _finding,
                enabled: ready && !_busy,
                onToggle: (value) => _setFinding(value ?? false),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WatchMirrorSheet extends ConsumerStatefulWidget {
  const _WatchMirrorSheet({required this.frameIntervalMs});

  final int frameIntervalMs;

  @override
  ConsumerState<_WatchMirrorSheet> createState() => _WatchMirrorSheetState();
}

class _WatchMirrorSheetState extends ConsumerState<_WatchMirrorSheet> {
  Uint8List? _frame;
  Object? _error;
  bool _active = true;

  @override
  void initState() {
    super.initState();
    _loop();
  }

  Future<void> _loop() async {
    while (mounted && _active) {
      try {
        final frame = await ref
            .read(deviceManagerProvider.notifier)
            .requestZeppOsScreenshot();
        if (!mounted || !_active) return;
        setState(() {
          _frame = frame;
          _error = null;
        });
        await Future<void>.delayed(
          Duration(milliseconds: widget.frameIntervalMs),
        );
      } catch (error) {
        if (!mounted || !_active) return;
        setState(() => _error = error);
        await Future<void>.delayed(const Duration(seconds: 1));
      }
    }
  }

  @override
  void dispose() {
    _active = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Material(
      color: colors.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.onSurfaceVariant.withValues(alpha: .35),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.zeppOsScreenMirror,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Flexible(
              child: SingleChildScrollView(
                child: _WatchMirror(frame: _frame, error: _error),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WatchMirror extends StatelessWidget {
  const _WatchMirror({required this.frame, required this.error});

  final Uint8List? frame;
  final Object? error;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final android = Theme.of(context).platform == TargetPlatform.android;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: android ? 28 : 0),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: android ? 220 : 320),
          child: AspectRatio(
            aspectRatio: 1,
            child: Semantics(
              label: l10n.zeppOsScreenMirrorSemantics,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (frame == null && error == null)
                    Positioned.fill(
                      child: SvgPicture.asset(
                        'assets/images/devices/xiaomi-watch.svg',
                        colorFilter: ColorFilter.mode(
                          colors.onSurface,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  if (frame == null && error == null)
                    SizedBox(
                      width: 44,
                      height: 44,
                      child: CircularProgressIndicator(
                        color: colors.primary,
                        strokeWidth: 4,
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                  if (frame == null && error != null)
                    _MirrorStatus(
                      icon: Icons.error_outline,
                      text: localizedErrorMessage(l10n, error),
                    ),
                  if (frame != null)
                    Positioned.fill(
                      child: Align(
                        child: FractionallySizedBox(
                          widthFactor: 13 / 16,
                          heightFactor: 13 / 16,
                          child: ClipOval(
                            child: ColoredBox(
                              color: Colors.black,
                              child: Image.memory(
                                frame!,
                                fit: BoxFit.cover,
                                gaplessPlayback: true,
                                errorBuilder: (_, error, _) => _MirrorStatus(
                                  icon: Icons.broken_image_outlined,
                                  text: l10n.zeppOsScreenMirrorUnsupported(
                                    localizedErrorMessage(l10n, error),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (frame != null)
                    Positioned.fill(
                      child: SvgPicture.asset(
                        'assets/images/devices/xiaomi-watch-mirror-shell.svg',
                        colorFilter: ColorFilter.mode(
                          colors.onSurface,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MirrorStatus extends StatelessWidget {
  const _MirrorStatus({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 36),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    ),
  );
}
