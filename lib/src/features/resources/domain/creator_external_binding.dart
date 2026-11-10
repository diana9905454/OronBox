import 'dart:convert';

class CreatorBandBbsBindingEntry {
  const CreatorBandBbsBindingEntry({
    required this.categoryId,
    required this.resourceId,
    this.url = '',
  });

  final String categoryId;
  final String resourceId;
  final String url;
  String get resolvedUrl => _publicUrl(url).isNotEmpty
      ? _publicUrl(url)
      : _bandBbsResourceUrl(resourceId);
}

List<CreatorBandBbsBindingEntry> parseCreatorBandBbsBinding(Object? value) {
  Object? decoded = value;
  try {
    if (value is String) decoded = jsonDecode(value);
  } catch (_) {
    return const [];
  }
  if (decoded is! Map) return const [];
  final entries = <CreatorBandBbsBindingEntry>[];
  for (final entry in decoded.entries) {
    final categoryId = entry.key.toString();
    final item = entry.value;
    final resourceId = item is Map
        ? item['resource_id']?.toString() ?? ''
        : item?.toString() ?? '';
    if (categoryId.isEmpty || resourceId.isEmpty) continue;
    entries.add(
      CreatorBandBbsBindingEntry(
        categoryId: categoryId,
        resourceId: resourceId,
        url: item is Map ? item['url']?.toString() ?? '' : '',
      ),
    );
  }
  entries.sort(
    (a, b) => (int.tryParse(a.categoryId) ?? 0).compareTo(
      int.tryParse(b.categoryId) ?? 0,
    ),
  );
  return entries;
}

Map<String, Object?>? creatorExternalBinding(
  List<Map<String, Object?>> bindings,
  String provider,
) => bindings.where((binding) => binding['provider'] == provider).firstOrNull;

String _publicUrl(Object? value) {
  final raw = value is String ? value.trim() : '';
  final uri = Uri.tryParse(raw);
  return uri != null &&
          (uri.scheme == 'https' || uri.scheme == 'http') &&
          uri.host.isNotEmpty &&
          uri.userInfo.isEmpty
      ? raw
      : '';
}

String _bandBbsResourceUrl(Object? id) {
  final text = id?.toString() ?? '';
  return RegExp(r'^[1-9][0-9]*$').hasMatch(text)
      ? 'https://www.bandbbs.cn/resources/$text/'
      : '';
}

List<String> creatorPublicationLinkUrls(Map<String, Object?> publication) {
  final urls = <String>{};
  final detail = publication['status_detail'];
  if (detail is Map) {
    for (final key in ['resources', 'completed_categories']) {
      final resources = detail[key];
      if (resources is! Map) continue;
      final entries = resources.entries.toList()
        ..sort(
          (a, b) => (int.tryParse(a.key.toString()) ?? 0).compareTo(
            int.tryParse(b.key.toString()) ?? 0,
          ),
        );
      for (final entry in entries) {
        final value = entry.value;
        var url = value is Map ? _publicUrl(value['url']) : '';
        if (url.isEmpty && publication['target'] == 'bandbbs') {
          url = _bandBbsResourceUrl(
            value is Map ? value['resource_id'] : value,
          );
        }
        if (url.isNotEmpty) urls.add(url);
      }
    }
  }
  final externalUrl = _publicUrl(publication['external_url']);
  if (externalUrl.isNotEmpty) urls.add(externalUrl);
  return urls.toList();
}
