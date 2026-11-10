import 'package:material_ui/material_ui.dart';

class SegmentedTileInfo extends InheritedWidget {
  const SegmentedTileInfo({
    super.key,
    required this.needDivider,
    required this.isTopTile,
    required this.isBottomTile,
    required super.child,
  });

  final bool needDivider;
  final bool isTopTile;
  final bool isBottomTile;

  @override
  bool updateShouldNotify(SegmentedTileInfo oldWidget) => true;

  static SegmentedTileInfo of(BuildContext context) {
    final SegmentedTileInfo? result =
        context.dependOnInheritedWidgetOfExactType<SegmentedTileInfo>();
    // assert(result != null, 'No IOSSettingsTileAdditionalInfo found in context');
    return result ??
        const SegmentedTileInfo(
          needDivider: true,
          isBottomTile: true,
          isTopTile: true,
          child: SizedBox(),
        );
  }
}
