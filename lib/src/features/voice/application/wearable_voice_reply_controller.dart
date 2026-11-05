import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oronbox/src/core/ai/ai_settings_store.dart';
import 'package:oronbox/src/device/core/event_bus.dart';
import 'package:oronbox/src/features/devices/controllers/device_manager.dart';

final wearableVoiceReplyControllerProvider =
    Provider<WearableVoiceReplyController>((ref) {
      return WearableVoiceReplyController(
        ref.read(deviceManagerProvider.notifier),
      );
    });

/// Adapts a completed or streaming AI answer to the connected wearable.
class WearableVoiceReplyController {
  const WearableVoiceReplyController(this._manager);

  final DeviceManager _manager;

  Future<void> sendText(
    String text, {
    required String recognizedText,
    XiaoAiSessionTarget? target,
  }) async {
    if (text.trim().isEmpty) return;
    if (!AiSettingsStore.streamEnabled) {
      await _manager.sendXiaoAiReply(
        text,
        recognizedText: recognizedText,
        target: target,
      );
      return;
    }
    final controller = StreamController<String>();
    final sending = _manager.sendXiaoAiStreamReply(
      controller.stream,
      recognizedText: recognizedText,
      target: target,
    );
    controller.add(text);
    await controller.close();
    await sending;
  }

  Future<void> sendStream(
    Stream<String> textStream, {
    required String recognizedText,
    XiaoAiSessionTarget? target,
  }) => _manager.sendXiaoAiStreamReply(
    textStream,
    recognizedText: recognizedText,
    target: target,
  );
}
