// lib/features/parent/parent_gate_dialog.dart
import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/config/app_config.dart';
import '../../core/providers.dart';
import '../../core/services/parent_gate.dart';
import '../../l10n/strings_vi.dart';

/// Shows the parent lock. Resolves to true only when the adult passes.
///
/// With a PIN set, the PIN is asked; otherwise a random multiplication such
/// as 7 x 8, which a 6-year-old cannot solve yet.
Future<bool> showParentGate(BuildContext context) async {
  final passed = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (context) => const _ParentGateDialog(),
  );
  return passed ?? false;
}

class _ParentGateDialog extends ConsumerStatefulWidget {
  const _ParentGateDialog();

  @override
  ConsumerState<_ParentGateDialog> createState() => _ParentGateDialogState();
}

class _ParentGateDialogState extends ConsumerState<_ParentGateDialog> {
  GateChallenge _challenge = GateChallenge.random();
  String _input = '';
  int _failures = 0;
  bool _wrong = false;
  DateTime? _lockedUntil;
  Timer? _unlockTimer;

  @override
  void dispose() {
    _unlockTimer?.cancel();
    super.dispose();
  }

  bool get _locked {
    final until = _lockedUntil;
    return until != null && DateTime.now().isBefore(until);
  }

  void _press(String digit) {
    if (_locked) {
      return;
    }
    final usesPin = ref.read(parentSettingsProvider).hasPin;
    final maxLength = usesPin ? AppConfig.gatePinLength : 3;
    if (_input.length >= maxLength) {
      return;
    }
    setState(() {
      _input += digit;
      _wrong = false;
    });
  }

  void _erase() {
    if (_input.isEmpty) {
      return;
    }
    setState(() => _input = _input.substring(0, _input.length - 1));
  }

  void _submit() {
    if (_locked || _input.isEmpty) {
      return;
    }
    final settings = ref.read(parentSettingsProvider);
    final ok = settings.hasPin ? PinCheck.matches(_input, settings) : _challenge.check(_input);
    if (ok) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _failures++;
      _wrong = true;
      _input = '';
      _challenge = GateChallenge.random();
      if (_failures >= AppConfig.gateMaxAttempts) {
        _failures = 0;
        _lockedUntil = DateTime.now().add(const Duration(seconds: AppConfig.gateLockoutSeconds));
        _unlockTimer?.cancel();
        _unlockTimer = Timer(const Duration(seconds: AppConfig.gateLockoutSeconds), () {
          if (mounted) {
            setState(() => _lockedUntil = null);
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(parentSettingsProvider);
    final usesPin = settings.hasPin;
    final shown = usesPin ? '•' * _input.length : _input;

    return AlertDialog(
      title: const Text(S.gateTitle, textAlign: TextAlign.center),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(usesPin ? S.gatePinPrompt : S.gateQuestionPrefix),
            if (!usesPin)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  S.gateQuestion(_challenge.a, _challenge.b),
                  style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
                ),
              ),
            const SizedBox(height: 10),
            Container(
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.ink, width: 2),
              ),
              child: Text(
                shown,
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: 4),
              ),
            ),
            SizedBox(
              height: 28,
              child: Center(
                child: Text(
                  _locked ? S.gateLocked : (_wrong ? S.gateWrong : ''),
                  style: const TextStyle(fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            _NumberPad(onDigit: _press, onErase: _erase, onSubmit: _submit, enabled: !_locked),
            if (usesPin)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(S.gateUseMath, style: TextStyle(fontSize: 12), textAlign: TextAlign.center),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text(S.cancel),
        ),
      ],
    );
  }
}

class _NumberPad extends StatelessWidget {
  const _NumberPad({
    required this.onDigit,
    required this.onErase,
    required this.onSubmit,
    required this.enabled,
  });

  final void Function(String digit) onDigit;
  final VoidCallback onErase;
  final VoidCallback onSubmit;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    Widget key(Widget child, VoidCallback onTap) {
      return Padding(
        padding: const EdgeInsets.all(4),
        child: SizedBox(
          width: 76,
          height: 52,
          child: OutlinedButton(
            onPressed: enabled ? onTap : null,
            style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
            child: child,
          ),
        ),
      );
    }

    Widget digit(String d) => key(
          Text(d, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          () => onDigit(d),
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(mainAxisSize: MainAxisSize.min, children: [digit('1'), digit('2'), digit('3')]),
        Row(mainAxisSize: MainAxisSize.min, children: [digit('4'), digit('5'), digit('6')]),
        Row(mainAxisSize: MainAxisSize.min, children: [digit('7'), digit('8'), digit('9')]),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            key(const Icon(Icons.backspace_outlined, semanticLabel: S.gateErase), onErase),
            digit('0'),
            key(const Icon(Icons.check_rounded, semanticLabel: S.gateSubmit), onSubmit),
          ],
        ),
      ],
    );
  }
}
