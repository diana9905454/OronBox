sealed class AiStreamEvent {
  const AiStreamEvent();
}

final class AiTextDelta extends AiStreamEvent {
  const AiTextDelta(this.text);
  final String text;
}

final class AiToolCallEvent extends AiStreamEvent {
  const AiToolCallEvent({
    required this.id,
    required this.name,
    required this.arguments,
  });

  final String id;
  final String name;
  final Map<String, dynamic> arguments;
}

final class AiDoneEvent extends AiStreamEvent {
  const AiDoneEvent({this.fullText = ''});
  final String fullText;
}

final class AiErrorEvent extends AiStreamEvent {
  const AiErrorEvent(this.message);
  final String message;
}
