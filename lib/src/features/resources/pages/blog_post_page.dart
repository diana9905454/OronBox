import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/utils/error_localization.dart';
import 'package:oronbox/src/app/widgets/network_img_layer.dart';
import 'package:oronbox/src/app/widgets/page_container.dart';
import 'package:oronbox/src/app/widgets/sys_app_bar.dart';
import 'package:oronbox/src/app/widgets/markdown_style_sheet.dart';
import 'package:oronbox/src/core/constants/oronbox_server.dart';
import 'package:oronbox/src/core/constants/style_constants.dart';
import 'package:oronbox/src/data/community/community_source.dart';
import 'package:oronbox/src/data/oronbox/oronbox_home_api.dart';
import 'package:oronbox/src/features/resources/application/home_providers.dart';
import 'package:oronbox/src/features/resources/application/resource_catalog_providers.dart';
import 'package:oronbox/src/features/resources/domain/community_resource.dart';
import 'package:oronbox/src/features/resources/widgets/resource_external_link.dart';
import 'package:oronbox/src/features/resources/widgets/resource_media_hero.dart';

String blogTypeLabel(AppLocalizations l10n, String type) => switch (type) {
  'recommendation' => l10n.blogTypeRecommendation,
  'docs' => l10n.blogTypeDocs,
  _ => l10n.blogTypeAnnouncement,
};

class BlogPostPage extends ConsumerWidget {
  const BlogPostPage({super.key, required this.slug, this.preview});

  final String slug;
  final BlogCard? preview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final post = ref.watch(blogPostProvider(slug));
    return Scaffold(
      appBar: SysAppBar(
        secondary: true,
        title: Text(l10n.resourceArticleDetails),
      ),
      body: switch (post) {
        AsyncData(:final value) => _BlogPostBody(post: value),
        AsyncError(:final error) => Center(
          child: Padding(
            padding: const EdgeInsets.all(StyleConstants.pagePadding),
            child: Text(
              localizedErrorMessage(l10n, error),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        _ =>
          preview == null
              ? const Center(child: CircularProgressIndicator())
              : _BlogPostPreviewHeader(post: preview!),
      },
    );
  }
}

class _BlogPostBody extends StatelessWidget {
  const _BlogPostBody({required this.post});

  final BlogPost post;

  static final _directivePattern = RegExp(r'::resource\{id=([^}\s]+)\}');

  List<Widget> _contentSegments(BuildContext context) {
    final theme = Theme.of(context);
    final styleSheet = markdownStyleSheetFromTheme(theme).copyWith(
      p: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
      pPadding: const EdgeInsets.only(bottom: 12),
      h1: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
      h1Padding: const EdgeInsets.only(top: 20, bottom: 10),
      h2: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      h2Padding: const EdgeInsets.only(top: 16, bottom: 8),
      h3: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      h3Padding: const EdgeInsets.only(top: 12, bottom: 6),
    );
    final body = post.body
        .replaceAll("](/api/blobs/", "](/api/v1/blobs/")
        .replaceAll(
          '](/api/v1/blobs/',
          ']($oronBoxServerBaseUrl/api/v1/blobs/',
        );
    final segments = <Widget>[];
    var cursor = 0;
    for (final match in _directivePattern.allMatches(body)) {
      if (match.start > cursor) {
        segments.add(
          _MarkdownSegment(
            data: body.substring(cursor, match.start),
            styleSheet: styleSheet,
          ),
        );
      }
      segments.add(_EmbeddedResourceCard(resourceId: match.group(1)!));
      cursor = match.end;
    }
    if (cursor < body.length) {
      segments.add(
        _MarkdownSegment(data: body.substring(cursor), styleSheet: styleSheet),
      );
    }
    return segments;
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.only(
        bottom: bottomContentPadding(context, extra: 24),
      ),
      children: [
        _BlogPostHeader(post: post),
        PageContainer(
          safeArea: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _contentSegments(context),
          ),
        ),
      ],
    );
  }
}

class _BlogPostPreviewHeader extends StatelessWidget {
  const _BlogPostPreviewHeader({required this.post});

