import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/widgets/page_container.dart';
import 'package:oronbox/src/app/widgets/sys_app_bar.dart';
import 'package:oronbox/src/core/constants/style_constants.dart';

class AcknowledgementItem {
  const AcknowledgementItem({
    required this.name,
    required this.description,
    this.url,
  });

  final String name;
  final String description;
  final String? url;
}

class AcknowledgementsPage extends StatelessWidget {
  const AcknowledgementsPage({super.key});

  List<AcknowledgementItem> _items(AppLocalizations l10n) {
    return [
      AcknowledgementItem(
        name: 'Kazumi',
        description: l10n.acknowledgementsKazumi,
        url: 'https://github.com/Predidit/Kazumi',
      ),
      AcknowledgementItem(
        name: 'AstralSightStudios/AstroBox-Public',
        description: l10n.acknowledgementsAstroBoxPublic,
        url: 'https://github.com/AstralSightStudios/AstroBox-Public',
      ),
      AcknowledgementItem(
        name: 'AstralSightStudios/AstroBox-NG-Module-Core',
        description: l10n.acknowledgementsAstroBoxNgCore,
        url: 'https://github.com/AstralSightStudios/AstroBox-NG-Module-Core',
      ),
      AcknowledgementItem(
        name: 'AstralSightStudios/AstroBox-NG-Module-Pb',
        description: l10n.acknowledgementsAstroBoxNgPb,
        url: 'https://github.com/AstralSightStudios/AstroBox-NG-Module-Pb',
      ),
      AcknowledgementItem(
        name: 'AstralSightStudios/AstroBox-NG-Module-Bluetooth',
        description: l10n.acknowledgementsAstroBoxNgBluetooth,
        url: 'https://github.com/AstralSightStudios/AstroBox-NG-Module-Bluetooth',
      ),
      AcknowledgementItem(
        name: 'AstralSightStudios/AstroBox-NG-Module-Account',
        description: l10n.acknowledgementsAstroBoxNgAccount,
        url: 'https://github.com/AstralSightStudios/AstroBox-NG-Module-Account',
      ),
      AcknowledgementItem(
        name: 'AstralSightStudios/AstroBox-NG-Module-Provider',
        description: l10n.acknowledgementsAstroBoxNgProvider,
        url:
            'https://github.com/AstralSightStudios/AstroBox-NG-Module-Provider',
      ),
      AcknowledgementItem(
        name: 'AstralSightStudios/AstroBox-NG-Module-AppWasm',
        description: l10n.acknowledgementsAstroBoxNgAppWasm,
        url: 'https://github.com/AstralSightStudios/AstroBox-NG-Module-AppWasm',
      ),
      AcknowledgementItem(
        name: 'Gadgetbridge',
        description: l10n.acknowledgementsGadgetbridge,
        url: 'https://codeberg.org/Freeyourgadget/Gadgetbridge',
      ),
      AcknowledgementItem(
        name: 'Breezy Weather',
        description: l10n.acknowledgementsBreezyWeather,
        url: 'https://github.com/breezy-weather/breezy-weather',
      ),
      AcknowledgementItem(
        name: 'Open-Meteo',
        description: l10n.acknowledgementsOpenMeteo,
        url: 'https://open-meteo.com/',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final items = _items(l10n);

    return Scaffold(
      appBar: SysAppBar(secondary: true, title: Text(l10n.acknowledgements)),
      body: ListView.separated(
        padding: EdgeInsets.only(
          top: StyleConstants.pagePadding,
          bottom: bottomContentPadding(
            context,
            extra: StyleConstants.pagePadding,
          ),
        ),
        itemCount: items.length,
        separatorBuilder: (_, _) =>
            const SizedBox(height: StyleConstants.cardSpace),
        itemBuilder: (context, index) {
          final item = items[index];
          return PageContainer(
            safeArea: false,
            padding: const EdgeInsets.symmetric(
              horizontal: StyleConstants.pagePadding,
            ),
            child: Card(
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(StyleConstants.cardRadius),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: item.url == null
                    ? null
                    : () => _launchUrl(context, item.url!),
                borderRadius: BorderRadius.circular(StyleConstants.cardRadius),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.name,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          if (item.url != null)
                            const Icon(
                              Icons.open_in_new,
                              size: 16,
                              color: Colors.grey,
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.description,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _launchUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
