import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:oronbox/src/core/constants/oronbox_server.dart';
import 'package:oronbox/src/core/network/app_http_transport.dart';
import 'package:oronbox/src/features/resources/domain/community_resource.dart';
import 'package:oronbox/src/data/oronbox/oronbox_resource_provider.dart';

enum HomeBannerType { resource, blog, link }

class HomeBanner {
  const HomeBanner({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    this.coverUrl,
    this.resourceId = '',
    this.blogSlug = '',
    this.linkUrl,
  });

  final String id;
  final HomeBannerType type;
  final String title;
  final String subtitle;
  final Uri? coverUrl;
  final String resourceId;
  final String blogSlug;
  final Uri? linkUrl;
}

class HomeResourceCard {
  const HomeResourceCard({
    required this.id,
    required this.slug,
    required this.name,
    required this.summary,
    required this.kind,
    required this.owner,
    this.paidType = CommunityPaidType.free,
    this.iconUrl,
    this.coverUrl,
    this.previews = const [],
  });

  final String id;
  final String slug;
  final String name;
  final String summary;
  final String kind;
  final String owner;
  final CommunityPaidType paidType;
  final Uri? iconUrl;
  final Uri? coverUrl;
  final List<Uri> previews;
}

class BlogCard {
  const BlogCard({
    required this.slug,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.author,
    this.coverUrl,
    this.publishedAt,
  });

  final String slug;
  final String type;
  final String title;
  final String subtitle;
  final String author;
  final Uri? coverUrl;
  final DateTime? publishedAt;
}

class BlogPost extends BlogCard {
  const BlogPost({
    required super.slug,
    required super.type,
    required super.title,
    required super.subtitle,
    required super.author,
    required this.body,
    super.coverUrl,
    super.publishedAt,
  });

  final String body;
}

class HomeSectionCard {
  const HomeSectionCard({required this.id, this.resource, this.blog});

  final String id;
  final HomeResourceCard? resource;
  final BlogCard? blog;
}

class HomeSection {
  const HomeSection({
    required this.id,
    required this.name,
    required this.description,
    required this.cards,
  });

  final String id;
  final String name;
  final String description;
  final List<HomeSectionCard> cards;
}

class HomeResourceFeed {
  const HomeResourceFeed({
    required this.featured,
    required this.recommended,
    required this.latest,
    this.available = true,
  });

  const HomeResourceFeed.unavailable()
    : featured = const [],
      recommended = const [],
      latest = const [],
      available = false;

  final List<CommunityResource> featured;
  final List<CommunityResource> recommended;
  final List<CommunityResource> latest;
  final bool available;
}

class HomeFeed {
  const HomeFeed({
    required this.banners,
    required this.blogs,
    required this.sections,
    required this.resourceFeed,
  });

  final List<HomeBanner> banners;
  final List<BlogCard> blogs;
  final List<HomeSection> sections;
  final HomeResourceFeed resourceFeed;

  bool get isEmpty =>
      banners.isEmpty &&
      blogs.isEmpty &&
      sections.every((section) => section.cards.isEmpty) &&
      (!resourceFeed.available ||
          (resourceFeed.featured.isEmpty &&
              resourceFeed.recommended.isEmpty &&
              resourceFeed.latest.isEmpty));
}

class OronBoxHomeApi {
  OronBoxHomeApi({Dio? dio}) : _dio = dio ?? createAppHttpTransport();

  final Dio _dio;

  Future<HomeFeed> fetchHome({int? seed}) async {
    final feedSeed = seed ?? math.Random.secure().nextInt(0x7fffffff);
    final homeFuture = _dio.get<Object?>(
      '$oronBoxServerBaseUrl/api/v1/home',
      queryParameters: {'seed': feedSeed},
    );
    final blogFuture = _fetchBlogRoot();
    final homeResponse = await homeFuture;
    final blogRoot = await blogFuture;
    final root = _map(homeResponse.data);
    final resourceCatalog = OronBoxResourceCatalog(dio: _dio);
    final feedValue = root['resource_feed'];
    final resourceFeed = feedValue is Map
        ? _resourceFeed(
            feedValue.cast<String, Object?>(),
            resourceCatalog,
            explicitlyAvailable: root['resource_feed_available'] as bool?,
          )
        : const HomeResourceFeed.unavailable();
    return HomeFeed(
      banners: (root['banners'] as List? ?? const [])
          .whereType<Map>()
          .map((value) => _banner(value.cast<String, Object?>()))
          .toList(),
      blogs: (blogRoot['posts'] as List? ?? const [])
          .whereType<Map>()
          .map((value) => _blogCard(value.cast<String, Object?>()))
          .toList(),
      sections: (root['sections'] as List? ?? const [])
          .whereType<Map>()
          .map((value) => _section(value.cast<String, Object?>()))
          .toList(),
      resourceFeed: resourceFeed,
    );
  }

  Future<Map<String, Object?>> _fetchBlogRoot() async {
    try {
      final response = await _dio.get<Object?>(
        '$oronBoxServerBaseUrl/api/v1/blog?limit=5',
      );
      return _map(response.data);
    } catch (_) {
      // Articles are supplementary to the resource feed. A temporary blog
      // endpoint failure must not hide the homepage's resource sections.
      return const {};
    }
  }

