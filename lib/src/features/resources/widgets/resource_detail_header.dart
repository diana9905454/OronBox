import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/widgets/network_img_layer.dart';
import 'package:oronbox/src/app/theme/app_theme.dart';
import 'package:oronbox/src/app/widgets/page_container.dart';
import 'package:oronbox/src/core/constants/style_constants.dart';
import 'package:oronbox/src/data/community/community_source.dart';
import 'package:oronbox/src/features/resources/application/oronbox_resource_attributes.dart';
import 'package:oronbox/src/features/resources/domain/community_resource.dart';
import 'package:oronbox/src/features/resources/widgets/resource_external_link.dart';
import 'package:oronbox/src/features/resources/widgets/resource_media_hero.dart';

/// Shared header for resource detail pages and collection pages: media
/// backdrop, icon, title, authors and stat chips.
class ResourceDetailHeader extends ConsumerWidget {
  const ResourceDetailHeader({
    super.key,
    required this.resource,
    required this.mediaResource,
    required this.animateCover,
    required this.animateIcon,
  });

  final CommunityResource resource;
  final CommunityResource mediaResource;
  final bool animateCover;
  final bool animateIcon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final attributeLabels = {
      for (final attribute
          in ref.watch(oronBoxResourceAttributesProvider).value ??
              const <OronBoxResourceAttribute>[])
        attribute.id: attribute.labelFor(Localizations.localeOf(context)),
    };
    final icon = NetworkImgLayer(
      src: mediaResource.iconUrl?.toString() ?? '',
      width: 76,
      height: 76,
    );
    return _Hero(
      image: mediaResource.coverUrl ?? mediaResource.iconUrl,
      resourceRef: resource.ref,
      animateCover: animateCover,
      child: PageContainer(
        padding: const EdgeInsets.fromLTRB(
          StyleConstants.pagePadding,
          8,
          StyleConstants.pagePadding,
          StyleConstants.pagePadding,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (animateIcon)
              ResourceMediaHero(
                tag: resourceMediaHeroTag(resource.ref, 'icon'),
                url: mediaResource.iconUrl?.toString() ?? '',
                width: 76,
                height: 76,
                style: const ResourceMediaHeroStyle(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              )
            else
              icon,
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (resource.name.trim().isNotEmpty)
                    Text(
                      resource.name,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  const SizedBox(height: 4),
                  _Authors(resource: resource),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _Chip(
                        label: resource.isCollection
                            ? l10n.resourceCollectionType(
                                _typeLabel(
                                  l10n,
                                  resource.type,
                                  source: resource.ref.source,
                                ),
                              )
                            : _typeLabel(
                                l10n,
                                resource.type,
                                source: resource.ref.source,
                              ),
                        color: theme.colorScheme.primary,
                      ),
                      if (!resource.isCollection)
                        _Chip(
                          label: _paidLabel(l10n, resource.paidType),
                          color: resource.paidType == CommunityPaidType.free
                              ? context.appColors.success
                              : theme.colorScheme.tertiary,
                        ),
                      if (resource.ref.source == CommunitySourceId.bandbbs ||
                          resource.ref.source == CommunitySourceId.oronBox)
                        ...resource.tags
                            .take(2)
                            .map(
                              (tag) => _Chip(
                                label:
                                    resource.ref.source ==
                                        CommunitySourceId.oronBox
                                    ? attributeLabels[tag] ?? tag
                                    : tag,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                      if (resource.downloadCount != null)
                        _Chip(
                          label: l10n.downloadTimes(resource.downloadCount!),
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      if (resource.curationGrade == 'featured')
                        _Chip(
                          label: l10n.resourceFeatured,
                          color: theme.colorScheme.primary,
                        ),
                      if (resource.coinCount > 0)
                        _Chip(
                          label: l10n.resourceCoinCount(resource.coinCount),
                          color: theme.colorScheme.onSurfaceVariant,
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

class _Hero extends StatelessWidget {
  const _Hero({
    required this.child,
    required this.resourceRef,
    required this.animateCover,
    this.image,
  });
  final Widget child;
  final ResourceRef resourceRef;
  final bool animateCover;
  final Uri? image;
  @override
  Widget build(BuildContext context) => Stack(
    children: [
      if (image != null)
        Positioned.fill(
          child: animateCover
              ? ResourceMediaHero(
                  tag: resourceMediaHeroTag(resourceRef, 'cover'),
                  url: image.toString(),
                  width: double.infinity,
                  height: double.infinity,
                  style: const ResourceMediaHeroStyle(
                    opacity: .16,
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                )
              : Opacity(
                  opacity: .16,
                  child: NetworkImgLayer(
                    src: image.toString(),
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
        ),
      Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: context.appSelectionContainer.withValues(alpha: .22),
          ),
        ),
      ),
      child,
    ],
  );
}

class _Authors extends StatelessWidget {
  const _Authors({required this.resource});

  final CommunityResource resource;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (resource.authors.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: resource.authors
          .map(
            (author) => InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _openAuthor(context, resource, author),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '@${author.name}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    if (resource.ref.source == CommunitySourceId.huamiAppStore)
                      Padding(
                        padding: const EdgeInsets.only(left: 3),
                        child: Icon(
                          Icons.chevron_right,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  void _openAuthor(
    BuildContext context,
    CommunityResource resource,
    CommunityResourceAuthor author,
  ) {
    if (resource.ref.source == CommunitySourceId.huamiAppStore) {
      final name = author.name.trim();
      if (name.isEmpty) return;
      context.push(
        '/resources/huami-publisher?name=${Uri.encodeQueryComponent(name)}',
      );
      return;
    }
    final url = author.url;
    if (url != null) {
      openResourceExternalLink(context, url);
    }
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      color: color.withValues(alpha: .12),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontWeight: FontWeight.w600),
    ),
  );
}

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
