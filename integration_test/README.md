# `integration_test/`

End-to-end / integration tests, as required by [`AGENTS.md`](../AGENTS.md).

While `test/` holds **unit** tests (isolated logic, mocked
dependencies/transport), this directory holds **integration** tests that
exercise a feature top to bottom — a full screen or flow against a real or faked
Home Assistant server.

Run them with:

```bash
fvm flutter test integration_test
```

Add one file per flow, named after the flow under test (e.g.
`connection_flow_test.dart`). This folder is intentionally a placeholder until
the first real feature lands a flow worth covering end to end.
