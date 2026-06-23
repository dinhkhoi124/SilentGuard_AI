import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/domain/entities/app_user.dart';

void main() {
  test('AppUser exposes Firebase Auth profile fields', () {
    const user = AppUser(
      uid: 'uid-1',
      email: 'user@SlientGuard.vn',
      displayName: 'SlientGuard User',
      photoUrl: 'https://example.com/avatar.png',
    );

    expect(user.uid, 'uid-1');
    expect(user.email, 'user@SlientGuard.vn');
    expect(user.displayName, 'SlientGuard User');
    expect(user.photoUrl, 'https://example.com/avatar.png');
  });
}
