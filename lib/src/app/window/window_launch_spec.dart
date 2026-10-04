import 'dart:convert';

enum OronBoxWindowRole { main, debug, plugin }

class WindowLaunchSpec {
  const WindowLaunchSpec({
    this.role = OronBoxWindowRole.main,
    this.targetId,
    this.windowId,
  });

  final OronBoxWindowRole role;
  final String? targetId;
  final String? windowId;

  bool get isSecondary => role != OronBoxWindowRole.main;
  String get storageKey => switch (role) {
    OronBoxWindowRole.plugin when targetId != null => 'plugin.$targetId',
    _ => role.name,
  };

  static WindowLaunchSpec parse(List<String> arguments) {
    if (arguments.isNotEmpty && arguments[0] == 'multi_window') {
      final windowId = arguments.length > 1 ? arguments[1] : null;
      final raw = arguments.length > 2 ? arguments[2] : '';
      if (raw.isNotEmpty) {
        try {
          final json = jsonDecode(raw);
          if (json is Map) {
            final roleName = json['role']?.toString();
            final role = switch (roleName) {
              'debug' => OronBoxWindowRole.debug,
              'plugin' => OronBoxWindowRole.plugin,
              _ => OronBoxWindowRole.main,
            };
            return WindowLaunchSpec(
              role: role,
              targetId: json['targetId']?.toString(),
              windowId: windowId,
            );
          }
        } catch (_) {}
      }
      return WindowLaunchSpec(
        role: OronBoxWindowRole.main,
        windowId: windowId,
      );
    }

    final index = arguments.indexOf('--window');
    if (index >= 0 && index + 1 < arguments.length) {
      return switch (arguments[index + 1]) {
        'debug' => const WindowLaunchSpec(role: OronBoxWindowRole.debug),
        'plugin' => WindowLaunchSpec(
          role: OronBoxWindowRole.plugin,
          targetId: _option(arguments, '--plugin-id'),
        ),
        _ => const WindowLaunchSpec(),
      };
    }
    return const WindowLaunchSpec();
  }

  static String? _option(List<String> arguments, String name) {
    final index = arguments.indexOf(name);
    return index >= 0 && index + 1 < arguments.length
        ? arguments[index + 1]
        : null;
  }
}
