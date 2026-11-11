// lib/features/parent/diagnostics_screen.dart
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/config/app_config.dart';
import '../../core/providers.dart';
import '../../core/services/audio_request.dart';
import '../../core/services/llm_service.dart';
import '../../core/services/model_catalog.dart';
import '../../core/services/stt_service.dart';
import '../../l10n/strings_vi.dart';

/// Parent tool to try each on-device component after installation and to
/// check the speed targets (speech scoring and Bi's first word within 2 s).
class DiagnosticsScreen extends ConsumerStatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  ConsumerState<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends ConsumerState<DiagnosticsScreen> {
  String _enResult = '';
  String _viResult = '';
  String _sttResult = '';
  String _llmResult = '';
  String? _busy;
  double _level = 0;

  /// The diagnostic prompt mirrors the limits Bi will have in conversation.
  static const String _diagSystemPrompt =
      'You are Bi, a friendly 7-year-old bee who talks with a young child learning English. '
      'Reply in very simple English. Use at most ${AppConfig.biMaxSentencesPerTurn} short sentences '
      'and at most ${AppConfig.biMaxWordsPerSentenceLow} words per sentence. '
      'End with one easy question. Never ask for personal information.';

  late final LlmService _llm;

  @override
  void initState() {
    super.initState();
    _llm = ref.read(appServicesProvider).llm;
  }

  @override
  void dispose() {
    // Never leave the language model in memory after leaving this screen.
    _llm.unload();
    super.dispose();
  }

  Future<void> _guard(String name, Future<void> Function() task) async {
    if (_busy != null) {
      return;
    }
    setState(() => _busy = name);
    try {
      await task();
    } finally {
      if (mounted) {
        setState(() => _busy = null);
      }
    }
  }

  void _show(void Function() update) {
    if (mounted) {
      setState(update);
    }
  }

  Future<void> _testEnglish() => _guard('en', () async {
        final services = ref.read(appServicesProvider);
        final settings = ref.read(parentSettingsProvider);
        final watch = Stopwatch()..start();
        try {
          await services.audioCache.fileFor(
            AudioRequest.en(S.diagEnSample, voice: settings.voice, speed: settings.speechRate),
          );
          final ms = watch.elapsedMilliseconds;
          final note = ms < 150 ? S.diagCached : S.diagFirstRun;
          _show(() => _enResult = '${S.milliseconds(ms)} ($note)');
          await services.speech.sayEn(
            S.diagEnSample,
            voice: settings.voice,
            speed: settings.speechRate,
          );
        } catch (e) {
          _show(() => _enResult = '$e');
        }
      });

  Future<void> _testVietnamese() => _guard('vi', () async {
        final services = ref.read(appServicesProvider);
        final watch = Stopwatch()..start();
        try {
          final path = await services.audioCache.fileFor(const AudioRequest.vi(S.diagViSample));
          final ms = watch.elapsedMilliseconds;
          _show(() {
            _viResult = path == null
                ? S.diagSystemVoice
                : '${S.milliseconds(ms)} (${ms < 150 ? S.diagCached : S.diagFirstRun})';
          });
          await services.speech.sayVi(S.diagViSample);
        } catch (e) {
          _show(() => _viResult = '$e');
        }
      });

  Future<void> _testListening() => _guard('stt', () async {
        final services = ref.read(appServicesProvider);
        try {
          await services.stt.ensureReady(services.profile);
          _show(() => _sttResult = S.diagSttPrompt);
          final result = await services.stt.listenOnce(
            onLevel: (level) => _show(() => _level = level),
          );
          final heard = result.text.isEmpty ? S.diagNothingHeard : result.text;
          _show(() {
            _level = 0;
            _sttResult = '${S.diagHeard}: $heard · ${S.milliseconds(result.decodeMs)}';
          });
        } on SttException catch (e) {
          _show(() {
            _level = 0;
            _sttResult = e.code == 'mic_permission' ? S.diagMicDenied : e.code;
          });
        } catch (e) {
          _show(() {
            _level = 0;
            _sttResult = '$e';
          });
        }
      });

  Future<void> _testBrain() => _guard('llm', () async {
        final services = ref.read(appServicesProvider);
        final pack = ModelCatalog.gemmaFor(services.profile);
        if (pack == null || !await services.downloader.isInstalled(pack)) {
          _show(() => _llmResult = S.diagLlmMissing);
          return;
        }
        final settings = ref.read(parentSettingsProvider);
        try {
          final loadWatch = Stopwatch()..start();
          final backend = await services.llm.load(
            modelPath: p.join(services.downloader.packDir(pack), pack.fileName),
            preferGpu: services.profile.preferGpu,
          );
          final loadMs = loadWatch.elapsedMilliseconds;
          await services.llm.startConversation(_diagSystemPrompt);

          final replyWatch = Stopwatch()..start();
          int? firstTokenMs;
          final buffer = StringBuffer();
          await for (final chunk in services.llm.send('Hello Bi!')) {
            firstTokenMs ??= replyWatch.elapsedMilliseconds;
            buffer.write(chunk);
          }
          // Even in diagnostics nothing is spoken before the safety filter.
          final checked = services.contentFilter.checkOutput(buffer.toString(), level: 1);
          final note = checked.blocked ? '\n${S.diagFiltered} (${checked.reason.name})' : '';
          _show(() {
            _llmResult = '${backend.toUpperCase()} · load ${S.milliseconds(loadMs)} · '
                'first ${S.milliseconds(firstTokenMs ?? 0)}\n${checked.safeText}$note';
          });
          await services.speech.sayEn(
            checked.safeText,
            voice: settings.voice,
            speed: settings.speechRate,
          );
        } catch (e) {
          _show(() => _llmResult = '$e');
        } finally {
          await services.llm.unload();
        }
      });

  Widget _card({
    required String id,
    required IconData icon,
    required String title,
    required String result,
    required VoidCallback onRun,
    Widget? extra,
  }) {
    final running = _busy == id;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 28),
                const SizedBox(width: 10),
                Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
                FilledButton.tonal(
                  onPressed: _busy == null ? onRun : null,
                  child: running
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 3),
                        )
                      : const Icon(Icons.play_arrow_rounded),
                ),
              ],
            ),
            ?extra,
            if (running && result.isEmpty) const Text(S.diagRunning),
            if (result.isNotEmpty)
              Padding(padding: const EdgeInsets.only(top: 6), child: Text(result)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(S.diagTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(S.diagIntro),
            const SizedBox(height: 8),
            _card(
              id: 'en',
              icon: Icons.record_voice_over_outlined,
              title: S.diagEn,
              result: _enResult,
              onRun: _testEnglish,
            ),
            _card(
              id: 'vi',
              icon: Icons.record_voice_over_outlined,
              title: S.diagVi,
              result: _viResult,
              onRun: _testVietnamese,
            ),
            _card(
              id: 'stt',
              icon: Icons.mic_none_rounded,
              title: S.diagStt,
              result: _sttResult,
              onRun: _testListening,
              extra: _busy == 'stt'
                  ? Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: LinearProgressIndicator(
                        value: (_level * 6).clamp(0.0, 1.0).toDouble(),
                        minHeight: 10,
                      ),
                    )
                  : null,
            ),
            _card(
              id: 'llm',
              icon: Icons.psychology_alt_outlined,
              title: S.diagLlm,
              result: _llmResult,
              onRun: _testBrain,
            ),
          ],
        ),
      ),
    );
  }
}
