// lib/features/speak/mic_panel.dart
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/theme.dart';
import '../../core/config/app_config.dart';
import '../../core/db/repositories.dart';
import '../../core/providers.dart';
import '../../core/services/stt_service.dart';
import '../../curriculum/scorers/pronunciation_scorer.dart';
import '../../l10n/strings_vi.dart';
import '../../widgets/bi_mascot.dart';
import '../../widgets/item_picture.dart';
import '../daily_lesson/activities/activity_base.dart';

/// What the microphone heard, scored against the target.
class MicOutcome {
  const MicOutcome({required this.score, required this.result});

  /// Null when speech scoring is unavailable (no model or no microphone).
  final PronunciationScore? score;
  final SttResult? result;
}

enum _MicState { idle, listening, thinking, scored }

/// One tap on the big microphone, automatic stop when the child finishes
/// (voice activity detection), a live sound wave, 1-3 stars, and the two
/// playback buttons "Nghe Bi" / "Nghe con".
class MicPanel extends ConsumerStatefulWidget {
  const MicPanel({
    super.key,
    required this.target,
    required this.onResult,
    this.alternatives = const [],
    this.onPlayModel,
    this.sentence = false,
    this.enabled = true,
    this.itemId = '',
    this.anyAnswer = false,
  });

  /// What the child should say.
  final String target;
  final List<String> alternatives;
  final void Function(MicOutcome outcome) onResult;

  /// Plays Bi's model ("Nghe Bi").
  final Future<void> Function()? onPlayModel;
  final bool sentence;
  final bool enabled;
  final String itemId;

  /// Open answers: any clear speech gets full marks.
  final bool anyAnswer;

  @override
  ConsumerState<MicPanel> createState() => MicPanelState();
}

class MicPanelState extends ConsumerState<MicPanel> {
  _MicState _state = _MicState.idle;
  double _level = 0;
  int _stars = 0;
  String? _recording;
  bool _micDenied = false;

  AppServices get _services => ref.read(appServicesProvider);

  /// Ready for another attempt.
  void reset() {
    if (mounted) {
      setState(() {
        _state = _MicState.idle;
        _stars = 0;
      });
    }
  }

