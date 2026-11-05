/// 待决执行的确认项
class PendingAiConfirmation {
  final String id;
  final String deviceId;
  final String toolName;
  final Map<String, dynamic> arguments;
  final String? conversationId;
  final String? toolCallId;
  final String originalUserText;
  final DateTime createdAt;
  final Duration timeout;
  final String description;

  PendingAiConfirmation({
    required this.id,
    required this.deviceId,
    required this.toolName,
    required this.arguments,
    required this.description,
    this.conversationId,
    this.toolCallId,
    this.originalUserText = '',
    DateTime? createdAt,
    this.timeout = const Duration(seconds: 60),
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isExpired => DateTime.now().difference(createdAt) > timeout;
}

/// 确认意图解析与跨会话状态管理
class AiConfirmationManager {
  static final AiConfirmationManager instance = AiConfirmationManager._();
  AiConfirmationManager._();

  final Map<String, PendingAiConfirmation> _pending = {};

  /// 注册待决确认
  void addPending(PendingAiConfirmation confirmation) {
    _cleanExpired();
    _pending[confirmation.deviceId] = confirmation;
  }

  /// 获取设备的待决确认（若已超时则清理并返回 null）
  PendingAiConfirmation? getPending(String deviceId) {
    _cleanExpired();
    final p = _pending[deviceId];
    if (p == null) return null;
    if (p.isExpired) {
      _pending.remove(deviceId);
      return null;
    }
    return p;
  }

  /// 移除确认
  void clearPending(String deviceId) {
    _pending.remove(deviceId);
  }

  /// 清理所有超时记录
  void _cleanExpired() {
    final now = DateTime.now();
    _pending.removeWhere((_, v) => now.difference(v.createdAt) > v.timeout);
  }

  static const _confirmPrefixes = <String>[
    '允许执行',
    '确认执行',
    '允许',
    '确认',
    '同意',
    '确定',
    '好的',
    '行',
    'yes',
    'allow',
    'confirm',
    'proceed',
    'ok',
    'sure',
  ];

  static const _rejectPrefixes = <String>[
    '拒绝执行',
    '取消',
    '拒绝',
    '不用了',
    '不要',
    '算了',
    'no',
    'cancel',
    'reject',
    'never mind',
    'stop',
  ];

  /// 检查语句是否为同意确认
  bool isConfirmation(String text) {
    return _matchPrefix(text, _confirmPrefixes) != null;
  }

  /// 检查语句是否为拒绝或取消
  bool isRejection(String text) {
    return _matchPrefix(text, _rejectPrefixes) != null;
  }

  String reason(String text) =>
      _matchPrefix(text, [..._confirmPrefixes, ..._rejectPrefixes]) ?? '';

  String? _matchPrefix(String text, List<String> prefixes) {
    final trimmed = text.trim();
    final sorted = [...prefixes]
      ..sort((left, right) => right.length.compareTo(left.length));
    for (final prefix in sorted) {
      if (!trimmed.toLowerCase().startsWith(prefix.toLowerCase())) continue;
      final remainder = trimmed.substring(prefix.length);
      if (_requiresWordBoundary(prefix) &&
          remainder.isNotEmpty &&
          RegExp(r'[A-Za-z0-9]').hasMatch(remainder[0])) {
        continue;
      }
      return remainder
          .trimLeft()
          .replaceFirst(RegExp(r'^[：:，,、\-—]+'), '')
          .trim();
    }
    return null;
  }

  bool _requiresWordBoundary(String prefix) =>
      prefix.codeUnits.every((unit) => unit < 128);
}
