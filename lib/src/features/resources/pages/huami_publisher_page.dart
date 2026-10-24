import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/utils/error_localization.dart';
import 'package:oronbox/src/app/widgets/app_state_view.dart';
import 'package:oronbox/src/app/widgets/page_container.dart';
import 'package:oronbox/src/app/widgets/sys_app_bar.dart';
import 'package:oronbox/src/core/constants/style_constants.dart';
import 'package:oronbox/src/features/resources/application/resource_catalog_providers.dart';
import 'package:oronbox/src/features/resources/widgets/bandbbs_resource_card.dart';

class HuamiPublisherPage extends ConsumerWidget {
  const HuamiPublisherPage({super.key, required this.publisherName});

  final String publisherName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final name = publisherName.trim();
    final resources = ref.watch(huamiPublisherResourcesProvider(name));
    return Scaffold(
      appBar: SysAppBar(
        secondary: true,
        title: Text(name.isEmpty ? '@' : '@$name'),
      ),
      body: resources.isLoading
          ? const LoadingView(message: '')
          : resources.when(
              loading: () => const LoadingView(message: ''),
              error: (error, _) => ErrorStateView(
                message: localizedErrorMessage(l10n, error),
                onRetry: () =>
                    ref.invalidate(huamiPublisherResourcesProvider(name)),
              ),
              data: (items) {
                if (name.isEmpty || items.isEmpty) {
                  return EmptyStateView(
                    icon: Icons.search_off_outlined,
                    title: l10n.notFound,
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(huamiPublisherResourcesProvider(name));
                  },
                  child: ListView.separated(
                    padding: EdgeInsets.only(
                      top: StyleConstants.pagePadding,
                      bottom: bottomContentPadding(context),
                    ),
                    itemBuilder: (context, index) => PageContainer(
                      safeArea: false,
                      padding: const EdgeInsets.symmetric(
                        horizontal: StyleConstants.pagePadding,
                      ),
                      child: BandBbsResourceCard(item: items[index]),
                    ),
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemCount: items.length,
                  ),
                );
              },
            ),
    );
  }
}