  Future<void> _listen() async {
    if (_state == _MicState.listening || _state == _MicState.thinking || !widget.enabled) {
      return;
    }
    final services = _services;
    final difficulty = ref.read(parentSettingsProvider).speechDifficulty;
    final profileFuture = ref.read(activeProfileProvider.future);
    // Whisper loads on first use (a few seconds): show "thinking" until the
    // microphone really listens, so the child does not speak too early.
    setState(() {
      _state = _MicState.thinking;
      _level = 0;
    });
    try {
      await services.speech.stop();
      final profile = await profileFuture;
      await services.stt.ensureReady(services.profile);
      if (!mounted) {
        return;
      }
      setState(() => _state = _MicState.listening);
      final path = services.recordingPath(profile.id);
      final result = await services.stt.listenOnce(
        timeout: Duration(
          seconds: widget.sentence ? AppConfig.listenTimeoutSentenceSeconds : AppConfig.listenTimeoutSeconds,
        ),
        saveWavPath: path,
        onLevel: (level) {
          if (mounted && _state == _MicState.listening) {
            setState(() => _level = level);
          }
        },
      );
      if (!mounted) {
        return;
      }
      setState(() => _state = _MicState.thinking);
      if (result.wavPath != null) {
        _recording = result.wavPath;
        unawaited(services.db.mediaRepo
            .addRecording(profileId: profile.id, filePath: result.wavPath!, itemId: widget.itemId)
            .catchError((Object _) => 0));
      }
      final scorer = PronunciationScorer(difficulty: difficulty);
      var score = scorer.score(widget.target, result.text, alternatives: widget.alternatives);
      if (widget.anyAnswer) {
        final clear = result.text.trim().isNotEmpty && result.speechMs >= AppConfig.minAnswerSpeechMs;
        score = PronunciationScore(
          similarity: clear ? 1 : 0,
          stars: clear ? 3 : 0,
          wordScores: const [],
          heard: result.text,
        );
      }
      if (result.speechMs > 0) {
        unawaited(services.db.speechTurnRepo
            .add(
              profile.id,
              SpeechTurn(
                source: SpeechTurn.lesson,
                at: DateTime.now(),
                itemId: widget.itemId,
                score: widget.anyAnswer ? -1 : score.similarity,
                speechMs: result.speechMs,
                latencyMs: result.timedOut ? -1 : result.scoreLatencyMs,
              ),
            )
            .catchError((Object _) {}));
      }
      setState(() {
        _state = _MicState.scored;
        _stars = score.stars;
      });
      widget.onResult(MicOutcome(score: score, result: result));
    } on SttException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _state = _MicState.idle;
        _micDenied = e.code == 'mic_permission';
      });
      if (_micDenied) {
        await services.speech.sayVi(S.insMicDenied);
      }
      widget.onResult(const MicOutcome(score: null, result: null));
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _state = _MicState.idle);
      widget.onResult(const MicOutcome(score: null, result: null));
    }
  }

  Future<void> _playMine() async {
    final path = _recording;
    if (path == null) {
      return;
    }
    try {
      await _services.speech.playFile(path);
    } catch (_) {
      // Recording already purged.
    }
  }

  @override
  Widget build(BuildContext context) {
    final caps = ref.watch(appServicesProvider).capabilities.value;
    if (!caps.speech || _micDenied) {
      // No scoring possible: the child still practises out loud.
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.onPlayModel != null)
            KidIconButton(icon: Icons.volume_up_rounded, onPressed: widget.onPlayModel, label: S.hearBi),
          const SizedBox(height: 12),
          KidIconButton(
            icon: Icons.check_rounded,
            color: AppColors.leaf,
            size: 96,
            label: S.iSaidIt,
            onPressed: widget.enabled ? () => widget.onResult(const MicOutcome(score: null, result: null)) : null,
          ),
        ],
      );
    }

    final listening = _state == _MicState.listening;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 56,
          child: Center(
            child: switch (_state) {
              _MicState.listening => _Wave(level: _level),
              _MicState.thinking => const BiMascot(mood: BiMood.thinking, size: 56),
              _MicState.scored => StarRow(stars: _stars, size: 40),
              _MicState.idle => const SizedBox.shrink(),
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.onPlayModel != null)
              KidIconButton(icon: Icons.volume_up_rounded, onPressed: widget.onPlayModel, label: S.hearBi),
            const SizedBox(width: 20),
            GestureDetector(
              onTap: _listen,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 116,
                height: 116,
                decoration: BoxDecoration(
                  color: listening ? AppColors.berry : AppColors.honey,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.ink, width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: listening ? AppColors.berry.withValues(alpha: 0.6) : const Color(0x33000000),
                      blurRadius: listening ? 24 : 6,
                      spreadRadius: listening ? 6 : 0,
                    ),
                  ],
                ),
                child: Icon(
                  listening ? Icons.hearing_rounded : Icons.mic_rounded,
                  size: 64,
                  color: AppColors.ink,
                  semanticLabel: S.micLabel,
                ),
              ),
            ),
            const SizedBox(width: 20),
            KidIconButton(
              icon: Icons.child_care_rounded,
              onPressed: _recording != null && _state == _MicState.scored ? _playMine : null,
              label: S.hearMe,
            ),
          ],
        ),
      ],
    );
  }
}

/// Live sound wave while the microphone listens.
class _Wave extends StatelessWidget {
  const _Wave({required this.level});

  final double level;

  @override
  Widget build(BuildContext context) {
    final strength = (level * 8).clamp(0.08, 1.0).toDouble();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 9; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: 9,
            height: 10 + 44 * strength * (0.45 + 0.55 * math.sin((i + 1) * 1.3).abs()),
            decoration: BoxDecoration(color: AppColors.grape, borderRadius: BorderRadius.circular(5)),
          ),
      ],
    );
  }
}
