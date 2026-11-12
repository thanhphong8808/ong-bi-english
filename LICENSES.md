# Giấy phép các thành phần

Ong Bi English chỉ dùng thư viện, model và font miễn phí. Không có API trả phí,
quảng cáo, mua trong app, analytics hay tracking.

Mã nguồn và nội dung của chính app (code, linh vật Bi, giáo trình) là sản phẩm
tự sáng tác của dự án này. Giáo trình không dùng nhân vật, bài hát hay văn bản có bản
quyền của người khác. Vài bài ở Level 5 kể lại theo lời văn riêng các truyện dân gian
và ngụ ngôn đã thuộc phạm vi công cộng (sự tích quả dưa hấu, chàng tiều phu và chiếc
rìu, con cáo và con quạ, chú vịt con xấu xí).

## Thư viện đóng gói trong APK

| Thành phần | Dùng để | Giấy phép |
|---|---|---|
| Flutter, Dart SDK | Khung ứng dụng | BSD-3-Clause |
| flutter_riverpod | Quản lý trạng thái | MIT |
| go_router | Điều hướng | BSD-3-Clause |
| drift, drift_flutter, sqlite3 | Cơ sở dữ liệu SQLite | MIT (SQLite: public domain) |
| path, path_provider, crypto | Tiện ích | BSD-3-Clause |
| sherpa_onnx (sherpa-onnx, ONNX Runtime) | Nhận dạng và tổng hợp giọng nói | Apache-2.0 (ONNX Runtime: MIT) |
| record | Ghi âm | BSD-3-Clause |
| just_audio | Phát âm thanh | MIT |
| flutter_svg | Vẽ SVG | MIT |
| flutter_tts | Giọng hệ thống Android (dự phòng tiếng Việt) | MIT |
| google_mlkit_digital_ink_recognition | Cầu nối Flutter tới ML Kit | MIT |
| Google ML Kit Digital Ink Recognition | Nhận dạng chữ viết tay trên máy | Miễn phí theo Điều khoản ML Kit của Google (không phải mã nguồn mở) |
| LiteRT-LM (`litertlm-android`) | Chạy Gemma 4 trên máy | Apache-2.0 |
| Apache Commons Compress | Giải nén `.tar.bz2` | Apache-2.0 |
| kotlinx.coroutines | Xử lý bất đồng bộ Kotlin | Apache-2.0 |

## Dữ liệu đóng gói trong APK

| Dữ liệu | Dùng để | Giấy phép |
|---|---|---|
| CMU Pronouncing Dictionary (gói `cmudict` 1.1.3, `assets/pron/ipa_en_us.txt.gz`, chuyển sang IPA bằng `tool/pron/build_ipa_dict.py`) | Phiên âm dưới chữ tiếng Anh | BSD-2-Clause, Copyright (C) 1993-2015 Carnegie Mellon University (`assets/pron/CMUDICT-LICENSE.txt`) |

## Font đóng gói trong APK

| Font | Dùng để | Giấy phép |
|---|---|---|
| Nunito | Giao diện | SIL OFL 1.1 (`assets/fonts/Nunito-OFL.txt`) |
| Andika | Chữ mẫu tập viết (a, g một tầng) | SIL OFL 1.1 (`assets/fonts/Andika-OFL.txt`) |
| Noto Color Emoji | Hình minh hoạ từ vựng | SIL OFL 1.1 (`assets/fonts/NotoColorEmoji-OFL.txt`) |

## Model tải về ở lần cài đầu (không nằm trong APK)

| Gói | Nguồn | Giấy phép |
|---|---|---|
| Silero VAD | GitHub Releases của sherpa-onnx | MIT |
| Whisper base.en / tiny.en (ONNX int8) | GitHub Releases của sherpa-onnx | MIT (OpenAI) |
| Kokoro-82M v1.0 (`kokoro-multi-lang-v1_0`) | GitHub Releases của sherpa-onnx | Apache-2.0 |
| Piper `vi_VN-vais1000-medium` | GitHub Releases của sherpa-onnx | Piper: MIT. Dữ liệu giọng VAIS-1000: CC BY 4.0 |
| Piper `en_US-amy-low` (dự phòng, tuỳ chọn) | GitHub Releases của sherpa-onnx | Piper: MIT. Xem `MODEL_CARD` trong gói |
| Gemma 4 E2B / E4B instruct (`.litertlm`) | Hugging Face `litert-community` | Apache-2.0 (Google) |

Ghi chú:

- Các gói Kokoro và Piper có kèm thư mục `espeak-ng-data` (dữ liệu phát âm của
  eSpeak NG, giấy phép GPL-3.0). Dữ liệu này được tải về máy cùng model, không
  đóng gói trong APK.
- Ghi công giọng tiếng Việt theo CC BY 4.0: bộ dữ liệu VAIS-1000 (Vietnamese
  Speech Synthesis Corpus), huấn luyện bởi dự án Piper.
- Chỉ dùng bản Gemma 4 instruct chính thức. Không dùng bản "uncensored" hay
  "abliterated"; test `test/model_catalog_test.dart` kiểm tra điều này.
