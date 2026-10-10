import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viralforge_experiment/api/api_client.dart';
import 'package:viralforge_experiment/widgets/video_drop_area.dart';

import 'support.dart';

Future<void> pick(WidgetTester tester, String name, int size) async {
  tester.widget<VideoDropArea>(find.byType(VideoDropArea)).onPicked(PickedVideo(name, fakeBytes(size)));
  await tester.pump();
}

Future<void> fillForm(WidgetTester tester) async {
  // Niche and audience are prefilled from the project; make sure they are present.
  final fields = find.byType(TextFormField);
  await tester.enterText(fields.at(0), 'Budget cooking');
  await tester.enterText(fields.at(1), 'Students');
}

Future<void> openNew(WidgetTester tester, FakeApi api) async {
  await pumpApp(tester, auth: FakeAuth(), api: api, location: '/projects/p1/new');
}

void main() {
  testWidgets('shows the upload area with limits', (tester) async {
    final api = FakeApi()..projects = [sampleProject()];
    await openNew(tester, api);
    expect(find.text('Drop a video here'), findsOneWidget);
    expect(find.textContaining('50 MB'), findsOneWidget);
    expect(find.text('Upload and analyse'), findsOneWidget);
  });

  testWidgets('rejects unsupported and oversized files before uploading', (tester) async {
    final api = FakeApi()..projects = [sampleProject()];
    await openNew(tester, api);
    await pick(tester, 'notes.pdf', 1000);
    expect(find.textContaining('Unsupported file type'), findsOneWidget);
    expect(find.text('Drop a video here'), findsOneWidget);
    await pick(tester, 'big.mp4', 60 * 1024 * 1024);
    expect(find.textContaining('The limit is 50 MB'), findsOneWidget);
    expect(api.uploads, isEmpty);
  });

  testWidgets('asks for a video before starting', (tester) async {
    final api = FakeApi()..projects = [sampleProject()];
    await openNew(tester, api);
    await fillForm(tester);
    await tester.tap(find.text('Upload and analyse'));
    await tester.pump();
    expect(find.text('Choose a video to analyse first.'), findsOneWidget);
    expect(api.createdAnalyses, isEmpty);
  });

  testWidgets('uploads, starts the analysis and opens its status page', (tester) async {
    final api = FakeApi()..projects = [sampleProject()];
    await openNew(tester, api);
    await pick(tester, 'recipe.mp4', 4096);
    expect(find.text('recipe.mp4'), findsOneWidget);
    await fillForm(tester);
    await tester.tap(find.text('Upload and analyse'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(api.uploads, ['recipe.mp4']);
    expect(api.createdAnalyses.single['video_id'], 'v-1');
    expect(api.createdAnalyses.single['platform'], 'tiktok');
    expect(api.createdAnalyses.single['input_type'], 'video');
    expect(find.text('Your analysis is queued'), findsOneWidget);
    await tester.pumpWidget(const SizedBox()); // dispose: cancels the polling timer
  });

  testWidgets('server rejection keeps the user on the form with the reason', (tester) async {
    final api = FakeApi()
      ..projects = [sampleProject()]
      ..uploadError = const ApiException(422, 'video_too_long', 'The video must be 90 seconds or shorter (yours is 120s).');
    await openNew(tester, api);
    await pick(tester, 'long.mp4', 4096);
    await fillForm(tester);
    await tester.tap(find.text('Upload and analyse'));
    await tester.pumpAndSettle();
    expect(find.textContaining('90 seconds or shorter'), findsWidgets);
    expect(find.text('Drop a video here'), findsOneWidget);
    expect(api.createdAnalyses, isEmpty);
  });

  testWidgets('a failed start after upload retries without uploading twice', (tester) async {
    final api = FakeApi()
      ..projects = [sampleProject()]
      ..createAnalysisError = const ApiException(503, 'model_unavailable', "Model 'x' is not available for this API key.");
    await openNew(tester, api);
    await pick(tester, 'recipe.mp4', 4096);
    await fillForm(tester);
    await tester.tap(find.text('Upload and analyse'));
    await tester.pumpAndSettle();
    expect(find.textContaining('not available'), findsOneWidget);
    expect(api.uploads.length, 1);

    await tester.tap(find.text('Start analysis'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(api.uploads.length, 1);
    expect(api.createdAnalyses.length, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('script mode validates length and sends script text', (tester) async {
    final api = FakeApi()..projects = [sampleProject()];
    await openNew(tester, api);
    await tester.tap(find.text('Script only'));
    await tester.pumpAndSettle();
    expect(find.byType(VideoDropArea), findsNothing);
    await tester.tap(find.text('Analyse script'));
    await tester.pump();
    expect(find.text('Write at least 20 characters.'), findsOneWidget);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Scene one: a surprising hook about saving money on groceries.');
    await tester.enterText(fields.at(1), 'Budget cooking');
    await tester.enterText(fields.at(2), 'Students');
    await tester.tap(find.text('Analyse script'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(api.createdAnalyses.single['input_type'], 'script');
    expect(api.createdAnalyses.single.containsKey('video_id'), isFalse);
    expect(api.uploads, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });
}
