part of 'creator_editor_page.dart';

extension _CreatorEditorBundleBuilder on _CreatorEditorViewState {
  Future<Uint8List?> _prepareBundle(
    List<Map<String, Object?>> publications,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final missing = [
      for (final asset in [_icon, _cover, ..._previews, ..._artifacts])
        if (asset != null && asset.bytes == null) asset,
    ];
    for (var index = 0; index < missing.length; index++) {
      if (!mounted) return null;
      _update(() {
        _publishStage = l10n.creatorPublishPreparing(
          index + 1,
          missing.length + 1,
        );
        _publishStageProgress = index / (missing.length + 1);
      });
      missing[index].bytes = await widget.controller.blob(
        widget.workspace.resource.id,
        missing[index].sha256,
      );
    }
    // Normalize legacy media loaded from older revisions as well. Newly
    // selected media already uses WebP, so avoid a second lossy encode when
    // the extension and dimensions are already canonical.
    for (final entry in <(String, _DraftAsset?)>[
      ('icon', _icon),
      ('cover', _cover),
      ..._previews.map((asset) => ('preview', asset)),
    ]) {
      final asset = entry.$2;
      if (asset?.bytes == null) continue;
      final maxDimension = entry.$1 == 'icon'
          ? creatorIconMaxDimension
          : creatorMediaMaxDimension;
      if (asset!.name.toLowerCase().endsWith('.webp') &&
          asset.width <= maxDimension &&
          asset.height <= maxDimension) {
        continue;
      }
      final processed = await processResourceImage(
        asset.bytes!,
        maxDimension: maxDimension,
      );
      if (processed == null) {
        _showFailure(l10n.creatorInvalidImage);
        return null;
      }
      asset
        ..name = 'image.webp'
        ..bytes = processed.bytes
        ..width = processed.width
        ..height = processed.height;
    }
    if (!mounted) return null;
    _update(() {
      _publishStage = l10n.creatorPublishPreparing(
        missing.length + 1,
        missing.length + 1,
      );
      _publishStageProgress = 1;
    });
    return _buildBundle(publications);
  }

  Uint8List _buildBundle(List<Map<String, Object?>> publications) {
    final archive = Archive();
    void addFile(String path, Uint8List bytes) =>
        archive.addFile(ArchiveFile(path, bytes.length, bytes));
    String digest(Uint8List bytes) => sha256.convert(bytes).toString();
    Map<String, Object?> mediaRef(_DraftAsset asset, String path) => {
      'file': path,
      'sha256': digest(asset.bytes!),
      'width': asset.width,
      'height': asset.height,
    };
    String pathOf(String stem, _DraftAsset asset) => '$stem.webp';
    final media = <String, Object?>{};
    if (_icon case final icon?) {
      final path = pathOf('media/icon', icon);
      addFile(path, icon.bytes!);
      media['icon'] = mediaRef(icon, path);
    }
    if (_cover case final cover?) {
      final path = pathOf('media/cover', cover);
      addFile(path, cover.bytes!);
      media['cover'] = mediaRef(cover, path);
    }
    media['previews'] = [
      for (var index = 0; index < _previews.length; index++)
        () {
          final path = pathOf('media/preview-$index', _previews[index]);
          addFile(path, _previews[index].bytes!);
          return mediaRef(_previews[index], path);
        }(),
    ];
    final artifacts = [
      for (var index = 0; index < _artifacts.length; index++)
        () {
          final asset = _artifacts[index];
          final path = 'artifacts/$index.bin';
          addFile(path, asset.bytes!);
          return <String, Object?>{
            'file': path,
            'original_name': asset.name,
            'type': asset.type,
            'package_id': asset.packageId,
            'package_version': asset.version,
            'sha256': digest(asset.bytes!),
            'device_ids': (_deviceSelections[asset.key] ?? const <String>{})
                .toList(),
          };
        }(),
    ];
    final manifest = utf8.encode(
      jsonEncode({
        'version': 1,
        'kind': widget.workspace.resource.kind == CreatorResourceKind.watchface
            ? 'watchface'
            : 'quickapp',
        'name': _name.text.trim(),
        'summary': _summary.text.trim(),
        'description': _description.text,
        'description_format':
            _description.text == widget.workspace.latestRevision?.description
            ? widget.workspace.latestRevision!.descriptionFormat
            : 'markdown',
        'paid_type': communityPaidTypeToWire(_paidType),
        if (_externalPurchaseEnabled) ...{
          'purchase_link': _externalPurchaseLink.text.trim(),
          'purchase_price': double.tryParse(
            _externalPurchaseAmount.text.trim(),
          ),
          'purchase_currency': 'CNY',
        },
        'attributes': _attributes.toList()..sort(),
        'links': [
          for (final link in _links)
            if (link.title.text.trim().isNotEmpty &&
                link.url.text.trim().isNotEmpty)
              {'title': link.title.text.trim(), 'url': link.url.text.trim()},
        ],
        'media': media,
        'artifacts': artifacts,
        'publications': plansForManifest(publications),
      }),
    );
    addFile('manifest.json', manifest);
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  List<Map<String, Object?>> plansForManifest(
    List<Map<String, Object?>> publications,
  ) => [
    for (final publication in publications)
      if (publication['target'] != 'oronbox') publication,
  ];
}
