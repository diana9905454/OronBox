part of 'creator_editor_page.dart';

extension _CreatorEditorAssetCards on _CreatorEditorViewState {
  String? _assetMeta(_DraftAsset? asset) {
    if (asset == null) return null;
    final parts = [
      if (asset.width > 0 && asset.height > 0)
        '${asset.width} × ${asset.height}',
      if (asset.size != null) formatCreatorFileSize(asset.size!),
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  Widget _mediaRoleCard(
    AppLocalizations l10n,
    String role, {
    required double previewHeight,
  }) {
    final colors = Theme.of(context).colorScheme;
    final asset = role == 'icon' ? _icon : _cover;
    final processing = _processingMediaRole == role;
    final label = switch ((role, _publishAstroBox)) {
      ('icon', true) => l10n.creatorRequiredIcon,
      ('cover', true) => l10n.creatorRequiredCover,
      ('icon', _) => l10n.creatorOptionalIcon,
      (_, _) => l10n.creatorOptionalCover,
    };
    final shapeHint =
        asset == null ||
            asset.width <= 0 ||
            asset.height <= 0 ||
            !_publishAstroBox
        ? null
        : switch (role) {
            'icon' =>
              asset.width != asset.height ? l10n.creatorIconShapeHint : null,
            _ =>
              (asset.width / asset.height - 1.5).abs() > 0.02
                  ? l10n.creatorCoverShapeHint
                  : null,
          };
    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: previewHeight,
            child: _mediaPreviewBox(colors, role, asset, processing),
          ),
          const SizedBox(height: 10),
          Text(label, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 2),
          Text(
            _assetMeta(asset) ?? ' ',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: colors.onSurfaceVariant),
          ),
          if (shapeHint != null) ...[
            const SizedBox(height: 2),
            Text(
              shapeHint,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: colors.error),
            ),
          ],
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: widget.state.loading || processing
                      ? null
                      : () => _pickMediaRole(role),
                  icon: const Icon(Icons.file_upload_outlined, size: 18),
                  label: Text(asset == null ? l10n.add : l10n.replace),
                ),
              ),
              if (asset != null)
                Expanded(
                  child: TextButton.icon(
                    onPressed: widget.state.loading || processing
                        ? null
                        : () => _update(() {
                            if (role == 'icon') {
                              _icon = null;
                            } else {
                              _cover = null;
                            }
                          }),
                    style: TextButton.styleFrom(foregroundColor: colors.error),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: Text(l10n.delete),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _mediaPreviewBox(
    ColorScheme colors,
    String role,
    _DraftAsset? asset,
    bool processing,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: ColoredBox(
        color: colors.surfaceContainerHighest,
        child: processing
            ? _imageProcessingIndicator()
            : asset?.bytes != null
            ? Image.memory(
                asset!.bytes!,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              )
            : Center(
                child: Icon(
                  role == 'icon'
                      ? Icons.image_outlined
                      : Icons.panorama_outlined,
                  size: 40,
                  color: colors.onSurfaceVariant,
                ),
              ),
      ),
    );
  }

  Widget _previewCard(AppLocalizations l10n, int index) {
    const previewHeight = 144.0;
    const cardWidth = 220.0;
    final colors = Theme.of(context).colorScheme;
    final asset = _previews[index];
    final processing = _processingPreviewIndex == index;
    return SizedBox(
      width: cardWidth,
      child: Container(
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    height: previewHeight,
                    child: ColoredBox(
                      color: colors.surfaceContainerHighest,
                      child: processing
                          ? _imageProcessingIndicator()
                          : asset.bytes != null
                          ? Image.memory(
                              asset.bytes!,
                              fit: BoxFit.contain,
                              alignment: Alignment.center,
                              width: double.infinity,
                              height: double.infinity,
                            )
                          : Center(
                              child: Icon(
                                Icons.image_outlined,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                    ),
                  ),
                ),
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest.withValues(
                        alpha: 0.9,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '#${index + 1}',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(bottom: 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _assetMeta(asset) ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: colors.onSurfaceVariant),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _cardAction(
                        icon: Icons.file_upload_outlined,
                        tooltip: l10n.replace,
                        onPressed:
                            widget.state.loading ||
                                _processingPreviewIndex != null
                            ? null
                            : () => _replacePreview(index),
                      ),
                      _cardAction(
                        icon: Icons.delete_outline,
                        tooltip: l10n.delete,
                        onPressed:
                            widget.state.loading ||
                                _processingPreviewIndex != null
                            ? null
                            : () => _update(() => _previews.removeAt(index)),
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

  Widget _processingPreviewCard() {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: 220,
      height: 196,
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: _imageProcessingIndicator(),
    );
  }

  Widget _imageProcessingIndicator() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox.square(
          dimension: 28,
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
        const SizedBox(height: 10),
        Text(
          AppLocalizations.of(context)!.creatorProcessingImage,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
  );

  Widget _cardAction({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
  }) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 32, height: 32),
      padding: EdgeInsets.zero,
    );
  }

  Widget _artifactCard(AppLocalizations l10n, int index) {
    final colors = Theme.of(context).colorScheme;
    final asset = _artifacts[index];
    final selected = _deviceSelections[asset.key] ?? const <String>{};
    final meta = [
      if (asset.packageId.isNotEmpty) asset.packageId,
      if (asset.version.isNotEmpty) asset.version,
      if (asset.size != null) formatCreatorFileSize(asset.size!),
    ].join(' · ');
    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.insert_drive_file_outlined),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      asset.name,
                      style: Theme.of(context).textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (meta.isNotEmpty)
                      Text(
                        meta,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: colors.onSurfaceVariant),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: widget.state.loading
                    ? null
                    : () => _pickArtifact(asset),
                icon: const Icon(Icons.sync, size: 18),
                label: Text(l10n.replace),
              ),
              TextButton(
                onPressed: widget.state.loading
                    ? null
                    : () => _removeArtifact(asset.key),
                style: TextButton.styleFrom(foregroundColor: colors.error),
                child: Text(l10n.delete),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            l10n.creatorBindDevices,
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 8),
          Material(
            color: colors.surfaceContainerHighest.withValues(alpha: .52),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: widget.state.loading
                  ? null
                  : () => _openDeviceSelection(asset),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Icon(Icons.devices_other_outlined, color: colors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            selected.isEmpty
                                ? l10n.creatorNoDevicesSelected
                                : l10n.creatorSelectedDeviceCount(
                                    selected.length,
                                  ),
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          if (selected.isNotEmpty)
                            Text(
                              widget.state.devices
                                  .where(
                                    (device) => selected.contains(device.id),
                                  )
                                  .map((device) => device.name)
                                  .join('、'),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: colors.onSurfaceVariant),
                            ),
                          if (selected.isEmpty)
                            Text(
                              l10n.creatorAtLeastOneDevice,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: colors.error),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.chevron_right, color: colors.onSurfaceVariant),
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
