import 'package:material_ui/material_ui.dart';
import 'package:segmented_list/tile/abstract_segmented_tile.dart';
import 'package:segmented_list/tile/segmented_tile_info.dart';
import 'package:segmented_list/section/abstract_segmented_section.dart';

class SegmentedSection extends AbstractSegmentedSection {
  const SegmentedSection({
    required this.tiles,
    this.margin,
    this.title,
    this.bottomInfo,
    super.key,
  });

  final List<AbstractSegmentedTile> tiles;
  final EdgeInsetsDirectional? margin;
  final Widget? title;
  final Widget? bottomInfo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inheritedTextStyle = DefaultTextStyle.of(context).style;

    return Padding(
      padding:
          margin ?? EdgeInsetsDirectional.only(start: 16, end: 16, bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.all(10),
              child: DefaultTextStyle(
                style: inheritedTextStyle.merge(TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                )),
                child: title!,
              ),
            ),
          tileList,
          if (bottomInfo != null)
            Padding(
              padding: const EdgeInsets.all(10),
              child: DefaultTextStyle(
                style: inheritedTextStyle.merge(TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                )),
                child: bottomInfo!,
              ),
            ),
        ],
      ),
    );
  }

  Widget get tileList {
    return ListView.builder(
      shrinkWrap: true,
      itemCount: tiles.length,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (BuildContext context, int index) {
        return SegmentedTileInfo(
          isTopTile: index == 0,
          isBottomTile: index == tiles.length - 1,
          needDivider: index != tiles.length - 1,
          child: tiles[index],
        );
      },
    );
  }
}
