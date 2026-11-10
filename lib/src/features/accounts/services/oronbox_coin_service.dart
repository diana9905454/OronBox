import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oronbox/src/commands/command_protocol.dart';
import 'package:oronbox/src/core/errors/coded_error.dart';
import 'package:oronbox/src/features/accounts/application/host_accounts.dart';
import 'package:oronbox/src/host/application_host_provider.dart';

final oronBoxCoinServiceProvider = Provider<OronBoxCoinService>(
  (ref) => OronBoxCoinService(ref.watch(applicationHostProvider)),
);

/// Coins the signed-in user has already given to a resource (0, 1 or 2).
/// Errors remain in the provider so the UI can distinguish an unknown status
/// from a confirmed zero and prevent an unsafe duplicate action.
final oronBoxMyCoinsProvider = FutureProvider.autoDispose.family<int, String>((
  ref,
  resourceId,
) {
  final account = ref.watch(
    hostAccountsProvider.select(
      (state) => (state.bandbbs.isSignedIn, state.bandbbs.userId),
    ),
  );
  if (!account.$1) return 0;
  return ref.watch(oronBoxCoinServiceProvider).myCoins(resourceId);
}, retry: (_, _) => null);

class CoinAccount {
  const CoinAccount({required this.balanceUnits, this.frozenReason = ''});

  factory CoinAccount.fromJson(Map<String, Object?> json) => CoinAccount(
    balanceUnits: (json['balance_units'] as num?)?.toInt() ?? 0,
    frozenReason: json['voting_frozen_reason']?.toString() ?? '',
  );

  final int balanceUnits;
  final String frozenReason;

  String get displayBalance {
    final whole = balanceUnits ~/ 10;
    final decimal = balanceUnits.remainder(10);
    return decimal == 0 ? '$whole' : '$whole.$decimal';
  }
}

class CoinCheckinResult {
  const CoinCheckinResult({required this.reward, required this.account});

  final int reward;
  final CoinAccount account;
}

class OronBoxCoinService {
  const OronBoxCoinService(this._host);

  final OronBoxCommandBus _host;

  Future<CoinAccount> account() async {
    return CoinAccount.fromJson(_map(await _execute('coins.account')));
  }

  Future<CoinCheckinResult> checkin() async {
    final json = _map(await _execute('coins.checkin'));
    return CoinCheckinResult(
      reward: (json['reward_coins'] as num?)?.toInt() ?? 0,
      account: CoinAccount.fromJson(_map(json['account'])),
    );
  }

  Future<void> coin(String resourceId, int coins) async {
    await _execute('coins.resource', {'resource': resourceId, 'coins': coins});
  }

  /// How many coins the signed-in user has already given to [resourceId]
  /// (0, 1 or 2). Requires an active OronBox session.
  Future<int> myCoins(String resourceId) async {
    final json = _map(
      await _execute('coins.resource.status', {'resource': resourceId}),
    );
    return (json['my_coins'] as num?)?.toInt() ?? 0;
  }

  Future<Object?> _execute(
    String method, [
    Map<String, Object?> params = const {},
  ]) async {
    final result = await _host.execute(
      OronBoxCommand(method: method, params: params),
    );
    if (!result.ok) throw CoinCommandException(result.error!);
    return result.value;
  }

  Map<String, Object?> _map(Object? value) => value is Map
      ? value.cast<String, Object?>()
      : throw FormatException('OronBox server returned ${value.runtimeType}');
}

class CoinCommandException implements CodedError {
  const CoinCommandException(this.error);

  final CommandError error;

  @override
  String get code => error.code;
  @override
  String get message => error.message;
  @override
  Object? get details => error.details;

  @override
  String toString() => message;
}
