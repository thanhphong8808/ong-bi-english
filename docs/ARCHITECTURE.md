# Kiến trúc

## Tổng quan

```
UI (features/)  ──►  AppServices (core/providers.dart)
                        ├─ AppDatabase (drift / SQLite)
                        ├─ DeviceProfile        ◄─ DeviceBridge.kt
                        ├─ ModelDownloader      ◄─ FilesBridge.kt   (nơi duy nhất dùng mạng)
                        ├─ SttService  ──► SherpaWorker "ongbi-stt" (isolate): Silero VAD + Whisper
                        ├─ TtsEnService ─┐
                        ├─ TtsViService ─┴► SherpaWorker "ongbi-tts" (isolate): Kokoro, Piper
                        ├─ AudioCache ──► SpeechOutput (just_audio)
                        ├─ LlmService           ◄─ LlmBridge.kt (LiteRT-LM, Gemma 4)
                        ├─ InkService (ML Kit Digital Ink)
                        └─ ContentFilter (logic thuần, không phụ thuộc LLM)
```

`main()` dựng `AppServices` một lần, đọc cài đặt phụ huynh, rồi chọn màn đầu:
`/setup` nếu chưa cài xong, ngược lại `/home`.

## Ràng buộc và nơi thực thi

| Ràng buộc | Thực thi ở đâu |
|---|---|
| Offline sau lần cài đầu | `ModelDownloader` là lớp duy nhất mở kết nối HTTP. Tải gói ML Kit chữ viết tay cũng chỉ gọi từ màn Cài đặt lần đầu. Manifest tắt cleartext. |
| Chỉ tải qua Wi‑Fi | `DeviceBridge.isUnmeteredNetwork` kiểm tra trước mỗi lần tải và mỗi lần thử lại |
| Phụ huynh mới được tải | Mọi nút tải/nhập ở `SetupScreen` gọi `showParentGate` trước |
| Học cốt lõi không cần LLM | Gói Gemma đánh dấu `optional`; `main()` chỉ kiểm tra gói bắt buộc; `LlmService` chỉ được gọi từ "Nói chuyện với Bi" và "Kiểm tra hệ thống" |
| LLM chỉ nạp khi cần | `LlmService.load` khi vào màn, `unload` trong `dispose`/`finally` |
| An toàn nội dung | `ContentFilter.checkInput` / `checkOutput` chạy trước khi đọc bất kỳ câu nào của LLM |
| Không link ra ngoài | App không có `url_launcher`, không có WebView. Địa chỉ tải thủ công chỉ là chữ |
| Riêng tư | `RecordingJanitor.purge` chạy mỗi lần mở app; `allowBackup="false"` |
| Mọi ngưỡng ở một chỗ | `lib/core/config/app_config.dart` |
| Chuỗi tiếng Việt | `lib/l10n/strings_vi.dart` |

## Cầu nối Kotlin

| Kênh | File | Việc |
|---|---|---|
| `ongbi/device` | `DeviceBridge.kt` | RAM, chip, tần số lõi CPU, OpenCL, loại mạng, bộ nhớ trống |
| `ongbi/files` + `ongbi/files/progress` | `FilesBridge.kt` | Giải nén `.tar.bz2`, SHA-256, nhập model thủ công, lưu file vào Download (sao lưu, giấy khen), đọc file sao lưu |
| `ongbi/llm` + `ongbi/llm/stream` | `LlmBridge.kt` | Nạp model, tạo hội thoại, trả lời dạng luồng, huỷ, giải phóng |
| `ongbi/reminder` | `ReminderBridge.kt` + `ReminderReceiver.kt` | Thông báo nhắc giờ học (AlarmManager, đặt lại sau khi khởi động máy) |

## Luồng một buổi học

1. `HomeScreen` hỏi `StudyClock` còn được học không (giới hạn phút, khung giờ). Hết giờ
   thì sang `SleepScreen`.
