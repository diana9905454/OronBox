import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/utils/error_localization.dart';
import 'package:flutter/material.dart';
import 'package:oronbox/src/features/settings/services/legal_agreements.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:oronbox/src/app/widgets/sys_app_bar.dart';
import 'package:oronbox/src/app/widgets/markdown_style_sheet.dart';
import 'package:oronbox/src/core/constants/style_constants.dart';
import 'package:oronbox/src/features/resources/widgets/resource_external_link.dart';

Future<String> loadLegalDocument(
  WidgetRef ref,
  String id,
  String language,
) async {
  return LegalAgreements.read(id, language);
}

String legalDocumentLanguage(Locale locale) {
  return locale.languageCode == 'zh' ? 'zh' : 'en';
}

class LegalDocumentPage extends ConsumerWidget {
  const LegalDocumentPage({super.key, required this.id, required this.title});

  final String id;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Scaffold(
      appBar: SysAppBar(secondary: true, title: Text(title)),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 840),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(
                    StyleConstants.cardRadius,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(
                    StyleConstants.cardRadius,
                  ),
                  child: FutureBuilder<String>(
                    future: loadLegalDocument(
                      ref,
                      id,
                      legalDocumentLanguage(Localizations.localeOf(context)),
                    ),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            localizedErrorMessage(
                              AppLocalizations.of(context)!,
                              snapshot.error,
                            ),
                          ),
                        );
                      }
                      if (!snapshot.hasData) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(48),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }
                      return Markdown(
                        data: snapshot.data!,
                        selectable: true,
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                        styleSheet: markdownStyleSheetFromTheme(theme).copyWith(
                          p: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                          pPadding: const EdgeInsets.only(bottom: 12),
                          h1: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          h1Padding: const EdgeInsets.only(top: 16, bottom: 8),
                          h2: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          h2Padding: const EdgeInsets.only(top: 12, bottom: 6),
                        ),
                        onTapLink: (_, href, _) {
                          final uri = Uri.tryParse(href ?? '');
                          if (uri != null && uri.hasScheme) {
                            openResourceExternalLink(context, uri);
                          }
                        },
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Keeps the editor mounted while a new publishing agreement is read.
Future<bool> ensurePublishingAgreement(BuildContext context) async {
  await LegalAgreements.refreshManifest();
  if (!context.mounted) return false;
  if (LegalAgreements.accepted('resource-publishing')) return true;
  String body;
  try {
    body = await LegalAgreements.read(
      'resource-publishing',
      legalDocumentLanguage(Localizations.localeOf(context)),
    );
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.creatorTermsLoadFailed),
        ),
      );
    }
    return false;
  }
  if (!context.mounted) return false;
  final agreed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(AppLocalizations.of(context)!.creatorTermsUpdated),
      content: SizedBox(width: 720, height: 480, child: Markdown(data: body)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(AppLocalizations.of(context)!.creatorPublishingLater),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(AppLocalizations.of(context)!.creatorTermsAgree),
        ),
      ],
    ),
  );
  return agreed == true &&
      await LegalAgreements.acceptShown('resource-publishing');
}
