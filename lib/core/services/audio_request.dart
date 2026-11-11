// lib/core/services/audio_request.dart
import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'english_voice.dart';

enum AudioLang { en, vi }

/// One fixed sentence to speak. Equal requests share one cached file.
class AudioRequest {
  const AudioRequest.en(
    this.text, {
    this.voice = EnglishVoice.usFemale,
    this.speed = 1.0,
  }) : lang = AudioLang.en;

  const AudioRequest.vi(this.text, {this.speed = 1.0})
      : lang = AudioLang.vi,
        voice = EnglishVoice.usFemale;

  final AudioLang lang;
  final String text;
  final EnglishVoice voice;
  final double speed;
}

/// Stable cache key: engine tag + speed + normalised text.
String audioCacheKey(String engineTag, double speed, String text) {
  final normalised = text.trim().replaceAll(RegExp(r'\s+'), ' ');
  final raw = '$engineTag|${speed.toStringAsFixed(2)}|$normalised';
  return sha1.convert(utf8.encode(raw)).toString();
}