  Future<BlogPost> fetchBlogPost(String slug) async {
    final response = await _dio.get<Object?>(
      '$oronBoxServerBaseUrl/api/v1/blog/${Uri.encodeComponent(slug)}',
    );
    final json = _map(response.data);
    return BlogPost(
      slug: json['slug']?.toString() ?? slug,
      type: json['type']?.toString() ?? 'announcement',
      title: json['title']?.toString() ?? '',
      subtitle: json['subtitle']?.toString() ?? '',
      author: json['author']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      coverUrl:
          Uri.tryParse(json['cover_url']?.toString() ?? '')?.hasScheme == true
          ? Uri.parse(json['cover_url'].toString())
          : _blobUri(json['cover_sha256']?.toString() ?? ''),
      publishedAt: DateTime.tryParse(json['published_at']?.toString() ?? ''),
    );
  }

  HomeBanner _banner(Map<String, Object?> json) {
    final link = Uri.tryParse(json['link_url']?.toString() ?? '');
    return HomeBanner(
      id: json['id']?.toString() ?? '',
      type: switch (json['type']?.toString()) {
        'blog' => HomeBannerType.blog,
        'link' => HomeBannerType.link,
        _ => HomeBannerType.resource,
      },
      title: json['title']?.toString() ?? '',
      subtitle: json['subtitle']?.toString() ?? '',
      coverUrl:
          Uri.tryParse(json['cover_url']?.toString() ?? '')?.hasScheme == true
          ? Uri.parse(json['cover_url'].toString())
          : _blobUri(json['cover_sha256']?.toString() ?? ''),
      resourceId: json['resource_id']?.toString() ?? '',
      blogSlug: json['blog_slug']?.toString() ?? '',
      linkUrl: link?.hasScheme == true ? link : null,
    );
  }

  HomeSection _section(Map<String, Object?> json) {
    return HomeSection(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      cards: (json['cards'] as List? ?? const [])
          .whereType<Map>()
          .map((value) => _card(value.cast<String, Object?>()))
          .whereType<HomeSectionCard>()
          .toList(),
    );
  }

  HomeResourceFeed _resourceFeed(
    Map<String, Object?> json,
    OronBoxResourceCatalog catalog, {
    bool? explicitlyAvailable,
  }) {
    final featured = _resourceList(json['featured'], catalog);
    final recommended = _resourceList(json['recommended'], catalog);
    final latest = _resourceList(json['latest'], catalog);
    return HomeResourceFeed(
      featured: featured,
      recommended: recommended,
      latest: latest,
      available:
          explicitlyAvailable ??
          (featured.isNotEmpty || recommended.isNotEmpty || latest.isNotEmpty),
    );
  }

  List<CommunityResource> _resourceList(
    Object? value,
    OronBoxResourceCatalog catalog,
  ) => (value as List? ?? const [])
      .whereType<Map>()
      .map((item) => catalog.summaryFromWire(item.cast<String, Object?>()))
      .where((item) => item.ref.id.isNotEmpty)
      .toList();

  HomeSectionCard? _card(Map<String, Object?> json) {
    final id = json['id']?.toString() ?? '';
    if (json['resource'] is Map) {
      final resource = (json['resource']! as Map).cast<String, Object?>();
      final iconUrl = _blobUri(resource['icon_sha256']?.toString() ?? '');
      return HomeSectionCard(
        id: id,
        resource: HomeResourceCard(
          id: resource['id']?.toString() ?? '',
          slug: resource['slug']?.toString() ?? '',
          name: resource['name']?.toString() ?? '',
          summary: resource['summary']?.toString() ?? '',
          kind: resource['kind']?.toString() ?? '',
          owner: resource['owner']?.toString() ?? '',
          paidType: communityPaidTypeFromWire(resource['paid_type']),
          iconUrl: iconUrl,
          coverUrl:
              _blobUri(resource['cover_sha256']?.toString() ?? '') ?? iconUrl,
          previews: (resource['previews'] as List? ?? const [])
              .map((value) => _blobUri(value.toString()))
              .whereType<Uri>()
              .toList(),
        ),
      );
    }
    if (json['blog'] is Map) {
      return HomeSectionCard(
        id: id,
        blog: _blogCard((json['blog']! as Map).cast<String, Object?>()),
      );
    }
    return null;
  }

  BlogCard _blogCard(Map<String, Object?> json) => BlogCard(
    slug: json['slug']?.toString() ?? '',
    type: json['type']?.toString() ?? 'announcement',
    title: json['title']?.toString() ?? '',
    subtitle: json['subtitle']?.toString() ?? '',
    author: json['author']?.toString() ?? '',
    coverUrl:
        Uri.tryParse(json['cover_url']?.toString() ?? '')?.hasScheme == true
        ? Uri.parse(json['cover_url'].toString())
        : _blobUri(json['cover_sha256']?.toString() ?? ''),
    publishedAt: DateTime.tryParse(json['published_at']?.toString() ?? ''),
  );

  Uri? _blobUri(String digest) => digest.length == 64
      ? Uri.parse('$oronBoxServerBaseUrl/api/v1/blobs/$digest?line=local')
      : null;

  Map<String, Object?> _map(Object? value) => value is Map
      ? value.cast<String, Object?>()
      : throw FormatException('OronBox server returned ${value.runtimeType}');
}
