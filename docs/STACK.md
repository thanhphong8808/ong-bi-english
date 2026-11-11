# STACK – phiên bản và lý do chọn

Kiểm tra ngày 2026-11-10, cập nhật 2026-11-11. Cột "Nguồn kiểm tra" ghi rõ con số lấy từ đâu.

## Bộ công cụ build

| Thành phần | Phiên bản dùng | Nguồn kiểm tra |
|---|---|---|
| Flutter | kênh `stable` mới nhất (CI không ghim số); đã đối chiếu với 3.47.9 | `flutter/flutter` nhánh `stable` |
| Dart | `^3.13.0` | Đi kèm Flutter 3.47; đáp ứng yêu cầu của go_router 18, record 7, flutter_riverpod 3.5 |
| Gradle | 9.3.1 | `templateDefaultGradleVersion` trong `gradle_utils.dart` của Flutter stable |
| Android Gradle Plugin | 9.1.0 | `templateAndroidGradlePluginVersion` (cùng file) |
| Kotlin Gradle Plugin | 2.4.0 | `templateKotlinGradlePluginVersion`; LiteRT-LM 0.18.0 cần Kotlin 2.4 |
| Java | 17 | Mức tối thiểu Flutter stable chấp nhận |
| compileSdk / targetSdk | theo Flutter (`flutter.compileSdkVersion`, hiện là 36) | template Flutter stable |
| minSdk | 29 | Yêu cầu của dự án |

`android/gradle.properties` có `android.newDsl=false` và `android.builtInKotlin=false`,
đúng như template Flutter stable hiện tại cho AGP 9.

## Gói Dart

| Gói | Phiên bản | Nguồn kiểm tra |
|---|---|---|
| flutter_riverpod | ^3.5.0 (phát hành 2026-11-06) | `pubspec.yaml` + CHANGELOG trong repo riverpod |
| go_router | ^18.1.4 | `pubspec.yaml` + CHANGELOG trong `flutter/packages` |
| drift | ^2.35.4 (SQL thuần, không sinh mã) | `pubspec.yaml` trong repo drift |
| drift_flutter | ^0.3.1 | như trên |
| sherpa_onnx | **1.12.29 (ghim cứng)** | Mã nguồn tag `v1.12.29`; xem ghi chú bên dưới |
| record | ^7.1.2 | Bản phát hành mới nhất trên pub.dev (repo đã lên 7.2.0 nhưng chưa phát hành) |
| just_audio | ^0.10.6 | `pubspec.yaml` trong repo just_audio |
| flutter_svg | ^2.3.3 | `pubspec.yaml` trong `flutter/packages` |
| flutter_tts | ^4.2.5 | `pubspec.yaml` trong repo flutter_tts |
| google_mlkit_digital_ink_recognition | ^1.0.2 | `pubspec.yaml` trong repo google_ml_kit_flutter |
| crypto | ^3.0.8 | repo `dart-lang/core` |
| path / path_provider | ^1.9.1 / ^2.1.6 | repo `dart-lang/core`, `flutter/packages` |
| flutter_lints | ^6.0.0 | `flutter/packages` |

Các số trên là bản `flutter pub get` thực tế chọn trên GitHub Actions ngày 2026-11-11
(build-2: phân tích mã không lỗi, 142 test đạt, APK arm64 107,7 MB). Dùng ràng buộc `^`
nên các lần build sau lấy bản vá mới nhất tương thích.

## Thư viện Android (Kotlin)

| Thư viện | Phiên bản | Nguồn kiểm tra |
|---|---|---|
| `com.google.ai.edge.litertlm:litertlm-android` | 0.18.0 | Trang "Build an Android app with the LiteRT-LM Kotlin API" (developer.android.com); các PR nâng cấp lên 0.18.0 trên GitHub |
| `org.apache.commons:commons-compress` | 1.27.1 | Bản ổn định đã biết; chưa đối chiếu được bản mới nhất |
| `kotlinx-coroutines-android` | 1.10.2 | Bản ổn định đã biết; chưa đối chiếu được bản mới nhất |

## Quyết định kỹ thuật

**LLM dùng API Kotlin, không dùng gói Flutter.** LiteRT-LM chỉ có API Kotlin/Java chính
thức cho Android, nên `LlmBridge.kt` gọi `Engine`, `EngineConfig`, `Conversation` qua
platform channel. Ưu tiên `Backend.GPU()`, lỗi thì `LlmService.load` tự thử lại
`Backend.CPU()`. Chưa truyền `SamplerConfig` vì tài liệu không nêu tên tham số trong
`ConversationConfig`; đang dùng cấu hình lấy mẫu mặc định của model.

