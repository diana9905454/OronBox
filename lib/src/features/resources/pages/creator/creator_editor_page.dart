import 'dart:async';
import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/utils/error_localization.dart';
import 'package:oronbox/src/app/utils/picked_file.dart';
import 'package:oronbox/src/core/constants/style_constants.dart';
import 'package:oronbox/src/features/accounts/application/host_accounts.dart';
import 'package:oronbox/src/features/resources/application/creator/creator_workspace_controller.dart';
import 'package:oronbox/src/features/resources/application/oronbox_resource_attributes.dart';
import 'package:oronbox/src/features/resources/domain/community_resource.dart';
import 'package:oronbox/src/features/resources/domain/creator_external_binding.dart';
import 'package:oronbox/src/features/resources/domain/creator_publication_plan.dart';
import 'package:oronbox/src/features/resources/domain/creator_workspace.dart';
import 'package:oronbox/src/features/resources/pages/creator/creator_device_selection_dialog.dart';
import 'package:oronbox/src/features/resources/pages/creator/creator_editor_models.dart';
import 'package:oronbox/src/features/resources/pages/creator/creator_shared.dart';
import 'package:oronbox/src/features/resources/services/resource_install_service.dart';
import 'package:oronbox/src/features/resources/services/resource_image_processor.dart';
import 'package:oronbox/src/features/resources/services/resource_payload_analyzer.dart';
import 'package:oronbox/src/features/resources/services/watchface_payload_repair.dart';

part 'creator_editor_bundle_builder.dart';
part 'creator_editor_asset_cards.dart';
part 'creator_editor_publication_section.dart';

class CreatorEditorView extends StatefulWidget {
  const CreatorEditorView({
    super.key,
    required this.workspace,
    required this.state,
    required this.controller,
    required this.ref,
  });

  final CreatorWorkspace workspace;
  final CreatorWorkspaceState state;
  final CreatorWorkspaceController controller;
  final WidgetRef ref;

  @override
  State<CreatorEditorView> createState() => _CreatorEditorViewState();
}

Widget _publicationLogo(String target) => switch (target) {
  'bandbbs' => const CreatorBrandLogo(
    asset: 'assets/images/brands/bandbbs.svg',
    label: 'BandBBS',
  ),
  'astrobox' => const CreatorBrandLogo(
    asset: 'assets/images/brands/astrobox.svg',
    label: 'AstroBox',
  ),
  _ => const CreatorOronBoxLogo(),
};

// BandBBS fan-out publishes one resource per category; the URLs live in
// status_detail.resources.
List<String> _publicationLinkUrls(Map<String, Object?> publication) {
  final urls = <String>[];
  final resources =
      (publication['status_detail'] as Map?)?['resources'] as Map?;
  if (resources != null) {
    final categories = resources.keys.map((value) => value.toString()).toList()
      ..sort((a, b) => (int.tryParse(a) ?? 0).compareTo(int.tryParse(b) ?? 0));
    for (final category in categories) {
      final url = (resources[category] as Map?)?['url']?.toString() ?? '';
      if (url.isNotEmpty) urls.add(url);
    }
  }
  return urls;
}

// velajs' starter project uses this identifier.  It is not a publisher-owned
// package name and AstroBox uses package IDs as global resource identities.
const _velajsDefaultPackageId = 'com.application.watch.demo';

String? _invalidPackageIdReason(
  String? packageId, {
  required bool isWatchface,
  required AppLocalizations l10n,
}) {
  final value = packageId?.trim() ?? '';
  if (value.isEmpty) {
    return isWatchface
        ? l10n.creatorWatchfaceMissingId
        : l10n.creatorQuickAppMissingPackage;
  }
  if (value == _velajsDefaultPackageId) {
    return l10n.creatorVelajsDefaultPackage;
  }
  return null;
}

bool _isValidWatchfaceIdOverride(String value) =>
    RegExp(r'^[0-9]{1,12}$').hasMatch(value.trim()) &&
    !RegExp(r'^[0]+$').hasMatch(value.trim());