2. `ProgressService` đọc `ProgressSnapshot` (Leitner, unit, hội thoại, lượt làm bài).
3. `LessonComposer.compose` chọn loại bài theo trạng thái unit:
   `learning` (từ mới) → `review` (ôn cả unit) → `test` (kiểm tra unit, đạt 80%) →
   `waitRetake` (trượt: ôn, làm lại từ hôm sau) / `remedial` (học lại mục sai) → `done`.
   Hết unit của cấp → thi lên cấp (`TestBuilder.levelTest`, 75% và mỗi phần ≥ 60%);
   trượt thì ôn tập vài ngày rồi thi lại.
4. Mỗi bước là một `LessonStep` (`lesson_plan.dart`); `activity_factory.dart` chọn màn
   hoạt động tương ứng. Bước nào cần micro, mô hình chữ viết hay khả năng đọc chữ chỉ
   được tạo khi thiết bị và cài đặt cho phép (`ComposerOptions`).
5. `ProgressService.completeLesson` ghi kết quả từng bước vào Leitner, cộng sao, mở
   hình dán, chấm bài kiểm tra bằng `TestGrader` (không dùng LLM).

## Giao thức SherpaWorker## Giao thức SherpaWorker

Thông điệp là `Map`. Lệnh có `id` sẽ nhận trả lời `{id, result}` hoặc `{id, error}`;
sự kiện không có `id` đi vào `SherpaWorker.events`.

| Lệnh | Ý nghĩa |
|---|---|
| `stt.init` | Nạp Whisper và Silero VAD |
| `stt.begin` | Bắt đầu một lượt nghe (tuỳ chọn `savePath` để lưu giọng bé) |
| `stt.chunk` | Gửi PCM16 16 kHz. Phát sự kiện `level`, `speechStart`; khi VAD thấy bé ngừng nói thì phát `final {text, speechMs, wavPath}` |
| `stt.end` | Hết giờ chờ: chốt phần đã nghe và phát `final` |
| `tts.init` / `tts.synth` / `tts.release` | Nạp giọng, tổng hợp ra file WAV, giải phóng |

## Cơ sở dữ liệu (schema v1)

drift dùng ở chế độ SQL thuần, không sinh mã: `schema.dart` chứa câu lệnh `CREATE TABLE`,
`app_database.dart` mở SQLite và chạy migration, `repositories.dart` chứa các lớp dữ
liệu và truy vấn (`customSelect`, `customInsert`, `customUpdate`). Không cần `build_runner`.

| Bảng | Nội dung |
|---|---|
| `profiles` | Hồ sơ bé (tối đa 3): tên, cấp, sao, đã làm kiểm tra đầu vào chưa |
| `settings` | Cài đặt dạng khoá–giá trị (`profile_id = 0` là cài đặt chung) |
| `item_progress` | Trạng thái Leitner theo từng mục và từng kỹ năng |
| `attempts` | Từng lượt trả lời (biểu đồ tuần, mục hay sai) |
| `unit_progress` | Số buổi đã học, đã ôn, đã đạt, điểm cao nhất, lần kiểm tra cuối, cần học lại |
| `dialogue_progress` | Giai đoạn luyện của từng hội thoại mẫu |
| `study_days` | Số giây học mỗi ngày (giới hạn thời gian, biểu đồ) |
| `test_results` | Lịch sử kiểm tra đầu vào, unit, lên cấp |
| `audio_cache` | File âm thanh đã tổng hợp |
| `recordings` | Ghi âm của bé (tự xoá sau thời hạn) |
| `chat_logs` | Nhật ký "Nói chuyện với Bi", có cờ an toàn |
| `model_installs` | Gói model đã cài, SHA-256, đã kiểm tra hay chưa |
| `rewards` | Hình dán đã nhận |

Migration: tăng `DbSchema.version` và thêm danh sách câu lệnh vào `DbSchema.upgrades`
(khoá là phiên bản xuất phát). Sao lưu/khôi phục (`BackupService`) xuất các bảng tiến
độ ra JSON, có số phiên bản để từ chối file của bản app mới hơn.

## Định dạng giáo trình

