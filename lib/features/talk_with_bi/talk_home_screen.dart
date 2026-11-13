// lib/features/talk_with_bi/talk_home_screen.dart
//
// "Nói chuyện với Bi": chat about a topic, role-play (pick a situation, then
// a role), or listen to a fable. Every guided talk works without Bi's
// brain; free chat with the brain is offered inside each topic when it is
// installed.
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/kid_scaffold.dart';
import '../../app/router.dart';
import '../../app/theme.dart';
import '../../core/providers.dart';
import '../../curriculum/talk_scripts.dart';
import '../../l10n/strings_vi.dart';
import '../../widgets/bi_mascot.dart';
import '../../widgets/giant_button.dart';
import '../../widgets/item_picture.dart';
import '../../widgets/story_art.dart';
import '../../widgets/ui_kit.dart';

/// Scripts the child finished, per profile (a star on their cards).
class TalkDone {
  const TalkDone._();

  static const String key = 'talk_done';

  static Future<Set<String>> load(AppServices services, int profileId) async {
    final raw = await services.db.settingsRepo.read(key, profileId: profileId);
    if (raw == null || raw.isEmpty) {
      return {};
    }
    try {
      return {for (final id in jsonDecode(raw) as List) '$id'};
    } catch (_) {
      return {};
    }
  }

  static Future<void> add(AppServices services, int profileId, String scriptId) async {
    final done = await load(services, profileId);
    if (done.add(scriptId)) {
      await services.db.settingsRepo.write(key, jsonEncode(done.toList()), profileId: profileId);
    }
  }
}

/// Route argument for /talk/guided.
class GuidedTalkArgs {
  const GuidedTalkArgs({
    required this.script,
    required this.kidRole,
    this.onChoice,
    this.onFinished,
    this.record = true,
    this.doneSpokenVi,
  });

  final TalkScript script;
  final String kidRole;

  /// Called with every answer the child picks (the morning hello notes
  /// some of them in Bi's notebook).
  final void Function(String blockId, TalkOption option)? onChoice;

  /// Called once when the talk ends.
  final Future<void> Function()? onFinished;

  /// Marks the script as done (a star on its card).
  final bool record;

  /// What Bi says at the end instead of the usual praise.
  final String? doneSpokenVi;
}

enum _View { modes, topics, scripts, roles, stories }

class TalkHomeScreen extends ConsumerStatefulWidget {
  const TalkHomeScreen({super.key, this.startWithStories = false});

  /// Opened from "Nghe kể chuyện" on the home screen.
  final bool startWithStories;

  @override
  ConsumerState<TalkHomeScreen> createState() => _TalkHomeScreenState();
}

