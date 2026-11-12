// lib/features/parent/parent_words_screen.dart
//
// "Bộ từ của bố mẹ": parents add words from the child's school book. Each
// word gets the built-in voice automatically, is taught in the next daily
// lessons (two at a time), comes back in Leitner review and is known to Bi.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/config/app_config.dart';
import '../../core/db/repositories.dart';
import '../../core/providers.dart';
import '../../curriculum/parent_words.dart';
import '../../l10n/strings_vi.dart';
import '../../widgets/item_picture.dart';

/// Pictures a parent can pick for a word (emoji the app's font can draw).
const List<String> parentWordEmojis = [
  '🐶', '🐱', '🐭', '🐰', '🐻', '🐼', '🐯', '🦁', '🐮', '🐷', '🐸', '🐵', '🐔', '🐧', '🐦', '🦆',
  '🐟', '🐢', '🐍', '🦋', '🐝', '🐞', '🐘', '🦒', '🍎', '🍌', '🍇', '🍓', '🍉', '🍊', '🥕', '🌽',
  '🍞', '🍚', '🍜', '🥚', '🥛', '🍰', '🍦', '🍬', '🏠', '🏫', '🚗', '🚌', '🚲', '✈️', '⛵', '🚂',
  '⚽', '🏀', '🎈', '🎁', '🧸', '🪁', '📚', '✏️', '🖍️', '🎒', '👕', '👗', '👟', '🧢', '☀️', '🌙',
  '⭐', '☁️', '🌧️', '🌈', '❄️', '🌳', '🌸', '🍀', '👨', '👩', '👦', '👧', '👶', '👴', '👵', '🧑‍🏫',
  '👀', '👂', '👃', '👄', '✋', '🦶', '❤️', '😀', '😢', '😠', '😴', '🤒', '1️⃣', '2️⃣', '3️⃣', '🔴',
];

final _wordsProvider = FutureProvider.autoDispose<List<ParentWord>>((ref) async {
  return ref.watch(appServicesProvider).db.parentWordRepo.all();
});

class ParentWordsScreen extends ConsumerWidget {
  const ParentWordsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final words = ref.watch(_wordsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text(S.parentWordsTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context, ref, words.value?.length ?? 0),
        icon: const Icon(Icons.add_rounded),
        label: const Text(S.parentWordsAdd),
      ),
      body: words.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (list) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          children: [
            const Text(S.parentWordsIntro),
            const SizedBox(height: 12),
            if (list.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: Text(S.parentWordsEmpty, textAlign: TextAlign.center)),
              ),
            for (final word in list.reversed)
              Card(
                child: ListTile(
                  leading: word.emoji.isEmpty
                      ? const SizedBox(width: 40, child: Icon(Icons.image_not_supported_outlined))
                      : SizedBox(width: 40, child: Center(child: EmojiText(word.emoji, size: 30))),
                  title: Text(word.en, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text([word.vi, if (word.exampleEn.isNotEmpty) word.exampleEn].join('\n')),
                  isThreeLine: word.exampleEn.isNotEmpty,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: S.parentWordsListen,
                        icon: const Icon(Icons.volume_up_rounded),
                        onPressed: () => _listen(ref, word.en),
                      ),
                      IconButton(
                        tooltip: S.parentWordsDelete,
                        icon: const Icon(Icons.delete_outline_rounded),
                        onPressed: () => _delete(context, ref, word),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _listen(WidgetRef ref, String text) async {
    final services = ref.read(appServicesProvider);
    final voice = ref.read(parentSettingsProvider).voice;
    await services.speech.sayEn(text, voice: voice).catchError((Object _) {});
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, ParentWord word) async {
    final services = ref.read(appServicesProvider);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(S.parentWordsDeleteAsk(word.en)),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text(S.cancel)),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text(S.parentWordsDelete)),
        ],
      ),
    );
    if (ok != true) {
      return;
    }
    await services.db.parentWordRepo.delete(word.id);
    await services.reloadParentWords();
    ref.invalidate(_wordsProvider);
  }

  Future<void> _add(BuildContext context, WidgetRef ref, int count) async {
    final messenger = ScaffoldMessenger.of(context);
    if (count >= AppConfig.parentWordsMax) {
      messenger.showSnackBar(const SnackBar(content: Text(S.parentWordsFull)));
      return;
    }
    final services = ref.read(appServicesProvider);
    final draft = await showDialog<_Draft>(context: context, builder: (_) => const _AddWordDialog());
    if (draft == null) {
      return;
    }
    await services.db.parentWordRepo.add(en: draft.en, vi: draft.vi, emoji: draft.emoji, exampleEn: draft.example);
    await services.reloadParentWords();
    ref.invalidate(_wordsProvider);
    messenger.showSnackBar(SnackBar(content: Text(S.parentWordsAdded(draft.en))));
  }
}

class _Draft {
  const _Draft(this.en, this.vi, this.emoji, this.example);

  final String en;
  final String vi;
  final String emoji;
  final String example;
}

class _AddWordDialog extends StatefulWidget {
  const _AddWordDialog();

  @override
  State<_AddWordDialog> createState() => _AddWordDialogState();
}

class _AddWordDialogState extends State<_AddWordDialog> {
  final _en = TextEditingController();
  final _vi = TextEditingController();
  final _example = TextEditingController();
  String _emoji = '';
  String? _error;

  @override
  void dispose() {
    _en.dispose();
    _vi.dispose();
    _example.dispose();
    super.dispose();
  }

  void _save() {
    final en = cleanParentWord(_en.text);
    final vi = _vi.text.trim();
    final example = cleanParentExample(_example.text);
    String? error;
    if (en == null) {
      error = S.parentWordsBadWord;
    } else if (vi.isEmpty || vi.length > 60) {
      error = S.parentWordsBadMeaning;
    } else if (example == null) {
      error = S.parentWordsBadExample;
    }
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(context).pop(_Draft(en!, vi, _emoji, example!));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(S.parentWordsAdd),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _en,
                decoration: const InputDecoration(labelText: S.parentWordsEnglish, hintText: 'pencil case'),
                textInputAction: TextInputAction.next,
                autocorrect: false,
              ),
              TextField(
                controller: _vi,
                decoration: const InputDecoration(labelText: S.parentWordsMeaning, hintText: 'hộp bút'),
                textInputAction: TextInputAction.next,
              ),
              TextField(
                controller: _example,
                decoration: const InputDecoration(labelText: S.parentWordsExample, hintText: 'This is my pencil case.'),
                autocorrect: false,
              ),
              const SizedBox(height: 12),
              Text(S.parentWordsPicture, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 6),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (final emoji in parentWordEmojis)
                    InkWell(
                      onTap: () => setState(() => _emoji = _emoji == emoji ? '' : emoji),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _emoji == emoji ? Theme.of(context).colorScheme.primary : Colors.transparent,
                            width: 2.5,
                          ),
                        ),
                        child: EmojiText(emoji, size: 24),
                      ),
                    ),
                ],
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text(S.cancel)),
        FilledButton(onPressed: _save, child: const Text(S.save)),
      ],
    );
  }
}
