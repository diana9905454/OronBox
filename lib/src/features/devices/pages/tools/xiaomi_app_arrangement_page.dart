import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:segmented_list/segmented_list.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/utils/error_localization.dart';
import 'package:oronbox/src/app/widgets/app_state_view.dart';
import 'package:oronbox/src/app/widgets/page_container.dart';
import 'package:oronbox/src/app/widgets/stable_fab.dart';
import 'package:oronbox/src/app/widgets/sys_app_bar.dart';
import 'package:oronbox/src/core/constants/style_constants.dart';
import 'package:oronbox/src/core/models/bt_models.dart';
import 'package:oronbox/src/device/core/device_state.dart' as proto;
import 'package:oronbox/src/device/xiaomi/protocol/generated/wear_system.pb.dart'
    as pb_system;
import 'package:oronbox/src/features/devices/controllers/device_manager.dart';

sealed class _SortItem {
  const _SortItem();
}

class _AppSortItem extends _SortItem {
  const _AppSortItem({
    required this.app,
    required this.isTopTile,
    required this.isBottomTile,
    required this.needDivider,
  });

  final AppInfo app;
  final bool isTopTile;
  final bool isBottomTile;
  final bool needDivider;
}

class _HeaderSortItem extends _SortItem {
  const _HeaderSortItem({
    required this.type,
    required this.title,
    required this.count,
  });

  final _SortHeaderType type;
  final String title;
  final int count;
}

enum _SortHeaderType { more, hidden }

enum _SortSection { main, more, hidden }

class XiaomiAppArrangementPage extends ConsumerStatefulWidget {
  const XiaomiAppArrangementPage({super.key});

  @override
  ConsumerState<XiaomiAppArrangementPage> createState() =>
      _XiaomiAppArrangementPageState();
}

