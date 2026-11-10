import 'package:material_ui/material_ui.dart';
import 'package:segmented_list/tile/abstract_segmented_tile.dart';
import 'package:segmented_list/tile/segmented_tile_info.dart';

enum SettingsTileType {
  simpleTile,
  switchTile,
  navigationTile,
  checkboxTile,
  radioTile,
}

class SegmentedTile<T> extends AbstractSegmentedTile {
  SegmentedTile({
    this.leading,
    this.trailing,
    required this.title,
    this.description,
    this.onPressed,
    this.enabled = true,
    super.key,
  }) {
    onToggle = null;
    onChanged = null;
    initialValue = null;
    value = null;
    tileType = SettingsTileType.simpleTile;
  }

  SegmentedTile.navigation({
    this.leading,
    this.trailing,
    this.value,
    required this.title,
    this.description,
    this.onPressed,
    this.enabled = true,
    super.key,
  }) {
    onToggle = null;
    onChanged = null;
    initialValue = null;
    tileType = SettingsTileType.navigationTile;
  }

  SegmentedTile.switchTile({
    required this.initialValue,
    required this.onToggle,
    this.leading,
    this.trailing,
    required this.title,
    this.description,
    this.enabled = true,
    super.key,
  }) {
    onPressed = null;
    onChanged = null;
    value = null;
    tileType = SettingsTileType.switchTile;
  }

  SegmentedTile.checkboxTile({
    required this.initialValue,
    required this.onToggle,
    this.leading,
    this.trailing,
    required this.title,
    this.description,
    this.enabled = true,
    super.key,
  }) {
    onPressed = null;
    onChanged = null;
    value = null;
    tileType = SettingsTileType.checkboxTile;
  }

  SegmentedTile.radioTile({
    required this.radioValue,
    required this.groupValue,
    required this.onChanged,
    this.leading,
    this.trailing,
    required this.title,
    this.description,
    this.enabled = true,
    super.key,
  }) {
    onPressed = null;
    onToggle = null;
    value = null;
    tileType = SettingsTileType.radioTile;
  }

  /// The widget at the beginning of the tile
  final Widget? leading;

  /// The Widget at the end of the tile
  final Widget? trailing;

  /// The widget at the center of the tile
  final Widget title;

  /// The widget at the bottom of the [title]
  final Widget? description;

  /// A function that is called by tap on a tile
  late final Function(BuildContext)? onPressed;

  /// A function that is called by tap on a switch or checkbox
  /// !! Caution: bool value could be null, you may have to add null check
  late final Function(bool?)? onToggle;

  /// A function that is called by tap on a radio button
  late final Function(T?)? onChanged;

  /// The text displayed at the end of the tile
  late final Widget? value;

  /// The bool value used by switch
  late final bool? initialValue;

  /// The bool value used by switch
  late final T radioValue;

  /// The bool value used by switch
  late final T? groupValue;

  /// Whether this tile is clickable
  late final bool enabled;

  late final SettingsTileType tileType;

  static const WidgetStateProperty<Icon> thumbIcon =
      WidgetStateProperty<Icon>.fromMap(
    <WidgetStatesConstraint, Icon>{
      WidgetState.selected: Icon(Icons.check_rounded),
      WidgetState.any: Icon(Icons.close_rounded),
    },
  );

  @override
  Widget build(BuildContext context) {
    final settingsTileInfo = SegmentedTileInfo.of(context);
    final radius = _cardRadius(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(settingsTileInfo.isTopTile ? radius : 3),
            bottom: Radius.circular(settingsTileInfo.isBottomTile ? radius : 3),
          ),
          child: buildTileContent(context),
        ),
        if (settingsTileInfo.needDivider) SizedBox(height: 2),
      ],
    );
  }

  Widget buildLeading(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16.0),
      child: IconTheme.merge(
        data: IconThemeData(
          color: enabled
              ? Theme.of(context).colorScheme.onSurface
              : Theme.of(context).disabledColor,
        ),
        child: leading!,
      ),
    );
  }

  Widget buildTitle(BuildContext context) {
    final theme = Theme.of(context);
    final inheritedTextStyle = DefaultTextStyle.of(context).style;

    return Padding(
      padding: EdgeInsetsDirectional.symmetric(
        vertical: description != null ? 17 : 24,
        horizontal: 16,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DefaultTextStyle(
            style: inheritedTextStyle.merge(TextStyle(
              color:
                  enabled ? theme.colorScheme.onSurface : theme.disabledColor,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            )),
            child: title,
          ),
          if (description != null) ...[
            const SizedBox(height: 2),
            DefaultTextStyle(
              style: inheritedTextStyle.merge(TextStyle(
                color: enabled
                    ? theme.colorScheme.onSurfaceVariant
                    : theme.disabledColor,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              )),
              child: description!,
            ),
          ],
        ],
      ),
    );
  }

  Widget buildTrailing(BuildContext context) {
    final theme = Theme.of(context);
    final inheritedTextStyle = DefaultTextStyle.of(context).style;

    return Row(
      children: [
        if (trailing != null)
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: trailing!,
          ),
        if (tileType == SettingsTileType.switchTile)
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Transform.scale(
              scale: 0.85,
              child: Switch(
                thumbIcon: thumbIcon,
                value: initialValue ?? true,
                onChanged: (enabled) ? onToggle : null,
              ),
            ),
          ),
        if (tileType == SettingsTileType.checkboxTile)
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Checkbox(
              tristate: true,
              value: initialValue,
              onChanged: (enabled) ? onToggle : null,
            ),
          ),
        if (tileType == SettingsTileType.radioTile)
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Icon(
              groupValue == radioValue
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: enabled ? theme.colorScheme.primary : theme.disabledColor,
            ),
          ),
        if (value != null)
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: DefaultTextStyle(
              style: inheritedTextStyle.merge(TextStyle(
                color: enabled
                    ? theme.colorScheme.onSurfaceVariant
                    : theme.disabledColor,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              )),
              child: value!,
            ),
          ),
      ],
    );
  }

  Widget buildTileContent(BuildContext context) {
    final theme = Theme.of(context);
    // You need to wrap Ink widgets with Material to clip it properly.
    return Material(
      color: theme.cardTheme.color ?? theme.colorScheme.surfaceContainerHighest,
      child: InkWell(
        onTap: (enabled)
            ? () {
                if (onPressed != null) {
                  onPressed!.call(context);
                }
                if (onToggle != null) {
                  onToggle!.call(null);
                }
                if (onChanged != null) {
                  onChanged!.call(radioValue);
                }
              }
            : () {},
        mouseCursor: SystemMouseCursors.click,
        child: Row(
          children: [
            if (leading != null) buildLeading(context),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Expanded(child: buildTitle(context)),
                      buildTrailing(context),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _cardRadius(BuildContext context) {
    final shape = Theme.of(context).cardTheme.shape;
    if (shape is RoundedRectangleBorder) {
      return shape.borderRadius.resolve(TextDirection.ltr).topLeft.x;
    }
    return Theme.of(context).useMaterial3 ? 16 : 10;
  }
}
