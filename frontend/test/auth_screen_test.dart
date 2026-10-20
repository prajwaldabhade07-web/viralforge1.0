import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viralforge_experiment/api/auth_service.dart';

import 'support.dart';

void main() {
  testWidgets('signed-out users are sent to the sign-in screen', (tester) async {
    await pumpApp(tester, auth: FakeAuth(signedIn: false), api: FakeApi());
    expect(find.text('Sign in'), findsWidgets);
    expect(find.textContaining('Know how your video will land'), findsOneWidget);
  });

  testWidgets('invalid email and empty password are rejected before any request', (tester) async {
    final auth = FakeAuth(signedIn: false);
    await pumpApp(tester, auth: auth, api: FakeApi());
    await tester.enterText(find.byType(TextFormField).at(0), 'not-an-email');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pump();
    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(find.text('Enter your password.'), findsOneWidget);
    expect(auth.signInCalls, isEmpty);
  });

  testWidgets('successful sign-in opens the dashboard', (tester) async {
    final auth = FakeAuth(signedIn: false);
    await pumpApp(tester, auth: auth, api: FakeApi());
    await tester.enterText(find.byType(TextFormField).at(0), '  maya@example.com ');
    await tester.enterText(find.byType(TextFormField).at(1), 'correct horse');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(auth.signInCalls.single, ['maya@example.com', 'correct horse']);
    expect(find.text('Drop a clip. Pip does the rest.'), findsOneWidget);
  });

  testWidgets('failed sign-in shows the reason', (tester) async {
    final auth = FakeAuth(signedIn: false)..signInError = const AuthFailure('Email or password is incorrect.');
    await pumpApp(tester, auth: auth, api: FakeApi());
    await tester.enterText(find.byType(TextFormField).at(0), 'maya@example.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'wrongpass');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Email or password is incorrect.'), findsOneWidget);
    expect(find.text('Sign in'), findsWidgets);
  });

  testWidgets('registration enforces password length and explains email confirmation', (tester) async {
    final auth = FakeAuth(signedIn: false);
    await pumpApp(tester, auth: auth, api: FakeApi());
    await tester.tap(find.text('Create an account'));
    await tester.pump();
    await tester.enterText(find.byType(TextFormField).at(0), 'new@example.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'short');
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pump();
    expect(find.text('Use at least 8 characters.'), findsOneWidget);
    expect(auth.registerCalls, isEmpty);

    await tester.enterText(find.byType(TextFormField).at(1), 'long enough pw');
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();
    expect(auth.registerCalls.single, ['new@example.com', 'long enough pw']);
    expect(find.textContaining('Check your inbox'), findsOneWidget);
  });

  testWidgets('signing out from the account menu returns to the sign-in screen', (tester) async {
    final auth = FakeAuth();
    await pumpApp(tester, auth: auth, api: FakeApi());
    await tester.tap(find.byKey(const Key('account-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Know how your video will land'), findsOneWidget);
  });
}