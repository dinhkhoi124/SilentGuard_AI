import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/router/auth_notifier.dart';
import 'package:mobile/injection_container.dart';
import 'package:mobile/main.dart';

void main() {
  setUpAll(init);

  setUp(() {
    sl<AuthNotifier>().logout();
  });

  testWidgets('đăng ký bằng tài khoản mẫu và mở trang chủ', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('Bắt đầu nào!'), findsOneWidget);

    final welcomeSignUp = find.text('Đăng ký').first;
    await tester.ensureVisible(welcomeSignUp);
    await tester.tap(welcomeSignUp);
    await tester.pumpAndSettle();

    expect(find.text('Tham gia Smartify'), findsOneWidget);

    await tester.enterText(find.byType(EditableText).first, 'wrong@email.com');
    await tester.enterText(find.byType(EditableText).last, 'wrong');
    final signUpButton = find.text('Đăng ký').last;
    await tester.ensureVisible(signUpButton);
    await tester.tap(signUpButton);
    await tester.pump();

    expect(
      find.text('Tài khoản không đúng. Dùng: user@smartify.vn / 123456'),
      findsOneWidget,
    );

    await tester.enterText(find.byType(EditableText).first, 'user@smartify.vn');
    await tester.enterText(find.byType(EditableText).last, '123456');
    await tester.tap(signUpButton);
    await tester.pumpAndSettle();

    expect(find.text('Nhà của tôi'), findsOneWidget);
    expect(find.text('Chưa có thiết bị'), findsOneWidget);
  });

  testWidgets('đăng nhập sau khi hiển thị hộp thoại tải', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    final welcomeSignIn = find.text('Đăng nhập');
    await tester.ensureVisible(welcomeSignIn);
    await tester.tap(welcomeSignIn);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(EditableText).first, 'user@smartify.vn');
    await tester.enterText(find.byType(EditableText).last, '123456');
    final signInButton = find.text('Đăng nhập');
    await tester.ensureVisible(signInButton);
    await tester.tap(signInButton);
    await tester.pump();

    expect(find.text('Đang đăng nhập...'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.text('Nhà của tôi'), findsOneWidget);
  });

  testWidgets('thêm và xóa camera trực tiếp trên trang chủ', (tester) async {
    sl<AuthNotifier>().login();
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('Chưa có thiết bị'), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton).last);
    await tester.pumpAndSettle();

    expect(find.text('CAMERA PHÒNG KHÁCH'), findsOneWidget);
    expect(find.text('CAMERA PHÒNG NGỦ'), findsNothing);

    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xóa thiết bị'));
    await tester.pumpAndSettle();

    expect(
      find.text('Bạn có chắc muốn xóa "CAMERA PHÒNG KHÁCH" không?'),
      findsOneWidget,
    );
    await tester.tap(find.text('Xóa'));
    await tester.pumpAndSettle();

    expect(find.text('CAMERA PHÒNG KHÁCH'), findsNothing);
    expect(find.text('Chưa có thiết bị'), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton).last);
    await tester.pumpAndSettle();
    expect(find.text('CAMERA PHÒNG KHÁCH'), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton).last);
    await tester.pumpAndSettle();
    expect(find.text('CAMERA PHÒNG KHÁCH'), findsOneWidget);
    expect(find.text('CAMERA PHÒNG NGỦ'), findsOneWidget);
  });
}
