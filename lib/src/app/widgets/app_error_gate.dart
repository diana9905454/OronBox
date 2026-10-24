import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/widgets/app_scaffold_messenger.dart';
import 'package:oronbox/src/app/utils/error_localization.dart';
import 'package:oronbox/src/features/accounts/application/host_accounts.dart';

/// Converts application-wide state failures into one user-facing notice.
///
/// Feature widgets remain responsible for failures caused by their own user
/// actions. Cross-cutting failures such as an expired account session belong
/// here so daemon and in-process hosts behave identically.
class AppErrorGate extends ConsumerWidget {
  const AppErrorGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(
      hostAccountsProvider.select(
        (state) => (state.noticeRevision, state.noticeCode),
      ),
      (previous, next) {
        if (next.$1 == 0 || previous?.$1 == next.$1 || next.$2 == null) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final messenger = appScaffoldMessengerKey.currentState;
          final messengerContext = messenger?.context;
          if (messenger == null || messengerContext == null) return;
          final l10n = AppLocalizations.of(messengerContext)!;
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(
                  localizedErrorMessage(l10n, '${next.$2}: application state'),
                ),
              ),
            );
        });
      },
    );
    return child;
  }
}
