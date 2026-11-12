import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jolom/core/di/injection.dart';
import 'package:jolom/core/domain/entities/user_entity.dart';
import 'package:jolom/core/providers/shared_preferences_provider.dart';
import 'package:jolom/features/auth/domain/repositories/auth_repository.dart';
import 'package:jolom/features/auth/presentation/screens/login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late _FakeAuthRepository auth;
  late SharedPreferences preferences;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    auth = _FakeAuthRepository();
    await getIt.reset();
    getIt.registerSingleton<AuthRepository>(auth);
  });

  tearDown(() => getIt.reset());

  testWidgets('explica el acceso unificado sin mostrar contraseña', (
    tester,
  ) async {
    await tester.pumpWidget(_testApp(preferences));

    expect(find.text('Accede o crea tu cuenta'), findsOneWidget);
    expect(find.text('Continuar con correo'), findsOneWidget);
    expect(find.text('Continuar con Google'), findsOneWidget);
    expect(
      find.text('¿Ya tienes una cuenta con contraseña? Iniciar sesión'),
      findsOneWidget,
    );
    expect(find.text('Contraseña'), findsNothing);
    expect(find.text('Crear cuenta'), findsNothing);
  });

  testWidgets('muestra contraseña solo al solicitar el acceso existente', (
    tester,
  ) async {
    await tester.pumpWidget(_testApp(preferences));

    final passwordAccess = find.text(
      '¿Ya tienes una cuenta con contraseña? Iniciar sesión',
    );
    await tester.ensureVisible(passwordAccess);
    await tester.pumpAndSettle();
    await tester.tap(passwordAccess);
    await tester.pumpAndSettle();

    expect(find.text('Contraseña'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.text('Crear cuenta'), findsNothing);
    expect(find.text('Volver al acceso por vínculo'), findsOneWidget);
  });

  testWidgets('confirma claramente que el vínculo fue enviado', (tester) async {
    await tester.pumpWidget(_testApp(preferences));

    final termsCheckbox = find.byType(Checkbox);
    await tester.ensureVisible(termsCheckbox);
    await tester.pumpAndSettle();
    await tester.tap(termsCheckbox);
    await tester.enterText(find.byType(TextField), 'persona@ejemplo.com');
    final continueWithEmail = find.text('Continuar con correo');
    await tester.ensureVisible(continueWithEmail);
    await tester.pumpAndSettle();
    await tester.tap(continueWithEmail);
    await tester.pumpAndSettle();

    expect(auth.sentTo, 'persona@ejemplo.com');
    expect(find.text('Revisa tu correo'), findsOneWidget);
    expect(find.textContaining('persona@ejemplo.com'), findsOneWidget);
    expect(find.byType(Checkbox), findsNothing);
    expect(find.textContaining('Acepto los'), findsNothing);
    expect(
      find.textContaining('Revisa las carpetas de Spam o Correo no deseado'),
      findsOneWidget,
    );
    expect(find.text('Usar otro correo'), findsOneWidget);
  });

  testWidgets('la X lleva al inicio aunque exista una ruta anterior', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/origen',
      routes: [
        GoRoute(
          path: '/origen',
          builder: (context, state) => const Scaffold(body: Text('Origen')),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/home',
          builder: (context, state) => const Scaffold(body: Text('Inicio')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    router.push('/login');
    await tester.pumpAndSettle();

    expect(find.text('Accede o crea tu cuenta'), findsOneWidget);
    await tester.tap(find.byTooltip('Cerrar'));
    await tester.pumpAndSettle();

    expect(find.text('Inicio'), findsOneWidget);
    expect(find.text('Origen'), findsNothing);
  });
}

Widget _testApp(SharedPreferences preferences) {
  final router = GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/home',
        builder: (context, state) => const Scaffold(body: Text('Inicio')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
    child: MaterialApp.router(routerConfig: router),
  );
}

class _FakeAuthRepository implements AuthRepository {
  String? sentTo;

  @override
  UserEntity? get currentUser => null;

  @override
  Stream<UserEntity?> authStateChanges() => Stream.value(null);

  @override
  Future<void> sendEmailSignInLink(String email) async {
    sentTo = email;
  }

  @override
  bool isEmailSignInLink(String emailLink) => true;

  @override
  Future<UserEntity> signInWithEmailLink({
    required String email,
    required String emailLink,
  }) async => UserEntity(id: 'uid', email: email);

  @override
  Future<UserEntity> signInWithEmailPassword({
    required String email,
    required String password,
  }) async => UserEntity(id: 'password', email: email);

  @override
  Future<UserEntity> signInWithGoogle() async => const UserEntity(id: 'google');

  @override
  Future<UserEntity> signInWithApple() async => const UserEntity(id: 'apple');

  @override
  Future<void> signOut() async {}

  @override
  Future<void> updateDisplayName(String displayName) async {}

  @override
  Future<UserEntity?> fetchUserProfile(String uid) async => null;

  @override
  Stream<UserEntity?> watchUserProfile(String uid) => Stream.value(null);
}
