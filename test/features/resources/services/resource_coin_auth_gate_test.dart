import 'package:oronbox/src/features/accounts/application/host_accounts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oronbox/src/commands/command_protocol.dart';
import 'package:oronbox/src/features/accounts/services/bandbbs_auth_service.dart';
import 'package:oronbox/src/features/accounts/services/oronbox_coin_service.dart';

void main() {
  test('does not request coin status when the user is signed out', () async {
    final host = _RecordingHost();
    final container = ProviderContainer(
      overrides: [
        bandBbsAuthProvider.overrideWith(_SignedOutAuthNotifier.new),
        hostAccountsProvider.overrideWith(_SignedOutHost.new),
        oronBoxCoinServiceProvider.overrideWithValue(OronBoxCoinService(host)),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      oronBoxMyCoinsProvider('resource-id'),
      (_, _) {},
    );
    addTearDown(subscription.close);

    expect(
      await container.read(oronBoxMyCoinsProvider('resource-id').future),
      0,
    );
    expect(host.methods, isEmpty);
  });
  test(
    'uses the host login when credentials belong to another process',
    () async {
      final host = _RecordingHost();
      final container = ProviderContainer(
        overrides: [
          bandBbsAuthProvider.overrideWith(_SignedOutAuthNotifier.new),
          hostAccountsProvider.overrideWith(_SignedInHost.new),
          oronBoxCoinServiceProvider.overrideWithValue(
            OronBoxCoinService(host),
          ),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        oronBoxMyCoinsProvider('resource-id'),
        (_, _) {},
      );
      addTearDown(subscription.close);
      await container.read(oronBoxMyCoinsProvider('resource-id').future);
      expect(host.methods, ['coins.resource.status']);
    },
  );

  test(
    'token metadata changes do not restart an in-flight coin status request',
    () async {
      final host = _RecordingHost();
      final container = ProviderContainer(
        overrides: [
          bandBbsAuthProvider.overrideWith(_SignedInAuthNotifier.new),
          hostAccountsProvider.overrideWith(_SignedInHost.new),
          oronBoxCoinServiceProvider.overrideWithValue(
            OronBoxCoinService(host),
          ),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        oronBoxMyCoinsProvider('resource-id'),
        (_, _) {},
      );
      addTearDown(subscription.close);
      var reads = 0;
      host.onRead = () {
        if (++reads < 6) {
          (container.read(
            bandBbsAuthProvider.notifier,
          ) as _SignedInAuthNotifier).refreshUserMetadata();
        }
      };
      await container
          .read(oronBoxMyCoinsProvider('resource-id').future)
          .timeout(const Duration(seconds: 2));
      expect(reads, 1);
    },
  );
  test('status failures wait for explicit retry', () async {
    final host = _RecordingHost()..failStatus = true;
    final container = ProviderContainer(
      overrides: [
        hostAccountsProvider.overrideWith(_SignedInHost.new),
        oronBoxCoinServiceProvider.overrideWithValue(OronBoxCoinService(host)),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(
      oronBoxMyCoinsProvider('resource-id'),
      (_, _) {},
    );
    addTearDown(sub.close);
    await expectLater(
      container.read(oronBoxMyCoinsProvider('resource-id').future),
      throwsA(isA<CoinCommandException>()),
    );
    await Future<void>.delayed(const Duration(milliseconds: 350));
    expect(host.methods.length, 1);
    expect(
      container.read(oronBoxMyCoinsProvider('resource-id')).hasError,
      isTrue,
    );
    host.failStatus = false;
    container.invalidate(oronBoxMyCoinsProvider('resource-id'));
    expect(
      await container.read(oronBoxMyCoinsProvider('resource-id').future),
      0,
    );
    expect(host.methods.length, 2);
  });

  test(
    'changing host accounts reloads status and signing out stops requests',
    () async {
      final host = _RecordingHost();
      final container = ProviderContainer(
        overrides: [
          hostAccountsProvider.overrideWith(_SignedInHost.new),
          oronBoxCoinServiceProvider.overrideWithValue(
            OronBoxCoinService(host),
          ),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(
        oronBoxMyCoinsProvider('resource-id'),
        (_, _) {},
      );
      addTearDown(sub.close);
      await container.read(oronBoxMyCoinsProvider('resource-id').future);
      final accounts =
          container.read(hostAccountsProvider.notifier) as _SignedInHost;
      accounts.setUser('456');
      await container.read(oronBoxMyCoinsProvider('resource-id').future);
      expect(host.methods.length, 2);
      accounts.setUser(null);
      expect(
        await container.read(oronBoxMyCoinsProvider('resource-id').future),
        0,
      );
      expect(host.methods.length, 2);
    },
  );
}

class _SignedOutAuthNotifier extends BandBbsAuthNotifier {
  @override
  BandBbsAuthState build() => BandBbsAuthState.empty;
}

class _RecordingHost implements OronBoxCommandBus {
  void Function()? onRead;
  bool failStatus = false;
  final methods = <String>[];

  @override
  Stream<CommandEvent> get events => const Stream.empty();

  @override
  Future<CommandResult> execute(OronBoxCommand command) async {
    methods.add(command.method);
    await Future<void>.delayed(Duration.zero);
    onRead?.call();
    if (failStatus) {
      return const CommandResult.failure(
        CommandError('coin_status_failed', 'unavailable'),
      );
    }
    return const CommandResult.success({'my_coins': 0});
  }

  @override
  Future<void> close() async {}
}

class _SignedOutHost extends HostAccountsNotifier {
  @override
  HostAccountsState build() => const HostAccountsState();
}

class _SignedInHost extends HostAccountsNotifier {
  void setUser(String? id) {
    state = HostAccountsState(
      accounts: {
        if (id != null)
          'bandbbs': HostAccount(
            provider: 'bandbbs',
            signedIn: true,
            userId: id,
          ),
      },
    );
  }

  @override
  HostAccountsState build() => const HostAccountsState(
    accounts: {
      'bandbbs': HostAccount(
        provider: 'bandbbs',
        signedIn: true,
        userId: '123',
      ),
    },
  );
}

class _SignedInAuthNotifier extends BandBbsAuthNotifier {
  @override
  BandBbsAuthState build() => BandBbsAuthState.empty.copyWith(
    session: OronBoxSession(
      accessToken: 'at',
      refreshToken: 'rt',
      expiresAt: DateTime(2030),
    ),
  );
  void refreshUserMetadata() {
    state = state.copyWith();
  }
}
