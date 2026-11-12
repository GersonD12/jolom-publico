import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jolom/core/di/injection.dart';
import 'package:jolom/core/errors/user_facing_error.dart';
import 'package:jolom/core/providers/feature_providers.dart';
import 'package:jolom/core/providers/session_provider.dart';
import 'package:jolom/core/providers/shared_preferences_provider.dart';
import 'package:jolom/features/auth/domain/repositories/auth_repository.dart';
import 'package:jolom/features/auth/presentation/email_link_auth_state.dart';
import 'package:url_launcher/url_launcher.dart';

/// Acceso unificado: vínculo por correo, Google y Apple solo en iOS.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  static const _siteUrl = String.fromEnvironment(
    'JOLOM_SITE_URL',
    defaultValue: 'https://jolom.example',
  );
  static const _termsUrl = '$_siteUrl/terminos';
  static const _privacyUrl = '$_siteUrl/privacidad';

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  late final TapGestureRecognizer _termsRecognizer;
  late final TapGestureRecognizer _privacyRecognizer;
  bool _isLoading = false;
  bool _acceptedTerms = false;
  bool _emailLinkSent = false;
  bool _usePassword = false;
  String? _errorMessage;
  bool _didNavigateAfterAuth = false;

  bool get _supportsAppleSignIn => !kIsWeb && Platform.isIOS;

  @override
  void initState() {
    super.initState();
    _termsRecognizer = TapGestureRecognizer()
      ..onTap = () => _openUrl(_termsUrl);
    _privacyRecognizer = TapGestureRecognizer()
      ..onTap = () => _openUrl(_privacyUrl);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _termsRecognizer.dispose();
    _privacyRecognizer.dispose();
    super.dispose();
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Silencioso: el usuario puede reintentar tocando el enlace.
    }
  }

  /// Valida aceptación de términos antes de crear cuenta o usar proveedores.
  bool _ensureTermsAccepted() {
    if (_acceptedTerms) return true;
    const message = 'Debes aceptar los términos y condiciones para continuar.';
    setState(() {
      _errorMessage = message;
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text(message)));
    return false;
  }

  Future<void> _runAuth(Future<void> Function() action) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await action();
      if (mounted) _navigateAfterAuth();
    } catch (error) {
      setState(() {
        _errorMessage = userFacingError(error);
      });
    } finally {
      // Evitar setState si ya se hizo go (el route se está desmontando).
      // Si el perfil aún hidrata, mantener el spinner hasta el redirect.
      if (mounted && !_didNavigateAfterAuth) {
        final stillHydrating =
            ref.read(appAccessStatusProvider) == AppAccessStatus.loading;
        if (!stillHydrating) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  /// Sale de /login con [go] para limpiar el push encima del shell.
  /// Si el perfil aún hidrata, deja que el redirect de GoRouter lo haga.
  void _navigateAfterAuth() {
    if (_didNavigateAfterAuth || !mounted) return;

    final accessStatus = ref.read(appAccessStatusProvider);
    if (accessStatus == AppAccessStatus.loading) {
      debugPrint('[auth-nav] post-login diferido (perfil hidratando)');
      return;
    }

    _didNavigateAfterAuth = true;

    final pending = ref.read(pendingBookingProvider);
    if (pending != null) {
      debugPrint('[auth-nav] post-login → /appointments (pending booking)');
      context.go('/appointments');
      return;
    }

    final from = GoRouterState.of(context).uri.queryParameters['from'];
    if (from != null && from.isNotEmpty) {
      final decoded = Uri.decodeComponent(from);
      if (decoded.startsWith('/') &&
          decoded != '/login' &&
          !decoded.startsWith('/login?') &&
          decoded != '/splash') {
        debugPrint('[auth-nav] post-login → $decoded (from query)');
        context.go(decoded);
        return;
      }
    }

    debugPrint('[auth-nav] post-login → /home (fallback)');
    context.go('/home');
  }

  Future<void> _sendEmailLink() async {
    if (!_ensureTermsAccepted()) return;
    final email = _emailController.text.trim();
    if (!isValidEmailAddress(email)) {
      setState(() {
        _errorMessage = 'Ingresa un correo electrónico válido.';
      });
      return;
    }

    final auth = getIt<AuthRepository>();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await auth.sendEmailSignInLink(email);
      await ref
          .read(sharedPreferencesProvider)
          .setString(pendingEmailLinkAddressKey, email);
      if (!mounted) return;
      setState(() {
        _emailLinkSent = true;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = userFacingError(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _signInWithPassword() async {
    final email = _emailController.text.trim();
    if (!isValidEmailAddress(email)) {
      setState(() {
        _errorMessage = 'Ingresa un correo electrónico válido.';
      });
      return;
    }
    if (_passwordController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Ingresa tu contraseña.';
      });
      return;
    }

    await _runAuth(
      () => getIt<AuthRepository>().signInWithEmailPassword(
        email: email,
        password: _passwordController.text,
      ),
    );
  }

  void _setPasswordMode(bool enabled) {
    setState(() {
      _usePassword = enabled;
      _errorMessage = null;
      if (!enabled) _passwordController.clear();
    });
  }

  Future<void> _signInWithGoogle() async {
    if (!_ensureTermsAccepted()) return;
    final auth = getIt<AuthRepository>();
    await _runAuth(auth.signInWithGoogle);
  }

  Future<void> _signInWithApple() async {
    if (!_ensureTermsAccepted()) return;
    final auth = getIt<AuthRepository>();
    await _runAuth(auth.signInWithApple);
  }

  void _dismissLogin(BuildContext context) {
    // No usar pop: después de cerrar/eliminar la cuenta puede quedar una ruta
    // privada debajo de /login. Volver a ella activa el redirect de sesión y
    // muestra /login otra vez, haciendo que la X parezca no responder.
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    // Respaldo si la sesión llega por el stream antes/después de _runAuth.
    ref.listen(sessionProvider, (prev, next) {
      final loggedIn = next.asData?.value != null;
      final wasLoggedOut = prev?.asData?.value == null;
      if (loggedIn && wasLoggedOut) {
        _navigateAfterAuth();
      }
    });

    final theme = Theme.of(context);
    final linkStyle = TextStyle(
      color: theme.colorScheme.primary,
      decoration: TextDecoration.underline,
    );

    final pillShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(28),
    );
    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(28),
      borderSide: BorderSide.none,
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leadingWidth: 72,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: IconButton(
            tooltip: 'Cerrar',
            icon: const Icon(Icons.close, size: 32),
            onPressed: () => _dismissLogin(context),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Jolom',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.displaySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -2,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Accede o crea tu cuenta',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Reserva tu turno en pocos segundos.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 36),
                  if (_emailLinkSent)
                    _EmailLinkSentCard(
                      email: _emailController.text.trim(),
                      isLoading: _isLoading,
                      onResend: _sendEmailLink,
                      onChangeEmail: () {
                        setState(() {
                          _emailLinkSent = false;
                          _errorMessage = null;
                        });
                      },
                    )
                  else ...[
                    if (_supportsAppleSignIn) ...[
                      FilledButton.icon(
                        onPressed: _isLoading ? null : _signInWithApple,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(58),
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.black45,
                          shape: pillShape,
                        ),
                        icon: const Icon(Icons.apple, size: 27),
                        label: const Text('Continuar con Apple'),
                      ),
                      const SizedBox(height: 12),
                    ],
                    OutlinedButton.icon(
                      onPressed: _isLoading ? null : _signInWithGoogle,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(58),
                        foregroundColor: theme.colorScheme.onSurface,
                        side: BorderSide(
                          color: theme.colorScheme.outline,
                          width: 1.5,
                        ),
                        shape: pillShape,
                      ),
                      icon: const _GoogleGIcon(size: 22),
                      label: const Text('Continuar con Google'),
                    ),
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Text(
                            'o continúa con tu correo',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _emailController,
                      enabled: !_isLoading,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: _usePassword
                          ? TextInputAction.next
                          : TextInputAction.done,
                      autofillHints: const [AutofillHints.email],
                      autocorrect: false,
                      onSubmitted: (_) {
                        if (_isLoading || _usePassword) return;
                        _sendEmailLink();
                      },
                      decoration: InputDecoration(
                        hintText: 'Correo electrónico',
                        prefixIcon: const Icon(Icons.mail_outline, size: 26),
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerHighest,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 19,
                        ),
                        border: fieldBorder,
                        enabledBorder: fieldBorder,
                        focusedBorder: fieldBorder.copyWith(
                          borderSide: BorderSide(
                            color: theme.colorScheme.primary,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    if (_usePassword) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _passwordController,
                        enabled: !_isLoading,
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        onSubmitted: (_) {
                          if (!_isLoading) _signInWithPassword();
                        },
                        decoration: InputDecoration(
                          hintText: 'Contraseña',
                          prefixIcon: const Icon(Icons.lock_outline, size: 26),
                          filled: true,
                          fillColor: theme.colorScheme.surfaceContainerHighest,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 19,
                          ),
                          border: fieldBorder,
                          enabledBorder: fieldBorder,
                          focusedBorder: fieldBorder.copyWith(
                            borderSide: BorderSide(
                              color: theme.colorScheme.primary,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: _isLoading
                          ? null
                          : _usePassword
                          ? _signInWithPassword
                          : _sendEmailLink,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(58),
                        shape: pillShape,
                      ),
                      icon: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              _usePassword ? Icons.login : Icons.arrow_forward,
                            ),
                      label: Text(
                        _usePassword
                            ? 'Iniciar sesión'
                            : 'Continuar con correo',
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _usePassword
                          ? 'Solo para cuentas que ya tienen contraseña.'
                          : 'Te enviaremos un vínculo seguro. '
                                'No necesitas contraseña.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : () => _setPasswordMode(!_usePassword),
                      child: Text(
                        _usePassword
                            ? 'Volver al acceso por vínculo'
                            : '¿Ya tienes una cuenta con contraseña? '
                                  'Iniciar sesión',
                        textAlign: TextAlign.center,
                      ),
                    ),
                    if (!_usePassword) ...[
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 28,
                            height: 28,
                            child: Checkbox(
                              value: _acceptedTerms,
                              onChanged: _isLoading
                                  ? null
                                  : (value) {
                                      setState(() {
                                        _acceptedTerms = value ?? false;
                                        if (_acceptedTerms) {
                                          _errorMessage = null;
                                        }
                                      });
                                    },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text.rich(
                              TextSpan(
                                style: theme.textTheme.bodySmall?.copyWith(
                                  height: 1.45,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                children: [
                                  const TextSpan(text: 'Acepto los '),
                                  TextSpan(
                                    text: 'términos y condiciones',
                                    style: linkStyle,
                                    recognizer: _termsRecognizer,
                                  ),
                                  const TextSpan(text: ' y la '),
                                  TextSpan(
                                    text: 'política de privacidad',
                                    style: linkStyle,
                                    recognizer: _privacyRecognizer,
                                  ),
                                  const TextSpan(text: '.'),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmailLinkSentCard extends StatelessWidget {
  const _EmailLinkSentCard({
    required this.email,
    required this.isLoading,
    required this.onResend,
    required this.onChangeEmail,
  });

  final String email;
  final bool isLoading;
  final VoidCallback onResend;
  final VoidCallback onChangeEmail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              Icons.mark_email_read_outlined,
              size: 42,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text('Revisa tu correo', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Enviamos un vínculo seguro a\n$email',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Ábrelo en este dispositivo para acceder a Jolom.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '¿No encuentras el mensaje? Revisa las carpetas de '
                      'Spam o Correo no deseado.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: isLoading ? null : onResend,
              child: Text(isLoading ? 'Enviando…' : 'Reenviar vínculo'),
            ),
            TextButton(
              onPressed: isLoading ? null : onChangeEmail,
              child: const Text('Usar otro correo'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Icono de la "G" de Google con colores de marca.
class _GoogleGIcon extends StatelessWidget {
  const _GoogleGIcon({this.size = 18});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GoogleGPainter()),
    );
  }
}

class _GoogleGPainter extends CustomPainter {
  static const _blue = Color(0xFF4285F4);
  static const _green = Color(0xFF34A853);
  static const _yellow = Color(0xFFFBBC05);
  static const _red = Color(0xFFEA4335);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final strokeWidth = size.width * 0.18;
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    // Arcos de la G (colores oficiales de Google).
    paint.color = _blue;
    canvas.drawArc(rect, -0.55, 1.85, false, paint);
    paint.color = _green;
    canvas.drawArc(rect, 1.3, 1.1, false, paint);
    paint.color = _yellow;
    canvas.drawArc(rect, 2.4, 0.85, false, paint);
    paint.color = _red;
    canvas.drawArc(rect, 3.25, 1.15, false, paint);

    // Barra horizontal derecha de la G.
    final barPaint = Paint()
      ..color = _blue
      ..style = PaintingStyle.fill;
    final barHeight = strokeWidth;
    final barTop = center.dy - barHeight / 2;
    canvas.drawRect(
      Rect.fromLTWH(
        center.dx - strokeWidth * 0.15,
        barTop,
        radius + strokeWidth * 0.5,
        barHeight,
      ),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
