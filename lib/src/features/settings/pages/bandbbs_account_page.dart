import 'package:segmented_list/segmented_list.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/utils/error_localization.dart';
import 'package:oronbox/src/app/widgets/dialog_helper.dart';
import 'package:oronbox/src/app/widgets/network_img_layer.dart';
import 'package:oronbox/src/app/widgets/sys_app_bar.dart';
import 'package:oronbox/src/app/widgets/page_container.dart';
import 'package:oronbox/src/core/constants/style_constants.dart';
import 'package:oronbox/src/core/providers/app_settings_providers.dart';
import 'package:oronbox/src/core/services/shared_prefs_service.dart';
import 'package:oronbox/src/data/community/community_source.dart';
import 'package:oronbox/src/features/accounts/application/host_accounts.dart';
import 'package:oronbox/src/features/accounts/services/oronbox_coin_service.dart';
import 'package:oronbox/src/features/resources/application/creator/creator_workspace_controller.dart';
import 'package:oronbox/src/features/resources/pages/creator/creator_shared.dart';
import 'package:oronbox/src/features/resources/application/resource_catalog_providers.dart';
import 'package:oronbox/src/features/resources/domain/community_resource.dart';
import 'package:oronbox/src/features/resources/services/download_queue_notifier.dart';

class BandBbsAccountPage extends ConsumerStatefulWidget {
  const BandBbsAccountPage({super.key});
  @override
  ConsumerState<BandBbsAccountPage> createState() => _BandBbsAccountPageState();
}