class _TalkHomeScreenState extends ConsumerState<TalkHomeScreen> {
  late _View _view = widget.startWithStories ? _View.stories : _View.modes;
  TalkKind _kind = TalkKind.chat;
  TalkTopic? _topic;
  TalkScript? _script;
  TalkLibrary? _library;
  Set<String> _done = const {};
  int _level = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final services = ref.read(appServicesProvider);
    final library = await services.talkLibrary();
    final profile = await ref.read(activeProfileProvider.future);
    final done = await TalkDone.load(services, profile.id);
    if (mounted) {
      setState(() {
        _library = library;
        _done = done;
        _level = profile.level;
      });
    }
  }

  String get _spoken => switch (_view) {
        _View.modes => S.talkChooseSpoken,
        _View.topics => S.talkPickTopicSpoken,
        _View.scripts => _kind == TalkKind.role ? S.talkPickRolePlaySpoken : S.talkPickChatSpoken,
        _View.roles => S.talkPickRoleSpoken,
        _View.stories => S.talkPickStorySpoken,
      };

  void _back() {
    if (_view == _View.modes || (widget.startWithStories && _view == _View.stories)) {
      context.pop();
      return;
    }
    setState(() {
      switch (_view) {
        case _View.modes:
          break;
        case _View.topics || _View.stories:
          _view = _View.modes;
        case _View.scripts:
          _view = _View.topics;
        case _View.roles:
          _view = _View.scripts;
      }
    });
  }

  Future<void> _open(TalkScript script, String kidRole) async {
    await context.push(AppRoutes.talkGuided, extra: GuidedTalkArgs(script: script, kidRole: kidRole));
    await _load();
  }

  /// Easier talks first, then the rest in file order.
  List<TalkScript> _sorted(List<TalkScript> scripts) {
    final order = {for (var i = 0; i < scripts.length; i++) scripts[i].id: i};
    return [...scripts]..sort((a, b) {
        final aFit = a.level <= _level ? 0 : 1;
        final bFit = b.level <= _level ? 0 : 1;
        return aFit != bFit ? aFit - bFit : order[a.id]!.compareTo(order[b.id]!);
      });
  }

  @override
  Widget build(BuildContext context) {
    final library = _library;
    return KidScaffold(
      instructionVi: _spoken,
      showBack: true,
      onBack: _back,
      child: library == null ? const Center(child: CircularProgressIndicator()) : _body(library),
    );
  }

  Widget _body(TalkLibrary library) {
    switch (_view) {
      case _View.modes:
        final level = _level;
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            SoftCard(
              gradient: AppGradients.honey,
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
              onTap: () => context.push(AppRoutes.chat),
              semanticLabel: S.chatTitle,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(S.chatTitle, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 4),
                        const Text(S.chatSub, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 12),
                        PillButton(
                          label: S.homeHelloStart,
                          icon: Icons.mic_rounded,
                          color: AppColors.white,
                          onPressed: () => context.push(AppRoutes.chat),
                        ),
                      ],
                    ),
                  ),
                  BiMascot(mood: BiMood.happy, size: 120, level: level),
                ],
              ),
            ),
            const SizedBox(height: 18),
            GiantButton(
              emoji: '💬',
              label: S.talkModeChat,
              color: AppColors.sky,
              onPressed: () => setState(() {
                _kind = TalkKind.chat;
                _view = _View.topics;
              }),
            ),
            const SizedBox(height: 16),
            GiantButton(
              emoji: '🎭',
              label: S.talkModeRole,
              color: AppColors.honeyDeep,
              onPressed: () => setState(() {
                _kind = TalkKind.role;
                _view = _View.topics;
              }),
            ),
            const SizedBox(height: 16),
            GiantButton(
              emoji: '📖',
              label: S.talkModeStory,
              color: AppColors.berry,
              onPressed: () => setState(() => _view = _View.stories),
            ),
          ],
        );
      case _View.topics:
        final topics = [
          for (final t in library.topics)
            if (library.of(_kind, topic: t.id).isNotEmpty) t,
        ];
        return GridView.count(
          crossAxisCount: 2,
          padding: const EdgeInsets.all(12),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.15,
          children: [
            for (final t in topics)
              _Card(
                emoji: t.emoji,
                title: t.vi,
                subtitle: t.en,
                done: library.of(_kind, topic: t.id).every((s) => _done.contains(s.id)),
                onTap: () => setState(() {
                  _topic = t;
                  _view = _View.scripts;
                }),
              ),
          ],
        );
      case _View.scripts:
        final topic = _topic!;
        final scripts = _sorted(library.of(_kind, topic: topic.id));
        final services = ref.read(appServicesProvider);
        final freeChat = _kind == TalkKind.chat &&
            services.capabilities.value.llm &&
            ref.read(parentSettingsProvider).talkWithBiEnabled;
        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Text('${topic.emoji}  ${topic.vi}', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            for (final s in scripts)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: _Row(
                  emoji: s.emoji,
                  title: s.titleVi,
                  subtitle: s.kind == TalkKind.role
                      ? '${s.titleEn} · ${s.playableRoles.map((r) => r.vi).join(' / ')}'
                      : s.titleEn,
                  done: _done.contains(s.id),
                  onTap: () {
                    if (s.kind == TalkKind.role) {
                      setState(() {
                        _script = s;
                        _view = _View.roles;
                      });
                    } else {
                      _open(s, TalkScript.kidRole);
                    }
                  },
                ),
              ),
            if (freeChat)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: _Row(
                  emoji: '🐝',
                  title: S.talkFree,
                  subtitle: S.talkFreeNote,
                  done: false,
                  onTap: () => context.push(AppRoutes.talkFree, extra: topic),
                ),
              ),
          ],
        );
      case _View.roles:
        final script = _script!;
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text('${script.emoji}  ${script.titleVi}',
                  textAlign: TextAlign.center, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
              Text(script.titleEn, style: const TextStyle(fontSize: 18, fontFamily: AppTheme.writingFont)),
              const SizedBox(height: 16),
              Expanded(
                child: Row(
                  children: [
                    for (final role in script.playableRoles)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: PictureCard(
                            onTap: () => _open(script, role.id),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                EmojiText(role.emoji, size: 90),
                                const SizedBox(height: 10),
                                Text(role.vi,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                                Text(role.en,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 18, fontFamily: AppTheme.writingFont)),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      case _View.stories:
        final stories = _sorted(library.of(TalkKind.story));
        return GridView.count(
          crossAxisCount: 2,
          padding: const EdgeInsets.all(14),
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 0.82,
          children: [
            for (final s in stories)
              _StoryCard(
                script: s,
                done: _done.contains(s.id),
                onTap: () => _open(s, TalkScript.kidRole),
              ),
          ],
        );
    }
  }
}

/// A fable with its cover picture (or its emoji until the art is in).
class _StoryCard extends StatelessWidget {
  const _StoryCard({required this.script, required this.done, required this.onTap});

  final TalkScript script;
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(8),
      onTap: onTap,
      semanticLabel: script.titleVi,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                StoryScene(storyId: script.id, scene: 0, fallbackEmoji: script.emoji, animate: false, radius: 18),
                if (done) const Positioned(top: 6, right: 6, child: EmojiText('⭐', size: 22)),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(script.titleVi,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, height: 1.1)),
          Text(script.titleEn,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontFamily: AppTheme.writingFont, color: AppColors.inkSoft)),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.emoji, required this.title, required this.subtitle, required this.done, required this.onTap});

  final String emoji;
  final String title;
  final String subtitle;
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PictureCard(
      onTap: onTap,
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                EmojiText(emoji, size: 54),
                const SizedBox(height: 4),
                Text(title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, height: 1.1)),
                Text(subtitle,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: const TextStyle(fontSize: 13, fontFamily: AppTheme.writingFont, height: 1.1)),
              ],
            ),
          ),
          if (done) const Positioned(top: 0, right: 0, child: EmojiText('⭐', size: 22)),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.emoji, required this.title, required this.subtitle, required this.done, required this.onTap});

  final String emoji;
  final String title;
  final String subtitle;
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PictureCard(
      onTap: onTap,
      child: Row(
        children: [
          EmojiText(emoji, size: 44),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
                Text(subtitle, style: const TextStyle(fontSize: 15, fontFamily: AppTheme.writingFont)),
              ],
            ),
          ),
          if (done) const EmojiText('⭐', size: 26),
        ],
      ),
    );
  }
}
