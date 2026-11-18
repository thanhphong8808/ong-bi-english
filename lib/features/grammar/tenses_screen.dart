// lib/features/grammar/tenses_screen.dart
//
// "Bảng các thì": the seven tenses a child meets first, each with when to
// use it, the yes / no / question forms, signal words and an example.
// Tap a tense: Bi explains it; "Học bài này" opens the matching lesson.
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/kid_scaffold.dart';
import '../../app/router.dart';
import '../../app/theme.dart';
import '../../core/providers.dart';
import '../../curriculum/grammar.dart';
import '../../l10n/strings_vi.dart';
import '../../widgets/item_picture.dart';
import '../../widgets/ui_kit.dart';
import 'grammar_practice_screen.dart';

class TensesScreen extends ConsumerStatefulWidget {
  const TensesScreen({super.key});

  @override
  ConsumerState<TensesScreen> createState() => _TensesScreenState();
}

class _TensesScreenState extends ConsumerState<TensesScreen> {
  late final AppServices _services = ref.read(appServicesProvider);
  GrammarBook? _book;
  String? _open;

  @override
  void initState() {
    super.initState();
    _services.grammarBook().then((book) {
      if (mounted) {
        setState(() => _book = book);
      }
    });
  }

  @override
  void dispose() {
    unawaited(_services.speech.stop());
    super.dispose();
  }

  Future<void> _explain(GrammarTense t) async {
    final settings = ref.read(parentSettingsProvider);
    setState(() => _open = t.id);
    await _services.speech.stop();
    try {
      await _services.speech.sayVi('${t.nameVi}. ${t.useVi}', speed: settings.speechRate);
      if (mounted && _open == t.id) {
        await _services.speech.sayEn(t.example.en, voice: settings.voice, speed: settings.speechRate);
      }
    } catch (_) {
      // Best-effort speech.
    }
  }

  @override
  Widget build(BuildContext context) {
    final book = _book;
    return KidScaffold(
      instructionVi: S.tensesSpoken,
      showBack: true,
      child: book == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                const Text(S.grammarTenses, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                for (final t in book.tenses)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: SoftCard(
                      semanticLabel: t.nameVi,
                      color: _open == t.id ? AppColors.honeySoft : AppColors.white,
                      onTap: () => _explain(t),
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              EmojiText(t.emoji, size: 34),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(t.nameVi, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                                    Text(t.nameEn,
                                        style: const TextStyle(
                                            fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.inkSoft)),
                                  ],
                                ),
                              ),
                              const Icon(Icons.volume_up_rounded, color: AppColors.honeyDeep),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _Line(label: S.tenseUse, value: t.useVi),
                          _Line(label: S.tenseYes, value: t.yes, english: true),
                          _Line(label: S.tenseNo, value: t.no, english: true),
                          _Line(label: S.tenseAsk, value: t.ask, english: true),
                          _Line(label: S.tenseSignals, value: t.signals, english: true),
                          const SizedBox(height: 6),
                          Text('“${t.example.en}”', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                          Text(t.example.vi,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.inkSoft)),
                          if (_open == t.id && book.lesson(t.lessonId) != null) ...[
                            const SizedBox(height: 10),
                            PillButton(
                              label: S.tenseOpenLesson,
                              icon: Icons.school_rounded,
                              onPressed: () {
                                unawaited(_services.speech.stop());
                                context.push(
                                  AppRoutes.grammarLesson,
                                  extra: GrammarPracticeArgs.lesson(book.lesson(t.lessonId)!),
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value, this.english = false});

  final String label;
  final String value;
  final bool english;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.inkSoft)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: english ? FontWeight.w900 : FontWeight.w700,
                color: english ? AppColors.grape : AppColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
