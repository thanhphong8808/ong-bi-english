// lib/widgets/spoken_text.dart
//
// English text the child reads while Bi speaks: each word changes colour as
// Bi says it (the word being said is white on purple, words already said turn
// purple), with its pronunciation (IPA) underneath. Tapping a word says it.
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../app/theme.dart';
import '../core/providers.dart';
import '../core/services/english_voice.dart';
import '../core/services/speech_output.dart';
import '../curriculum/karaoke.dart';
import '../curriculum/pron_lexicon.dart';

const Color _ipaColor = Color(0xFF7A6A55);

/// Colour of words already said, and background of the word being said.
const Color karaokeColor = AppColors.grape;

/// [KaraokeText] wired to Bi's voice, the dictionary and the parent settings.
class SpokenText extends ConsumerWidget {
  const SpokenText(
    this.text, {
    super.key,
    this.fontSize = 32,
    this.ipa,
    this.alignment = WrapAlignment.center,
    this.voice,
    this.showIpa,
  });

  final String text;
  final double fontSize;

  /// IPA of the whole text (a curriculum word), shown under it as one line
  /// instead of word by word.
  final String? ipa;
  final WrapAlignment alignment;

  /// Voice used when a word is tapped (defaults to the parent's choice).
  final EnglishVoice? voice;

  /// Overrides the parent setting (for example, off inside small cards).
  final bool? showIpa;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final services = ref.watch(appServicesProvider);
    final settings = ref.watch(parentSettingsProvider);
    return KaraokeText(
      text,
      progress: services.speech.progress,
      lexicon: services.pron.lexicon,
      showIpa: showIpa ?? settings.showIpa,
      fontSize: fontSize,
      ipa: ipa,
      alignment: alignment,
      onWord: (clean) =>
          services.speech.sayEn(clean, voice: voice ?? settings.voice, speed: settings.speechRate).catchError((Object _) {}),
    );
  }
}

/// The text itself; no providers, so widget tests can drive [progress].
class KaraokeText extends StatelessWidget {
  const KaraokeText(
    this.text, {
    super.key,
    required this.progress,
    required this.lexicon,
    required this.showIpa,
    required this.onWord,
    this.fontSize = 32,
    this.ipa,
    this.alignment = WrapAlignment.center,
  });

  final String text;
  final ValueListenable<SpeechProgress> progress;
  final ValueListenable<PronLexicon> lexicon;
  final bool showIpa;

  /// Called with a tapped English word, lower case, without punctuation.
  final void Function(String word) onWord;
  final double fontSize;
  final String? ipa;
  final WrapAlignment alignment;

  @override
  Widget build(BuildContext context) {
    final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final starts = wordStarts(words);
    final key = karaokeKey(text);
    final wholeIpa = ipa?.replaceAll('/', '').trim();

    void tapped(String word) {
      final clean = PronLexicon.clean(word);
      if (RegExp(r"^[a-z]+(?:'[a-z]+)?$").hasMatch(clean)) {
        onWord(clean);
      }
    }

    return ValueListenableBuilder<PronLexicon>(
      valueListenable: lexicon,
      builder: (context, lex, _) => ValueListenableBuilder<SpeechProgress>(
        valueListenable: progress,
        builder: (context, p, _) {
          final speaking = p.active && karaokeKey(p.text) == key;
          final reached = speaking ? wordsReached(starts, p.fraction) : 0;
          final wordCells = Wrap(
            alignment: alignment,
            spacing: fontSize * 0.28,
            runSpacing: fontSize * 0.18,
            children: [
              for (var i = 0; i < words.length; i++)
                KaraokeWord(
                  word: words[i],
                  ipa: showIpa && wholeIpa == null ? lex.word(words[i]) : null,
                  fontSize: fontSize,
                  state: !speaking
                      ? KaraokeState.plain
                      : (i < reached - 1
                          ? KaraokeState.said
                          : (i == reached - 1 ? KaraokeState.saying : KaraokeState.plain)),
                  onTap: () => tapped(words[i]),
                ),
            ],
          );
          if (!showIpa || wholeIpa == null || wholeIpa.isEmpty) {
            return wordCells;
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              wordCells,
              Text(
                '/$wholeIpa/',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: AppTheme.writingFont, fontSize: fontSize * 0.45, color: _ipaColor),
              ),
            ],
          );
        },
      ),
    );
  }
}

enum KaraokeState { plain, said, saying }

class KaraokeWord extends StatelessWidget {
  const KaraokeWord({
    super.key,
    required this.word,
    required this.ipa,
    required this.fontSize,
    required this.state,
    required this.onTap,
  });

  final String word;
  final String? ipa;
  final double fontSize;
  final KaraokeState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      KaraokeState.plain => AppColors.ink,
      KaraokeState.said => karaokeColor,
      KaraokeState.saying => AppColors.white,
    };
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: fontSize * 0.14),
            decoration: BoxDecoration(
              color: state == KaraokeState.saying ? karaokeColor : Colors.transparent,
              borderRadius: BorderRadius.circular(fontSize * 0.25),
            ),
            child: Text(
              word,
              style: TextStyle(
                fontFamily: AppTheme.writingFont,
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                color: color,
                height: 1.15,
              ),
            ),
          ),
          if (ipa != null)
            Text(
              ipa!,
              style: TextStyle(
                fontFamily: AppTheme.writingFont,
                fontSize: (fontSize * 0.5).clamp(13.0, 22.0).toDouble(),
                color: _ipaColor,
                height: 1.1,
              ),
            ),
        ],
      ),
    );
  }
}
