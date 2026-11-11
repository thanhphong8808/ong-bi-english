// lib/app/kid_scaffold.dart
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers.dart';
import '../l10n/strings_vi.dart';
import 'theme.dart';

/// Frame for every kid-mode screen.
///
/// Rules it enforces: one task per screen, Bi reads the Vietnamese
/// instruction aloud on entry, and a speaker button replays it. No text
/// fields, no menus.
class KidScaffold extends ConsumerStatefulWidget {
  const KidScaffold({
    super.key,
    required this.instructionVi,
    required this.child,
    this.showBack = false,
    this.onBack,
    this.topRight,
    this.bottom,
  });

  /// Spoken by Bi when the screen opens.
  final String instructionVi;
  final Widget child;
  final bool showBack;
  final VoidCallback? onBack;
  final Widget? topRight;
  final Widget? bottom;

  @override
  ConsumerState<KidScaffold> createState() => _KidScaffoldState();
}

class _KidScaffoldState extends ConsumerState<KidScaffold> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _speak());
  }

  @override
  void didUpdateWidget(KidScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.instructionVi != widget.instructionVi) {
      _speak();
    }
  }

  Future<void> _speak() async {
    if (!mounted || widget.instructionVi.isEmpty) {
      return;
    }
    final services = ref.read(appServicesProvider);
    final settings = ref.read(parentSettingsProvider);
    try {
      await services.speech.sayVi(widget.instructionVi, speed: settings.speechRate);
    } catch (_) {
      // Speech is best-effort: the screen stays usable through its pictures.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(
                children: [
                  if (widget.showBack)
                    _RoundIconButton(
                      icon: Icons.arrow_back_rounded,
                      semanticLabel: S.back,
                      onPressed: widget.onBack ?? () => Navigator.of(context).maybePop(),
                    ),
                  _RoundIconButton(
                    icon: Icons.volume_up_rounded,
                    semanticLabel: S.listenAgain,
                    onPressed: _speak,
                  ),
                  const Spacer(),
                  if (widget.topRight != null) widget.topRight!,
                ],
              ),
            ),
            Expanded(child: widget.child),
            if (widget.bottom != null) widget.bottom!,
          ],
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Material(
        color: AppColors.white,
        shape: const CircleBorder(side: BorderSide(color: AppColors.ink, width: 2.5)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 64,
            height: 64,
            child: Icon(icon, size: 36, color: AppColors.ink, semanticLabel: semanticLabel),
          ),
        ),
      ),
    );
  }
}
