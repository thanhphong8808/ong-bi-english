// lib/features/pocket/pocket_screen.dart
//
// "Câu bỏ túi": the child's pocket of everyday sentences. Tap a sentence to
// hear it; "Luyện tập" plays a short round where Bi sets a little scene
// ("Your tummy goes rumble, rumble! What do you say?") and the child says
// the sentence. Reviews follow the Leitner boxes in PocketProgress. The
// sentences the child asked Bi about ("Bi ơi, nói thế nào?") are here too.
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/kid_scaffold.dart';
import '../../app/theme.dart';
import '../../core/config/app_config.dart';
import '../../core/providers.dart';
import '../../curriculum/bi_world.dart';
import '../../curriculum/pocket_phrases.dart';
import '../../l10n/strings_vi.dart';
import '../../widgets/bi_mascot.dart';
import '../../widgets/item_picture.dart';
import '../../widgets/spoken_text.dart';
import '../../widgets/ui_kit.dart';
import '../speak/mic_panel.dart';
import '../talk_with_bi/bi_chat_screen.dart' show MyPhrases;

class PocketScreen extends ConsumerStatefulWidget {
  const PocketScreen({super.key});

  @override
  ConsumerState<PocketScreen> createState() => _PocketScreenState();
}

class _PocketScreenState extends ConsumerState<PocketScreen> {
  late final AppServices _services = ref.read(appServicesProvider);
  PocketProgress _progress = PocketProgress.decode(null);
  List<(String, String)> _mine = const [];
  int _level = 0;
  int? _profileId;
  String? _group;

  // Practice round.
  List<PocketPhrase>? _round;
  int _index = 0;
  int _stars = 0;
  bool _answered = false;
  final GlobalKey<MicPanelState> _mic = GlobalKey<MicPanelState>();

  @override
  void initState() {
    super.initState();
    _services.studyClock.start();
    _load();
  }

  @override
  void dispose() {
    _services.studyClock.stop();
    unawaited(_services.speech.stop());
    super.dispose();
  }

  Future<void> _load() async {
    final profile = await ref.read(activeProfileProvider.future);
    final raw = await _services.db.settingsRepo.read(PocketProgress.key, profileId: profile.id);
    final mine = await MyPhrases.load(_services, profile.id);
    if (mounted) {
      setState(() {
        _profileId = profile.id;
        _level = profile.level;
        _progress = PocketProgress.decode(raw);
        _mine = mine;
      });
    }
  }

  Future<void> _save() async {
    final id = _profileId;
    if (id != null) {
      await _services.db.settingsRepo.write(PocketProgress.key, _progress.encode(), profileId: id);
    }
  }

  double get _speed => ref.read(slowModeProvider) ? AppConfig.slowSpeechRate : AppConfig.normalSpeechRate;

  Future<void> _hear(String en) =>
      _services.speech.sayEn(en, voice: ref.read(parentSettingsProvider).voice, speed: _speed).catchError((Object _) {});

  // ------------------------------------------------------------ practice

