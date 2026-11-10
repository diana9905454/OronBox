import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter/material.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/utils/error_localization.dart';
import 'package:oronbox/src/app/widgets/page_container.dart';
import 'package:oronbox/src/app/widgets/sys_app_bar.dart';
import 'package:oronbox/src/core/constants/style_constants.dart';
import 'package:oronbox/src/data/oronbox/oronbox_resource_provider.dart';
import 'package:oronbox/src/features/resources/domain/community_resource.dart';
import 'package:oronbox/src/features/resources/widgets/bandbbs_resource_card.dart';
import 'package:oronbox/src/features/resources/widgets/resource_detail_header.dart';

class ResourceCollectionPage extends StatefulWidget {
  const ResourceCollectionPage({super.key, required this.collection});

  final CommunityResource collection;

  @override
  State<ResourceCollectionPage> createState() => _ResourceCollectionPageState();
}

class _ResourceCollectionPageState extends State<ResourceCollectionPage> {
  late final Future<OronBoxCollectionDetail> _detail = OronBoxResourceCatalog()
      .getCollection(widget.collection.ref.id);
  OronBoxCollectionDetail? _loaded;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final detail = await _detail;
      if (mounted) setState(() => _loaded = detail);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Mirrors the resource detail page: the header renders immediately from
    // the tapped list card so the shared element transition plays, then picks
    // up the freshly loaded collection data (correct coin count, owner).
    final representative = _loaded?.representative ?? widget.collection;
    final mediaResource = _loaded == null
        ? representative
        : CommunityResource(
            ref: widget.collection.ref,
            paidType: CommunityPaidType.free,
            name: _loaded!.name,
            type: _loaded!.type,
            authors: representative.authors,
            supportedDevices: representative.supportedDevices,
            iconUrl: _loaded!.iconUrl ?? representative.iconUrl,
            coverUrl: _loaded!.coverUrl ?? representative.coverUrl,
            summary: _loaded!.summary,
          );
    final headerResource = _loaded == null
        ? widget.collection
        : CommunityResource(
            ref: widget.collection.ref,
            name: _loaded!.name,
            type: _loaded!.type,
            paidType: CommunityPaidType.free,
            authors: [
              if (_loaded!.owner.isNotEmpty)
                CommunityResourceAuthor(name: _loaded!.owner),
            ],
            supportedDevices: const {},
            iconUrl: mediaResource.iconUrl,
            coverUrl: mediaResource.coverUrl,
            summary: _loaded!.summary,
            // The collection endpoint does not return listing tags. Keep the
            // tags from the tapped card so the header does not change height
            // after the detail request completes.
            tags: widget.collection.tags,
            // The collection detail API carries no download count, so keep the
            // list card's value to avoid the stat disappearing after the hero
            // animation hands over to the loaded header.
            downloadCount: widget.collection.downloadCount,
            coinCount: _loaded!.coinCount,
            isCollection: true,
            resourceCount: _loaded!.resourceCount > 0
                ? _loaded!.resourceCount
                : _loaded!.resources.length,
          );
    return Scaffold(
      appBar: SysAppBar(
        secondary: true,
        title: Text(l10n.resourceCollectionDetails),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: ResourceDetailHeader(
              resource: headerResource,
              mediaResource: mediaResource,
              animateCover: widget.collection.coverUrl != null,
              animateIcon: widget.collection.iconUrl != null,
            ),
          ),
          if (_error != null)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(StyleConstants.pagePadding),
                  child: Text(localizedErrorMessage(l10n, _error!)),
                ),
              ),
            )
          else if (_loaded == null)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            )
          else
            SliverPadding(
              padding: EdgeInsets.only(
                bottom: bottomContentPadding(context, extra: 24),
              ),
              sliver: SliverToBoxAdapter(
                child: PageContainer(
                  safeArea: false,
                  padding: const EdgeInsets.all(StyleConstants.pagePadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_loaded!.summary.isNotEmpty) ...[
                        Text(
                          _loaded!.summary,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (_loaded!.description.isNotEmpty)
                        MarkdownBody(data: _loaded!.description, selectable: true),
                      Text(
                        l10n.creatorResourceList,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      ..._loaded!.resources.map(
                        (resource) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: BandBbsResourceCard(item: resource),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
