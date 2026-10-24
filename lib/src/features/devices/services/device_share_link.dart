import 'package:oronbox/src/core/models/bt_models.dart';

class DeviceShareLink {
  const DeviceShareLink._();

  static Uri build(MiWearState device) {
    return Uri(
      scheme: 'https',
      host: 'oronbox.zxor.org',
      path: '/open',
      queryParameters: _parameters(device),
    );
  }

  static Uri buildDeepLink(MiWearState device) {
    return Uri(
      scheme: 'oronbox',
      host: 'open',
      queryParameters: _parameters(device),
    );
  }

  static Uri buildAstroBoxCompatible(MiWearState device) {
    return Uri(
      scheme: 'https',
      host: 'astrobox.online',
      path: '/open',
      queryParameters: _parameters(device),
    );
  }

  static Map<String, String> _parameters(MiWearState device) => {
    'source': 'deviceQr',
    'name': device.name,
    'mac': (_formatMac(device.addr) ?? device.addr).replaceAll(':', ''),
    if (device.authkey case final authkey? when authkey.isNotEmpty)
      'authkey': authkey,
  };

  static MiWearState? parse(String value) {
    final raw = value.trim();
    final question = raw.indexOf('?');
    final query = (question >= 0 ? raw.substring(question + 1) : raw)
        .split('#')
        .first;
    if (RegExp(r'%(?![0-9a-fA-F]{2})').hasMatch(query)) return null;
    try {
      final parameters = Uri.parse('?$query').queryParametersAll;
      for (final key in ['name', 'addr', 'mac', 'authkey']) {
        if ((parameters[key]?.length ?? 0) > 1) return null;
      }
      final name = parameters['name']?.single.trim() ?? '';
      final addresses = <String>{};
      for (final field in ['addr', 'mac']) {
        final value = parameters[field]?.single;
        if (value == null) continue;
        final address = _formatMac(value);
        if (address == null) return null;
        addresses.add(address);
      }
      if (addresses.length != 1) return null;
      final addr = addresses.single;
      final authkey = parameters['authkey']?.single.trim() ?? '';
      if (name.isEmpty ||
          (authkey.isNotEmpty &&
              !RegExp(r'^[0-9a-fA-F]{32}$').hasMatch(authkey))) {
        return null;
      }
      return MiWearState(
        name: name,
        addr: addr,
        connectType: 'spp',
        authkey: authkey,
        disconnected: true,
      );
    } on FormatException {
      return null;
    }
  }

  static String? _formatMac(String value) {
    final raw = value.trim();
    if (!RegExp(
      r'^(?:[0-9a-fA-F]{12}|(?:[0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}|(?:[0-9a-fA-F]{2}-){5}[0-9a-fA-F]{2})$',
    ).hasMatch(raw)) {
      return null;
    }
    final compact = raw.replaceAll(RegExp('[:-]'), '').toUpperCase();
    return List.generate(
      6,
      (index) => compact.substring(index * 2, index * 2 + 2),
    ).join(':');
  }
}
