import 'package:material_ui/material_ui.dart';
import 'package:segmented_list/tile/segmented_tile_info.dart';
import 'package:segmented_list/tile/abstract_segmented_tile.dart';

class CustomSegmentedTile extends AbstractSegmentedTile {
  const CustomSegmentedTile({
    required this.child,
    super.key,
  });

  final Widget Function(SegmentedTileInfo info) child;

  @override
  Widget build(BuildContext context) {
    final settingsTileInfo = SegmentedTileInfo.of(context);
    return child(settingsTileInfo);
  }
}