**sherpa_onnx ghim ở 1.12.29.** Bản 2.0.0 có mục "Remove espeak-ng and piper-phonemize
from sherpa-onnx (#4055)". Kokoro và Piper trong app đều dựa vào `espeak-ng-data`, và
chưa thể chạy thử 2.x trên máy thật, nên ghim bản 1.x cuối cùng. API Dart dùng trong
app (`OfflineRecognizer`, `VoiceActivityDetector`, `OfflineTts`, `writeWave`) đã đối
chiếu với mã nguồn tag `v1.12.29`; các chữ ký này không đổi ở `v2.0.1`, nên việc nâng
cấp sau này chỉ cần đổi số phiên bản rồi chạy "Kiểm tra hệ thống" trong khu phụ huynh.

**sherpa-onnx chạy trong isolate riêng.** Lời gọi FFI là đồng bộ, Kokoro mất vài giây
trên CPU điện thoại. Có hai isolate: một cho nghe (VAD + Whisper), một cho đọc (Kokoro,
Piper), để việc tạo sẵn âm thanh nền không làm chậm chấm bài nói.

**Giải nén và SHA-256 làm ở Kotlin.** Gói Kokoro nặng 350 MB; giải nén bzip2 bằng Dart
thuần sẽ chậm và tốn RAM. `FilesBridge.kt` giải nén theo luồng bằng Commons Compress,
có chặn path traversal.

**Nhập model thủ công dùng trình chọn file hệ thống** (`ACTION_OPEN_DOCUMENT`), không
cần quyền bộ nhớ, chạy được với scoped storage từ Android 10.

**Chấm phát âm bằng so khớp văn bản, không dùng KWS hay wav2vec2.** Whisper chép lại
lời bé, `PronunciationScorer` so với câu mẫu (từ và ký tự, có xử lý từ rút gọn, số, từ
đệm và cửa sổ trượt cho câu trả lời dài). Ba mức độ khó có ngưỡng sao riêng trong
`AppConfig.speechStarThresholds`. Keyword spotting cần thêm gói tải và bảng từ khoá mã
hoá riêng; chấm âm vị bằng wav2vec2 cần thêm khoảng 300 MB. Cả hai chỉ nên thêm khi đo
trên giọng trẻ thật cho thấy so khớp văn bản chưa đủ.

**Kiểm thử không cần máy Android.** Phần logic (giáo trình, Leitner, chấm điểm, bộ lọc,
Bi) là Dart thuần nên `flutter test` chạy được trên CI. Riêng phần Kotlin chỉ được biên
dịch khi `flutter build apk` chạy trên GitHub Actions.

## Model: đường dẫn, dung lượng, checksum

Các gói sherpa-onnx đã tải thử thành công ngày 2026-11-10 (dung lượng và SHA-256 đo trực tiếp).

| Gói | File | Dung lượng (byte) | SHA-256 |
|---|---|---|---|
| Silero VAD | `asr-models/silero_vad.onnx` | 643 854 | `9e2449e1…cbb1fd6` |
| Whisper base.en | `asr-models/sherpa-onnx-whisper-base.en.tar.bz2` | 208 576 005 | `475bc705…df581542` |
| Whisper tiny.en | `asr-models/sherpa-onnx-whisper-tiny.en.tar.bz2` | 118 071 777 | `2bd6cf96…c20005dd` |
| Kokoro v1.0 | `tts-models/kokoro-multi-lang-v1_0.tar.bz2` | 349 886 476 | `60703707…00e0f7a4` |
| Piper vi_VN vais1000 | `tts-models/vits-piper-vi_VN-vais1000-medium.tar.bz2` | 67 154 040 | `fa136771…fa55551a` |
| Piper en_US amy (dự phòng) | `tts-models/vits-piper-en_US-amy-low.tar.bz2` | 67 095 344 | `c70f5284…dade3cf639` |

Gốc URL: `https://github.com/k2-fsa/sherpa-onnx/releases/download/`. Giá trị SHA-256 đầy
đủ nằm trong `lib/core/services/model_catalog.dart`.

Giọng Kokoro dùng trong app (id trong `kokoro-multi-lang-v1_0`): `af_heart` = 3 (Mỹ, nữ),
`am_michael` = 16 (Mỹ, nam), `bf_emma` = 21 (Anh, nữ), `bm_george` = 26 (Anh, nam).

Gemma 4 (Hugging Face `litert-community`, Apache-2.0):

| Gói | URL | Dung lượng |
|---|---|---|
| E2B | `gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm` | khoảng 2,58 GB |
| E4B | `gemma-4-E4B-it-litert-lm/resolve/main/gemma-4-E4B-it.litertlm` | khoảng 3,65 GB |

Đã đối chiếu ngày 2026-11-11 trên trang danh sách file của hai repo: `gemma-4-E2B-it.litertlm`
(2,59 GB) và `gemma-4-E4B-it.litertlm` (3,66 GB) có ở nhánh `main`, giấy phép Apache-2.0,
không yêu cầu đăng nhập. Nếu sau này máy chủ trả 401/403, app chuyển gói sang trạng thái
"Cần tải thủ công" và hướng dẫn phụ huynh nhập file.

**Chính sách checksum**

- Hugging Face: app đọc SHA-256 do máy chủ công bố (header `x-linked-etag`) và bắt buộc khớp.
- GitHub: so với giá trị ghim. Kho `tts-models` thỉnh thoảng được tải lại (gói Kokoro
  mới cập nhật ngày 2026-10-26), nên khi không khớp app vẫn cài nếu giải nén không lỗi
  (bzip2 có CRC từng khối) và đủ file bắt buộc, đồng thời ghi `checksumVerified = false`
  và hiện ghi chú cho phụ huynh trong "Quản lý model".
