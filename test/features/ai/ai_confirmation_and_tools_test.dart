import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/features/ai/application/ai_confirmation_parser.dart';

void main() {
  group('AiConfirmationManager Test', () {
    final manager = AiConfirmationManager.instance;

    test('isConfirmation matches Chinese and English affirmative phrases', () {
      expect(manager.isConfirmation('允许执行'), isTrue);
      expect(manager.isConfirmation('确认执行'), isTrue);
      expect(manager.isConfirmation('允许'), isTrue);
      expect(manager.isConfirmation('确认'), isTrue);
      expect(manager.isConfirmation('同意'), isTrue);
      expect(manager.isConfirmation('确定'), isTrue);
      expect(manager.isConfirmation('好的'), isTrue);
      expect(manager.isConfirmation('允许执行(继续)'), isTrue);
      expect(manager.isConfirmation('允许执行继续'), isTrue);
      expect(manager.reason('允许执行继续'), '继续');
      expect(manager.isConfirmation('yes'), isTrue);
      expect(manager.isConfirmation('YES'), isTrue);
      expect(manager.isConfirmation('confirm'), isTrue);
      expect(manager.isConfirmation('proceed'), isTrue);
      expect(manager.isConfirmation('ok'), isTrue);

      expect(manager.isConfirmation('我不允许执行'), isFalse);
      expect(manager.isConfirmation('今天天气怎么样'), isFalse);
    });

    test('isRejection matches negative phrases', () {
      expect(manager.isRejection('取消'), isTrue);
      expect(manager.isRejection('拒绝'), isTrue);
      expect(manager.isRejection('不用了'), isTrue);
      expect(manager.isRejection('不要'), isTrue);
      expect(manager.isRejection('no'), isTrue);
      expect(manager.isRejection('cancel'), isTrue);
      expect(manager.isRejection('拒绝执行改成九点'), isTrue);
      expect(manager.reason('拒绝执行改成九点'), '改成九点');

      expect(manager.isRejection('好的'), isFalse);
    });

    test('PendingAiConfirmation lifecycle and expiry', () {
      final devId = 'dev_test_123';
      final pending = PendingAiConfirmation(
        id: '1',
        deviceId: devId,
        toolName: 'set_alarm',
        arguments: {'hour': 8, 'minute': 30},
        description: 'Test alarm',
        timeout: const Duration(milliseconds: 100),
      );

      manager.addPending(pending);
      expect(manager.getPending(devId), isNotNull);
      expect(manager.getPending(devId)!.toolName, 'set_alarm');

      // 等待超时
      Future.delayed(const Duration(milliseconds: 120), () {
        expect(manager.getPending(devId), isNull);
      });
    });
  });
}
