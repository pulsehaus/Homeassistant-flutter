import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/connection_form_controller.dart';
import '../domain/server_url.dart';

/// First-run screen where the user points the app at their Home Assistant
/// instance: a server URL and a long-lived access token. Built on the shared
/// [AppPage] template so it inherits the app bar and surface treatment.
///
/// Submitting validates the credentials against the live instance (a real
/// WebSocket `auth` handshake) before saving — invalid input shows an inline
/// error and is never persisted. Logic lives in [ConnectionFormController]; this
/// widget only collects input and reflects state.
class ConnectionPage extends ConsumerStatefulWidget {
  const ConnectionPage({super.key});

  @override
  ConsumerState<ConnectionPage> createState() => _ConnectionPageState();
}

class _ConnectionPageState extends ConsumerState<ConnectionPage> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  final _tokenController = TextEditingController();
  bool _obscureToken = true;

  @override
  void dispose() {
    _urlController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // Run the synchronous field validators first for instant feedback.
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    await ref
        .read(connectionFormControllerProvider.notifier)
        .submit(
          serverUrl: _urlController.text,
          accessToken: _tokenController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formState = ref.watch(connectionFormControllerProvider);
    final isSubmitting = formState.isSubmitting;
    final errorMessage = formState.status == ConnectionFormStatus.error
        ? formState.errorMessage
        : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Connect to Home Assistant')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Enter your instance address and a long-lived access '
                      'token to get started.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      key: const Key('connection_url_field'),
                      controller: _urlController,
                      enabled: !isSubmitting,
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Server URL',
                        hintText: 'https://ha.example.com',
                        prefixIcon: Icon(Icons.link),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => ServerUrl.isValid(value ?? '')
                          ? null
                          : 'Enter a valid URL, e.g. https://ha.example.com',
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const Key('connection_token_field'),
                      controller: _tokenController,
                      enabled: !isSubmitting,
                      obscureText: _obscureToken,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: InputDecoration(
                        labelText: 'Long-lived access token',
                        prefixIcon: const Icon(Icons.key),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          tooltip: _obscureToken ? 'Show token' : 'Hide token',
                          icon: Icon(
                            _obscureToken
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () =>
                              setState(() => _obscureToken = !_obscureToken),
                        ),
                      ),
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                          ? 'Enter a long-lived access token'
                          : null,
                    ),
                    if (errorMessage != null) ...[
                      const SizedBox(height: 16),
                      _ErrorBanner(message: errorMessage),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      key: const Key('connection_submit_button'),
                      onPressed: isSubmitting ? null : _submit,
                      child: isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Connect'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Inline, themed banner that surfaces a validation/connection failure.
class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline,
            color: theme.colorScheme.onErrorContainer,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