Nội dung gốc viết tay ở `tool/content_src/L0.txt`–`L5.txt` (mỗi dòng một từ, mẫu câu,
hội thoại, bài đọc, ghi chú ngữ pháp, câu mở đầu bài viết). `tool/build_curriculum.py`
dựng thành `assets/curriculum/level_N/LNUxx.json` và `assets/curriculum/index.json`,
tự sinh ngân hàng câu hỏi (ít nhất 30 câu mỗi unit), phiên âm và gán kỹ năng. Từ đã
dạy ở unit trước không bị dạy lại thành mục mới (trừ từ nhiều nghĩa trong `POLYSEMOUS`).

| Trường | Ý nghĩa |
|---|---|
| `items[].type` | `word`, `phrase`, `sound`, `letter` |
| `items[].image` | `emoji` (mã hex) hoặc `svg` (file trong `assets/svg/`); `picturable = false` với từ trừu tượng |
| `items[].skills` | Tập con của `listen`, `speak`, `read`, `write` |
| `readings[]` | Bài đọc (từ Level 2) và câu hỏi đọc hiểu |
| `grammar`, `writing[].starters` | Ghi chú ngữ pháp tiếng Việt và câu mở đầu cho bài viết (từ Level 3) |
| `quiz_bank[].kind` | `pick_image`, `pick_meaning`, `pick_word`, `say_word`, `repeat_sentence`, `answer_question`, `true_false`, `fill_blank`, `color_item`, `trace_letter`, `write_letter`, `copy_word`, `dictate_word`, `dictate_sentence`, `read_question`, `letter_sound` |

`tool/validate_curriculum.dart` (chạy trong CI) kiểm tra: schema, id trùng, đáp án nằm
trong lựa chọn, mã emoji hợp lệ (bước dựng còn kiểm tra emoji có trong font Noto), SVG tồn tại, hội thoại 4–8 lượt với đúng 2 vai,
ít nhất 30 câu hỏi mỗi unit, số unit mỗi cấp, từ bị dạy lặp, và mỗi câu ví dụ, câu hội
thoại, câu bài đọc có tối đa 1 từ chưa học (tính theo thứ tự unit). Từ chức năng được
coi là đã biết nằm ở `basicWords` (`lib/curriculum/basic_words.dart`, giữ đồng bộ với
validator).

## Kiểm thử (`flutter test`)

| File | Kiểm tra |
|---|---|
| `leitner_scheduler_test.dart` | 7 hộp, khoảng cách ngày, sai về hộp 1, điều kiện "đã thuộc" theo cấp |
| `pronunciation_scorer_test.dart` | Chấm phát âm (rút gọn, số, từ đệm, độ khó), chính tả |
| `trace_scorer_test.dart` | Tô đúng cả 52 chữ, tay run vẫn đạt, sai hướng, sai thứ tự, thiếu nét, lệch xa |
| `lesson_composer_test.dart` | Chạy LessonComposer và TestBuilder qua cả 80 unit, mọi giai đoạn, có/không micro, có/không mô hình chữ viết, hoãn đọc chữ; mỗi bước phải hiển thị được |
| `test_grader_test.dart` | Ngưỡng 80%, 75%, sàn 60% mỗi phần, xếp lớp đầu vào |
| `bi_safety_test.dart` | Bộ test an toàn cho Bi với mô hình giả: lời bé buồn/sợ/thô tục không tới LLM; lời LLM có link, số điện thoại, địa chỉ, giữ bí mật, từ bạo lực… không bao giờ được đọc; tối đa 2 câu, kết thúc bằng câu hỏi; LLM lỗi vẫn có câu dự phòng |
| `content_filter_test.dart` | Bộ lọc đầu vào và đầu ra |
| `assets_test.dart` | Mọi file giáo trình, SVG, font đều có và được khai báo trong `pubspec.yaml` |
| `device_profile_test.dart`, `model_catalog_test.dart` | Chọn model theo RAM, chỉ dùng Gemma 4 instruct chính thức |
| `parent_gate_test.dart`, `pcm_and_cache_test.dart` | Cổng phụ huynh, mã PIN, cài đặt, xử lý âm thanh |