class _XiaomiAppArrangementPageState
    extends ConsumerState<XiaomiAppArrangementPage> {
  List<AppInfo> _apps = const [];
  List<AppInfo> _savedApps = const [];
  List<_SortItem> _items = const [];

  pb_system.AppLayout? _layout;
  pb_system.AppLayout_Layout? _selectedLayout;
  pb_system.AppLayout_Layout? _savedLayout;

  bool _loading = true;
  bool _saving = false;
  String? _error;
  bool _supportMore = false;

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
      final manager = ref.read(deviceManagerProvider.notifier);
      pb_system.AppLayout? layout;
      try {
        layout = await manager.loadXiaomiAppLayout();
      } catch (_) {
        // Layout loading might not be supported on all device models.
      }

      final apps = await manager.loadXiaomiAppOrder();
      final supportMore = apps.any((a) => a.canMore || a.inMore);

      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        setState(() {
          _layout = layout;
          _selectedLayout = layout?.layout;
          _savedLayout = layout?.layout;
          _apps = List.unmodifiable(apps);
          _savedApps = List.unmodifiable(apps);
          _supportMore = supportMore;
          _items = _buildSortItems(apps, supportMore, l10n);
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

  static List<_SortItem> _buildSortItems(
    List<AppInfo> apps,
    bool supportMore,
    AppLocalizations l10n,
  ) {
    final mainApps = apps
        .where((a) => !a.hidden && (!supportMore || !a.inMore))
        .toList();
    final moreApps = supportMore
        ? apps.where((a) => !a.hidden && a.inMore).toList()
        : <AppInfo>[];
    final hiddenApps = apps.where((a) => a.hidden).toList();

    final items = <_SortItem>[];

    for (var i = 0; i < mainApps.length; i++) {
      items.add(
        _AppSortItem(
          app: mainApps[i],
          isTopTile: i == 0,
          isBottomTile: i == mainApps.length - 1,
          needDivider: i != mainApps.length - 1,
        ),
      );
    }

    if (supportMore && moreApps.isNotEmpty) {
      items.add(
        _HeaderSortItem(
          type: _SortHeaderType.more,
          title: l10n.appOrderMoreSection,
          count: moreApps.length,
        ),
      );
      for (var i = 0; i < moreApps.length; i++) {
        items.add(
          _AppSortItem(
            app: moreApps[i],
            isTopTile: i == 0,
            isBottomTile: i == moreApps.length - 1,
            needDivider: i != moreApps.length - 1,
          ),
        );
      }
    }

    if (hiddenApps.isNotEmpty) {
      items.add(
        _HeaderSortItem(
          type: _SortHeaderType.hidden,
          title: l10n.appOrderHiddenSection,
          count: hiddenApps.length,
        ),
      );
      for (var i = 0; i < hiddenApps.length; i++) {
        items.add(
          _AppSortItem(
            app: hiddenApps[i],
            isTopTile: i == 0,
            isBottomTile: i == hiddenApps.length - 1,
            needDivider: i != hiddenApps.length - 1,
          ),
        );
      }
    }

    return items;
  }

  static List<AppInfo> _extractApps(List<_SortItem> items, bool supportMore) {
    final apps = <AppInfo>[];
    var currentSection = _SortSection.main;

    for (final item in items) {
      if (item is _HeaderSortItem) {
        currentSection = switch (item.type) {
          _SortHeaderType.more => _SortSection.more,
          _SortHeaderType.hidden => _SortSection.hidden,
        };
      } else if (item is _AppSortItem) {
        final app = switch (currentSection) {
          _SortSection.main => item.app.copyWith(hidden: false, inMore: false),
          _SortSection.more => item.app.copyWith(hidden: false, inMore: true),
          _SortSection.hidden =>
            item.app.persist
                ? item.app.copyWith(hidden: false, inMore: false)
                : item.app.copyWith(hidden: true, inMore: false),
        };
        apps.add(app);
      }
    }
    return apps;
  }

  void _onReorderItem(int oldIndex, int newIndex) {
    if (_saving || oldIndex == newIndex) return;
    if (oldIndex < 0 || oldIndex >= _items.length) return;
    if (_items[oldIndex] is _HeaderSortItem) return;

    final nextItems = [..._items];
    final movedItem = nextItems.removeAt(oldIndex);
    final targetIndex = newIndex.clamp(0, nextItems.length);
    nextItems.insert(targetIndex, movedItem);

    final apps = _extractApps(nextItems, _supportMore);
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _apps = apps;
      _items = _buildSortItems(apps, _supportMore, l10n);
    });
  }

  void _toggleHide(AppInfo app) {
    if (_saving) return;
    final l10n = AppLocalizations.of(context)!;

    if (app.hidden) {
      final updatedApps = [
        for (final item in _apps)
          if (item.packageName == app.packageName)
            item.copyWith(
              hidden: false,
              inMore: _supportMore && (item.canMore || item.inMore),
            )
          else
            item,
      ];
      setState(() {
        _apps = updatedApps;
        _items = _buildSortItems(updatedApps, _supportMore, l10n);
      });
    } else {
      if (app.persist) return;
      final updatedApps = [
        for (final item in _apps)
          if (item.packageName == app.packageName)
            item.copyWith(hidden: true, inMore: false)
          else
            item,
      ];
      setState(() {
        _apps = updatedApps;
        _items = _buildSortItems(updatedApps, _supportMore, l10n);
      });
    }
  }

  bool get _isLayoutDirty =>
      _layout != null &&
      _selectedLayout != null &&
      _selectedLayout != _savedLayout;

  bool get _isAppsDirty {
    if (_apps.length != _savedApps.length) return true;
    for (var i = 0; i < _apps.length; i++) {
      final current = _apps[i];
      final saved = _savedApps[i];
      if (current.packageName != saved.packageName ||
          current.hidden != saved.hidden ||
          current.inMore != saved.inMore) {
        return true;
      }
    }
    return false;
  }

  bool get _dirty => _isLayoutDirty || _isAppsDirty;

  Future<void> _save() async {
    if (_saving || !_dirty) return;
    setState(() => _saving = true);
    final l10n = AppLocalizations.of(context)!;
    try {
      final manager = ref.read(deviceManagerProvider.notifier);
      if (_isLayoutDirty && _selectedLayout != null) {
        await manager.setXiaomiAppLayout(_selectedLayout!);
      }
      if (_isAppsDirty) {
        await manager.setXiaomiAppOrder(_apps);
      }
      if (mounted) {
        setState(() {
          _savedLayout = _selectedLayout;
          _savedApps = List.unmodifiable(_apps);
        });
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.appOrderSaved)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localizedErrorMessage(l10n, error))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _reset() {
    if (_saving || !_dirty) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _selectedLayout = _savedLayout;
      _apps = List.unmodifiable(_savedApps);
      _items = _buildSortItems(_savedApps, _supportMore, l10n);
    });
  }

  List<pb_system.AppLayout_Layout> _supportedLayouts(int mask) {
    final values = [
      pb_system.AppLayout_Layout.LIST,
      pb_system.AppLayout_Layout.GRID,
      pb_system.AppLayout_Layout.GRID_TEXT,
    ];
    final supported = values
        .where((value) => mask == 0 || (mask & value.value) != 0)
        .toList(growable: false);
    return supported.isEmpty ? [values.first] : supported;
  }

  String _layoutName(AppLocalizations l10n, pb_system.AppLayout_Layout value) =>
      switch (value) {
        pb_system.AppLayout_Layout.LIST => l10n.appLayoutList,
        pb_system.AppLayout_Layout.GRID => l10n.appLayoutGrid,
        pb_system.AppLayout_Layout.GRID_TEXT => l10n.appLayoutTextGrid,
        _ => value.name,
      };

  IconData _layoutIcon(pb_system.AppLayout_Layout value) => switch (value) {
    pb_system.AppLayout_Layout.LIST => Icons.view_list_outlined,
    pb_system.AppLayout_Layout.GRID => Icons.grid_view_outlined,
    pb_system.AppLayout_Layout.GRID_TEXT => Icons.view_module_outlined,
    _ => Icons.dashboard_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(deviceManagerProvider);
    final ready = state.protocolState == proto.ProtocolState.ready;

    final supportedLayouts = _supportedLayouts(_layout?.supportLayouts ?? 0);
    final showLayoutSection = supportedLayouts.length > 1;

    final mainAppsCount = _apps
        .where((a) => !a.hidden && (!_supportMore || !a.inMore))
        .length;

    return Scaffold(
      appBar: SysAppBar(
        secondary: true,
        title: Text(l10n.appArrangementTitle),
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
                key: const ValueKey('app-arrangement-actions'),
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  StableExtendedFab(
                    heroTag: 'xiaomi-app-arrangement-reset',
                    onPressed: _saving ? null : _reset,
                    icon: const Icon(Icons.undo),
                    label: Text(l10n.appOrderUndo),
                    secondary: true,
                  ),
                  const SizedBox(height: 12),
                  StableExtendedFab(
                    heroTag: 'xiaomi-app-arrangement-save',
                    onPressed: _saving ? null : _save,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(
                      _saving ? l10n.appOrderSaving : l10n.appOrderSave,
                    ),
                    animationKey: _saving,
                  ),
                ],
              )
            : const SizedBox.shrink(
                key: ValueKey('app-arrangement-actions-empty'),
              ),
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
          : ReorderableListView.builder(
              padding: EdgeInsets.only(
                top: 8,
                bottom: bottomContentPadding(context, extra: _dirty ? 72 : 16),
              ),
              header: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showLayoutSection)
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: StyleConstants.pageMaxWidth,
                        ),
                        child: CustomSegmentedSection(
                          child: RadioGroup<pb_system.AppLayout_Layout>(
                            groupValue: _selectedLayout ?? _layout?.layout,
                            onChanged: (value) {
                              if (!_saving && value != null) {
                                setState(() => _selectedLayout = value);
                              }
                            },
                            child: SegmentedSection(
                              title: Text(l10n.appLayoutTitle),
                              tiles: [
                                for (final value in supportedLayouts)
                                  SegmentedTile(
                                    leading: Icon(_layoutIcon(value)),
                                    title: Text(_layoutName(l10n, value)),
                                    trailing: Radio<pb_system.AppLayout_Layout>(
                                      value: value,
                                    ),
                                    enabled: !_saving,
                                    onPressed: (_) {
                                      if (!_saving) {
                                        setState(() => _selectedLayout = value);
                                      }
                                    },
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  _SectionDividerHeader(
                    title: l10n.appOrderTitle,
                    count: mainAppsCount,
                    topPadding: showLayoutSection ? 4 : 8,
                  ),
                ],
              ),
              itemCount: _items.length,
              onReorderItem: _onReorderItem,
              buildDefaultDragHandles: false,
              proxyDecorator: (child, _, _) => child,
              itemBuilder: (context, index) {
                final item = _items[index];
                return switch (item) {
                  _HeaderSortItem() => _SectionDividerHeader(
                    key: ValueKey('header_${item.type.name}'),
                    title: item.title,
                    count: item.count,
                    topPadding: 12,
                  ),
                  _AppSortItem() => _ReorderableAppTile(
                    key: ValueKey('app_${item.app.packageName}'),
                    index: index,
                    title: item.app.appName.trim().isEmpty
                        ? item.app.packageName
                        : item.app.appName,
                    enabled: !_saving,
                    isPersist: item.app.persist,
                    isHidden: item.app.hidden,
                    onToggleHide: () => _toggleHide(item.app),
                    isTopTile: item.isTopTile,
                    isBottomTile: item.isBottomTile,
                    needDivider: item.needDivider,
                  ),
                };
              },
            ),
    );
  }
}