class _BandBbsAccountPageState extends ConsumerState<BandBbsAccountPage> {
  final _id = TextEditingController();
  CommunityResourceDetail? _resource;
  Object? _error;
  var _loading = false;
  CoinAccount? _coinAccount;
  var _coinLoading = true;
  var _checkingIn = false;
  var _checkedIn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(ref.read(creatorWorkspaceProvider.notifier).refresh());
      unawaited(_loadCoins());
    });
  }

  Future<void> _loadCoins() async {
    try {
      final account = await ref.read(oronBoxCoinServiceProvider).account();
      final checkedIn =
          SharedPrefsService.instance.getString(_checkinPreferenceKey) ==
          _today;
      if (mounted) {
        setState(() {
          _coinAccount = account;
          _checkedIn = checkedIn;
        });
      }
      if (!checkedIn) unawaited(_checkin());
    } catch (error) {
      if (mounted) {
        setState(() => _coinAccount = null);
      }
    } finally {
      if (mounted) setState(() => _coinLoading = false);
    }
  }

  Future<void> _checkin() async {
    if (_checkingIn) return;
    setState(() => _checkingIn = true);
    try {
      final result = await ref.read(oronBoxCoinServiceProvider).checkin();
      if (!mounted) return;
      setState(() {
        _coinAccount = result.account;
        _checkedIn = true;
      });
      await SharedPrefsService.instance.setString(
        _checkinPreferenceKey,
        _today,
      );
      if (!mounted) return;
      OronBoxDialog.showToast(
        message: AppLocalizations.of(context)!
            .oronBoxCoinsCheckinReward(result.reward),
        context: context,
      );
    } catch (error) {
      if (mounted) showCreatorFailure(context, error);
    } finally {
      if (mounted) setState(() => _checkingIn = false);
    }
  }

  String get _checkinPreferenceKey {
    final userId = ref.read(hostAccountsProvider).bandbbs.userId ?? 'unknown';
    return 'oronbox.coins.checkin.$userId';
  }

  String get _today {
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${now.year}-${two(now.month)}-${two(now.day)}';
  }

  @override
  void dispose() {
    _id.dispose();
    super.dispose();
  }

  Future<void> _authorizePublishing() async {
    try {
      await ref
          .read(hostAccountsProvider.notifier)
          .startBandBbsPublishingAuthorization();
      unawaited(ref.read(creatorWorkspaceProvider.notifier).refresh());
    } catch (error) {
      if (mounted) showCreatorFailure(context, error);
    }
  }

  Future<void> _query() async {
    final id = _id.text.trim();
    if (id.isEmpty || _loading) return;
    setState(() {
      _loading = true;
      _error = null;
      _resource = null;
    });
    try {
      final resource = await ref
          .read(communityCatalogProviderForSource(CommunitySourceId.bandbbs))
          .getDetail(ResourceRef(source: CommunitySourceId.bandbbs, id: id));
      if (mounted) {
        setState(() {
          _resource = resource;
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final account = ref.watch(hostAccountsProvider).bandbbs;
    final publishGranted =
        ref.watch(
          creatorWorkspaceProvider.select(
            (state) => state.grants['bandbbs_publish'],
          ),
        ) ==
        true;
    return Scaffold(
      appBar: SysAppBar(secondary: true, title: Text(l10n.bandBbsAccountTitle)),
      body: SegmentedList(
        maxWidth: StyleConstants.pageMaxWidth,
        contentPadding: EdgeInsets.only(
          top: 8,
          bottom: bottomContentPadding(context, extra: 16),
        ),
        sections: [
          SegmentedSection(
            tiles: [
              SegmentedTile(
                leading: account.avatarUrl != null
                    ? NetworkImgLayer(
                        src: account.avatarUrl!,
                        width: 32,
                        height: 32,
                        type: 'avatar',
                      )
                    : CircleAvatar(
                        radius: 16,
                        child: Text(
                          (account.username ?? account.userId ?? 'B')
                              .characters
                              .first,
                        ),
                      ),
                title: Text(account.username ?? l10n.settingsAccountBBSAccount),
                description: Text(
                  account.userId == null
                      ? l10n.settingsConnected
                      : '${l10n.settingsAccountBandBbsAccount} · ${account.userId}',
                ),
                trailing: TextButton(
                  onPressed: () async {
                    await ref
                        .read(hostAccountsProvider.notifier)
                        .logout('bandbbs');
                    if (!context.mounted) return;
                    OronBoxDialog.showToast(
                      message: l10n.bandBbsLoggedOut,
                      context: context,
                    );
                    context.pop();
                  },
                  child: Text(l10n.bandBbsLogout),
                ),
              ),
            ],
          ),
          SegmentedSection(
            title: Text(l10n.bandBbsPublishAuthTitle),
            tiles: [
              SegmentedTile(
                leading: const Icon(Icons.publish_outlined),
                title: Text(l10n.bandBbsPublishAuthTitle),
                description: Text(
                  publishGranted
                      ? l10n.creatorBandBbsAuthorized
                      : l10n.creatorBandBbsAuthorizationRequired,
                ),
                trailing: publishGranted
                    ? Icon(
                        Icons.check_circle_outline,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : FilledButton.tonal(
                        onPressed: _authorizePublishing,
                        child: Text(l10n.creatorAuthorize),
                      ),
              ),
            ],
          ),
          SegmentedSection(
            title: Text(l10n.oronBoxCoinsTitle),
            tiles: [
              SegmentedTile(
                leading: const Icon(Icons.toll_outlined),
                title: Text(
                  l10n.oronBoxCoinsBalance(_coinAccount?.displayBalance ?? '0'),
                ),
                description: Text(l10n.oronBoxCoinsDescription),
                trailing: FilledButton.tonal(
                  onPressed: _coinLoading || _checkingIn || _checkedIn
                      ? null
                      : _checkin,
                  child: _checkingIn
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          _checkedIn
                              ? l10n.oronBoxCoinsCheckedIn
                              : l10n.oronBoxCoinsCheckin,
                        ),
                ),
              ),
            ],
          ),
          SegmentedSection(
            title: Text(l10n.bandBbsResourceQueryTitle),
            tiles: [
              SegmentedTile(
                leading: const Icon(Icons.tag),
                title: Text(l10n.bandBbsResourceId),
                description: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _id,
                          keyboardType: TextInputType.number,
                          onSubmitted: (_) => _query(),
                          decoration: InputDecoration(
                            labelText: l10n.bandBbsResourceIdHint,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: _loading ? null : _query,
                        icon: _loading
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.search),
                        label: Text(l10n.bandBbsQueryResource),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          SegmentedSection(
            title: Text(l10n.settingsGeneral),
            tiles: [
              SegmentedTile.switchTile(
                onToggle: (value) async {
                  await ref
                      .read(appSettingsProvider.notifier)
                      .setBandBbsLoadPreviews(value ?? false);
                },
                initialValue: ref
                    .watch(appSettingsProvider)
                    .bandbbsLoadPreviews,
                leading: const Icon(Icons.image_outlined),
                title: Text(l10n.bandBbsLoadPreviews),
                description: Text(l10n.bandBbsLoadPreviewsDesc),
              ),
              SegmentedTile.switchTile(
                onToggle: (value) async {
                  await ref
                      .read(appSettingsProvider.notifier)
                      .setBandBbsShowAllCategories(value ?? false);
                },
                initialValue: ref
                    .watch(appSettingsProvider)
                    .bandbbsShowAllCategories,
                leading: const Icon(Icons.category_outlined),
                title: Text(l10n.bandBbsShowAllCategories),
                description: Text(l10n.bandBbsShowAllCategoriesDesc),
              ),
            ],
          ),
          if (_error != null || _resource != null)
            SegmentedSection(
              tiles: [
                SegmentedTile(
                  title: _error != null
                      ? Text(
                          localizedErrorMessage(l10n, _error!),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        )
                      : _Result(resource: _resource!),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _Result extends ConsumerWidget {
  const _Result({required this.resource});
  final CommunityResourceDetail resource;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
    margin: const EdgeInsets.only(top: 16),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              NetworkImgLayer(
                src: resource.iconUrl?.toString() ?? '',
                width: 56,
                height: 56,
                type: 'avatar',
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  resource.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              if (resource.publicUrl != null)
                IconButton(
                  icon: const Icon(Icons.open_in_new),
                  onPressed: () => launchUrl(
                    resource.publicUrl!,
                    mode: LaunchMode.externalApplication,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          ...resource.files.map(
            (file) => ListTile(
              title: Text(file.fileName),
              subtitle: Text(file.version),
              trailing: FilledButton.icon(
                onPressed:
                    resource.canDownload && file.supportedDevices.isNotEmpty
                    ? () {
                        final target = file.supportedDevices.first;
                        ref
                            .read(downloadQueueProvider.notifier)
                            .enqueue(
                              resource: resource,
                              file: file,
                              codename: target,
                            );
                      }
                    : null,
                icon: const Icon(Icons.download),
                label: Text(AppLocalizations.of(context)!.download),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
