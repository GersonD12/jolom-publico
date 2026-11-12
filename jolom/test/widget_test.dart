import 'package:flutter_test/flutter_test.dart';
import 'package:jolom/core/domain/entities/user_entity.dart';

void main() {
  test('UserEntity marca autenticado cuando tiene id', () {
    const user = UserEntity(id: 'uid-1', email: 'test@example.com');
    expect(user.isAuthenticated, isTrue);
    expect(user.isAnonymous, isFalse);
  });

  test('UserEntity bloquea cuentas en proceso de eliminación', () {
    final user = UserEntity.fromFirestoreMap('uid-2', {
      'accountStatus': 'deletionPending',
      'isBanned': false,
      'isDeleted': false,
    });

    expect(user.accountStatus, AccountStatus.deletionPending);
    expect(user.accountStatus.blocksAccess, isTrue);
  });

  test('AccountStatus legacy permanece activo', () {
    final user = UserEntity.fromFirestoreMap('uid-3', const {});

    expect(user.accountStatus, AccountStatus.active);
    expect(user.accountStatus.blocksAccess, isFalse);
  });

  test('UserEntity ignora el estado legado de suspensión', () {
    final user = UserEntity.fromFirestoreMap('uid-4', {
      'moderationStatus': 'suspended',
    });

    expect(user.isModerationBlocked, isFalse);
  });

  test('UserEntity bloquea una cuenta baneada', () {
    final user = UserEntity.fromFirestoreMap('uid-6', const {
      'moderationStatus': 'banned',
      'isBanned': true,
    });

    expect(user.isModerationBlocked, isTrue);
  });
}
