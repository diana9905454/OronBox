import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';

class ZeppOsMapPreview extends StatefulWidget {
  const ZeppOsMapPreview({
    required this.tiles,
    this.onTap,
    this.showCenterMarker = false,
    this.maxWidth = 512,
    super.key,
  });

  final List<({int x, int y, String url})> tiles;
  final ValueChanged<Offset>? onTap;
  final bool showCenterMarker;
  final double maxWidth;

  @override
  State<ZeppOsMapPreview> createState() => _ZeppOsMapPreviewState();
}

class _ZeppOsMapPreviewState extends State<ZeppOsMapPreview> {
  final TransformationController _transformation = TransformationController();
  Offset? _pointerDown;

  @override
  void didUpdateWidget(covariant ZeppOsMapPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameTileRange(oldWidget.tiles, widget.tiles)) {
      _transformation.value = Matrix4.identity();
    }
  }

  @override
  void dispose() {
    _transformation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tiles = widget.tiles;
    if (tiles.isEmpty) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    final minX = tiles.map((tile) => tile.x).reduce(math.min);
    final maxX = tiles.map((tile) => tile.x).reduce(math.max);
    final minY = tiles.map((tile) => tile.y).reduce(math.min);
    final maxY = tiles.map((tile) => tile.y).reduce(math.max);
    final columns = maxX - minX + 1;
    final rows = maxY - minY + 1;
    final lookup = <(int, int), ({int x, int y, String url})>{
      for (final tile in tiles) (tile.x, tile.y): tile,
    };
    final safeGrid = columns * rows <= 400;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: widget.maxWidth),
            child: AspectRatio(
              aspectRatio: safeGrid ? columns / rows : 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: LayoutBuilder(
                  builder: (context, constraints) => Listener(
                    onPointerDown: (event) =>
                        _pointerDown = event.localPosition,
                    onPointerUp: widget.onTap == null
                        ? null
                        : (event) {
                            final down = _pointerDown;
                            _pointerDown = null;
                            if (down == null ||
                                (event.localPosition - down).distance > 8) {
                              return;
                            }
                            final scene = _transformation.toScene(
                              event.localPosition,
                            );
                            widget.onTap!(
                              Offset(
                                scene.dx / constraints.maxWidth,
                                scene.dy / constraints.maxHeight,
                              ),
                            );
                          },
                    onPointerCancel: (_) => _pointerDown = null,
                    child: InteractiveViewer(
                      transformationController: _transformation,
                      minScale: 1,
                      maxScale: 5,
                      boundaryMargin: const EdgeInsets.all(48),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (safeGrid)
                            GridView.builder(
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: columns,
                                  ),
                              itemCount: columns * rows,
                              itemBuilder: (context, index) {
                                final x = minX + index % columns;
                                final y = minY + index ~/ columns;
                                final tile = lookup[(x, y)];
                                if (tile == null) {
                                  return ColoredBox(
                                    color: colors.surfaceContainerHighest,
                                  );
                                }
                                return Image.network(
                                  tile.url,
                                  headers: const {
                                    'User-Agent':
                                        'OronBox/1.0 ZeppOS map preview',
                                  },
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => ColoredBox(
                                    color: colors.surfaceContainerHighest,
                                    child: Icon(
                                      Icons.cloud_off_outlined,
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),
                                );
                              },
                            )
                          else
                            ColoredBox(
                              color: colors.surfaceContainerHighest,
                              child: Center(
                                child: Text(
                                  AppLocalizations.of(
                                    context,
                                  )!.zeppOsMapPreviewTooLarge,
                                  style: TextStyle(
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ),
                          if (widget.showCenterMarker)
                            const Center(
                              child: Icon(
                                Icons.add_location_alt,
                                size: 36,
                                shadows: [
                                  Shadow(color: Colors.white, blurRadius: 5),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '© OpenStreetMap contributors',
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(color: colors.onSurfaceVariant),
        ),
      ],
    );
  }

  static bool _sameTileRange(
    List<({int x, int y, String url})> a,
    List<({int x, int y, String url})> b,
  ) {
    if (a.length != b.length) return false;
    for (var index = 0; index < a.length; index++) {
      if (a[index].x != b[index].x || a[index].y != b[index].y) return false;
    }
    return true;
  }
}
