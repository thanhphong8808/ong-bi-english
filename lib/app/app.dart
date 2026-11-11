// lib/app/app.dart
import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';

import '../l10n/strings_vi.dart';
import 'theme.dart';

class OngBiApp extends StatelessWidget {
  const OngBiApp({super.key, required this.router});

  final GoRouter router;

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
        return MediaQuery(
          data: media.copyWith(textScaler: const TextScaler.linear(1.0)),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
