// lib/features/grammar/verb_table_screen.dart
//
// "Bảng chia động từ": every verb with its five forms (base, he/she/it,
// -ing, past, past participle) and its meaning. Tap a verb to hear the forms
// and three example sentences; filter regular / irregular verbs.
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/kid_scaffold.dart';
import '../../app/theme.dart';
import '../../core/providers.dart';
import '../../curriculum/grammar.dart';
import '../../l10n/strings_vi.dart';
import '../../widgets/item_picture.dart';
import '../../widgets/ui_kit.dart';

enum _Filter { all, irregular, regular }

class VerbTableScreen extends ConsumerStatefulWidget {
  const VerbTableScreen({super.key});

  @override
  ConsumerState<VerbTableScreen> createState() => _VerbTableScreenState();
}

class _VerbTableScreenState extends ConsumerState<VerbTableScreen> {
  late final AppServices _services = ref.read(appServicesProvider);
  List<GrammarVerb> _verbs = const [];
  _Filter _filter = _Filter.all;
  String? _open;

  @override
  void initState() {
    super.initState();
    _services.grammarBook().then((book) {
      if (mounted) {
        setState(() => _verbs = book.verbs);
      }
    });
  }

  @override
  void dispose() {
    unawaited(_services.speech.stop());
    super.dispose();
  }

  /// Example sentences that show the forms in use.
  static List<String> examples(GrammarVerb v) {
    if (v.base == 'be') {
      return const ['I am happy.', 'She is happy.', 'They were happy yesterday.'];
    }
    if (v.base == 'rain') {
      return const ['It rains a lot in summer.', 'It is raining now.', 'It rained yesterday.'];
    }
    return [
      'I ${v.base} every day.',
      'She ${v.third} every day.',
      'I am ${v.ing} now.',
      'Yesterday I ${v.past.split(' / ').first}.',
    ];
  }

  Future<void> _say(GrammarVerb v) async {
    final settings = ref.read(parentSettingsProvider);
    setState(() => _open = v.base);
    await _services.speech.stop();
    final forms = '${v.base}, ${v.third}, ${v.ing}, ${v.past.replaceAll(' / ', ', ')}, ${v.pastParticiple}';
    try {
      await _services.speech.sayEn(forms, voice: settings.voice, speed: settings.speechRate);
      if (mounted && _open == v.base) {
        await _services.speech.sayVi(v.vi, speed: settings.speechRate);
      }
    } catch (_) {
      // Speech is a nicety here; the table stays readable.
    }
  }

  @override
  Widget build(BuildContext context) {
    final shown = _verbs.where((v) => switch (_filter) {
          _Filter.all => true,
          _Filter.irregular => v.irregular,
          _Filter.regular => !v.irregular,
        }).toList();
    return KidScaffold(
      instructionVi: S.verbsSpoken,
      showBack: true,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(S.grammarVerbs, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              children: [
                for (final f in _Filter.values)
                  ChoiceChip(
                    label: Text(switch (f) {
                      _Filter.all => S.verbsAll,
                      _Filter.irregular => S.verbsIrregular,
                      _Filter.regular => S.verbsRegular,
                    }),
                    selected: _filter == f,
                    onSelected: (_) => setState(() => _filter = f),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              itemCount: shown.length,
              itemBuilder: (context, i) {
                final v = shown[i];
                final open = _open == v.base;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SoftCard(
                    semanticLabel: v.base,
                    padding: const EdgeInsets.all(12),
                    color: open ? AppColors.honeySoft : AppColors.white,
                    onTap: () => _say(v),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            EmojiText(v.emoji, size: 30),
                            const SizedBox(width: 10),
                            Text(v.base, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(v.vi,
                                  style: const TextStyle(
                                      fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.inkSoft)),
                            ),
                            if (v.irregular)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.grapeSoft,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text(S.verbsIrregular,
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.grape)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _Form(label: S.verbsThird, value: v.third),
                            _Form(label: S.verbsIng, value: v.ing),
                            _Form(label: S.verbsPast, value: v.past, strong: v.irregular),
                            _Form(label: S.verbsPp, value: v.pastParticiple, strong: v.irregular),
                          ],
                        ),
                        if (open) ...[
                          const SizedBox(height: 8),
                          for (final e in examples(v))
                            Text('• $e', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Form extends StatelessWidget {
  const _Form({required this.label, required this.value, this.strong = false});

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.inkSoft)),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: strong ? AppColors.grape : AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}
