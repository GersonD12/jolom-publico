import 'package:flutter_test/flutter_test.dart';
import 'package:jolom/features/app_update/domain/domain.dart';

void main() {
  const installed = InstalledAppVersion(version: '1.2.0');

  AppUpdatePolicy policy({bool enabled = true, String version = '1.2.0'}) {
    return AppUpdatePolicy(
      enabled: enabled,
      requiredVersion: version,
      storeUrl: 'https://example.com/store',
      releaseNotes: 'Mejoras',
    );
  }

  group('AppUpdatePolicy.requiresUpdate', () {
    test('no bloquea cuando la política está desactivada', () {
      expect(
        policy(enabled: false, version: '9.0.0').requiresUpdate(installed),
        isFalse,
      );
    });

    test('bloquea cuando la versión semántica instalada es menor', () {
      expect(policy(version: '1.3.0').requiresUpdate(installed), isTrue);
    });

    test('no bloquea cuando la versión instalada es mayor', () {
      expect(policy(version: '1.1.9').requiresUpdate(installed), isFalse);
    });

    test('no bloquea cuando las versiones coinciden', () {
      expect(policy().requiresUpdate(installed), isFalse);
    });

    test('normaliza segmentos faltantes y sufijos de versión', () {
      const withSuffix = InstalledAppVersion(version: '1.2.0+20');
      expect(policy(version: '1.2').requiresUpdate(withSuffix), isFalse);
    });

    test('una versión remota inválida no bloquea accidentalmente', () {
      expect(policy(version: 'vigente').requiresUpdate(installed), isFalse);
    });
  });
}
