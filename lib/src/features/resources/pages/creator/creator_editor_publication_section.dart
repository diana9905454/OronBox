part of 'creator_editor_page.dart';

extension _CreatorEditorPublicationSection on _CreatorEditorViewState {
  Widget _publicationEditor(AppLocalizations l10n) {
    final grants = widget.state.grants;
    final githubLogin = grants['github_login']?.toString() ?? '';
    final bandAuthorized = grants['bandbbs_publish'] == true;
    final boundToBandBbs = widget.workspace.bindings.any(
      (binding) => binding['provider'] == 'bandbbs',
    );
    final bandBinding = creatorExternalBinding(
      widget.workspace.bindings,
      'bandbbs',
    );
    final bandEntries = parseCreatorBandBbsBinding(bandBinding?['external_id']);
    final astroBinding = creatorExternalBinding(
      widget.workspace.bindings,
      'astrobox',
    );
    final colors = Theme.of(context).colorScheme;
    return CreatorEditorCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _publicationTargetRow(
            leading: const CreatorOronBoxLogo(),
            title: Text(l10n.oronBox),
            subtitle: Text(l10n.creatorOronBoxRequired),
            trailing: const Switch(value: true, onChanged: null),
          ),
          _publicationTargetRow(
            leading: const CreatorBrandLogo(
              asset: 'assets/images/brands/bandbbs.svg',
              label: 'BandBBS',
            ),
            title: const Text('BandBBS'),
            subtitle: Text(
              boundToBandBbs
                  ? l10n.creatorBandBbsBoundUpdate
                  : l10n.creatorBandBbsDirectPublish,
            ),
            trailing: Switch(
              value: _publishBandBbs,
              onChanged: bandAuthorized
                  ? (value) async {
                      if (value && !await _confirmTargetTerms('bandbbs')) {
                        return;
                      }
                      _update(() => _publishBandBbs = value);
                      if (value) {
                        await _loadPublicationPlan();
                        final unsupported =
                            _publicationPlan?.unmappedDeviceNames ??
                            const <String>[];
                        if (unsupported.isNotEmpty) {
                          _showFailure(
                            l10n.creatorBandBbsUnsupportedDevicesNotice,
                          );
                        }
                      }
                    }
                  : null,
            ),
          ),
          if (!bandAuthorized)
            _publicationNotice(
              icon: Icons.lock_outline,
              message: l10n.creatorBandBbsAuthorizationRequired,
              action: FilledButton.tonal(
                onPressed: _authorizeBandBbs,
                child: Text(l10n.creatorAuthorize),
              ),
            ),
          if (_publishBandBbs) ...[
            if (bandEntries.isNotEmpty)
              _publicationDetails(
                bottomPadding: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _publicationSubheading(
                      icon: Icons.link,
                      label: l10n.creatorLinkedSections(bandEntries.length),
                    ),
                    const SizedBox(height: 8),
                    for (final entry in bandEntries)
                      _publicationBindingRow(
                        title:
                            _publicationPlan?.bandBbsTargets
                                .where(
                                  (target) =>
                                      target.categoryId.toString() ==
                                      entry.categoryId,
                                )
                                .firstOrNull
                                ?.categoryName ??
                            'BandBBS',
                        subtitle: l10n.creatorBandBbsBindingIds(
                          entry.categoryId,
                          entry.resourceId,
                        ),
                      ),
                  ],
                ),
              ),
            _publicationDetails(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _publicationSubheading(
                    icon: Icons.alt_route_outlined,
                    label: l10n.creatorThisCommit,
                  ),
                  const SizedBox(height: 8),
                  if (_loadingPublicationPlan)
                    _publicationStateRow(
                      icon: Icons.hourglass_top_rounded,
                      message: l10n.creatorResolvingPublicationTarget,
                    )
                  else if (_publicationPlan?.bandBbsProblem case final problem?)
                    _publicationStateRow(
                      icon: Icons.error_outline,
                      message:
                          '${l10n.creatorBandBbsUnresolved}: ${_bandBbsProblemText(l10n, problem)}',
                      color: colors.error,
                    )
                  else if (_publicationPlan case final plan?)
                    for (final target in plan.bandBbsTargets)
                      _publicationBindingRow(
                        title: target.categoryName,
                        subtitle:
                            '${target.packageName}\n${target.deviceNames.join(', ')}',
                      )
                  else
                    _publicationStateRow(
                      icon: Icons.info_outline,
                      message: l10n.creatorResolvingPublicationTarget,
                    ),
                  if (_publicationPlan case final plan?)
                    _unsupportedDeviceNotice(
                      l10n,
                      '米坛社区',
                      plan.unmappedDeviceNames,
                    ),
                ],
              ),
            ),
            _publicationDetails(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _bandBbsVersionTitle,
                    decoration: InputDecoration(
                      labelText: l10n.creatorBandBbsVersionTitle,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _bandBbsVersionMessage,
                    minLines: 3,
                    maxLines: 8,
                    decoration: InputDecoration(
                      labelText: l10n.creatorBandBbsVersionMessage,
                    ),
                  ),
                  if (boundToBandBbs && !_externalPurchaseEnabled) ...[
                    const SizedBox(height: 4),
                    CheckboxListTile(
                      value: _overwritePreviousBandBbs,
                      onChanged: widget.state.loading
                          ? null
                          : (value) => _update(
                              () => _overwritePreviousBandBbs = value == true,
                            ),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(l10n.creatorBandBbsOverwritePrevious),
                      subtitle: Text(
                        l10n.creatorBandBbsOverwritePreviousDescription,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          _publicationTargetRow(
            leading: const CreatorBrandLogo(
              asset: 'assets/images/brands/astrobox.svg',
              label: 'AstroBox',
            ),
            title: const Text('AstroBox-Repo'),
            subtitle: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _astroRepository,
              builder: (context, value, _) => Text(
                astroBinding == null
                    ? l10n.creatorAstroBoxPrPublish(value.text.trim())
                    : l10n.creatorAstroBoxBoundSync,
              ),
            ),
            trailing: Switch(
              value: _publishAstroBox,
              onChanged: (value) async {
                if (value && !await _confirmTargetTerms('astrobox')) return;
                _update(() => _publishAstroBox = value);
                if (value) {
                  final unsupported = _astroBoxUnsupportedDeviceNames();
                  if (unsupported.isNotEmpty && mounted) {
                    _showFailure(l10n.creatorAstroBoxUnsupportedDevicesNotice);
                  }
                }
              },
            ),
          ),
          if (_publishAstroBox) ...[
            _unsupportedDeviceNotice(
              l10n,
              'AstroBox',
              _astroBoxUnsupportedDeviceNames(),
            ),
            _publicationDetails(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _astroItemId,
                    decoration: InputDecoration(
                      labelText: l10n.creatorAstroBoxItemId,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _astroRepository,
                    decoration: InputDecoration(
                      labelText: l10n.creatorAstroBoxRepository,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _astroTags,
                    decoration: InputDecoration(
                      labelText: l10n.creatorAstroBoxTags,
                      hintText: l10n.creatorAstroTagsHint,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _astroAuthor,
                    decoration: InputDecoration(
                      labelText: l10n.creatorAstroBoxAuthor,
                    ),
                  ),
                  CheckboxListTile(
                    value: _astroBindABAccount,
                    onChanged: (value) =>
                        _update(() => _astroBindABAccount = value == true),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(l10n.creatorAstroBoxBindAccount),
                  ),
                  if (githubLogin.isEmpty)
                    _publicationNotice(
                      icon: Icons.error_outline,
                      message: l10n.creatorGitHubOwnPublishMissing,
                      padding: EdgeInsets.zero,
                      action: FilledButton.tonal(
                        onPressed: _authorizeGitHub,
                        child: Text(l10n.creatorConnect),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _publicationStatusSection(AppLocalizations l10n) {
    return CreatorEditorCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final publication in widget.workspace.publications)
            _publicationStatusTile(l10n, publication),
        ],
      ),
    );
  }

  Widget _publicationStatusTile(
    AppLocalizations l10n,
    Map<String, Object?> publication,
  ) {
    final colors = Theme.of(context).colorScheme;
    final target = publication['target']?.toString() ?? '';
    final links = _publicationLinkUrls(publication);
    final error = publication['error_message']?.toString().trim() ?? '';
    final isPublished =
        target == 'oronbox' && publication['state']?.toString() == 'published';
    return _publicationTargetRow(
      leading: _publicationLogo(target),
      title: Text(creatorTargetLabel(l10n, target)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (error.isNotEmpty) Text(error),
          for (final url in links)
            InkWell(
              onTap: () => unawaited(launchUrl(Uri.parse(url))),
              child: Text(
                url,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.primary,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          if (isPublished)
            InkWell(
              onTap: () => context.push(
                '/resources/detail/${widget.workspace.resource.id}?source=oronbox',
              ),
              child: Text(
                l10n.creatorOpenInOronBox,
                style: TextStyle(
                  color: colors.primary,
                  decoration: TextDecoration.underline,
                  decorationColor: colors.primary,
                ),
              ),
            ),
        ],
      ),
      trailing: CreatorStateBadge(
        state: publication['state']?.toString() ?? '',
      ),
    );
  }

  Widget _publicationTargetRow({
    required Widget leading,
    required Widget title,
    required Widget subtitle,
    required Widget trailing,
  }) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    minVerticalPadding: 6,
    leading: SizedBox(width: 32, child: Center(child: leading)),
    title: title,
    subtitle: subtitle,
    trailing: SizedBox(width: 52, child: Center(child: trailing)),
  );

  Widget _publicationDetails({
    required Widget child,
    double bottomPadding = 12,
  }) => Padding(
    padding: EdgeInsets.fromLTRB(64, 0, 16, bottomPadding),
    child: child,
  );

  Widget _publicationNotice({
    required IconData icon,
    required String message,
    required Widget action,
    EdgeInsetsGeometry padding = const EdgeInsets.fromLTRB(64, 0, 16, 10),
  }) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: colors.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message, style: Theme.of(context).textTheme.bodySmall),
          ),
          const SizedBox(width: 12),
          action,
        ],
      ),
    );
  }

  Widget _publicationSubheading({
    required IconData icon,
    required String label,
    Widget? trailing,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: colors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.labelLarge),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _publicationBindingRow({
    required String title,
    required String subtitle,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: .45),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.link_outlined, size: 18, color: colors.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: colors.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _publicationStateRow({
    required IconData icon,
    required String message,
    Color? color,
  }) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 18, color: color),
      const SizedBox(width: 10),
      Expanded(child: Text(message)),
    ],
  );

  String _bandBbsProblemText(
    AppLocalizations l10n,
    CreatorBandBbsPlanProblem problem,
  ) => switch (problem) {
    CreatorBandBbsPlanProblem.noDevices => l10n.creatorBandBbsNoDevices,
    CreatorBandBbsPlanProblem.unmappedDevices =>
      l10n.creatorBandBbsUnmappedDevices(
        _publicationPlan?.unmappedDeviceNames.join(', ') ?? '',
      ),
    CreatorBandBbsPlanProblem.sharedCategoryArtifacts =>
      l10n.creatorBandBbsSharedCategory,
  };


}
