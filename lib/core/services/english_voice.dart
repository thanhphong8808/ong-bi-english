// lib/core/services/english_voice.dart

/// English voices. Speaker ids are those of kokoro-multi-lang-v1_0.
enum EnglishVoice {
  usFemale(3, 'af_heart', false),
  usMale(16, 'am_michael', false),
  ukFemale(21, 'bf_emma', true),
  ukMale(26, 'bm_george', true);

  const EnglishVoice(this.kokoroSid, this.kokoroName, this.british);

  final int kokoroSid;
  final String kokoroName;
  final bool british;

  /// The other-gender voice of the same accent, for two-speaker dialogues.
  EnglishVoice get partner {
    switch (this) {
      case EnglishVoice.usFemale:
        return EnglishVoice.usMale;
      case EnglishVoice.usMale:
        return EnglishVoice.usFemale;
      case EnglishVoice.ukFemale:
        return EnglishVoice.ukMale;
      case EnglishVoice.ukMale:
        return EnglishVoice.ukFemale;
    }
  }
}
