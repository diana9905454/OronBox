import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/features/plugins/runtime/plugin_runtime_quickjs.dart';

void main() {
  test('unencodable host results reject the pending JavaScript request', () {
    final settlement = encodeQuickJsHostSettlement(true, Object());

    expect(settlement.succeeded, isFalse);
    expect(settlement.encodedPayload, contains('serialization failed'));
  });
}
