import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jolom/core/di/injection.dart';
import 'package:jolom/core/errors/user_facing_error.dart';
import 'package:jolom/core/providers/shared_preferences_provider.dart';
import 'package:jolom/features/auth/domain/repositories/auth_repository.dart';
import 'package:jolom/features/auth/presentation/email_link_auth_state.dart';

/// Completa el acceso cuando Firebase Hosting abre el vínculo en Jolom.
class EmailLinkCompletionScreen extends ConsumerStatefulWidget {
  const EmailLinkCompletionScreen({required this.emailLink, super.key});

  final String emailLink;

  @override
  ConsumerState<EmailLinkCompletionScreen> createState() =>
      _EmailLinkCompletionScreenState();
}

class _EmailLinkCompletionScreenState
    extends ConsumerState<EmailLinkCompletionScreen> {
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _needsEmailConfirmation = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepareLink());
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _prepareLink() async {
    final auth = getIt<AuthRepository>();
    if (!auth.isEmailSignInLink(widget.emailLink)) {
      setState(() {
        _errorMessage = 'Este vínculo no es válido o ya fue utilizado.';
      });
      return;
    }

    final preferences = ref.read(sharedPreferencesProvider);
    final pendingEmail = preferences.getString(pendingEmailLinkAddressKey);
    if (pendingEmail == null || pendingEmail.isEmpty) {
      setState(() {
        _needsEmailConfirmation = true;
      });
      return;
    }

    _emailController.text = pendingEmail;
    await _completeSignIn();
  }

  Future<void> _completeSignIn() async {
    final email = _emailController.text.trim();
    if (!isValidEmailAddress(email)) {
      setState(() {
        _errorMessage = 'Ingresa el correo al que enviamos el vínculo.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await getIt<AuthRepository>().signInWithEmailLink(
        email: email,
        emailLink: widget.emailLink,
      );
      await ref
          .read(sharedPreferencesProvider)
          .remove(pendingEmailLinkAddressKey);
      if (mounted) context.go('/home');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _needsEmailConfirmation = true;
        _errorMessage = userFacingError(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Cerrar',
          onPressed: () => context.go('/login'),
          icon: const Icon(Icons.close),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    _errorMessage == null
                        ? Icons.verified_user_outlined
                        : Icons.link_off,
                    size: 56,
                    color: _errorMessage == null
                        ? theme.colorScheme.primary
                        : theme.colorScheme.error,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _isLoading
                        ? 'Verificando tu correo…'
                        : 'Confirma tu acceso',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _needsEmailConfirmation
                        ? 'Por seguridad, escribe el correo al que enviamos '
                              'este vínculo.'
                        : 'Estamos comprobando el vínculo seguro de Jolom.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                  if (_isLoading) ...[
                    const SizedBox(height: 28),
                    const Center(child: CircularProgressIndicator()),
                  ],
                  if (_needsEmailConfirmation && !_isLoading) ...[
                    const SizedBox(height: 24),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.email],
                      autocorrect: false,
                      onSubmitted: (_) => _completeSignIn(),
                      decoration: const InputDecoration(
                        labelText: 'Correo electrónico',
                        prefixIcon: Icon(Icons.mail_outline),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _completeSignIn,
                      child: const Text('Verificar y continuar'),
                    ),
                  ],
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _isLoading ? null : () => context.go('/login'),
                    child: const Text('Solicitar un vínculo nuevo'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
