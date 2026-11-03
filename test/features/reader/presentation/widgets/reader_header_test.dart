import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_manga_reader/features/reader/presentation/widgets/reader_header.dart';

void main() {
  group('ReaderHeader Widget Tests', () {
    testWidgets('renders manga title and chapter title', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReaderHeader(
              mangaTitle: 'Solo Leveling',
              chapterTitle: 'Chapter 179',
              onBack: () {},
              onSettings: () {},
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Solo Leveling'), findsOneWidget);
      expect(find.text('Chapter 179'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    });

    testWidgets('triggers onBack when back button is pressed', (tester) async {
      bool backPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReaderHeader(
              mangaTitle: 'Tower of God',
              chapterTitle: 'Chapter 100',
              onBack: () => backPressed = true,
              onSettings: () {},
            ),
          ),
        ),
      );

      await tester.pump();

      await tester.tap(find.byIcon(Icons.arrow_back));
      expect(backPressed, isTrue);
    });

    testWidgets('triggers onSettings when settings button is pressed', (tester) async {
      bool settingsPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReaderHeader(
              mangaTitle: 'Omniscient Reader',
              chapterTitle: 'Chapter 50',
              onBack: () {},
              onSettings: () => settingsPressed = true,
            ),
          ),
        ),
      );

      await tester.pump();

      await tester.tap(find.byIcon(Icons.settings_outlined));
      expect(settingsPressed, isTrue);
    });

    testWidgets('triggers onChapterListTap when chapter info is clicked', (tester) async {
      bool chapterListTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReaderHeader(
              mangaTitle: 'The Beginning After The End',
              chapterTitle: 'Chapter 120',
              onBack: () {},
              onSettings: () {},
              onChapterListTap: () => chapterListTapped = true,
            ),
          ),
        ),
      );

      await tester.pump();

      await tester.tap(find.text('The Beginning After The End'));
      expect(chapterListTapped, isTrue);
    });

    testWidgets('triggers onToggleFullscreen and shows correct icon', (tester) async {
      bool fullscreenToggled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReaderHeader(
              mangaTitle: 'Nano Machine',
              chapterTitle: 'Chapter 10',
              onBack: () {},
              onSettings: () {},
              isFullscreen: false,
              onToggleFullscreen: () => fullscreenToggled = true,
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.byIcon(Icons.fullscreen_exit_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.fullscreen_exit_rounded));
      expect(fullscreenToggled, isTrue);

      // Re-render with isFullscreen: true
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReaderHeader(
              mangaTitle: 'Nano Machine',
              chapterTitle: 'Chapter 10',
              onBack: () {},
              onSettings: () {},
              isFullscreen: true,
              onToggleFullscreen: () {},
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.byIcon(Icons.fullscreen_rounded), findsOneWidget);
    });

    testWidgets('shows chapter list icon when onChapterListTap is provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReaderHeader(
              mangaTitle: 'Manga Title',
              chapterTitle: 'Chapter 1',
              onBack: () {},
              onSettings: () {},
              onChapterListTap: () {},
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.byIcon(Icons.format_list_bulleted_rounded), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);
    });

    testWidgets('hides keyboard shortcuts button on mobile screen width', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReaderHeader(
              mangaTitle: 'Manga Title',
              chapterTitle: 'Chapter 1',
              onBack: () {},
              onSettings: () {},
              onShowShortcuts: () {},
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.byIcon(Icons.keyboard_alt_outlined), findsNothing);
    });

    testWidgets('shows keyboard shortcuts button on desktop platform and desktop screen width', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ReaderHeader(
                mangaTitle: 'Manga Title',
                chapterTitle: 'Chapter 1',
                onBack: () {},
                onSettings: () {},
                onShowShortcuts: () {},
              ),
            ),
          ),
        );

        await tester.pump();

        expect(find.byIcon(Icons.keyboard_alt_outlined), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });
}
