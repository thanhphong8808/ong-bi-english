// lib/app/startup_error_app.dart
import 'package:material_ui/material_ui.dart';

import '../l10n/strings_vi.dart';
import 'theme.dart';

/// Shown when the app cannot start, so a parent can photograph the reason.
class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({super.key, required this.error, required this.stack, required this.savedTo});

  final Object error;
  final StackTrace stack;
  final String savedTo;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      home: Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(S.startupFailedTitle, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Text(S.startupFailedBody(savedTo), style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 16),
              SelectableText(
                '$error\n\n${stack.toString().split('\n').take(25).join('\n')}',
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
