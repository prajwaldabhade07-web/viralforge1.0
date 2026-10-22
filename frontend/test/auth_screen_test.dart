import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viralforge_experiment/api/auth_service.dart';
import 'package:viralforge_experiment/util/platform.dart';
import 'package:viralforge_experiment/widgets/login_scene.dart';

import 'support.dart';

/// The room starts dark; pull the cord to light it.
Future<void> light(WidgetTester tester) async {
  await tester.tap(find.byType(Lamp));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('signed-out users are sent to the sign-in scene', (tester) async {
    await pumpApp(tester, auth: FakeAuth(signedIn: false), api: FakeApi());
    expect(find.text('Sign in'), findsWidgets);
    expect(find.textContaining('Know how your video will land'), findsOneWidget);
    expect(find.text('Remember me'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);
    expect(find.text('PULL THE CORD TO SIGN IN'), findsOneWidget);
  });

  testWidgets('the form stays untouchable until the cord is pulled', (tester) async {
    final auth = FakeAuth(signedIn: false);
    await pumpApp(tester, auth: auth, api: FakeApi());
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'), warnIfMissed: false);
    await tester.pump();
    expect(find.text('Enter a valid email address.'), findsNothing);
    await light(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pump();
    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(auth.signInCalls, isEmpty);
  });

  testWidgets('invalid email and empty password are rejected before any request', (tester) async {
    final auth = FakeAuth(signedIn: false);
    await pumpApp(tester, auth: auth, api: FakeApi());
    await light(tester);
    await tester.enterText(find.byType(TextFormField).at(0), 'not-an-email');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pump();
    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(find.text('Enter your password.'), findsOneWidget);
    expect(auth.signInCalls, isEmpty);
  });

  testWidgets('successful sign-in opens the dashboard once onboarding is done', (tester) async {
    writePref('vf_onb_maya@example.com', '1');
    final auth = FakeAuth(signedIn: false);
    await pumpApp(tester, auth: auth, api: FakeApi());
    await light(tester);
    await tester.enterText(find.byType(TextFormField).at(0), '  maya@example.com ');
    await tester.enterText(find.byType(TextFormField).at(1), 'correct horse');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(auth.signInCalls.single, ['maya@example.com', 'correct horse']);
    expect(find.text('Drop a clip. Pip does the rest.'), findsOneWidget);
  });

  testWidgets('a first sign-in lands on the welcome questions', (tester) async {
    writePref('vf_onb_maya@example.com', '');
    final auth = FakeAuth(signedIn: false);
    await pumpApp(tester, auth: auth, api: FakeApi());
    await light(tester);
    await tester.enterText(find.byType(TextFormField).at(0), 'maya@example.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'correct horse');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('What should Pip call you?'), findsOneWidget);
  });

  testWidgets('failed sign-in shows the reason', (tester) async {
    final auth = FakeAuth(signedIn: false)..signInError = const AuthFailure('Email or password is incorrect.');
    await pumpApp(tester, auth: auth, api: FakeApi());
    await light(tester);
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
    await light(tester);
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

  testWidgets('the lamp switches the room off again without breaking the form', (tester) async {
    await pumpApp(tester, auth: FakeAuth(signedIn: false), api: FakeApi());
    await light(tester);
    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();
    await tester.tap(find.byType(Lamp));
    await tester.pumpAndSettle();
    expect(find.text('PULL THE CORD TO SIGN IN'), findsOneWidget);
    expect(find.text('Sign in'), findsWidgets);
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