import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/widgets/horizontal_scroller.dart';
import 'package:oronbox/src/app/widgets/network_img_layer.dart';
import 'package:oronbox/src/core/constants/style_constants.dart';
import 'package:oronbox/src/core/providers/app_settings_providers.dart';
import 'package:oronbox/src/data/community/community_source.dart';
import 'package:oronbox/src/features/resources/application/oronbox_resource_attributes.dart';
import 'package:oronbox/src/features/resources/application/resource_catalog_providers.dart';
import 'package:oronbox/src/features/resources/domain/community_resource.dart';
import 'package:oronbox/src/features/resources/widgets/resource_media_hero.dart';

/// List-style resource card for the BandBBS source, modeled after the
/// bandbbs.cn resource list: author + time, title + tagline, lazily loaded
/// preview images, stat chips, and the resource icon on the trailing edge.
class BandBbsResourceCard extends ConsumerWidget {
  const BandBbsResourceCard({super.key, required this.item});

  final CommunityResource item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final author = item.authors.firstOrNull;
    final detail = item.ref.source == CommunitySourceId.huamiAppStore
        ? ref.watch(communityResourceDetailProvider(item.ref)).value
        : null;
    final attributeLabels = {
      for (final attribute
          in ref.watch(oronBoxResourceAttributesProvider).value ??
              const <OronBoxResourceAttribute>[])
        attribute.id: attribute.labelFor(Localizations.localeOf(context)),
    };
    final authorName = detail?.authorName.isNotEmpty == true
        ? detail!.authorName
        : item.authorName;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      color: color.surfaceContainerHighest.withValues(alpha: .5),
      child: InkWell(
        onTap: () => item.isCollection
            ? context.push('/resources/collection/${item.ref.id}', extra: item)
            : context.push('/resources/detail/${item.ref.id}', extra: item),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (item.ref.source !=
                                    CommunitySourceId.astroboxRepo &&
                                author?.avatarUrl != null) ...[
                              NetworkImgLayer(
                                src: author?.avatarUrl?.toString() ?? '',
                                width: 20,
                                height: 20,
                                type: 'avatar',
                              ),
                              const SizedBox(width: 6),
                            ],
                            Flexible(
                              child: Text(
                                authorName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: color.onSurfaceVariant,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (item.updatedAt != null)
                              Text(
                                _relativeTime(l10n, item.updatedAt!),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: color.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                          ),
                        ),
                        if (item.summary.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            item.summary,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: color.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (item.iconUrl != null) ...[
                    const SizedBox(width: 12),
                    ResourceMediaHero(
                      tag: resourceMediaHeroTag(item.ref, 'icon'),
                      url: item.iconUrl!.toString(),
                      width: 48,
                      height: 48,
                      style: const ResourceMediaHeroStyle(
                        borderRadius: BorderRadius.all(Radius.circular(10)),
                      ),
                    ),
                  ],
                ],
              ),
              _LazyPreviews(item: item),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  _StatChip(
                    label: item.isCollection
                        ? l10n.resourceCollectionType(
                            _typeLabel(
                              l10n,
                              item.type,
                              source: item.ref.source,
                            ),
                          )
                        : _typeLabel(l10n, item.type, source: item.ref.source),
                    color: _typeColor(color, item.type),
                  ),
                  if (item.tags.firstOrNull != null)
                    _StatChip(
                      label: item.ref.source == CommunitySourceId.oronBox
                          ? attributeLabels[item.tags.first] ?? item.tags.first
                          : item.tags.first,
                      color: color.onSurfaceVariant,
                    ),
                  if (item.priceLabel != null)
                    _StatChip(label: item.priceLabel!, color: color.tertiary)
                  else if (item.paidType != CommunityPaidType.free)
                    _StatChip(
                      label: _paidLabel(l10n, item.paidType),
                      color: color.tertiary,
                    ),
                  if (item.downloadCount != null)
                    _StatChip(
                      icon: Icons.download,
                      label: '${item.downloadCount}',
                      color: color.onSurfaceVariant,
                    ),
                  if (item.ref.source == CommunitySourceId.oronBox &&
                      item.coinCount > 0)
                    _StatChip(
                      icon: Icons.toll_outlined,
                      label: '${item.coinCount}',
                      color: color.onSurfaceVariant,
                    ),
                  if (item.version != null && item.version!.isNotEmpty)
                    _StatChip(
                      icon: Icons.upload,
                      label: item.version!,
                      color: color.onSurfaceVariant,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _relativeTime(AppLocalizations l10n, DateTime time) {
    final now = DateTime.now();
    final t = time.toLocal();
    final hm =
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    if (t.year == now.year && t.month == now.month && t.day == now.day) {
      return l10n.timeTodayAt(hm);
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (t.year == yesterday.year &&
        t.month == yesterday.month &&
        t.day == yesterday.day) {
      return l10n.timeYesterdayAt(hm);
    }
    if (t.year == now.year) return '${t.month}-${t.day}';
    return '${t.year}-${t.month}-${t.day}';
  }
}

class _LazyPreviews extends ConsumerWidget {
  const _LazyPreviews({required this.item});

  final CommunityResource item;
  static const _height = 150.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (item.ref.source != CommunitySourceId.bandbbs) {
      return const SizedBox.shrink();
    }
    final loadPreviews = ref.watch(
      appSettingsProvider.select((settings) => settings.bandbbsLoadPreviews),
    );
    if (!loadPreviews) return const SizedBox.shrink();
    final detail = ref.watch(communityResourceDetailProvider(item.ref));
    final images = detail.value?.previewImages ?? const [];
    if (images.isEmpty) return const SizedBox.shrink();
    final cacheHeight = (_height * MediaQuery.devicePixelRatioOf(context))
        .round();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: HorizontalScroller(
        height: _height,
        children: [
          for (final image in images)
            if (_sized(image))
              NetworkImgLayer(
                src: (image.thumbnailUrl ?? image.url).toString(),
                width: _height * _aspectOf(image),
                height: _height,
                fit: BoxFit.contain,
                memCacheHeight: cacheHeight,
              )
            else
              NetworkImgAutoWidth(
                src: (image.thumbnailUrl ?? image.url).toString(),
                height: _height,
                maxWidth: 375,
                memCacheHeight: cacheHeight,
              ),
        ],
      ),
    );
  }

  bool _sized(CommunityResourceImage image) =>
      image.width != null && image.height != null && image.height! > 0;

  double _aspectOf(CommunityResourceImage image) {
    final width = image.width;
    final height = image.height;
    if (width == null || height == null || height <= 0) return 1;
    return width / height;
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.color, this.icon});

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(StyleConstants.chipRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

Color _typeColor(ColorScheme color, CommunityResourceType type) =>
    switch (type) {
      CommunityResourceType.quickApp => color.error,
      CommunityResourceType.miniprogram => color.error,
      CommunityResourceType.watchface => color.primary,
      CommunityResourceType.firmware => color.tertiary,
      CommunityResourceType.canopus => color.secondary,
    };

String _typeLabel(
  AppLocalizations l10n,
  CommunityResourceType type, {
  CommunitySourceId? source,
}) => switch (type) {
  CommunityResourceType.quickApp =>
    source == CommunitySourceId.huamiAppStore
        ? l10n.miniprogram
        : l10n.quickApp,
  CommunityResourceType.miniprogram => l10n.miniprogram,
  CommunityResourceType.watchface => l10n.watchface,
  CommunityResourceType.firmware => l10n.firmwareTool,
  CommunityResourceType.canopus => l10n.module,
};

String _paidLabel(AppLocalizations l10n, CommunityPaidType type) =>
    switch (type) {
      CommunityPaidType.free => l10n.free,
      CommunityPaidType.paid => l10n.paid,
      CommunityPaidType.forcePaid => l10n.forcePaid,
    };
