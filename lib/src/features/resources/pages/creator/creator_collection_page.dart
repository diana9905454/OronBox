import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/utils/error_localization.dart';
import 'package:oronbox/src/features/resources/application/creator/oronbox_creator_api.dart';
import 'package:oronbox/src/features/settings/pages/legal_documents_page.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:oronbox/src/app/utils/picked_file.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:oronbox/src/commands/command_protocol.dart';
import 'package:oronbox/src/host/application_host_provider.dart';
import 'package:oronbox/src/features/resources/application/creator/creator_workspace_controller.dart';
import 'package:oronbox/src/features/resources/domain/creator_workspace.dart';
import 'package:oronbox/src/features/resources/services/resource_image_processor.dart';

class CreatorCollectionPage extends ConsumerStatefulWidget {
  const CreatorCollectionPage({
    super.key,
    required this.collectionId,
    this.item,
    this.initialName = '',
    this.initialSummary = '',
    this.initialKind = 'quickapp',
    this.revisionId,
  });
  final String collectionId, initialName, initialSummary, initialKind;
  final String? revisionId;
  final Map<String, Object?>? item;
  @override
  ConsumerState<CreatorCollectionPage> createState() =>
      _CreatorCollectionPageState();
}

class _CreatorCollectionPageState extends ConsumerState<CreatorCollectionPage> {
  final _name = TextEditingController(),
      _summary = TextEditingController(),
      _description = TextEditingController();
  final _members = <String>[];
  final _images = <String, Uint8List>{};
  final _digests = <String, String>{};
  Map<String, Object?>? _item;
  String _kind = 'quickapp', _representative = '', _slug = '', _history = '';
  bool _loading = true, _busy = false;
  Object? _error;
  AppLocalizations get _l10n => AppLocalizations.of(context)!;
  bool get _new => widget.collectionId == 'new';
  @override
  void initState() {
    super.initState();
    _kind = widget.initialKind;
    _name.text = widget.initialName;
    _summary.text = widget.initialSummary;
    _slug = 'collection-${DateTime.now().microsecondsSinceEpoch}';
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_load()));
  }

  @override
  void dispose() {
    _name.dispose();
    _summary.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<Object?> _command(String method, Map<String, Object?> params) async {
    final result = await ref
        .read(applicationHostProvider)
        .execute(OronBoxCommand(method: method, params: params));
    if (!result.ok) {
      throw CreatorApiException(
        code: result.error?.code ?? 'creator_failed',
        message: result.error?.message ?? '',
        details: const {},
      );
    }
    return result.value;
  }

  void _seed(Map snapshot) {
    _name.text = snapshot['name']?.toString() ?? '';
    _summary.text = snapshot['summary']?.toString() ?? '';
    _description.text = snapshot['description']?.toString() ?? '';
    _members
      ..clear()
      ..addAll(
        (snapshot['resource_ids'] as List? ?? []).map((v) => v.toString()),
      );
    _representative = snapshot['representative_resource_id']?.toString() ?? '';
    for (final role in ['icon', 'cover']) {
      _digests[role] = snapshot['${role}_sha256']?.toString() ?? '';
    }
    _history = snapshot['id']?.toString() ?? '';
  }

  Future<void> _load() async {
    try {
      await ref.read(creatorWorkspaceProvider.notifier).refresh();
      if (!_new) {
        final value = await _command('creator.collection.get', {
          'collection': widget.collectionId,
          if (widget.revisionId != null) 'revision': widget.revisionId,
        });
        _item = (value as Map).cast<String, Object?>();
        _kind = _item!['kind']?.toString() ?? 'quickapp';
        final versions = _item!['revisions'] as List? ?? [];
        final requested = versions
            .whereType<Map>()
            .where((v) => v['id'] == widget.revisionId)
            .firstOrNull;
        _seed(
          requested ??
              _item!['pending_revision'] as Map? ??
              _item!['current_revision'] as Map? ??
              {},
        );
        await _loadImages();
      }
    } catch (e) {
      _error = e;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadImages() async {
    _images.clear();
    for (final role in ['icon', 'cover']) {
      final sha = _digests[role] ?? '';
      if (sha.isEmpty) continue;
      try {
        final result = await _command('creator.media.get', {'sha': sha}) as Map;
        if (!mounted) return;
        _images[role] = base64Decode(result['bytes'].toString());
      } catch (_) {
        /* keep metadata if the image is temporarily unavailable */
      }
    }
  }

  Future<void> _pick(String role) async {
    setState(() => _busy = true);
    try {
      final picked = await pickFileData(type: FileType.image, loadBytes: true);
      if (picked == null) return;
      final raw = await picked.readAsBytes();
      if (raw == null) {
        throw const CreatorApiException(
          code: 'image_read_failed',
          message: '',
          details: {},
        );
      }
      final processed = await processResourceImage(
        raw,
        maxDimension: creatorMediaMaxDimension,
      );
      if (processed == null) {
        throw const CreatorApiException(
          code: 'image_process_failed',
          message: '',
          details: {},
        );
      }
      final result = await _command('creator.media.upload', {
        'bytes': base64Encode(processed.bytes),
      }) as Map;
      if (!mounted) return;
      setState(() {
        _images[role] = processed.bytes;
        _digests[role] = result['sha256'].toString();
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    if (!await ensurePublishingAgreement(context) || !mounted) return;
    if (_busy) return;
    final pending = _item?['pending_revision'] as Map?;
    if (pending != null) {
      final yes = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(_l10n.creatorCollectionReplacePendingTitle),
          content: Text(
            AppLocalizations.of(context)!
                .creatorCollectionReplacePendingDescription,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(_l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(_l10n.creatorCollectionReplaceAndSubmit),
            ),
          ],
        ),
      );
      if (yes != true) return;
    }
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      final result = await _command('creator.collection.submit', {
        'collection': _new ? '' : widget.collectionId,
        'snapshot': {
          'slug': _slug,
          'kind': _kind,
          'name': _name.text.trim(),
          'summary': _summary.text.trim(),
          'description': _description.text,
          'resource_ids': _members,
          'representative_resource_id': _representative,
          'icon_sha256': _digests['icon'] ?? '',
          'cover_sha256': _digests['cover'] ?? '',
          if (!_new) 'expected_edit_version': _item?['edit_version'],
          'replace_pending_revision_id': pending?['id'] ?? '',
        },
      }) as Map;
      await ref.read(creatorWorkspaceProvider.notifier).refresh();
      if (!mounted) return;
      context.go('/resources/creator/collections/${result['id']}');
      if (!_new) {
        setState(() => _loading = true);
        await _load();
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final resources = ref
        .watch(creatorWorkspaceProvider)
        .resources
        .where(
          (w) =>
              (w.resource.kind == CreatorResourceKind.watchface
                      ? 'watchface'
                      : 'quickapp') ==
                  _kind &&
              (w.resource.collectionId.isEmpty ||
                  w.resource.collectionId == widget.collectionId),
        )
        .toList();
    final names = {
      for (final w in resources) w.resource.id: w.resource.draftName,
    };
    final revisions = (_item?['revisions'] as List? ?? [])
        .whereType<Map>()
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _new
              ? _l10n.creatorCollectionCreateTitle
              : _l10n.creatorCollectionEditTitle,
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_error != null)
                  Text(
                    localizedErrorMessage(_l10n, _error!),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                if (_item?['current_revision'] is Map)
                  Text(
                    _l10n.creatorCollectionCurrentRevision(
                      '${(_item!['current_revision'] as Map)['number']}',
                    ),
                  ),
                if (_item?['pending_revision'] is Map)
                  Text(
                    _l10n.creatorCollectionPendingRevision(
                      '${(_item!['pending_revision'] as Map)['number']}',
                    ),
                  ),
                if (revisions.isNotEmpty)
                  DropdownButtonFormField<String>(
                    initialValue: revisions.any((v) => v['id'] == _history)
                        ? _history
                        : null,
                    decoration: InputDecoration(
                      labelText: _l10n.creatorCollectionHistory,
                    ),
                    items: [
                      for (final v in revisions)
                        DropdownMenuItem(
                          value: v['id'].toString(),
                          child: Text('v${v['number']} · ${v['state']}'),
                        ),
                    ],
                    onChanged: _busy
                        ? null
                        : (id) {
                            final v = revisions.firstWhere(
                              (v) => v['id'] == id,
                            );
                            setState(() => _seed(v));
                            unawaited(
                              _loadImages().then((_) {
                                if (mounted) setState(() {});
                              }),
                            );
                          },
                  ),
                if (_new)
                  DropdownButtonFormField<String>(
                    initialValue: _kind,
                    items: [
                      DropdownMenuItem(
                        value: 'quickapp',
                        child: Text(_l10n.quickApp),
                      ),
                      DropdownMenuItem(
                        value: 'watchface',
                        child: Text(_l10n.watchface),
                      ),
                    ],
                    onChanged: _busy
                        ? null
                        : (v) => setState(() {
                            _kind = v!;
                            _members.clear();
                            _representative = '';
                          }),
                  ),
                TextField(
                  controller: _name,
                  decoration: InputDecoration(
                    labelText: _l10n.creatorCollectionName,
                  ),
                  maxLength: 120,
                ),
                TextField(
                  controller: _summary,
                  decoration: InputDecoration(
                    labelText: _l10n.creatorCollectionSummary,
                  ),
                  maxLength: 1000,
                ),
                TextField(
                  controller: _description,
                  decoration: InputDecoration(
                    labelText: _l10n.creatorCollectionBody,
                  ),
                  minLines: 5,
                  maxLines: 12,
                ),
                for (final role in ['icon', 'cover'])
                  ListTile(
                    title: Text(
                      role == 'icon'
                          ? _l10n.creatorMediaIcon
                          : _l10n.creatorMediaCover,
                    ),
                    leading: _images[role] != null
                        ? Image.memory(
                            _images[role]!,
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                          )
                        : null,
                    subtitle: Text(
                      (_digests[role] ?? '').isEmpty
                          ? _l10n.creatorMediaUnset
                          : _l10n.creatorMediaSet,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: _busy ? null : () => _pick(role),
                          icon: const Icon(Icons.image_outlined),
                        ),
                        IconButton(
                          onPressed: _busy
                              ? null
                              : () => setState(() {
                                  _digests[role] = '';
                                  _images.remove(role);
                                }),
                          icon: const Icon(Icons.clear),
                        ),
                      ],
                    ),
                  ),
                Text(_l10n.creatorCollectionMemberOrder),
                for (var i = 0; i < _members.length; i++)
                  ListTile(
                    title: Text(
                      names[_members[i]] ??
                          _l10n.creatorCollectionMemberUnavailable,
                    ),
                    leading: IconButton(
                      tooltip: _l10n.creatorCollectionSetRepresentative,
                      icon: Icon(
                        _members[i] == _representative
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                      ),
                      onPressed: _busy
                          ? null
                          : () => setState(() => _representative = _members[i]),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: _busy || i == 0
                              ? null
                              : () => setState(() {
                                  final v = _members.removeAt(i);
                                  _members.insert(i - 1, v);
                                }),
                          icon: const Icon(Icons.arrow_upward),
                        ),
                        IconButton(
                          onPressed: _busy
                              ? null
                              : () => setState(() {
                                  final id = _members.removeAt(i);
                                  if (id == _representative) {
                                    _representative =
                                        _members.firstOrNull ?? '';
                                  }
                                }),
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                      ],
                    ),
                  ),
                Text(_l10n.creatorCollectionAddMember),
                for (final w in resources.where(
                  (w) => !_members.contains(w.resource.id),
                ))
                  ListTile(
                    title: Text(w.resource.draftName),
                    trailing: IconButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                              _members.add(w.resource.id);
                              if (_representative.isEmpty) {
                                _representative = w.resource.id;
                              }
                            }),
                      icon: const Icon(Icons.add),
                    ),
                  ),
                if (resources.isEmpty)
                  Text(
                    AppLocalizations.of(context)!
                        .creatorCollectionNoMatchingResources,
                  ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _busy || _members.isEmpty ? null : _submit,
                  child: Text(
                    _busy
                        ? _l10n.creatorOperationWorking
                        : _l10n.creatorSubmitReview,
                  ),
                ),
              ],
            ),
    );
  }
}