class _SectionDividerHeader extends StatelessWidget {
  const _SectionDividerHeader({
    super.key,
    required this.title,
    required this.count,
    this.topPadding = 12,
  });

  final String title;
  final int count;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: StyleConstants.pageMaxWidth,
        ),
        child: Padding(
          padding: EdgeInsetsDirectional.only(
            start: 26,
            end: 26,
            top: topPadding,
            bottom: 6,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '($count)',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReorderableAppTile extends StatelessWidget {
  const _ReorderableAppTile({
    super.key,
    required this.index,
    required this.title,
    required this.enabled,
    required this.isPersist,
    required this.isHidden,
    required this.onToggleHide,
    required this.isTopTile,
    required this.isBottomTile,
    required this.needDivider,
  });

  final int index;
  final String title;
  final bool enabled;
  final bool isPersist;
  final bool isHidden;
  final VoidCallback onToggleHide;
  final bool isTopTile;
  final bool isBottomTile;
  final bool needDivider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = cardRadiusFor(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: StyleConstants.pageMaxWidth,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(isTopTile ? radius : 3),
                  bottom: Radius.circular(isBottomTile ? radius : 3),
                ),
                child: Material(
                  color:
                      theme.cardTheme.color ??
                      theme.colorScheme.surfaceContainerHighest,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 48,
                        height: 54,
                        child: Center(
                          child: isHidden
                              ? IconButton(
                                  icon: Icon(
                                    Icons.add_circle_outline,
                                    color: theme.colorScheme.primary,
                                    size: 20,
                                  ),
                                  onPressed: enabled ? onToggleHide : null,
                                )
                              : (isPersist
                                    ? Icon(
                                        Icons.lock_outline,
                                        size: 18,
                                        color: theme
                                            .colorScheme
                                            .onSurfaceVariant
                                            .withAlpha(128),
                                      )
                                    : IconButton(
                                        icon: Icon(
                                          Icons.remove_circle_outline,
                                          color: theme
                                              .colorScheme
                                              .onSurfaceVariant,
                                          size: 20,
                                        ),
                                        onPressed: enabled
                                            ? onToggleHide
                                            : null,
                                      )),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            title,
                            style: TextStyle(
                              color: enabled
                                  ? theme.colorScheme.onSurface
                                  : theme.disabledColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      if (!isHidden)
                        ReorderableDragStartListener(
                          index: index,
                          enabled: enabled,
                          child: SizedBox(
                            width: 50,
                            height: 54,
                            child: Center(
                              child: Icon(
                                Icons.drag_handle,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        )
                      else
                        const SizedBox(width: 50, height: 54),
                    ],
                  ),
                ),
              ),
              if (needDivider) const SizedBox(height: 2),
            ],
          ),
        ),
      ),
    );
  }
}
