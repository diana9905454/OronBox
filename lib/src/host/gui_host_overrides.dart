import 'dart:async';

import 'package:oronbox/src/host/application_host_provider.dart';
import 'package:oronbox/src/host/gui_application_host.dart';

List<dynamic> guiHostOverrides() => [
  applicationHostProvider.overrideWith((ref) {
    final host = createGuiApplicationHost(ref.container);
    ref.onDispose(() => unawaited(host.close()));
    return host;
  }),
];
