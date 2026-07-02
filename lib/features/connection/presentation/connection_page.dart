import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/connection_form_controller.dart';
import '../domain/server_url.dart';
import 'oauth_login_page.dart';

/// First-run screen where the user points the app at their Home Assistant
/// instance. The primary path is **Log in**, which drives the user through
/// HA's hosted OAuth2 authorize page in an embedded WebView
/// ([OAuthLoginPage]) — no token to find or copy. The manual long-lived-token
/// form (the only option before this feature) remains available as a
/// collapsed "Advanced" section, since some reverse-proxy setups make OAuth
/// redirects impractical.
///
/// Submitting the advanced form validates the credentials against the live
/// instance (a real WebSocket `auth` handshake) before saving — invalid input
/// shows an inline error and is never persisted. Logic lives in
/// [ConnectionFormController]; this widget only collects input and reflects
/// state.
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
  bool _advancedExpanded = false;

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

  Future<void> _logIn() async {
    if (!ServerUrl.isValid(_urlController.text)) {
      // Reuse the URL field's own validator for inline feedback. Only that
      // one field is registered with the Form while the advanced section is
      // collapsed, so this can't accidentally surface the token field's
      // "required" error too.
      _formKey.currentState?.validate();
      return;
    }
    FocusScope.of(context).unfocus();
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => OAuthLoginPage(serverUrl: _urlController.text),
      ),
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
                      'Enter your instance address, then log in with your '
                      'Home Assistant account.',
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
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      key: const Key('oauth_login_button'),
                      onPressed: isSubmitting ? null : _logIn,
                      icon: const Icon(Icons.login),
                      label: const Text('Log in'),
                    ),
                    const SizedBox(height: 8),
                    _AdvancedTokenSection(
                      expanded: _advancedExpanded,
                      onExpansionChanged: (expanded) =>
                          setState(() => _advancedExpanded = expanded),
                      tokenController: _tokenController,
                      obscureToken: _obscureToken,
                      onToggleObscure: () =>
                          setState(() => _obscureToken = !_obscureToken),
                      isSubmitting: isSubmitting,
                      errorMessage: errorMessage,
                      onSubmit: _submit,
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

/// Collapsed-by-default section holding the manual long-lived-token form —
/// the fallback path for setups (e.g. some reverse proxies) where the OAuth2
/// redirect can't be intercepted.
class _AdvancedTokenSection extends StatelessWidget {
  const _AdvancedTokenSection({
    required this.expanded,
    required this.onExpansionChanged,
    required this.tokenController,
    required this.obscureToken,
    required this.onToggleObscure,
    required this.isSubmitting,
    required this.errorMessage,
    required this.onSubmit,
  });

  final bool expanded;
  final ValueChanged<bool> onExpansionChanged;
  final TextEditingController tokenController;
  final bool obscureToken;
  final VoidCallback onToggleObscure;
  final bool isSubmitting;
  final String? errorMessage;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      // ExpansionTile draws its own divider lines by default; drop them so it
      // sits quietly under the primary "Log in" button.
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        key: const Key('advanced_token_section'),
        initiallyExpanded: expanded,
        onExpansionChanged: onExpansionChanged,
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(top: 16),
        title: Text(
          'Advanced: use a long-lived access token instead',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                key: const Key('connection_token_field'),
                controller: tokenController,
                enabled: !isSubmitting,
                obscureText: obscureToken,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: 'Long-lived access token',
                  prefixIcon: const Icon(Icons.key),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    tooltip: obscureToken ? 'Show token' : 'Hide token',
                    icon: Icon(
                      obscureToken
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: onToggleObscure,
                  ),
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Enter a long-lived access token'
                    : null,
              ),
              if (errorMessage != null) ...[
                const SizedBox(height: 16),
                _ErrorBanner(message: errorMessage!),
              ],
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('connection_submit_button'),
                onPressed: isSubmitting ? null : onSubmit,
                child: isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Connect with token'),
              ),
            ],
          ),
        ],
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