  void _startRound() {
    final round = _progress.round(_level, HelloDay.today, group: _group);
    if (round.isEmpty) {
      return;
    }
    setState(() {
      _round = round;
      _index = 0;
      _stars = 0;
      _answered = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _present());
  }

  Future<void> _present() async {
    final round = _round;
    if (round == null || !mounted) {
      return;
    }
    final p = round[_index];
    _mic.currentState?.reset();
    final voice = ref.read(parentSettingsProvider).voice;
    await _services.speech.sayEn(p.situationEn, voice: voice.partner, speed: _speed).catchError((Object _) {});
    if (!mounted || _round != round) {
      return;
    }
    await _services.speech.sayVi(p.situationVi).catchError((Object _) {});
    if (!mounted || _round != round) {
      return;
    }
    await _services.speech.sayVi(S.pocketSaySpoken).catchError((Object _) {});
    if (!mounted || _round != round) {
      return;
    }
    await _hear(p.en);
  }

  Future<void> _onResult(MicOutcome outcome) async {
    final round = _round;
    if (round == null || _answered) {
      return;
    }
    final p = round[_index];
    final stars = outcome.score?.stars ?? 2;
    final good = outcome.score == null || stars >= 2;
    _progress.answer(p.id, good: good, today: HelloDay.today);
    unawaited(_save());
    setState(() {
      _answered = true;
      _stars += stars;
    });
    await _services.speech
        .sayVi(good ? S.praiseLines[_index % S.praiseLines.length] : S.sayEffort)
        .catchError((Object _) {});
    if (!mounted || _round != round) {
      return;
    }
    if (_index + 1 >= round.length) {
      setState(() => _index = round.length);
      final id = _profileId;
      if (id != null) {
        await _services.db.profileRepo.addStars(id, AppConfig.starsPerStage).catchError((Object _) {});
        ref.invalidate(activeProfileProvider);
      }
      await _services.speech.sayVi(S.pocketRoundDoneSpoken).catchError((Object _) {});
      return;
    }
    setState(() {
      _index++;
      _answered = false;
    });
    await _present();
  }

  // ------------------------------------------------------------------ UI

  @override
  Widget build(BuildContext context) {
    final round = _round;
    return KidScaffold(
      instructionVi: round == null ? S.pocketSpoken : '',
      showBack: true,
      onBack: round == null
          ? null
          : () {
              unawaited(_services.speech.stop());
              setState(() => _round = null);
            },
      child: round == null ? _list() : _practice(round),
    );
  }

  Widget _list() {
    final total = PocketPhrases.forLevel(_level).length;
    final phrases = [
      for (final p in PocketPhrases.forLevel(_level))
        if (_group == null || p.group == _group) p,
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        SoftCard(
          gradient: AppGradients.honey,
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('🎒 ${S.pocketTitle}', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(S.pocketCount(_progress.collected.clamp(0, total).toInt(), total),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 10),
                    SoftProgress(value: total == 0 ? 0 : _progress.collected / total, color: AppColors.ink),
                    const SizedBox(height: 14),
                    PillButton(
                      label: S.pocketPractice,
                      icon: Icons.play_arrow_rounded,
                      color: AppColors.white,
                      onPressed: _startRound,
                    ),
                  ],
                ),
              ),
              BiMascot(mood: BiMood.happy, size: 110, level: _level),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _groupChip(null, '✨', 'Tất cả'),
              for (final g in PocketPhrases.groups)
                if (PocketPhrases.forLevel(_level).any((p) => p.group == g.id)) _groupChip(g.id, g.emoji, g.vi),
            ],
          ),
        ),
        if (_group == null && _mine.isNotEmpty) ...[
          const SectionTitle(S.pocketMine),
          for (final m in _mine.take(10)) _phraseRow('💬', m.$1, m.$2, mastered: false, fresh: false),
        ],
        const SectionTitle(S.pocketTitle),
        for (final p in phrases)
          _phraseRow(
            p.emoji,
            p.en,
            p.vi,
            mastered: (_progress.boxes[p.id] ?? 0) >= 3,
            fresh: !_progress.boxes.containsKey(p.id),
          ),
      ],
    );
  }

  Widget _groupChip(String? id, String emoji, String label) {
    final selected = _group == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        avatar: EmojiText(emoji, size: 18),
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _group = id),
      ),
    );
  }

  Widget _phraseRow(String emoji, String en, String vi, {required bool mastered, required bool fresh}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SoftCard(
        padding: const EdgeInsets.all(12),
        onTap: () => _hear(en),
        child: Row(
          children: [
            IconTile(emoji, size: 54),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(en, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                  Text(vi, style: const TextStyle(fontSize: 14, color: AppColors.inkSoft)),
                ],
              ),
            ),
            if (mastered) const EmojiText('⭐', size: 22),
            if (fresh)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppColors.skySoft, borderRadius: BorderRadius.circular(999)),
                child: const Text(S.pocketNew, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
              ),
            const SizedBox(width: 4),
            const Icon(Icons.volume_up_rounded, color: AppColors.inkSoft),
          ],
        ),
      ),
    );
  }

  Widget _practice(List<PocketPhrase> round) {
    if (_index >= round.length) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SoftCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                BiMascot(mood: BiMood.cheering, size: 150, level: _level),
                const Text(S.pocketRoundDone, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                StarRow(stars: (_stars / round.length).round().clamp(1, 3).toInt(), size: 40),
                const SizedBox(height: 16),
                PillButton(
                  label: S.talkOther,
                  icon: Icons.arrow_forward_rounded,
                  big: true,
                  onPressed: () {
                    setState(() => _round = null);
                    _load();
                  },
                ),
              ],
            ),
          ),
        ),
      );
    }
    final p = round[_index];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        children: [
          SoftProgress(value: _index / round.length),
          const SizedBox(height: 14),
          SoftCard(
            onTap: _present,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BiMascot(mood: BiMood.happy, size: 70, level: _level),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(S.pocketSituation,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.inkSoft)),
                      SpokenText(p.situationEn, fontSize: 20, alignment: WrapAlignment.start),
                      const SizedBox(height: 4),
                      Text(p.situationVi,
                          style: const TextStyle(fontSize: 15, color: AppColors.inkSoft, fontStyle: FontStyle.italic)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          const Text(S.pocketSayIt, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          SoftCard(
            color: AppColors.honeySoft,
            onTap: () => _hear(p.en),
            child: Column(
              children: [
                EmojiText(p.emoji, size: 56),
                SpokenText(p.en, fontSize: 30),
                Text(p.vi, style: const TextStyle(fontSize: 17, color: AppColors.inkSoft)),
              ],
            ),
          ),
          const Spacer(),
          MicPanel(
            key: _mic,
            target: p.en,
            sentence: true,
            enabled: !_answered,
            itemId: 'pocket:${p.id}',
            onPlayModel: () => _hear(p.en),
            onStart: () => unawaited(_services.speech.stop()),
            onResult: _onResult,
          ),
        ],
      ),
    );
  }
}

/// Day numbers shared by the pocket and the morning hello.
class HelloDay {
  const HelloDay._();

  static int get today => BiWorld.dayNumber(DateTime.now());
}
