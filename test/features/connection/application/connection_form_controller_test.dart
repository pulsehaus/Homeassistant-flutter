import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homeassistant_flutter/features/connection/application/connection_form_controller.dart';
import 'package:homeassistant_flutter/features/connection/application/connection_session_controller.dart';
import 'package:homeassistant_flutter/features/connection/application/connection_setup_providers.dart';
import 'package:homeassistant_flutter/features/connection/data/credential_validator.dart';
import 'package:homeassistant_flutter/features/connection/domain/connection_credentials.dart';

import '../fakes/fake_credential_store.dart';
import '../fakes/fake_credential_validator.dart';

void main() {
  ProviderContainer makeContainer({
    required CredentialValidationResult validationResult,
    FakeCredentialStore? store,
  }) {
    final container = ProviderContainer(
      overrides: [
        credentialStoreProvider.overrideWithValue(
          store ?? FakeCredentialStore(),
        ),
        credentialValidatorProvider.overrideWithValue(
          FakeCredentialValidator(validationResult),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('ConnectionFormController.submit', () {
    test('rejects an invalid URL without validating or saving', () async {
      final store = FakeCredentialStore();
      final container = makeContainer(
        validationResult: const CredentialValidationSuccess(),
        store: store,
      );
      await container.read(connectionSessionProvider.future);

      final ok = await container
          .read(connectionFormControllerProvider.notifier)
          .submit(serverUrl: 'not a url', accessToken: 'token');

      expect(ok, isFalse);
      final state = container.read(connectionFormControllerProvider);
      expect(state.status, ConnectionFormStatus.error);
      expect(state.errorMessage, isNotNull);
      expect(store.writes, isEmpty);
    });

    test('rejects an empty token without saving', () async {
      final store = FakeCredentialStore();
      final container = makeContainer(
        validationResult: const CredentialValidationSuccess(),
        store: store,
      );
      await container.read(connectionSessionProvider.future);

      final ok = await container
          .read(connectionFormControllerProvider.notifier)
          .submit(serverUrl: 'https://ha.example.com', accessToken: '   ');

      expect(ok, isFalse);
      expect(store.writes, isEmpty);
    });

    test(
      'surfaces the validation error and does not save on a bad token',
      () async {
        final store = FakeCredentialStore();
        final container = makeContainer(
          validationResult: const CredentialValidationFailure(
            'Invalid access token',
            isAuth: true,
          ),
          store: store,
        );
        await container.read(connectionSessionProvider.future);

        final ok = await container
            .read(connectionFormControllerProvider.notifier)
            .submit(serverUrl: 'https://ha.example.com', accessToken: 'bad');

        expect(ok, isFalse);
        final state = container.read(connectionFormControllerProvider);
        expect(state.status, ConnectionFormStatus.error);
        expect(state.errorMessage, 'Invalid access token');
        expect(store.writes, isEmpty);
      },
    );

    test('saves the credentials and updates the session on success', () async {
      final store = FakeCredentialStore();
      final container = makeContainer(
        validationResult: const CredentialValidationSuccess(),
        store: store,
      );
      await container.read(connectionSessionProvider.future);

      final ok = await container
          .read(connectionFormControllerProvider.notifier)
          .submit(serverUrl: 'https://ha.example.com', accessToken: 'token');

      expect(ok, isTrue);
      expect(
        container.read(connectionFormControllerProvider).status,
        ConnectionFormStatus.success,
      );
      expect(store.writes, [
        const ConnectionCredentials(
          serverUrl: 'https://ha.example.com',
          accessToken: 'token',
        ),
      ]);
      expect(
        container.read(connectionSessionProvider).value,
        const ConnectionCredentials(
          serverUrl: 'https://ha.example.com',
          accessToken: 'token',
        ),
      );
    });
  });
}