  final BlogCard post;

  @override
  Widget build(BuildContext context) => ListView(
    padding: EdgeInsets.only(bottom: bottomContentPadding(context, extra: 24)),
    children: [
      _BlogPostHeader(post: post),
      PageContainer(
        safeArea: false,
        child: Column(children: [const LinearProgressIndicator()]),
      ),
    ],
  );
}

class _BlogPostHeader extends StatelessWidget {
  const _BlogPostHeader({required this.post});

  final BlogCard post;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final publishedAt = post.publishedAt;
    return Stack(
      children: [
        if (post.coverUrl != null)
          Positioned.fill(
            child: ResourceMediaHero(
              tag: 'blog-cover-${post.slug}',
              url: post.coverUrl!.toString(),
              width: double.infinity,
              height: double.infinity,
              style: const ResourceMediaHeroStyle(
                opacity: .16,
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
              fit: BoxFit.cover,
            ),
          ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.primaryContainer.withValues(alpha: .22),
            ),
          ),
        ),
        PageContainer(
          padding: const EdgeInsets.fromLTRB(
            StyleConstants.pagePadding,
            8,
            StyleConstants.pagePadding,
            StyleConstants.pagePadding,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _TypeTag(
                    label: blogTypeLabel(
                      AppLocalizations.of(context)!,
                      post.type,
                    ),
                  ),
                  const Spacer(),
                  if (publishedAt != null)
                    Text(
                      '${publishedAt.year}/${publishedAt.month.toString().padLeft(2, '0')}/${publishedAt.day.toString().padLeft(2, '0')}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                post.title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (post.subtitle.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  post.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
              if (post.author.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  post.author,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _TypeTag extends StatelessWidget {
  const _TypeTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(StyleConstants.chipRadius),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MarkdownSegment extends StatelessWidget {
  const _MarkdownSegment({required this.data, required this.styleSheet});

  final String data;
  final MarkdownStyleSheet styleSheet;

  @override
  Widget build(BuildContext context) {
    if (data.trim().isEmpty) return const SizedBox.shrink();
    return MarkdownBody(
      data: data,
      selectable: true,
      styleSheet: styleSheet,
      onTapLink: (_, href, _) {
        final uri = Uri.tryParse(href ?? '');
        if (uri != null && uri.hasScheme) {
          openResourceExternalLink(context, uri);
        }
      },
    );
  }
}

final _embeddedResourceProvider = FutureProvider.autoDispose
    .family<CommunityResourceDetail?, String>((ref, id) async {
      try {
        return await ref
            .watch(communityCatalogProviderForSource(CommunitySourceId.oronBox))
            .getDetail(ResourceRef(source: CommunitySourceId.oronBox, id: id));
      } catch (_) {
        return null;
      }
    });

class _EmbeddedResourceCard extends ConsumerWidget {
  const _EmbeddedResourceCard({required this.resourceId});

  final String resourceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(_embeddedResourceProvider(resourceId));
    if (detail.isLoading) {
      return const _EmbeddedResourceSkeleton();
    }
    final value = detail.value;
    if (value == null) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final image = value.iconUrl ?? value.coverUrl;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      color: colors.surfaceContainerHighest.withValues(alpha: .5),
      child: InkWell(
        onTap: () => context.push(
          '/resources/detail/${value.ref.id}',
          extra: CommunityResource(
            ref: value.ref,
            name: value.name,
            type: value.type,
            paidType: value.paidType,
            authors: value.authors,
            supportedDevices: value.supportedDevices,
            iconUrl: value.iconUrl,
            coverUrl: value.coverUrl,
            summary: value.summary,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              NetworkImgLayer(
                src: image?.toString(),
                width: 56,
                height: 56,
                borderRadius: BorderRadius.circular(10),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (value.summary.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        value.summary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: colors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmbeddedResourceSkeleton extends StatelessWidget {
  const _EmbeddedResourceSkeleton();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant
        .withValues(alpha: .12);
    Widget bar(double width, double height) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(height / 2),
      ),
    );
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  bar(140, 14),
                  const SizedBox(height: 10),
                  bar(220, 10),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
