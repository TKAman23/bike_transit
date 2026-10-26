import 'package:bike_transit/views/forgot_password.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('empty email shows validation feedback', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ForgotPasswordPage()));

    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();

    expect(find.text('Please enter your email address.'), findsOneWidget);
    expect(find.text('Please recheck your e-mail.'), findsOneWidget);
  });
}
