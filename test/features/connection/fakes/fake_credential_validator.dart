import 'package:homeassistant_flutter/features/connection/data/credential_validator.dart';
import 'package:homeassistant_flutter/features/connection/domain/ha_connection_config.dart';

/// [CredentialValidator] stub that returns a canned [result] and records the
/// configs it was asked to validate, so form/flow tests need no real socket.
class FakeCredentialValidator implements CredentialValidator {
  FakeCredentialValidator(this.result);

  CredentialValidationResult result;

  /// Configs passed to [validate], in order.
  final List<HaConnectionConfig> validated = [];

  @override
  Future<CredentialValidationResult> validate(HaConnectionConfig config) async {
    validated.add(config);
    return result;
  }
}
