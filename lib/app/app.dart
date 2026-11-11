// lib/app/app.dart
import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';

import '../core/services/crash_report.dart';
import '../l10n/strings_vi.dart';
import 'theme.dart';

class OngBiApp extends StatelessWidget {
  const OngBiApp({super.key, required this.router, this.lastCrash});

  final GoRouter router;

  /// Report of the previous unexpected stop, shown once to the parent.
  final CrashReport? lastCrash;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: S.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      routerConfig: router,
      builder: (context, child) {
        // Keep kid-mode layouts stable regardless of the system font size.
        final media = MediaQuery.of(context);
        final page = MediaQuery(
          data: media.copyWith(textScaler: const TextScaler.linear(1.0)),
          child: child ?? const SizedBox.shrink(),
        );
        final crash = lastCrash;
        return crash == null ? page : _CrashNotice(report: crash, child: page);
      },
    );
  }
}

/// One-time notice about the previous crash, drawn above the first screen.
class _CrashNotice extends StatefulWidget {
  const _CrashNotice({required this.report, required this.child});

  final CrashReport report;
  final Widget child;

  @override
  State<_CrashNotice> createState() => _CrashNoticeState();
}

class _CrashNoticeState extends State<_CrashNotice> {
  bool _open = true;

  @override
  Widget build(BuildContext context) {
    if (!_open) {
      return widget.child;
    }
    final lines = widget.report.text.split('\n');
    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: ColoredBox(
            color: Colors.black54,
            child: SafeArea(
              child: Center(
                child: Card(
                  margin: const EdgeInsets.all(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(S.crashTitle, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        Text(S.crashBody(widget.report.savedTo)),
                        const SizedBox(height: 8),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 320),
                          child: SingleChildScrollView(
                            child: SelectableText(
                              lines.take(300).join('\n'),
                              style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton(
                            onPressed: () => setState(() => _open = false),
                            child: const Text(S.crashClose),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
