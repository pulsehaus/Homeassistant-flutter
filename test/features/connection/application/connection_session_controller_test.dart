import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homeassistant_flutter/features/connection/application/connection_session_controller.dart';
import 'package:homeassistant_flutter/features/connection/application/connection_setup_providers.dart';
import 'package:homeassistant_flutter/features/connection/domain/connection_credentials.dart';

import '../fakes/fake_credential_store.dart';

void main() {
  const credentials = ConnectionCredentials(
    serverUrl: 'https://ha.example.com',
    accessToken: 'token',
  );

  ProviderContainer containerWith(FakeCredentialStore store) {
    final container = ProviderContainer(
      overrides: [credentialStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('ConnectionSessionController', () {
    test('loads stored credentials on build', () async {
      final container = containerWith(
        FakeCredentialStore(initial: credentials),
      );

      final value = await container.read(connectionSessionProvider.future);
      expect(value, credentials);
    });

    test('build yields null when nothing is stored', () async {
      final container = containerWith(FakeCredentialStore());

      final value = await container.read(connectionSessionProvider.future);
      expect(value, isNull);
    });

    test('save persists credentials and updates the session', () async {
      final store = FakeCredentialStore();
      final container = containerWith(store);
      await container.read(connectionSessionProvider.future);

      await container
          .read(connectionSessionProvider.notifier)
          .save(credentials);

      expect(store.writes, [credentials]);
      expect(container.read(connectionSessionProvider).value, credentials);
    });

    test('clear wipes storage and resets the session to null', () async {
      final store = FakeCredentialStore(initial: credentials);
      final container = containerWith(store);
      await container.read(connectionSessionProvider.future);

      await container.read(connectionSessionProvider.notifier).clear();

      expect(store.clears, 1);
      expect(store.current, isNull);
      expect(container.read(connectionSessionProvider).value, isNull);
    });
  });
}
