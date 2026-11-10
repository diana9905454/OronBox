import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:oronbox/src/app/widgets/sys_app_bar.dart';
import 'package:oronbox/src/features/resources/application/creator/creator_workspace_controller.dart';
import 'package:oronbox/src/features/resources/pages/creator/creator_editor_page.dart';
import 'package:oronbox/src/features/resources/pages/creator/creator_shared.dart';

class CreatorResourcePage extends ConsumerStatefulWidget {
  const CreatorResourcePage({super.key, this.resourceId});
  final String? resourceId;

  @override
  ConsumerState<CreatorResourcePage> createState() =>
      _CreatorResourcePageState();
}

class _CreatorResourcePageState extends ConsumerState<CreatorResourcePage> {
  Future<bool>? _openFuture;

  @override
  void initState() {
    super.initState();
    if (widget.resourceId != null) {
      _openFuture = ref
          .read(creatorWorkspaceProvider.notifier)
          .openResource(widget.resourceId!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(creatorWorkspaceProvider);
    final controller = ref.read(creatorWorkspaceProvider.notifier);
    final workspace = state.selected;
    final openingDifferentResource =
        widget.resourceId != null &&
        workspace?.resource.id != widget.resourceId;
    if (openingDifferentResource) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final future = _openFuture;
        if (!context.mounted || future == null) return;
        future.then((found) {
          if (!context.mounted || found) return;
          context.go('/resources/creator/resources');
        });
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (workspace == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/resources/creator/resources');
      });
      return const SizedBox.shrink();
    }
    return Scaffold(
      appBar: SysAppBar(
        secondary: true,
        title: Text(
          creatorWorkspaceTitle(workspace),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: CreatorEditorView(
        key: ValueKey(
          '${workspace.resource.id}:${workspace.latestRevision?.id ?? 'new'}',
        ),
        workspace: workspace,
        state: state,
        controller: controller,
        ref: ref,
      ),
    );
  }
}
