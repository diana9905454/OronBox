import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/core/constants/style_constants.dart';
import 'package:oronbox/src/features/resources/domain/community_resource.dart';
import 'package:oronbox/src/data/community/community_source.dart';
import 'package:oronbox/src/features/resources/application/oronbox_resource_attributes.dart';
import 'package:oronbox/src/features/resources/widgets/resource_media_hero.dart';

String resourceTypeLabel(
  AppLocalizations l10n,
  CommunityResourceType type, {
  CommunitySourceId? source,
}) => switch (type) {
  CommunityResourceType.quickApp =>
    source == CommunitySourceId.huamiAppStore
        ? l10n.miniprograms
        : l10n.quickApps,
  CommunityResourceType.miniprogram => l10n.miniprograms,
  CommunityResourceType.watchface => l10n.watchfaces,
  CommunityResourceType.firmware => l10n.firmwareTools,
  CommunityResourceType.canopus => l10n.module,
};

String resourcePaidLabel(AppLocalizations l10n, CommunityPaidType type) =>
    switch (type) {
      CommunityPaidType.free => l10n.free,
      CommunityPaidType.paid => l10n.paid,
      CommunityPaidType.forcePaid => l10n.forcePaid,
    };

String communitySourceLabel(AppLocalizations l10n, CommunitySourceId source) =>
    switch (source) {
      CommunitySourceId.astroboxRepo => l10n.communitySourceAstroBoxRepo,
      CommunitySourceId.bandbbs => l10n.communitySourceBandBbs,
      CommunitySourceId.huamiAppStore => l10n.communitySourceHuamiAppStore,
      _ => source.displayName,
    };

class NoStretchScrollBehavior extends MaterialScrollBehavior {
  const NoStretchScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}

class ResourceCard extends ConsumerWidget {
  const ResourceCard({
    super.key,
    required this.item,
    required this.coverHeight,
    this.heroEnabled = true,
    this.onTap,
  });

  final CommunityResource item;
  final double coverHeight;
  final bool heroEnabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final color = Theme.of(context).colorScheme;
    final image = item.coverUrl ?? item.iconUrl;
    final heroRole = item.coverUrl != null ? 'cover' : 'icon';
    final attributeLabels = {
      for (final attribute
          in ref.watch(oronBoxResourceAttributesProvider).value ??
              const <OronBoxResourceAttribute>[])
        attribute.id: attribute.labelFor(Localizations.localeOf(context)),
    };
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      color: color.surfaceContainerHighest.withValues(alpha: .5),
      child: InkWell(
        onTap:
            onTap ??
            () => item.isCollection
                ? context.push(
                    '/resources/collection/${item.ref.id}',
                    extra: item,
                  )
                : context.push('/resources/detail/${item.ref.id}', extra: item),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HeroMode(
              enabled: heroEnabled,
              child: ResourceMediaHero(
                tag: resourceMediaHeroTag(item.ref, heroRole),
                url: image?.toString() ?? '',
                width: double.infinity,
                height: coverHeight,
                style: const ResourceMediaHeroStyle(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600, height: 1.25),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      ResourceLabel(
                        label: item.isCollection
                            ? l10n.resourceCollectionType(
                                resourceTypeLabel(
                                  l10n,
                                  item.type,
                                  source: item.ref.source,
                                ),
                              )
                            : resourceTypeLabel(
                                l10n,
                                item.type,
                                source: item.ref.source,
                              ),
                        color: color.primary,
                      ),
                      if (!item.isCollection)
                        ResourceLabel(
                          label: resourcePaidLabel(l10n, item.paidType),
                          color: color.tertiary,
                        ),
                      if (item.isCollection &&
                          (item.ref.source == CommunitySourceId.bandbbs ||
                              item.ref.source == CommunitySourceId.oronBox))
                        ...item.tags
                            .take(1)
                            .map(
                              (tag) => ResourceLabel(
                                label:
                                    item.ref.source == CommunitySourceId.oronBox
                                    ? attributeLabels[tag] ?? tag
                                    : tag,
                                color: color.onSurfaceVariant,
                              ),
                            ),
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
}

class ResourceLabel extends StatelessWidget {
  const ResourceLabel({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(StyleConstants.chipRadius),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
