// lib/widgets/spoken_text.dart
//
// English text the child reads while Bi speaks: each word changes colour as
// Bi says it (the word being said sits on a honey background), with its
// pronunciation (IPA) underneath. Tapping a word says it.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../app/theme.dart';
import '../core/providers.dart';
import '../core/services/english_voice.dart';
import '../core/services/speech_output.dart';
import '../curriculum/karaoke.dart';
import '../curriculum/pron_lexicon.dart';

const Color _ipaColor = Color(0xFF7A6A55);

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
    final withIpa = showIpa ?? settings.showIpa;
    final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final starts = wordStarts(words);
    final key = karaokeKey(text);
    final wholeIpa = ipa?.replaceAll('/', '').trim();

    void say(String word) {
      final clean = PronLexicon.clean(word);
      if (RegExp(r"^[a-z]+(?:'[a-z]+)?$").hasMatch(clean)) {
        services.speech.sayEn(clean, voice: voice ?? settings.voice, speed: settings.speechRate).catchError((Object _) {});
      }
    }

    return ValueListenableBuilder<PronLexicon>(
      valueListenable: services.pron.lexicon,
      builder: (context, lexicon, _) => ValueListenableBuilder<SpeechProgress>(
        valueListenable: services.speech.progress,
        builder: (context, progress, _) {
          final speaking = progress.active && karaokeKey(progress.text) == key;
          final reached = speaking ? wordsReached(starts, progress.fraction) : 0;
          final wordCells = Wrap(
            alignment: alignment,
            spacing: fontSize * 0.28,
            runSpacing: fontSize * 0.18,
            children: [
              for (var i = 0; i < words.length; i++)
                _WordCell(
                  word: words[i],
                  ipa: withIpa && wholeIpa == null ? lexicon.word(words[i]) : null,
                  fontSize: fontSize,
                  state: !speaking
                      ? _WordState.plain
                      : (i < reached - 1 ? _WordState.said : (i == reached - 1 ? _WordState.saying : _WordState.plain)),
                  onTap: () => say(words[i]),
                ),
            ],
          );
          if (!withIpa || wholeIpa == null || wholeIpa.isEmpty) {
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

enum _WordState { plain, said, saying }

class _WordCell extends StatelessWidget {
  const _WordCell({
    required this.word,
    required this.ipa,
    required this.fontSize,
    required this.state,
    required this.onTap,
  });

  final String word;
  final String? ipa;
  final double fontSize;
  final _WordState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = state == _WordState.said ? AppColors.grape : AppColors.ink;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: fontSize * 0.12),
            decoration: BoxDecoration(
              color: state == _WordState.saying ? AppColors.honey : Colors.transparent,
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
