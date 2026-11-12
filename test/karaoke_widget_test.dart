// test/karaoke_widget_test.dart
//
// Runs under `flutter test` (CI): the words of a sentence light up as the
// voice reaches them, with IPA underneath, and a tapped word is spoken.
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ong_bi_english/core/services/speech_output.dart';
import 'package:ong_bi_english/curriculum/pron_lexicon.dart';
import 'package:ong_bi_english/widgets/spoken_text.dart';

void main() {
  testWidgets('words light up in time with Bi and show their IPA', (tester) async {
    final progress = ValueNotifier<SpeechProgress>(SpeechProgress.idle);
    final lexicon = ValueNotifier<PronLexicon>(
      PronLexicon(const ['apples\tˈæpəlz', 'i\taɪ', 'like\tlaɪk', 'red\trɛd']),
    );
    final tapped = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KaraokeText(
            'I like red apples.',
            progress: progress,
            lexicon: lexicon,
            showIpa: true,
            onWord: tapped.add,
          ),
        ),
      ),
    );

    KaraokeState stateOf(String word) =>
        tester.widget<KaraokeWord>(find.byWidgetPredicate((w) => w is KaraokeWord && w.word == word)).state;
    List<KaraokeState> all() => [for (final w in const ['I', 'like', 'red', 'apples.']) stateOf(w)];

    expect(all(), everyElement(KaraokeState.plain));
    expect(find.text('laɪk'), findsOneWidget);
    expect(find.text('ˈæpəlz'), findsOneWidget);

    // Halfway through the sentence: the first words are said, one is being said.
    progress.value = const SpeechProgress('I like red apples.', 0.5);
    await tester.pump();
    expect(all(), [KaraokeState.said, KaraokeState.said, KaraokeState.saying, KaraokeState.plain]);

    // Another sentence playing: nothing lights up here.
    progress.value = const SpeechProgress('Something else', 0.5);
    await tester.pump();
    expect(all(), everyElement(KaraokeState.plain));

    // Same words with other punctuation still match; at the end the last word is lit.
    progress.value = const SpeechProgress('i like red apples', 1.0);
    await tester.pump();
    expect(all(), [KaraokeState.said, KaraokeState.said, KaraokeState.said, KaraokeState.saying]);

    progress.value = SpeechProgress.idle;
    await tester.pump();
    expect(all(), everyElement(KaraokeState.plain));

    await tester.tap(find.text('apples.'));
    expect(tapped, ['apples']);
  });

  testWidgets('inside an answer card a tap on the words chooses the card', (tester) async {
    final words = <String>[];
    var chosen = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GestureDetector(
            onTap: () => chosen++,
            child: KaraokeText(
              'I want noodles.',
              progress: ValueNotifier<SpeechProgress>(SpeechProgress.idle),
              lexicon: ValueNotifier<PronLexicon>(PronLexicon.empty),
              showIpa: false,
              wordTaps: false,
              onWord: words.add,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('noodles.'));
    await tester.tap(find.text('I'));
    expect(chosen, 2);
    expect(words, isEmpty);
  });

  testWidgets('a curriculum word shows its own IPA line', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KaraokeText(
            'hello',
            ipa: '/həˈloʊ/',
            progress: ValueNotifier<SpeechProgress>(SpeechProgress.idle),
            lexicon: ValueNotifier<PronLexicon>(PronLexicon.empty),
            showIpa: true,
            onWord: (_) {},
          ),
        ),
      ),
    );
    expect(find.text('/həˈloʊ/'), findsOneWidget);
  });
}
