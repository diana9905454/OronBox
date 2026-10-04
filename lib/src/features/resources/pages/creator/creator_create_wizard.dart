import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:segmented_list/segmented_list.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/utils/error_localization.dart';
import 'package:oronbox/src/app/widgets/network_img_layer.dart';
import 'package:oronbox/src/app/widgets/sys_app_bar.dart';
import 'package:oronbox/src/core/constants/style_constants.dart';
import 'package:oronbox/src/core/services/shared_prefs_service.dart';
import 'package:oronbox/src/data/bandbbs/bandbbs_resource_provider.dart';
import 'package:oronbox/src/data/community/community_source.dart';
import 'package:oronbox/src/features/accounts/services/bandbbs_auth_service.dart';
import 'package:oronbox/src/features/resources/application/creator/creator_workspace_controller.dart';
import 'package:oronbox/src/features/resources/application/import/community_import_service.dart';
import 'package:oronbox/src/features/resources/application/resource_catalog_providers.dart';
import 'package:oronbox/src/features/resources/domain/community_resource.dart';
import 'package:oronbox/src/features/resources/domain/creator_external_binding.dart';
import 'package:oronbox/src/features/resources/domain/creator_workspace.dart';
import 'package:oronbox/src/features/resources/domain/resource_catalog.dart';
import 'package:oronbox/src/features/resources/pages/creator/creator_shared.dart';

enum _WizardAction { resource, collection, import }

class CreatorCreateWizard extends ConsumerStatefulWidget {
  const CreatorCreateWizard({super.key});

  @override
  ConsumerState<CreatorCreateWizard> createState() =>
      _CreatorCreateWizardState();
}

class _CreatorCreateWizardState extends ConsumerState<CreatorCreateWizard> {
  _WizardAction? _action;
  var _step = 0;

  // Create form.
  var _kind = CreatorResourceKind.quickApp;
  final _name = TextEditingController();
  final _summary = TextEditingController();
  var _creating = false;

  // Import selection.
  var _source = CommunitySourceId.bandbbs;
  final _selected = <String, CommunityResource>{};
  List<CommunityResource> _items = const [];
  var _listLoading = false;
  Object? _listError;
  var _githubConnecting = false;
  var _externalItemsRequestGeneration = 0;

  // Import plan and run.
  CommunityImportPlan? _plan;
  var _preparing = false;
  var _running = false;
  CommunityImportStage? _stage;
  var _stageCurrent = 0;
  var _stageTotal = 0;
  var _stageLabel = '';
  CommunityImportResult? _result;
  final _importLog = <_ImportLogEntry>[];

  @override
  void dispose() {
    _name.dispose();
    _summary.dispose();
    super.dispose();
  }

  String get _githubLogin =>
      ref.read(creatorWorkspaceProvider).grants['github_login']?.toString() ??
      '';

