import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/features/plugins/legacy/astrobox_legacy_adapter.dart';
import 'package:oronbox/src/features/plugins/runtime/plugin_runtime.dart';
import 'package:oronbox/src/features/plugins/runtime/plugin_runtime_quickjs.dart';

void main() {
  test('interconnect send forwards the optional device id', () {
    expect(
      oronBoxPluginBootstrap,
      contains("host('interconnect.send', [packageName, data, deviceId])"),
    );
  });

  test('host calls use request IDs instead of returning Dart futures', () {
    expect(oronBoxPluginBootstrap, contains('nextHostRequest'));
    expect(oronBoxPluginBootstrap, contains('__zbSettleHostRequest'));
    expect(oronBoxPluginBootstrap, contains('__zbBeginOperation'));
    expect(oronBoxPluginBootstrap, contains('__zbPollOperation'));
  });

  test('unencodable host results reject the pending JavaScript request', () {
    final settlement = encodeQuickJsHostSettlement(true, Object());

    expect(settlement.succeeded, isFalse);
    expect(settlement.encodedPayload, contains('serialization failed'));
  });

  test('legacy adapter reuses the shared host pipeline', () {
    // The legacy host() must go through the request-id + settlement pipeline
    // (via __zbHost) instead of the synchronous sendMessage bridge, otherwise
    // every AstroBox plugin call resolves to null.
    expect(astroBoxLegacyBootstrap, contains('__zbHost'));
    expect(astroBoxLegacyBootstrap, isNot(contains("sendMessage('OronBoxHost'")));
  });

  test('legacy adapter overrides the lifecycle entry points', () {
    // The legacy bootstrap replaces these five entry points with legacy
    // semantics; the four host-driven helpers must stay untouched so the
    // Dart runtime can keep driving the plugin.
    expect(astroBoxLegacyBootstrap, contains('__zbSetRuntimeGlobals'));
    expect(astroBoxLegacyBootstrap, contains('__zbStartPlugin'));
    expect(astroBoxLegacyBootstrap, contains('__zbInvokeRegistered'));
    expect(astroBoxLegacyBootstrap, contains('__zbDispatchEvent'));
    expect(astroBoxLegacyBootstrap, contains('__zbFireTimer'));
    expect(astroBoxLegacyBootstrap, isNot(contains('__zbBeginOperation')));
  });
}
