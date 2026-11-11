// lib/core/services/parent_gate.dart
import 'dart:math';

import '../config/app_config.dart';
import 'parent_settings.dart';

/// A multiplication question a 6-year-old cannot answer yet, such as 7 x 8.
class GateChallenge {
  const GateChallenge(this.a, this.b);

  factory GateChallenge.random([Random? random]) {
    final rng = random ?? Random();
    const span = AppConfig.gateFactorMax - AppConfig.gateFactorMin + 1;
    return GateChallenge(
      AppConfig.gateFactorMin + rng.nextInt(span),
      AppConfig.gateFactorMin + rng.nextInt(span),
    );
  }

  final int a;
  final int b;

  int get answer => a * b;

  bool check(String input) => int.tryParse(input.trim()) == answer;
}

/// Verifies the parent PIN, when one is set.
class PinCheck {
  const PinCheck._();

  static bool isValidFormat(String pin) =>
      pin.length == AppConfig.gatePinLength && int.tryParse(pin) != null;

  static bool matches(String pin, ParentSettings settings) =>
      settings.hasPin && ParentSettings.hashPin(pin) == settings.pinHash;
}