class _CreatorEditorViewState extends State<CreatorEditorView> {
  int _editorStage = 0;
  late final TextEditingController _name = TextEditingController(
    text:
        widget.workspace.latestRevision?.name ??
        widget.workspace.resource.draftName,
  );
  late final TextEditingController _summary = TextEditingController(
    text: widget.workspace.latestRevision?.summary ?? '',
  );
  final _astroItemId = TextEditingController();
  final _astroRepository = TextEditingController();
  final _astroTags = TextEditingController();
  final _astroAuthor = TextEditingController();
  final _bandBbsVersionTitle = TextEditingController();
  final _bandBbsVersionMessage = TextEditingController();
  final _externalPurchaseLink = TextEditingController();
  final _externalPurchaseAmount = TextEditingController();
  bool _publishBandBbs = false;
  bool _publishAstroBox = false;
  bool _astroBindABAccount = true;
  bool _externalPurchaseEnabled = false;
  bool _overwritePreviousBandBbs = false;
  String _astroPaidType = '';
  CommunityPaidType _paidType = CommunityPaidType.free;
  List<Map<String, Object?>>? _publicationCategories;
  CreatorPublicationPlan? _publicationPlan;
  bool _loadingPublicationPlan = false;
  String? _processingMediaRole;
  int? _processingPreviewIndex;
  bool _addingPreview = false;
  final Map<String, Set<String>> _deviceSelections = {};
  _DraftAsset? _icon;
  _DraftAsset? _cover;
  final List<_DraftAsset> _previews = [];
  final List<_DraftAsset> _artifacts = [];
  late final List<_DraftLink> _links = [
    for (final link in widget.workspace.links)
      _DraftLink(title: link.title, url: link.url),
  ];
  late final Set<String> _attributes = {
    ...?widget.workspace.latestRevision?.attributes,
  };
  List<OronBoxResourceAttribute> _attributeDefinitions = const [];
  bool _loadingAttributes = true;
  String _lastAutoItemId = '';
  String _lastAutoRepo = '';
  String _publishStage = '';
  double _publishStageProgress = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_loadAttributes());
    _seedAssets();
    // The saved publish intent on the draft revision is the editing baseline;
    // submitted revisions only have dispatch rows, which double as the intent
    // of the last submit.
    CreatorRevision? draft;
    for (final revision in widget.workspace.revisions) {
      if (revision.state == 'draft') {
        draft = revision;
        break;
      }
    }
    final draftPlan = draft?.publicationPlan;
    final baselineRevision = draft ?? widget.workspace.latestRevision;
    if (baselineRevision != null) {
      _paidType = baselineRevision.paidType;
      _externalPurchaseLink.text = baselineRevision.purchaseLink;
      if (baselineRevision.purchasePrice != null) {
        _externalPurchaseAmount.text = baselineRevision.purchasePrice!
            .toStringAsFixed(2);
      }
      _externalPurchaseEnabled = baselineRevision.purchaseLink
          .trim()
          .isNotEmpty;
    }
    final planned = draftPlan ?? widget.workspace.publications;
    for (final publication in planned) {
      final config = publication['config'] is Map
          ? (publication['config'] as Map).cast<String, Object?>()
          : const <String, Object?>{};
      switch (publication['target']) {
        case 'bandbbs':
          _publishBandBbs = true;
          _overwritePreviousBandBbs =
              config['overwrite_previous_version'] == true;
          _bandBbsVersionTitle.text = config['version_title']?.toString() ?? '';
          _bandBbsVersionMessage.text =
              config['version_message']?.toString() ?? '';
          if (_externalPurchaseAmount.text.trim().isEmpty &&
              config['price'] is num) {
            _externalPurchaseAmount.text = (config['price'] as num)
                .toStringAsFixed(2);
          }
        case 'astrobox':
          _publishAstroBox = true;
          _astroItemId.text = config['item_id']?.toString() ?? '';
          _astroRepository.text = config['repo_name']?.toString() ?? '';
          _astroTags.text = (config['tags'] as List? ?? const []).join(';');
          _astroAuthor.text = config['author']?.toString() ?? '';
          _astroPaidType = config['paid_type']?.toString() ?? '';
          _astroBindABAccount = config['bind_ab_account'] != false;
      }
    }
    // No publish intent recorded (fresh import, or an empty one): derive it
    // from the imported external identities so their targets start enabled.
    if ((draftPlan == null || draftPlan.isEmpty) &&
        widget.workspace.publications.isEmpty) {
      for (final binding in widget.workspace.bindings) {
        switch (binding['provider']) {
          case 'bandbbs':
            _publishBandBbs = true;
          case 'astrobox':
            _publishAstroBox = true;
        }
      }
    }
    // Imported resources carry their existing external identity; prefill the
    // publish form from it so a publication updates in place.
    for (final binding in widget.workspace.bindings) {
      if (binding['provider'] != 'astrobox') continue;
      if (_astroItemId.text.isEmpty) {
        _astroItemId.text = binding['external_id']?.toString() ?? '';
      }
      final meta = binding['meta'];
      if (meta is Map) {
        if (_astroRepository.text.isEmpty) {
          _astroRepository.text = meta['repo_name']?.toString() ?? '';
        }
        if (_astroTags.text.isEmpty) {
          final rawTags = meta['tags']?.toString() ?? '';
          try {
            _astroTags.text = (jsonDecode(rawTags) as List? ?? const []).join(
              ';',
            );
          } catch (_) {
            _astroTags.text = rawTags
                .split(RegExp(r'[,;，；]'))
                .map((value) => value.trim())
                .where((value) => value.isNotEmpty)
                .join(';');
          }
        }
        if (_astroAuthor.text.isEmpty) {
          _astroAuthor.text = meta['author']?.toString() ?? '';
        }
        if (_astroPaidType.isEmpty) {
          _astroPaidType = meta['paid_type']?.toString() ?? '';
        }
      }
    }
    // Older imported workspaces may have the choice only in their external
    // AstroBox binding. Use it as a one-time seed when there is no revision
    // baseline; all subsequent edits are driven by the canonical field.
    if (baselineRevision == null && _astroPaidType.isNotEmpty) {
      _paidType = communityPaidTypeFromWire(_astroPaidType);
    }
    if (_astroAuthor.text.isEmpty) {
      _astroAuthor.text =
          widget.ref.read(hostAccountsProvider).bandbbs.username ?? '';
    }
    _autoFillAstroItemId();
    if (_publishBandBbs) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _loadPublicationPlan(),
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _hydratePreviews());
  }

  Future<void> _loadAttributes() async {
    try {
      final definitions = await OronBoxResourceAttributeCatalog().load();
      if (mounted) setState(() => _attributeDefinitions = definitions);
    } catch (error) {
      if (mounted) showCreatorFailure(context, error);
    } finally {
      if (mounted) setState(() => _loadingAttributes = false);
    }
  }

  void _seedAssets() {
    for (final media in widget.workspace.media) {
      final asset = _DraftAsset(
        key: media.id,
        name: media.role,
        sha256: media.sha256,
        sizeBytes: media.sizeBytes,
        width: media.width,
        height: media.height,
      );
      switch (media.role) {
        case 'icon':
          _icon ??= asset;
        case 'cover':
          _cover ??= asset;
        case 'preview':
          if (_previews.every((item) => item.key != asset.key)) {
            _previews.add(asset);
          }
      }
    }
    for (final artifact in widget.workspace.artifacts) {
      if (_artifacts.any((item) => item.key == artifact.id)) continue;
      _artifacts.add(
        _DraftAsset(
          key: artifact.id,
          name: artifact.name,
          sha256: artifact.sha256,
          sizeBytes: artifact.sizeBytes,
          packageId: artifact.packageId,
          version: artifact.version,
          type: artifact.analysisKind == 'watchface'
              ? 'velaos_watchface'
              : 'velaos_quickapp',
        ),
      );
      _deviceSelections[artifact.id] = artifact.devices.toSet();
    }
  }

  Future<void> _hydratePreviews() async {
    for (final asset in [_icon, _cover, ..._previews]) {
      if (asset == null || asset.bytes != null || asset.sha256.isEmpty) {
        continue;
      }
      try {
        final bytes = await widget.controller.blob(
          widget.workspace.resource.id,
          asset.sha256,
        );
        if (mounted && _contains(asset)) {
          setState(() => asset.bytes = bytes);
        }
      } catch (_) {}
    }
  }

  bool _contains(_DraftAsset asset) =>
      identical(_icon, asset) ||
      identical(_cover, asset) ||
      _previews.any((item) => identical(item, asset));

  void _autoFillAstroItemId() {
    final candidate = _artifacts
        .map((artifact) => artifact.packageId)
        .firstWhere((id) => id.isNotEmpty, orElse: () => '');
    if (candidate.isEmpty) return;
    if (_astroItemId.text.isEmpty || _astroItemId.text == _lastAutoItemId) {
      _astroItemId.text = candidate;
      _lastAutoItemId = candidate;
    }
    final repoCandidate = 'astrobox-resource-$candidate';
    if (creatorExternalBinding(widget.workspace.bindings, 'astrobox') != null) {
      return;
    }
    if (_astroRepository.text.isEmpty ||
        _astroRepository.text == _lastAutoRepo) {
      _astroRepository.text = repoCandidate;
      _lastAutoRepo = repoCandidate;
    }
  }

  Widget _stageChip(AppLocalizations l10n, String label, int stage) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: FilterChip(
      label: Text(label),
      selected: _editorStage == stage,
      showCheckmark: false,
      onSelected: (_) => setState(() => _editorStage = stage),
    ),
  );

  @override
  void dispose() {
    _name.dispose();
    _summary.dispose();
    _astroItemId.dispose();
    _astroRepository.dispose();
    _astroTags.dispose();
    _astroAuthor.dispose();
    _bandBbsVersionTitle.dispose();
    _bandBbsVersionMessage.dispose();
    _externalPurchaseLink.dispose();
    _externalPurchaseAmount.dispose();
    for (final link in _links) {
      link.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final workspace = widget.workspace;
    final colors = Theme.of(context).colorScheme;
    final publishIndicatorValue = _publishStage.isNotEmpty
        ? (_publishStageProgress > 0 ? _publishStageProgress : null)
        : switch (widget.state.publishProgress) {
            null => null,
            final progress => progress >= 1 ? null : progress,
          };
    final publishIndicatorLabel = _publishStage.isNotEmpty
        ? _publishStage
        : switch (widget.state.publishProgress) {
            null => '',
            final progress =>
              progress >= 1
                  ? l10n.creatorPublishServer
                  : l10n.creatorPublishUploading((progress * 100).round()),
          };
    return Column(
      children: [
        Expanded(
          child: SafeArea(
            top: false,
            bottom: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: StyleConstants.pageMaxWidth,
                ),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    Center(
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        children: [
                          _stageChip(l10n, l10n.creatorStageInfo, 0),
                          _stageChip(l10n, l10n.creatorStageFiles, 1),
                          _stageChip(l10n, l10n.creatorStagePublish, 2),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_editorStage == 2) ...[
                      CreatorSectionTitle(
                        icon: Icons.edit_outlined,
                        title: l10n.creatorReviewStatus,
                      ),
                      const SizedBox(height: 8),
                      if (widget.state.error != null) ...[
                        MaterialBanner(
                          content: Text(
                            localizedErrorMessage(l10n, widget.state.error!),
                          ),
                          actions: [
                            TextButton(
                              onPressed: widget.controller.refresh,
                              child: Text(l10n.refresh),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (workspace.resource.moderationState != 'visible') ...[
                        CreatorModerationNotice(resource: workspace.resource),
                        const SizedBox(height: 12),
                      ],
                      if (workspace.review case final review?) ...[
                        CreatorReviewFeedback(review: review),
                        const SizedBox(height: 16),
                      ],
                      if (workspace.bindings.any((binding) {
                        final meta = binding['meta'];
                        return meta is Map &&
                            meta['imported']?.toString() == 'true';
                      })) ...[
                        Card(
                          color: colors.secondaryContainer,
                          margin: EdgeInsets.zero,
                          child: ListTile(
                            leading: const Icon(Icons.fact_check_outlined),
                            title: Text(l10n.creatorImportReviewNotice),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ],
                    if (_editorStage == 0) ...[
                      CreatorSectionTitle(
                        icon: Icons.description_outlined,
                        title: l10n.basicInfo,
                      ),
                      const SizedBox(height: 8),
                      CreatorEditorCard(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          children: [
                            TextField(
                              controller: _name,
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                labelText: l10n.creatorResourceName,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _summary,
                              minLines: 3,
                              maxLines: 8,
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                labelText: l10n.creatorResourceSummary,
                              ),
                            ),
                            if (_name.text.trim().isEmpty ||
                                _summary.text.trim().isEmpty)
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    l10n.creatorResourceMetadataRequired,
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .error,
                                    ),
                                  ),
                                ),
                              ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<CommunityPaidType>(
                              initialValue: _paidType,
                              decoration: InputDecoration(
                                labelText: l10n.creatorPaidType,
                              ),
                              items: [
                                DropdownMenuItem(
                                  value: CommunityPaidType.free,
                                  child: Text(l10n.free),
                                ),
                                DropdownMenuItem(
                                  value: CommunityPaidType.paid,
                                  child: Text(l10n.paid),
                                ),
                                DropdownMenuItem(
                                  value: CommunityPaidType.forcePaid,
                                  child: Text(l10n.forcePaid),
                                ),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _paidType = value;
                                    if (value == CommunityPaidType.free) {
                                      _externalPurchaseEnabled = false;
                                    }
                                  });
                                }
                              },
                            ),
                            const SizedBox(height: 16),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                l10n.creatorContentAttributes,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: _loadingAttributes
                                  ? const SizedBox.square(
                                      dimension: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        for (final attribute
                                            in _attributeDefinitions)
                                          FilterChip(
                                            label: Text(
                                              attribute.labelFor(
                                                Localizations.localeOf(context),
                                              ),
                                            ),
                                            selected: _attributes.contains(
                                              attribute.id,
                                            ),
                                            onSelected: (selected) => setState(
                                              () => selected
                                                  ? _attributes.add(
                                                      attribute.id,
                                                    )
                                                  : _attributes.remove(
                                                      attribute.id,
                                                    ),
                                            ),
                                          ),
                                      ],
                                    ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      CreatorSectionTitle(
                        icon: Icons.link_outlined,
                        title: l10n.creatorAdditionalLinks,
                      ),
                      const SizedBox(height: 8),
                      for (var index = 0; index < _links.length; index++) ...[
                        CreatorEditorCard(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  children: [
                                    TextField(
                                      controller: _links[index].title,
                                      decoration: InputDecoration(
                                        labelText: l10n.creatorLinkTitle,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    TextField(
                                      controller: _links[index].url,
                                      keyboardType: TextInputType.url,
                                      decoration: InputDecoration(
                                        labelText: l10n.creatorLinkUrl,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: l10n.delete,
                                onPressed: () => setState(() {
                                  _links.removeAt(index).dispose();
                                }),
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton.tonalIcon(
                          onPressed: _links.length >= 16
                              ? null
                              : () => setState(() => _links.add(_DraftLink())),
                          icon: const Icon(Icons.add_link),
                          label: Text(l10n.creatorAddLink),
                        ),
                      ),
                      const SizedBox(height: 20),
                      CreatorSectionTitle(
                        icon: Icons.collections_outlined,
                        title: l10n.creatorIconCover,
                      ),
                      const SizedBox(height: 8),
                      Builder(
                        builder: (context) {
                          const iconWidth = 208.0;
                          const previewHeight = iconWidth - 24;
                          const coverWidth = previewHeight * 1.5 + 24;
                          return Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              SizedBox(
                                width: iconWidth,
                                child: _mediaRoleCard(
                                  l10n,
                                  'icon',
                                  previewHeight: previewHeight,
                                ),
                              ),
                              SizedBox(
                                width: coverWidth,
                                child: _mediaRoleCard(
                                  l10n,
                                  'cover',
                                  previewHeight: previewHeight,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      CreatorSectionTitle(
                        icon: Icons.photo_library_outlined,
                        title: l10n.previewImages,
                      ),
                      const SizedBox(height: 8),
                      if (_previews.isNotEmpty || _addingPreview)
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            for (
                              var index = 0;
                              index < _previews.length;
                              index++
                            )
                              _previewCard(l10n, index),
                            if (_addingPreview) _processingPreviewCard(),
                          ],
                        ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton.tonalIcon(
                          onPressed: widget.state.loading || _addingPreview
                              ? null
                              : _pickPreview,
                          icon: const Icon(Icons.add_photo_alternate_outlined),
                          label: Text(l10n.add),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    if (_editorStage == 1) ...[
                      CreatorSectionTitle(
                        icon: Icons.folder_zip_outlined,
                        title: l10n.packageFiles,
                      ),
                      const SizedBox(height: 8),
                      for (
                        var index = 0;
                        index < _artifacts.length;
                        index++
                      ) ...[
                        _artifactCard(l10n, index),
                        const SizedBox(height: 12),
                      ],
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton.tonalIcon(
                          onPressed: widget.state.loading
                              ? null
                              : _pickArtifact,
                          icon: const Icon(Icons.upload_file_outlined),
                          label: Text(l10n.creatorAddArtifact),
                        ),
                      ),
                      if (_paidType != CommunityPaidType.free) ...[
                        const SizedBox(height: 16),
                        CreatorEditorCard(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            children: [
                              CheckboxListTile(
                                value: _externalPurchaseEnabled,
                                onChanged: widget.state.loading
                                    ? null
                                    : (value) => setState(
                                        () => _externalPurchaseEnabled =
                                            value == true,
                                      ),
                                contentPadding: EdgeInsets.zero,
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                title: Text(
                                  l10n.creatorFullVersionExternalPurchase,
                                ),
                                subtitle: Text(
                                  l10n.creatorExternalPurchaseDescription,
                                ),
                              ),
                              if (_externalPurchaseEnabled) ...[
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _externalPurchaseLink,
                                  keyboardType: TextInputType.url,
                                  onChanged: (_) => setState(() {}),
                                  decoration: InputDecoration(
                                    labelText: l10n.creatorExternalPurchaseLink,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _externalPurchaseAmount,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  onChanged: (_) => setState(() {}),
                                  decoration: InputDecoration(
                                    labelText:
                                        l10n.creatorExternalPurchaseAmount,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                    ],
                    if (_editorStage == 2) ...[
                      if (workspace.publications.isNotEmpty) ...[
                        CreatorSectionTitle(
                          icon: Icons.assignment_turned_in_outlined,
                          title: l10n.creatorPublicationStatus,
                        ),
                        const SizedBox(height: 8),
                        _publicationStatusSection(l10n),
                        const SizedBox(height: 16),
                      ],
                      CreatorSectionTitle(
                        icon: Icons.publish_outlined,
                        title: l10n.publishTargets,
                      ),
                      const SizedBox(height: 8),
                      _publicationEditor(l10n),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        CreatorBottomBar(
          children: [
            if (widget.workspace.revisions.any(
                  (revision) => revision.state != 'draft',
                ) &&
                !widget.workspace.resource.isFrozen &&
                (widget.workspace.resource.moderationState == 'visible' ||
                    widget.workspace.resource.canRestore))
              TextButton.icon(
                onPressed: widget.state.loading ? null : _toggleTakedown,
                icon: Icon(
                  widget.workspace.resource.isSuspended
                      ? Icons.unarchive_outlined
                      : Icons.archive_outlined,
                ),
                label: Text(
                  widget.workspace.resource.isSuspended
                      ? l10n.creatorRestoreAction
                      : l10n.creatorArchiveAction,
                ),
              ),
            TextButton.icon(
              onPressed: widget.state.loading ? null : _saveDraft,
              icon: const Icon(Icons.save_outlined),
              label: Text(l10n.creatorSaveDraft),
            ),
            TextButton.icon(
              onPressed: widget.state.loading ? null : _confirmDelete,
              icon: const Icon(Icons.delete_outline),
              label: Text(l10n.creatorDeleteResource),
            ),
            const Spacer(),
            if (_publishStage.isNotEmpty ||
                widget.state.publishProgress != null)
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          publishIndicatorLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          value: publishIndicatorValue,
                          strokeWidth: 2.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            _primaryActionButton(l10n),
          ],
        ),
      ],
    );
  }

  Widget _submitButtonChild(AppLocalizations l10n) {
    if (!widget.state.loading) {
      return Text(
        _editorStage == 2 ? l10n.creatorSubmitReview : l10n.creatorNextStep,
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox.square(
          dimension: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: 8),
        Text(creatorOperationLabel(l10n, widget.state.operation)),
      ],
    );
  }

  Widget _primaryActionButton(AppLocalizations l10n) {
    final onPressed = widget.state.loading || widget.workspace.resource.isFrozen
        ? null
        : (_editorStage == 2 ? _publish : () => setState(() => _editorStage++));
    if (_editorStage == 2) {
      return FilledButton.icon(
        onPressed: onPressed,
        icon: widget.state.loading
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.send_outlined),
        label: Text(
          widget.state.loading
              ? creatorOperationLabel(l10n, widget.state.operation)
              : l10n.creatorSubmitReview,
        ),
      );
    }
    return FilledButton(onPressed: onPressed, child: _submitButtonChild(l10n));
  }

  CreatorExternalPurchaseIssue? _externalPurchaseIssue({
    required bool requireAmount,
  }) => validateCreatorExternalPurchase(
    enabled: _externalPurchaseEnabled,
    paidType: _paidType,
    link: _externalPurchaseLink.text,
    amount: _externalPurchaseAmount.text,
    requireAmount: requireAmount,
    requireHttps: _publishAstroBox,
  );

  String? _externalPurchaseValidationMessage(
    AppLocalizations l10n, {
    required bool requireAmount,
  }) => switch (_externalPurchaseIssue(requireAmount: requireAmount)) {
    CreatorExternalPurchaseIssue.link =>
      l10n.creatorExternalPurchaseLinkRequired,
    CreatorExternalPurchaseIssue.amount =>
      l10n.creatorExternalPurchaseAmountRequired,
    null => null,
  };

  bool get _bandBbsPublishingAuthorized =>
      widget.state.grants['bandbbs_publish'] == true;

  bool get _githubPublishingAuthorized =>
      (widget.state.grants['github_login']?.toString() ?? '').isNotEmpty;

  Future<PickedFileData?> _pickFile({bool image = false}) async {
    return pickFileData(
      type: image ? FileType.image : FileType.any,
      loadBytes: true,
    );
  }

  Future<void> _pickMediaRole(String role) => _run(() async {
    final file = await _pickFile(image: true);
    if (file == null || !mounted) return;
    setState(() => _processingMediaRole = role);
    await WidgetsBinding.instance.endOfFrame;
    try {
      final asset = await _processedImageAsset(
        (await file.readAsBytes())!,
        maxDimension: role == 'icon'
            ? creatorIconMaxDimension
            : creatorMediaMaxDimension,
      );
      if (!mounted) return;
      if (asset == null) {
        _showFailure(AppLocalizations.of(context)!.creatorInvalidImage);
        return;
      }
      setState(() {
        if (role == 'icon') {
          _icon = asset;
        } else {
          _cover = asset;
        }
      });
    } finally {
      if (mounted) setState(() => _processingMediaRole = null);
    }
  });

  Future<void> _pickPreview() => _run(() async {
    final file = await _pickFile(image: true);
    if (file == null || !mounted) return;
    setState(() => _addingPreview = true);
    await WidgetsBinding.instance.endOfFrame;
    try {
      final asset = await _processedImageAsset((await file.readAsBytes())!);
      if (!mounted) return;
      if (asset == null) {
        _showFailure(AppLocalizations.of(context)!.creatorInvalidImage);
        return;
      }
      setState(() => _previews.add(asset));
    } finally {
      if (mounted) setState(() => _addingPreview = false);
    }
  });

  Future<void> _replacePreview(int index) => _run(() async {
    final file = await _pickFile(image: true);
    if (file == null || !mounted) return;
    setState(() => _processingPreviewIndex = index);
    await WidgetsBinding.instance.endOfFrame;
    try {
      final asset = await _processedImageAsset((await file.readAsBytes())!);
      if (!mounted) return;
      if (asset == null) {
        _showFailure(AppLocalizations.of(context)!.creatorInvalidImage);
        return;
      }
      setState(() => _previews[index] = asset);
    } finally {
      if (mounted) setState(() => _processingPreviewIndex = null);
    }
  });

  Future<_DraftAsset?> _processedImageAsset(
    Uint8List raw, {
    int maxDimension = creatorMediaMaxDimension,
  }) async {
    final processed = await processResourceImage(
      raw,
      maxDimension: maxDimension,
    );
    if (processed == null) return null;
    final key = 'local-${DateTime.now().microsecondsSinceEpoch}';
    return _DraftAsset(
      key: key,
      name: 'image.webp',
      bytes: processed.bytes,
      width: processed.width,
      height: processed.height,
    );
  }

  Future<void> _pickArtifact([_DraftAsset? replace]) => _run(() async {
    final l10n = AppLocalizations.of(context)!;
    final file = await _pickFile();
    if (file == null || !mounted) return;
    var analysis = widget.ref
        .read(resourceInstallServiceProvider)
        .analyzePayload(
          fileName: file.name,
          bytes: (await file.readAsBytes())!,
          source: 'creator',
        );
    final isApp = analysis?.type == LocalDeviceInstallType.app;
    final isWatchface = analysis?.type == LocalDeviceInstallType.watchface;
    if (analysis == null ||
        analysis.platform != ResourcePlatform.vela ||
        (!isApp && !isWatchface)) {
      _showFailure(l10n.creatorInvalidPackage);
      return;
    }
    final expectApp =
        widget.workspace.resource.kind == CreatorResourceKind.quickApp;
    if (expectApp != isApp) {
      _showFailure(
        l10n.creatorKindMismatchMessage(
          isApp ? l10n.quickApp : l10n.watchface,
          creatorKindLabel(l10n, widget.workspace.resource.kind),
        ),
      );
      return;
    }
    final identifierIsZero =
        analysis.identifier?.trim().isNotEmpty == true &&
        RegExp(r'^0+$').hasMatch(analysis.identifier!.trim());
    if (isWatchface &&
        (analysis.identifier == null || identifierIsZero) &&
        (identifierIsZero || isZeroVelaWatchfaceId(analysis.payload))) {
      final id = await _promptWatchfaceId(l10n);
      if (id == null) return;
      final patched = replaceVelaWatchfaceId(analysis.payload, id);
      if (patched == null) {
        _showFailure(l10n.creatorWatchfacePayloadTooShort);
        return;
      }
      analysis = ResourcePayloadAnalysis(
        type: analysis.type,
        platform: analysis.platform,
        packageKind: analysis.packageKind,
        payload: Uint8List.fromList(patched),
        evidence: analysis.evidence,
        name: analysis.name,
        version: analysis.version,
        identifier: id,
        target: analysis.target,
      );
    }
    final packageIssue = _invalidPackageIdReason(
      analysis.identifier,
      isWatchface: isWatchface,
      l10n: l10n,
    );
    if (packageIssue != null) {
      _showFailure(packageIssue);
      return;
    }
    final asset = _DraftAsset(
      key: replace?.key ?? 'local-${DateTime.now().microsecondsSinceEpoch}',
      name: file.name,
      bytes: analysis.payload,
      packageId: analysis.identifier ?? '',
      version: analysis.version ?? '',
      type: isApp ? 'velaos_quickapp' : 'velaos_watchface',
    );
    setState(() {
      if (replace == null) {
        _artifacts.add(asset);
        _deviceSelections[asset.key] = <String>{};
      } else {
        final index = _artifacts.indexWhere((item) => item.key == replace.key);
        if (index >= 0) _artifacts[index] = asset;
      }
    });
    _autoFillAstroItemId();
    _rebuildPlan();
  });

  Future<String?> _promptWatchfaceId(AppLocalizations l10n) async {
    final controller = TextEditingController();
    try {
      return await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.creatorWatchfaceZeroIdTitle),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(12),
            ],
            decoration: InputDecoration(
              hintText: l10n.installQueueFixWatchfaceIdHint,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel),
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, _) => FilledButton(
                onPressed: _isValidWatchfaceIdOverride(value.text)
                    ? () => Navigator.pop(context, value.text.trim())
                    : null,
                child: Text(l10n.save),
              ),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  void _removeArtifact(String key) {
    setState(() {
      _artifacts.removeWhere((item) => item.key == key);
      _deviceSelections.remove(key);
    });
    _rebuildPlan();
  }

  Future<void> _openDeviceSelection(_DraftAsset asset) async {
    final current = _deviceSelections[asset.key] ?? const <String>{};
    final blockedMoves = <String, String>{};
    for (final device in widget.state.devices) {
      for (final other in _artifacts) {
        if (other.key == asset.key) continue;
        final otherSelection = _deviceSelections[other.key];
        if (otherSelection?.contains(device.id) != true) continue;
        if ((otherSelection?.length ?? 0) <= 1) {
          blockedMoves[device.id] = other.name;
        }
      }
    }
    final selected = await showDialog<Set<String>>(
      context: context,
      builder: (dialogContext) => _CreatorDeviceSelectionDialog(
        devices: widget.state.devices,
        initialSelection: current,
        blockedMoves: blockedMoves,
      ),
    );
    if (!mounted || selected == null) return;
    _applyDeviceSelection(asset.key, selected);
  }

  void _applyDeviceSelection(String artifactKey, Set<String> requested) {
    if (requested.isEmpty) return;
    final nextSelections = <String, Set<String>>{
      for (final entry in _deviceSelections.entries)
        entry.key: {...entry.value},
    };
    final current = nextSelections[artifactKey] ??= <String>{};
    final additions = requested.difference(current).toList();
    for (final deviceId in additions) {
      var canAdd = true;
      for (final other in _artifacts) {
        if (other.key == artifactKey) continue;
        final otherSelection = nextSelections[other.key];
        if (otherSelection?.contains(deviceId) != true) continue;
        if ((otherSelection?.length ?? 0) <= 1) {
          final l10n = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(l10n.creatorDeviceMoveBlocked(other.name)),
              ),
            );
          canAdd = false;
          break;
        }
        otherSelection!.remove(deviceId);
      }
      if (canAdd) current.add(deviceId);
    }
    current.removeWhere((deviceId) => !requested.contains(deviceId));
    setState(() {
      _deviceSelections
        ..clear()
        ..addAll(nextSelections);
    });
    _rebuildPlan();
  }

  Future<void> _loadPublicationPlan() async {
    if (_loadingPublicationPlan) return;
    setState(() => _loadingPublicationPlan = true);
    try {
      _publicationCategories ??= await widget.controller
          .bandBbsPublicationCategories();
      _rebuildPlan();
    } catch (error) {
      if (mounted) showCreatorFailure(context, error);
    } finally {
      if (mounted) setState(() => _loadingPublicationPlan = false);
    }
  }

  void _rebuildPlan() {
    final categories = _publicationCategories;
    if (categories == null || !_publishBandBbs) return;
    final synthetic = CreatorWorkspace(
      resource: widget.workspace.resource,
      artifacts: [
        for (final asset in _artifacts)
          CreatorArtifact(
            id: asset.key,
            name: asset.name,
            sha256: '',
            packageId: asset.packageId,
            version: asset.version,
            devices: (_deviceSelections[asset.key] ?? const <String>{})
                .toList(),
          ),
      ],
    );
    final plan = buildCreatorPublicationPlan(
      workspace: synthetic,
      devices: widget.state.devices,
      bandBbsCategories: categories,
    );
    if (mounted) setState(() => _publicationPlan = plan);
  }

  List<CreatorBandBbsTarget> get _effectiveBandBbsTargets =>
      _publicationPlan?.bandBbsTargets ?? const <CreatorBandBbsTarget>[];

  Map<String, Object?> _bandBbsConfig() => <String, Object?>{
    'agreement': true,
    if (_bandBbsVersionTitle.text.trim().isNotEmpty)
      'version_title': _bandBbsVersionTitle.text.trim(),
    if (_bandBbsVersionMessage.text.trim().isNotEmpty)
      'version_message': _bandBbsVersionMessage.text.trim(),
    if (_overwritePreviousBandBbs) 'overwrite_previous_version': true,
    if (_externalPurchaseEnabled)
      'price': double.tryParse(_externalPurchaseAmount.text.trim()),
    'targets': [for (final target in _effectiveBandBbsTargets) target.toJson()],
  };

  Map<String, Object?> _astroBoxConfig() => <String, Object?>{
    'item_id': _astroItemId.text.trim(),
    'repo_name': _astroRepository.text.trim(),
    'tags': _astroTags.text
        .split(RegExp(r'[,;，；]'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(),
    'author': _astroAuthor.text.trim(),
    if (_paidType != CommunityPaidType.free)
      'paid_type': communityPaidTypeToWire(_paidType),
    'bind_ab_account': _astroBindABAccount,
    'agreement': true,
  };

  List<Map<String, Object?>> _publishPlans() => [
    if (_publishBandBbs) {'target': 'bandbbs', 'config': _bandBbsConfig()},
    if (_publishAstroBox) {'target': 'astrobox', 'config': _astroBoxConfig()},
  ];

  Future<void> _publish() async {
    final l10n = AppLocalizations.of(context)!;
    final issues = _publishValidationIssues(l10n);
    if (issues.isNotEmpty) {
      _showFailure(
        [
          l10n.creatorSubmitValidationFailed,
          ...issues.map((issue) => '• $issue'),
        ].join('\n'),
      );
      return;
    }
    final purchaseError = _externalPurchaseValidationMessage(
      l10n,
      requireAmount: true,
    );
    if (purchaseError != null) {
      _showFailure(purchaseError);
      return;
    }
    var applyBandBbs = _publishBandBbs;
    final reviewState = widget.workspace.review?['state']?.toString();
    final astroReview =
        widget.workspace.publications.any(
          (item) => item['target']?.toString() == 'astrobox',
        ) &&
        (reviewState == 'rejected' ||
            reviewState == 'changes_requested' ||
            reviewState == 'fixed_pending_review');
    if (astroReview) {
      var selectedBandBbs = false;
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(l10n.creatorApplyChanges),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CheckboxListTile(
                  value: true,
                  onChanged: null,
                  title: Text(l10n.creatorGithubPr),
                ),
                CheckboxListTile(
                  value: true,
                  onChanged: null,
                  title: Text(l10n.creatorConfirmOronBox),
                ),
                CheckboxListTile(
                  value: selectedBandBbs,
                  onChanged: (value) =>
                      setDialogState(() => selectedBandBbs = value ?? false),
                  title: Text(l10n.bandbbs),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l10n.creatorConfirm),
              ),
            ],
          ),
        ),
      );
      if (accepted != true) return;
      applyBandBbs = selectedBandBbs;
    }
    if (!mounted) return;
    final plans = <Map<String, Object?>>[
      {'target': 'oronbox', 'config': <String, Object?>{}},
      ..._publishPlans(),
    ];
    // Rework with "sync to BandBBS" ticked must send the same complete
    // configuration as a normal BandBBS publish, not an empty one.
    if (applyBandBbs && !_publishBandBbs) {
      plans.add({'target': 'bandbbs', 'config': _bandBbsConfig()});
    }
    // The review dialog promises a GitHub PR update; make sure an astrobox
    // plan actually exists to carry it even when the checkbox was off.
    if (astroReview && plans.every((plan) => plan['target'] != 'astrobox')) {
      plans.add({'target': 'astrobox', 'config': _astroBoxConfig()});
    }
    if (astroReview) {
      for (final plan in plans) {
        if (plan['target'] == 'astrobox') {
          final config = (plan['config'] as Map<String, Object?>);
          config['update_existing'] = true;
          config['review_case_id'] = widget.workspace.review?['id'];
          config['apply_to_bandbbs'] = applyBandBbs;
          final publication = widget.workspace.publications
              .where((item) => item['target']?.toString() == 'astrobox')
              .firstOrNull;
          final detail = (publication?['status_detail'] as Map?)
              ?.cast<String, Object?>();
          final pullRequestNumber = detail?['pull_request_number'];
          if (pullRequestNumber is num && pullRequestNumber > 0) {
            config['pull_request_number'] = pullRequestNumber.toInt();
          }
        }
      }
    }
    // Derive the confirmation summary from the plans that will actually be
    // submitted, so the dialog can never promise (or hide) a target.
    bool planTargets(String target) =>
        plans.any((plan) => plan['target'] == target);
    final summary = <String>[
      l10n.creatorConfirmOronBox,
      if (planTargets('bandbbs'))
        l10n.creatorConfirmBandBbs(
          _effectiveBandBbsTargets
              .map((target) => target.categoryName)
              .join(' / '),
        ),
      if (planTargets('astrobox'))
        l10n.creatorConfirmAstroBox(
          widget.state.grants['github_login']?.toString() ?? 'GitHub',
          _astroRepository.text.trim(),
        ),
    ].join('\n\n');
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.creatorConfirmTitle),
        content: Text(summary),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.creatorSubmitReview),
          ),
        ],
      ),
    );
    if (accepted != true) return;
    await _run(() async {
      final bundle = await _prepareBundle(plans);
      if (bundle == null) return;
      if (mounted) setState(() => _publishStage = '');
      try {
        await widget.controller.publish(bundle: bundle);
      } finally {
        if (mounted) {
          setState(() {
            _publishStage = '';
            _publishStageProgress = 0;
          });
        }
      }
    });
  }

  List<String> _publishValidationIssues(AppLocalizations l10n) {
    final issues = <String>[];
    if (_name.text.trim().isEmpty) issues.add(l10n.creatorResourceName);
    if (_summary.text.trim().isEmpty) issues.add(l10n.creatorResourceSummary);
    final purchaseError = _externalPurchaseValidationMessage(
      l10n,
      requireAmount: true,
    );
    if (purchaseError != null) issues.add(purchaseError);
    if (_artifacts.isEmpty) issues.add(l10n.creatorAddArtifact);
    if (_previews.isEmpty) issues.add(l10n.previewImages);
    for (final artifact in _artifacts) {
      final packageIssue = _invalidPackageIdReason(
        artifact.packageId,
        isWatchface: artifact.type.contains('watchface'),
        l10n: l10n,
      );
      if (packageIssue != null) issues.add('${artifact.name}: $packageIssue');
      if ((_deviceSelections[artifact.key] ?? const <String>{}).isEmpty) {
        issues.add('${l10n.creatorBindDevices}: ${artifact.name}');
      }
    }
    if (_publishBandBbs) {
      if (!_bandBbsPublishingAuthorized) {
        issues.add(l10n.creatorBandBbsAuthorizationRequired);
      }
      if (_publicationPlan == null) {
        issues.add(l10n.creatorResolvingPublicationTarget);
      } else if (!_publicationPlan!.canPublishToBandBbs) {
        final problem = _publicationPlan!.bandBbsProblem;
        if (problem != null) issues.add(_bandBbsProblemText(l10n, problem));
      }
      if (!creatorBandBbsVersionFieldsComplete(
        _bandBbsVersionTitle.text,
        _bandBbsVersionMessage.text,
      )) {
        issues.add(l10n.creatorBandBbsVersionPairRequired);
      }
    }
    if (_publishAstroBox) {
      if (!_githubPublishingAuthorized) {
        issues.add(l10n.creatorGitHubOwnPublishMissing);
      }
      if (_icon == null) issues.add(l10n.creatorRequiredIcon);
      if (_cover == null) issues.add(l10n.creatorRequiredCover);
      if (_astroItemId.text.trim().isEmpty) {
        issues.add(l10n.creatorAstroBoxItemId);
      }
      if (_astroRepository.text.trim().isEmpty) {
        issues.add(l10n.creatorAstroBoxRepository);
      }
      if (_astroTags.text.trim().isEmpty) {
        issues.add(l10n.creatorAstroBoxTags);
      }
    }
    return issues;
  }

  List<String> _astroBoxUnsupportedDeviceNames() {
    final selected = <String>{
      for (final ids in _deviceSelections.values) ...ids,
    };
    return [
      for (final device in widget.state.devices)
        if (selected.contains(device.id) && device.astroBoxId.trim().isEmpty)
          device.name,
    ];
  }

  Widget _unsupportedDeviceNotice(
    AppLocalizations l10n,
    String platform,
    List<String> names,
  ) {
    if (names.isEmpty) return const SizedBox.shrink();
    final isAstro = platform == 'AstroBox';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isAstro ? Icons.filter_alt_outlined : Icons.skip_next_outlined,
            color: Theme.of(context).colorScheme.tertiary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isAstro
                      ? l10n.creatorFilteredSupport
                      : l10n.creatorSkippedPublication,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.tertiary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                for (final name in names)
                  Text(
                    name,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.tertiary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveDraft() {
    final l10n = AppLocalizations.of(context)!;
    if (_name.text.trim().isEmpty || _summary.text.trim().isEmpty) {
      _showFailure(l10n.creatorResourceMetadataRequired);
      return Future<void>.value();
    }
    final purchaseError = _externalPurchaseValidationMessage(
      l10n,
      requireAmount: false,
    );
    if (purchaseError != null) {
      _showFailure(purchaseError);
      return Future<void>.value();
    }
    return _run(() async {
      final bundle = await _prepareBundle(_publishPlans());
      if (bundle == null) return;
      try {
        await widget.controller.saveDraft(bundle: bundle);
      } finally {
        if (mounted) {
          setState(() {
            _publishStage = '';
            _publishStageProgress = 0;
          });
        }
      }
    });
  }



  void _update(VoidCallback fn) {
    if (mounted) setState(fn);
  }

  void _showFailure(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<bool> _confirmTargetTerms(String target) async {
    final l10n = AppLocalizations.of(context)!;
    final isBandBbs = target == 'bandbbs';
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isBandBbs ? 'BandBBS' : 'AstroBox-Repo'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isBandBbs
                    ? l10n.creatorBandBbsTermsNotice
                    : l10n.creatorAstroBoxTermsNotice,
              ),
              const Divider(height: 24),
              Text(
                isBandBbs
                    ? l10n.creatorBandBbsLimitsNotice
                    : l10n.creatorAstroBoxReviewNotice,
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => launchUrl(
                  isBandBbs
                      ? Uri.https('www.bandbbs.cn', '/help/terms/')
                      : Uri.https(
                          'github.com',
                          '/AstralSightStudios/AstroBox-Repo/blob/main/assets/docs/submission_standards.md',
                        ),
                ),
                icon: CreatorBrandLogo(
                  asset: isBandBbs
                      ? 'assets/images/brands/bandbbs.svg'
                      : 'assets/images/brands/astrobox.svg',
                  label: isBandBbs ? 'BandBBS' : 'AstroBox',
                  size: 18,
                ),
                label: Text(
                  isBandBbs
                      ? l10n.creatorTermsBandBbs
                      : l10n.creatorTermsAstroBox,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.agree),
          ),
        ],
      ),
    );
    return accepted == true;
  }

  Future<void> _authorizeBandBbs() async {
    await _run(() async {
      await widget.ref
          .read(hostAccountsProvider.notifier)
          .startBandBbsPublishingAuthorization();
      await widget.controller.refresh();
    });
  }

  Future<void> _authorizeGitHub() async {
    await _run(() async {
      try {
        final started = await widget.controller.startGitHubAuthorization();
        final flowId = started['flow_id']?.toString() ?? '';
        final uri = Uri.tryParse(
          started['authorization_url']?.toString() ?? '',
        );
        if (flowId.isEmpty || uri == null || !await launchUrl(uri)) {
          throw StateError('githubAuthorizationFailed');
        }
        for (var attempt = 0; attempt < 60 && mounted; attempt++) {
          await Future<void>.delayed(const Duration(seconds: 2));
          if (await widget.controller.pollGitHubAuthorization(flowId)) return;
        }
        throw StateError('githubAuthorizationTimedOut');
      } catch (_) {
        widget.controller.finishAuthorization();
        rethrow;
      }
    });
  }

  Future<void> _toggleTakedown() async {
    final l10n = AppLocalizations.of(context)!;
    if (widget.workspace.resource.canRestore) {
      await _run(() => widget.controller.restore());
      return;
    }
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.creatorArchiveAction),
        content: Text(l10n.creatorArchiveConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.creatorArchiveAction),
          ),
        ],
      ),
    );
    if (accepted == true) {
      await _run(() => widget.controller.takedown());
    }
  }

  Future<void> _confirmDelete() async {
    final l10n = AppLocalizations.of(context)!;
    final workspace = widget.workspace;
    final published = workspace.revisions.any(
      (revision) => revision.state != 'draft',
    );
    final providers = published
        ? workspace.bindings
              .map((binding) => binding['provider']?.toString() ?? '')
              .where((provider) => provider.isNotEmpty)
              .toSet()
        : const <String>{};
    if (providers.isEmpty) {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.creatorDeleteResource),
          content: Text(
            published
                ? l10n.creatorDeletePublishedConfirm
                : l10n.creatorDeleteConfirm,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.creatorDeleteResource),
            ),
          ],
        ),
      );
      if (accepted == true) {
        await _deleteResource();
      }
      return;
    }
    final selected = <String>{};
    var countdown = 0;
    Timer? timer;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          void toggle(String provider, bool checked) {
            setDialogState(() {
              if (checked) {
                if (selected.isEmpty) {
                  // Hard-block the confirm button for 3 seconds once any
                  // external deletion gets selected.
                  countdown = 3;
                  timer?.cancel();
                  timer = Timer.periodic(const Duration(seconds: 1), (tick) {
                    if (countdown <= 1) {
                      tick.cancel();
                      setDialogState(() => countdown = 0);
                    } else {
                      setDialogState(() => countdown -= 1);
                    }
                  });
                }
                selected.add(provider);
              } else {
                selected.remove(provider);
                if (selected.isEmpty) {
                  timer?.cancel();
                  countdown = 0;
                }
              }
            });
          }

          return AlertDialog(
            title: Text(l10n.creatorDeleteResource),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.creatorDeletePublishedConfirm),
                const SizedBox(height: 8),
                if (providers.contains('bandbbs'))
                  CheckboxListTile(
                    value: selected.contains('bandbbs'),
                    onChanged: (value) => toggle('bandbbs', value == true),
                    title: Text(l10n.creatorDeleteExternalBandbbs),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                if (providers.contains('astrobox'))
                  CheckboxListTile(
                    value: selected.contains('astrobox'),
                    onChanged: (value) => toggle('astrobox', value == true),
                    title: Text(l10n.creatorDeleteExternalAstrobox),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                if (selected.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      l10n.creatorDeleteExternalWarning,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: countdown == 0
                    ? () => Navigator.pop(context, true)
                    : null,
                child: Text(
                  countdown > 0
                      ? '${l10n.creatorDeleteResource} ($countdown)'
                      : l10n.creatorDeleteResource,
                ),
              ),
            ],
          );
        },
      ),
    );
    timer?.cancel();
    if (confirmed != true) return;
    if (!mounted) return;
    final navigator = Navigator.of(context, rootNavigator: true);
    final rootContext = navigator.context;
    final result = await _deleteResource(deleteExternal: selected.toList());
    if (result == null) return;
    final pr = result['astrobox_removal_pr']?.toString() ?? '';
    if (pr.isNotEmpty && rootContext.mounted) {
      await showDialog<void>(
        context: rootContext,
        builder: (context) => AlertDialog(
          title: Text(l10n.creatorDeletePrSubmitted),
          content: SelectableText(pr),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.creatorConfirm),
            ),
          ],
        ),
      );
    }
  }

  Future<Map<String, Object?>?> _deleteResource({
    List<String> deleteExternal = const [],
  }) async {
    try {
      return await widget.controller.deleteResource(
        deleteExternal: deleteExternal,
      );
    } catch (error) {
      if (mounted) showCreatorFailure(context, error);
      return null;
    }
  }

  Future<void> _run(Future<void> Function() operation) async {
    try {
      await operation();
    } catch (error) {
      if (mounted) showCreatorFailure(context, error);
    }
  }
}

typedef _CreatorDeviceSelectionDialog = CreatorDeviceSelectionDialog;
typedef _DraftAsset = DraftAsset;
typedef _DraftLink = DraftLink;
