import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

void main() {
  testWidgets('empty state invites creating a project', (tester) async {
    await pumpApp(tester, auth: FakeAuth(), api: FakeApi());
    expect(find.text('No projects yet'), findsOneWidget);
    expect(find.text('Create your first project'), findsOneWidget);
  });

  testWidgets('lists projects with analysis counts and opens one', (tester) async {
    final api = FakeApi()..projects = [sampleProject(count: 2), sampleProject(id: 'p2', name: 'Gym clips', count: 1)];
    await pumpApp(tester, auth: FakeAuth(), api: api);
    expect(find.text('Spring recipes'), findsOneWidget);
    expect(find.text('2 analyses'), findsOneWidget);
    expect(find.text('1 analysis'), findsOneWidget);
    await tester.tap(find.text('Spring recipes'));
    await tester.pumpAndSettle();
    expect(find.text('New analysis'), findsOneWidget);
    expect(find.text('No analyses yet'), findsOneWidget);
  });

  testWidgets('creating a project requires a name, then opens the project', (tester) async {
    final api = FakeApi();
    await pumpApp(tester, auth: FakeAuth(), api: api);
    await tester.tap(find.text('New project').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Create project'));
    await tester.pump();
    expect(find.text('Give the project a name.'), findsOneWidget);
    expect(api.createdProjects, isEmpty);

    await tester.enterText(find.byType(TextFormField).first, 'Launch week');
    await tester.tap(find.widgetWithText(FilledButton, 'Create project'));
    await tester.pumpAndSettle();
    expect(api.createdProjects.single['name'], 'Launch week');
    expect(find.text('Launch week'), findsWidgets);
    expect(find.text('New analysis'), findsOneWidget);
  });

  testWidgets('deleting a project asks for confirmation first', (tester) async {
    final api = FakeApi()..projects = [sampleProject()];
    await pumpApp(tester, auth: FakeAuth(), api: api, location: '/projects/p1');
    await tester.tap(find.text('Options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete project'));
    await tester.pumpAndSettle();
    expect(find.textContaining('permanently deletes'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(api.deletedProjects, isEmpty);

    await tester.tap(find.text('Options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete project'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete project'));
    await tester.pumpAndSettle();
    expect(api.deletedProjects, ['p1']);
    expect(find.text('No projects yet'), findsOneWidget);
  });

  testWidgets('mobile layout uses bottom navigation', (tester) async {
    final api = FakeApi()..projects = [sampleProject()];
    await pumpApp(tester, auth: FakeAuth(), api: api, size: const Size(390, 844));
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Spring recipes'), findsOneWidget);
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(find.text('No analyses yet'), findsOneWidget);
  });
}
