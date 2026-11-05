import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:segmented_list/segmented_list.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/widgets/sys_app_bar.dart';
import 'package:oronbox/src/app/widgets/page_container.dart';
import 'package:oronbox/src/core/constants/style_constants.dart';

class FeatureLabPage extends StatelessWidget {
  const FeatureLabPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: SysAppBar(secondary: true, title: Text(l10n.featureLabTitle)),
      body: SegmentedList(
        maxWidth: StyleConstants.pageMaxWidth,
        contentPadding: EdgeInsets.only(
          top: 8,
          bottom: bottomContentPadding(context, extra: 16),
        ),
        sections: [
          SegmentedSection(
            tiles: [
              SegmentedTile.navigation(
                leading: const Icon(Icons.auto_awesome),
                title: Text(l10n.globalAiTitle),
                description: Text(l10n.globalAiDescription),
                onPressed: (_) => context.push('/settings/labs/global-ai'),
              ),
              SegmentedTile.navigation(
                leading: const Icon(Icons.record_voice_over),
                title: Text(l10n.voiceLabTitle),
                description: Text(l10n.voiceAssistantDescription),
                onPressed: (_) =>
                    context.push('/settings/labs/voice-assistant'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