  Future<void> _chooseAction(_WizardAction action) async {
    if (action == _WizardAction.import) {
      final l10n = AppLocalizations.of(context)!;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.creatorImportNoticeTitle),
          content: Text(l10n.creatorImportNoticeMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.creatorImportNoticeConfirm),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() {
      _action = action;
      _step = 1;
    });
    if (action == _WizardAction.import && _items.isEmpty) {
      _loadExternalItems();
    }
  }

  void _back() {
    if (_step <= 0 || _preparing || _running || _creating) return;
    setState(() {
      if (_action == _WizardAction.import && _step >= 2) {
        // Import select is always step 1.
        _step = 1;
        _plan = null;
        _result = null;
        return;
      }
      _step = _step - 1;
      if (_step == 0) _action = null;
    });
  }

  Future<void> _loadExternalItems() async {
    final requestGeneration = ++_externalItemsRequestGeneration;
    final source = _source;
    final githubLogin = _githubLogin.toLowerCase();
    setState(() {
      _listLoading = true;
      _listError = null;
      _items = const [];
    });
    try {
      final List<CommunityResource> items;
      if (source == CommunitySourceId.bandbbs) {
        final auth = ref.read(bandBbsAuthProvider.notifier);
        await auth.restoreCredentials();
        await auth.reloadCredentials();
        final userId = ref.read(bandBbsAuthProvider).userId ?? '';
        final catalog = ref.read(
          localCommunityCatalogProviderForSource(CommunitySourceId.bandbbs),
        );
        items = userId.isEmpty
            ? const []
            : await (catalog as BandBbsCatalog).myResources(userId);
      } else {
        if (githubLogin.isEmpty) {
          items = const [];
        } else {
          final catalog = ref.read(
            communityCatalogProviderForSource(CommunitySourceId.astroboxRepo),
          );
          final collected = <CommunityResource>[];
          for (var page = 0; page < 5; page++) {
            final result = await catalog.getPage(
              CommunityResourceQuery(page: page, pageSize: 200),
            );
            collected.addAll(
              result.items.where(
                (item) => item.authors.any(
                  (author) => author.name.toLowerCase() == githubLogin,
                ),
              ),
            );
            if (!result.hasMore) break;
          }
          items = collected;
        }
      }
      if (!mounted || requestGeneration != _externalItemsRequestGeneration) {
        return;
      }
      setState(() {
        _items = items;
        final availableKeys = items.map((item) => item.ref.key).toSet();
        _selected.removeWhere((key, _) => !availableKeys.contains(key));
        _listLoading = false;
      });
    } catch (error) {
      if (!mounted || requestGeneration != _externalItemsRequestGeneration) {
        return;
      }
      setState(() {
        _listError = error;
        _listLoading = false;
      });
    }
  }

  Future<void> _connectGitHub() async {
    if (_githubConnecting) return;
    setState(() => _githubConnecting = true);
    final controller = ref.read(creatorWorkspaceProvider.notifier);
    try {
      final started = await controller.startGitHubAuthorization();
      final flowId = started['flow_id']?.toString() ?? '';
      final uri = Uri.tryParse(started['authorization_url']?.toString() ?? '');
      if (flowId.isEmpty || uri == null || !await launchUrl(uri)) {
        controller.finishAuthorization();
        return;
      }
      for (var attempt = 0; attempt < 60 && mounted; attempt++) {
        await Future<void>.delayed(const Duration(seconds: 2));
        if (await controller.pollGitHubAuthorization(flowId)) {
          await controller.refresh();
          if (mounted) await _loadExternalItems();
          return;
        }
      }
      controller.finishAuthorization();
    } catch (error) {
      controller.finishAuthorization();
      if (mounted) showCreatorFailure(context, error);
    } finally {
      if (mounted) setState(() => _githubConnecting = false);
    }
  }

  void _switchSource(CommunitySourceId source) {
    if (source == _source) return;
    setState(() {
      _source = source;
      _selected.clear();
      _plan = null;
    });
    _loadExternalItems();
  }

  void _toggleItem(CommunityResource item, bool select) {
    if (_isImported(item)) return;
    setState(() {
      if (!select) {
        _selected.remove(item.ref.key);
        return;
      }
      if (_source == CommunitySourceId.astroboxRepo) {
        _selected.clear();
      }
      _selected[item.ref.key] = item;
    });
  }

  bool _isImported(CommunityResource item) {
    for (final workspace in ref.read(creatorWorkspaceProvider).resources) {
      for (final binding in workspace.bindings) {
        if (item.ref.source == CommunitySourceId.astroboxRepo &&
            binding['provider'] == 'astrobox' &&
            binding['external_id']?.toString() == item.ref.id) {
          return true;
        }
        if (item.ref.source == CommunitySourceId.bandbbs &&
            binding['provider'] == 'bandbbs' &&
            parseCreatorBandBbsBinding(binding['external_id'])
                .any((entry) => entry.resourceId == item.ref.id)) {
          return true;
        }
      }
    }
    return false;
  }

  Future<void> _prepareImport() async {
    if (_selected.isEmpty || _preparing) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _step = 2;
      _preparing = true;
      _plan = null;
      _stage = CommunityImportStage.fetchingDetail;
      _stageCurrent = 0;
      _stageTotal = _selected.length;
      _stageLabel = '';
      _importLog.clear();
    });
    final service = ref.read(communityImportServiceProvider);
    final failures = <String>{};
    try {
      final detailsByRef = <String, CommunityResourceDetail>{};
      var pending = _selected.values.toList();
      while (pending.isNotEmpty) {
        final failedRefs = <ResourceRef>[];
        final roundDetails = await service.fetchDetails(
          pending,
          onProgress: _updateProgress,
          onError: (ref, error) {
            failures.add(ref.key);
            failedRefs.add(ref);
            if (mounted) {
              setState(
                () => _importLog.add(
                  _ImportLogEntry(
                    _ImportLogLevel.warning,
                    'DETAIL FAILED · source=${ref.source.storageKey} · '
                    'resource=${ref.id} · '
                    '${localizedErrorMessage(l10n, error)}',
                  ),
                ),
              );
            }
          },
        );
        for (final detail in roundDetails) {
          detailsByRef[detail.ref.key] = detail;
          failures.remove(detail.ref.key);
        }
        if (failedRefs.isEmpty) break;
        if (!mounted) return;
        final action = await _showImportDetailFailureDialog(l10n, failedRefs);
        if (action == null) {
          if (mounted) {
            setState(() {
              _preparing = false;
              _stage = null;
              _step = 1;
            });
          }
          return;
        }
        if (action) {
          pending = [
            for (final ref in failedRefs)
              if (_selected[ref.key] case final item?) item,
          ];
          continue;
        }
        break;
      }
      final details = detailsByRef.values.toList();
      if (details.isEmpty) {
        throw StateError('No external resource details were available');
      }
      var plan = await service.planImport(details);
      if (failures.isNotEmpty) {
        plan = CommunityImportPlan(
          details: plan.details,
          bindings: plan.bindings,
          warnings: [
            ...plan.warnings,
            ...failures.map((key) => 'detailFailed:$key'),
          ],
        );
      }
      if (!mounted) return;
      setState(() {
        _preparing = false;
        _plan = plan;
      });
      await _runImport();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _preparing = false;
        _stage = null;
        _result = CommunityImportResult(
          status: CommunityImportStatus.failed,
          message: 'import_failed',
          warnings: failures.toList(),
        );
        _importLog.add(
          _ImportLogEntry(
            _ImportLogLevel.error,
            'PLAN · ${localizedErrorMessage(l10n, error)}',
          ),
        );
        _step = 4;
      });
    }
  }

  /// Returns true to retry failed items, false to continue with the details
  /// already fetched, and null to cancel the import.
  Future<bool?> _showImportDetailFailureDialog(
    AppLocalizations l10n,
    List<ResourceRef> failed,
  ) => showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: Text(l10n.creatorImportPartialFailureTitle),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 320),
        child: SingleChildScrollView(
          child: Text(
            '${l10n.creatorImportPartialFailureMessage(failed.length)}\n\n'
            '${failed.map((ref) => '${ref.source.displayName} · ${ref.id}').join('\n')}',
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.creatorImportContinuePartial),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.creatorImportRetryFailed),
        ),
      ],
    ),
  );

  Future<CommunityImportRecoveryAction?> _showImportFailureDialog(
    AppLocalizations l10n,
    String item,
    Object error,
  ) => showDialog<CommunityImportRecoveryAction>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: Text(l10n.creatorImportPartialFailureTitle),
      content: Text(
        '$item\n${localizedErrorMessage(l10n, error)}\n\n'
        '${l10n.creatorImportPartialFailureMessage(1)}',
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(CommunityImportRecoveryAction.cancel),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: () =>
              Navigator.of(context)
                  .pop(CommunityImportRecoveryAction.continueImport),
          child: Text(l10n.creatorImportContinuePartial),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.of(context).pop(CommunityImportRecoveryAction.retry),
          child: Text(l10n.creatorImportRetryFailed),
        ),
      ],
    ),
  );

  void _updateProgress(
    CommunityImportStage stage,
    int current,
    int total,
    String label,
  ) {
    if (!mounted) return;
    setState(() {
      _stage = stage;
      _stageCurrent = current;
      _stageTotal = total;
      _stageLabel = label;
      final message = '${_stageTechnicalName(stage)} $current/$total · $label';
      if (_importLog.lastOrNull?.message != message) {
        _importLog.add(_ImportLogEntry(_ImportLogLevel.info, message));
      }
    });
  }

  String _stageTechnicalName(CommunityImportStage stage) => switch (stage) {
    CommunityImportStage.fetchingDetail => 'DETAIL',
    CommunityImportStage.downloading => 'DOWNLOAD',
    CommunityImportStage.media => 'MEDIA',
    CommunityImportStage.uploading => 'DRAFT',
  };

  Future<void> _runImport() async {
    final plan = _plan;
    if (plan == null || _running) return;
    final l10n = AppLocalizations.of(context)!;
    final resume = _result;
    setState(() {
      _step = 3;
      _running = true;
      _result = null;
    });
    final service = ref.read(communityImportServiceProvider);
    late CommunityImportResult result;
    try {
      result =
          resume?.resourceId != null &&
              (resume?.bundle != null || resume?.bundlePath != null)
          ? await service.resumeDraft(
              resourceId: resume!.resourceId!,
              bundle: resume.bundle,
              bundlePath: resume.bundlePath,
              bindings: plan.bindings,
            )
          : await service.importPlan(
              plan,
              onProgress: _updateProgress,
              onFailure: (item, error) async =>
                  await _showImportFailureDialog(l10n, item, error) ??
                  CommunityImportRecoveryAction.cancel,
            );
    } catch (error) {
      result = CommunityImportResult(
        status: CommunityImportStatus.failed,
        message: 'import_failed',
        warnings: [error.toString()],
      );
    }
    if (!mounted) return;
    setState(() {
      _running = false;
      _result = result;
      if (result.status == CommunityImportStatus.failed) {
        _importLog.add(
          _ImportLogEntry(
            _ImportLogLevel.error,
            result.message ?? 'importFailed',
          ),
        );
      }
      for (final warning in result.warnings) {
        _importLog.add(_ImportLogEntry(_ImportLogLevel.warning, warning));
      }
      _step = 4;
    });
  }

  void _importAgain() {
    final result = _result;
    if (result?.resourceId != null &&
        (result?.bundle != null || result?.bundlePath != null)) {
      _runImport();
      return;
    }
    setState(() {
      _step = 1;
      _plan = null;
      _result = null;
      _selected.clear();
      _stage = null;
    });
    _loadExternalItems();
  }

  Future<void> _create() async {
    final action = _action;
    final name = _name.text.trim();
    final summary = _summary.text.trim();
    if (action == null ||
        action == _WizardAction.import ||
        name.isEmpty ||
        (action == _WizardAction.resource && summary.isEmpty)) {
      return;
    }
    if (_creating) return;
    setState(() => _creating = true);
    final controller = ref.read(creatorWorkspaceProvider.notifier);
    try {
      if (action == _WizardAction.collection) {
        await controller.createCollection(
          slug: 'collection-${DateTime.now().microsecondsSinceEpoch}',
          name: name,
          summary: _summary.text.trim(),
          kind: _kind,
        );
      } else {
        const rulesSeenKey = 'creator.reviewRules.seen';
        final rulesSeen =
            SharedPrefsService.instance.getBool(rulesSeenKey) ?? false;
        if (!rulesSeen) {
          if (!mounted) return;
          final rulesAccepted = await showDialog<bool>(
            context: context,
            builder: (context) => const CreatorReviewRulesDialog(),
          );
          if (rulesAccepted != true) return;
          await SharedPrefsService.instance.setBool(rulesSeenKey, true);
        }
        await controller.create(
          'resource-${DateTime.now().microsecondsSinceEpoch}',
          name,
          _kind,
        );
        await controller.saveDraft(
          bundle: buildCommunityImportBundle(
            kind: _kind,
            name: name,
            summary: summary,
            links: const [],
            artifacts: const [],
          ),
        );
        final resourceId = controller.currentState.selected?.resource.id;
        if (mounted && resourceId != null && resourceId.isNotEmpty) {
          context.go('/resources/creator/resources/$resourceId');
          return;
        }
      }
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) showCreatorFailure(context, error);
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final canStepBack = _step > 0 && !_preparing && !_running && !_creating;
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && canStepBack) _back();
      },
      child: Scaffold(
        appBar: SysAppBar(
          secondary: true,
          leading: BackButton(
            onPressed: canStepBack
                ? _back
                : _step == 0
                ? () => Navigator.of(context).pop()
                : null,
          ),
          title: Text(_stepTitle(l10n)),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _stepContent(l10n),
            ),
          ),
        ),
        bottomNavigationBar: _bottomBar(l10n),
      ),
    );
  }

  String _stepTitle(AppLocalizations l10n) {
    if (_step == 0) return l10n.creatorWizardChooseAction;
    if (_action == _WizardAction.import) {
      return switch (_step) {
        1 => l10n.creatorImportSelectTitle,
        2 => l10n.creatorImportStageDetails,
        3 => l10n.creatorImportProgressTitle,
        _ => l10n.creatorImportResultTitle,
      };
    }
    return _action == _WizardAction.collection
        ? l10n.creatorNewCollection
        : l10n.creatorNewResource;
  }

  Widget _stepContent(AppLocalizations l10n) {
    if (_step == 0) return _actionChoices(l10n);
    if (_action != _WizardAction.import) return _createForm(l10n);
    return switch (_step) {
      1 => _importSelection(l10n),
      2 => _importProgress(l10n),
      3 => _importProgress(l10n),
      _ => _importResult(l10n),
    };
  }

  Widget _actionChoices(AppLocalizations l10n) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: (constraints.maxHeight - 16)
                .clamp(0, double.infinity)
                .toDouble(),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ActionCard(
                  icon: Icons.add_box_outlined,
                  title: l10n.creatorNewResource,
                  description: l10n.creatorNewResourceDescription,
                  onTap: () => _chooseAction(_WizardAction.resource),
                ),
                const SizedBox(height: 12),
                _ActionCard(
                  icon: Icons.collections_bookmark_outlined,
                  title: l10n.creatorNewCollection,
                  description: l10n.creatorNewCollectionDescription,
                  onTap: () => _chooseAction(_WizardAction.collection),
                ),
                const SizedBox(height: 12),
                _ActionCard(
                  icon: Icons.input_outlined,
                  title: l10n.creatorImportExternal,
                  description: l10n.creatorImportExternalDescription,
                  onTap: () => _chooseAction(_WizardAction.import),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _createForm(AppLocalizations l10n) {
    final isCollection = _action == _WizardAction.collection;
    return ListView(
      shrinkWrap: false,
      children: [
        const SizedBox(height: 8),
        Center(
          child: SegmentedButton<CreatorResourceKind>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: CreatorResourceKind.quickApp,
                label: Text(l10n.quickApp),
                icon: const Icon(Icons.apps_outlined),
              ),
              ButtonSegment(
                value: CreatorResourceKind.watchface,
                label: Text(l10n.watchface),
                icon: const Icon(Icons.watch_outlined),
              ),
            ],
            selected: {_kind},
            onSelectionChanged: (value) => setState(() => _kind = value.single),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _name,
          autofocus: true,
          maxLength: 120,
          textInputAction: TextInputAction.next,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: isCollection
                ? l10n.creatorCollectionName
                : l10n.creatorResourceName,
          ),
        ),
        TextField(
          controller: _summary,
          minLines: 4,
          maxLines: 8,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: isCollection
                ? l10n.creatorCollectionSummary
                : l10n.creatorResourceSummary,
          ),
        ),
        if (!isCollection &&
            (_name.text.trim().isEmpty || _summary.text.trim().isEmpty))
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              l10n.creatorResourceMetadataRequired,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
    );
  }

  Widget _importSelection(AppLocalizations l10n) {
    final colors = Theme.of(context).colorScheme;
    final isBandBbs = _source == CommunitySourceId.bandbbs;
    final needsGitHub = !isBandBbs && _githubLogin.isEmpty;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
          child: SegmentedButton<CommunitySourceId>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: CommunitySourceId.bandbbs,
                label: Text(l10n.communitySourceBandBbs),
              ),
              ButtonSegment(
                value: CommunitySourceId.astroboxRepo,
                label: Text(l10n.communitySourceAstroBoxRepo),
              ),
            ],
            selected: {_source},
            onSelectionChanged: (value) => _switchSource(value.single),
          ),
        ),
        if (isBandBbs)
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                l10n.creatorImportSameResourceHint,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: colors.onSurfaceVariant),
              ),
            ),
          ),
        Expanded(
          child: needsGitHub
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: Column(
                    children: [
                      Text(
                        l10n.creatorImportGitHubHint,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _githubConnecting ? null : _connectGitHub,
                        icon: _githubConnecting
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.link),
                        label: Text(l10n.creatorImportGitHubConnect),
                      ),
                    ],
                  ),
                )
              : _listLoading
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                )
              : _listError != null
              ? Center(child: Text(localizedErrorMessage(l10n, _listError)))
              : _items.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: Center(
                    child: Text(
                      l10n.communityImportPickerEmpty,
                      style: TextStyle(color: colors.onSurfaceVariant),
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadExternalItems,
                  child: SegmentedList(
                    maxWidth: StyleConstants.pageMaxWidth,
                    physics: const AlwaysScrollableScrollPhysics(),
                    contentPadding: const EdgeInsets.only(bottom: 16),
                    sections: [
                      SegmentedSection(
                        tiles: [
                          for (final item in _items) _importTile(item, l10n),
                        ],
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _importProgress(AppLocalizations l10n) => _progressBody(l10n);

  AbstractSegmentedTile _importTile(
    CommunityResource item,
    AppLocalizations l10n,
  ) {
    final imported = _isImported(item);
    final selected = _selected.containsKey(item.ref.key);
    final commit = item.sourceRepoCommitHash?.trim() ?? '';
    final sourceVersion = item.ref.source == CommunitySourceId.astroboxRepo
        ? (commit.length > 12 ? commit.substring(0, 12) : commit)
        : item.version ?? '';
    return SegmentedTile.checkboxTile(
      initialValue: imported || selected,
      onToggle: (value) => _toggleItem(item, value == true),
      enabled: !imported,
      leading: NetworkImgLayer(
        src: (item.iconUrl ?? item.coverUrl)?.toString() ?? '',
        width: 56,
        height: 56,
        borderRadius: BorderRadius.circular(10),
      ),
      title: Text(item.name),
      description: Text(
        imported ? l10n.creatorImportAlreadyImported : sourceVersion,
      ),
    );
  }

  Widget _progressBody(AppLocalizations l10n) {
    final stage = _stage;
    final stageIndex = stage == null
        ? -1
        : CommunityImportStage.values.indexOf(stage);
    final labels = [
      l10n.creatorImportStageDetails,
      l10n.creatorImportStageDownloading,
      l10n.creatorImportStageMedia,
      l10n.creatorImportStageUploading,
    ];
    return ListView(
      padding: const EdgeInsets.only(top: 16),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              children: [
                for (var index = 0; index < labels.length; index++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        if (index < stageIndex)
                          const Icon(Icons.check_circle, size: 20)
                        else if (index == stageIndex)
                          const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          Icon(
                            Icons.circle_outlined,
                            size: 20,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(labels[index])),
                        if (index == stageIndex && _stageTotal > 0)
                          Text('$_stageCurrent/$_stageTotal'),
                      ],
                    ),
                  ),
                if (_stageLabel.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    _stageLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (_importLog.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _logPanel(l10n, _importLog),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _importResult(AppLocalizations l10n) {
    final result = _result;
    final colors = Theme.of(context).colorScheme;
    if (result == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final (icon, iconColor, message) = switch (result.status) {
      CommunityImportStatus.created => (
        Icons.check_circle_outline,
        colors.primary,
        l10n.communityImportResultCreated,
      ),
      CommunityImportStatus.skipped => (
        Icons.remove_circle_outline,
        colors.tertiary,
        result.message == 'duplicate' || result.message == 'alreadyImported'
            ? l10n.creatorImportAlreadyImported
            : (result.message ?? ''),
      ),
      CommunityImportStatus.failed => (
        Icons.error_outline,
        colors.error,
        result.message == 'unsupportedType'
            ? l10n.communityImportUnsupported
            : (result.message == 'missingMetadata'
                  ? l10n.creatorResourceMetadataRequired
                  : (result.message == 'noArtifacts'
                        ? l10n.communityImportNoArtifacts
                        : l10n.communityImportResultFailed)),
      ),
    };
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 24),
      children: [
        Column(
          children: [
            Icon(icon, size: 56, color: iconColor),
            const SizedBox(height: 16),
            Text(message, style: Theme.of(context).textTheme.titleMedium),
            if (result.warnings.isNotEmpty) ...[
              const SizedBox(height: 12),
              _warningPanel(l10n, result.warnings),
            ],
            if (_importLog.isNotEmpty) ...[
              const SizedBox(height: 12),
              _logPanel(l10n, _importLog),
            ],
          ],
        ),
      ],
    );
  }

  Widget _warningPanel(AppLocalizations l10n, List<String> warnings) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      color: colors.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.creatorImportWarnings(warnings.length),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            for (final warning in warnings)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: SelectableText('WARN · $warning'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _logPanel(AppLocalizations l10n, List<_ImportLogEntry> entries) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      color: colors.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.creatorImportLogTitle,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: Scrollbar(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    return SelectableText(
                      '${entry.level.name.toUpperCase()} · ${entry.message}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: entry.level == _ImportLogLevel.error
                            ? colors.error
                            : colors.onSurfaceVariant,
                        fontFamily: 'monospace',
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget? _bottomBar(AppLocalizations l10n) {
    final isImport = _action == _WizardAction.import;
    if (_step == 0 || _step == 2 || _step == 3) {
      return null;
    }
    if (_step == 4) {
      return CreatorBottomBar(
        children: [
          TextButton(
            onPressed: _importAgain,
            child: Text(l10n.creatorImportContinue),
          ),
          const Spacer(),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.oobeFinish),
          ),
        ],
      );
    }
    final (mainLabel, mainAction, mainEnabled) = switch ((_step, isImport)) {
      (1, false) => (
        l10n.creatorConfirm,
        _create,
        _name.text.trim().isNotEmpty &&
            (isImport ||
                _action == _WizardAction.collection ||
                _summary.text.trim().isNotEmpty) &&
            !_creating,
      ),
      (1, true) => (l10n.oobeNext, _prepareImport, _selected.isNotEmpty),
      _ => (l10n.oobeNext, () {}, false),
    };
    return CreatorBottomBar(
      children: [
        TextButton(onPressed: _back, child: Text(l10n.oobeBack)),
        const Spacer(),
        if (isImport && _step == 1)
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Text(l10n.communityImportSelected(_selected.length)),
          ),
        FilledButton(
          onPressed: mainEnabled ? mainAction : null,
          child: _creating && !isImport
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(mainLabel),
        ),
      ],
    );
  }
}

enum _ImportLogLevel { info, warning, error }

class _ImportLogEntry {
  const _ImportLogEntry(this.level, this.message);

  final _ImportLogLevel level;
  final String message;
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Row(
            children: [
              Icon(icon, size: 28, color: colors.primary),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: colors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
