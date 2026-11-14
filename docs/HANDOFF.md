# Bàn giao cho phiên Claude mới: Ong Bi English

Tài liệu này tóm tắt những gì đã làm trong phiên trước để một phiên Claude mới (chạy trong ứng dụng Claude
trên máy tính, có trình duyệt) làm tiếp được ngay. Việc đang dở: **vẽ tranh minh hoạ truyện trên cinai.tv**.

## 1. Dự án

- Repo: `github.com/thanhphong8808/ong-bi-english`, nhánh `main`.
- App Android Flutter học tiếng Anh cho một bé 6 tuổi người Việt. Chạy offline, miễn phí 100%.
  Giao diện và README viết bằng tiếng Việt, comment trong code viết bằng tiếng Anh.
- Công nghệ: Flutter 3.47 / Dart 3.13, `material_ui`, Riverpod 3, go_router, drift dùng SQL thuần
  (bảng `settings` lưu theo từng hồ sơ), sherpa_onnx (Whisper + Silero VAD), TTS Kokoro/Piper, just_audio.
  "Bộ não" của Bi là Gemma 4 E2B/E4B bản instruct chính thức, chạy bằng LiteRT-LM 0.18 qua
  `android/.../LlmBridge.kt`. Gemma nghe được audio trực tiếp và dùng MTP speculative decoding.
- CI ở `.github/workflows/build-apk.yml`, gồm các job: build → speech → smoke → release.
  - Job smoke chạy trên máy ảo API 35 có Gemma E2B, dùng `tool/ci/smoke_test.sh` và `tool/ci/ui.py`.
    Ảnh chụp màn hình được in ra log dạng base64 giữa `BEGIN_PNG <tên>` và `END_PNG`.
  - Job release tạo tag `build-<n>` và đính kèm `OngBiEnglish-arm64-v8a.apk`.
- Chữ ký APK: SHA-256 của chứng chỉ bắt đầu bằng `5756fa3cdd552ea8`. Khoá ký nằm trong GitHub Secrets.
  **Không bao giờ commit khoá ký vào repo** (repo này công khai).
- Bản mới nhất: **build-30** (commit `66eb303`). CI xanh toàn bộ, smoke test có Gemma trả lời thật.

## 2. Ràng buộc bắt buộc (không được phá)

- Miễn phí 100%: không API trả phí, không cloud, không tài khoản, không quảng cáo, không mua trong app,
  không analytics hay tracking. Quyền INTERNET chỉ dùng để tải model, và chỉ khi phụ huynh bấm.
- Không link ra ngoài, không trình duyệt, không chat với người thật, không nội dung do người khác tải lên.
  Có lớp lọc an toàn ở cả đầu vào và đầu ra của LLM.
- File ghi âm tự xoá sau 7 ngày.
- Chỉ dùng bản instruct chính thức của Gemma 4. Cấm dùng các bản "uncensored" hoặc "abliterated".
- Nội dung (truyện, câu thoại, tranh) do dự án tự soạn. Không dùng nhân vật hay tác phẩm có bản quyền.
- Email của chủ dự án là thông tin riêng tư, không đưa vào repo hay gửi cho dịch vụ ngoài.

## 3. Cách chủ dự án (anh Thanh Phong) muốn làm việc

- Làm luôn, ít bàn. Gom các sửa đổi lại rồi đẩy một lần, tránh vá lặt vặt nhiều lần.
- "Kiểm tra hết lỗi trước khi đưa cho tôi": chỉ giao khi CI xanh và đã tự xem ảnh chụp từ smoke test.
- Trả lời bằng tiếng Việt. Giao kết quả dùng được ngay: link release, ảnh xem trước.

## 4. Tranh minh hoạ (cinai.tv): đã làm phần lớn

Làm bằng **GPT Image 2.5** trên cinai.tv (đang miễn phí, không tốn credit), thao tác trong trình duyệt của
ứng dụng Claude. Chủ dự án tự đăng nhập.

**Tranh truyện: xong đủ 123 ảnh** (23 bìa + 100 cảnh) trong `assets/story_art/`.
- Model từ chối prompt "Character sheet", nên mỗi truyện tạo **ảnh bìa trước**, rồi bấm "Remix with this image"
  trên ảnh bìa để làm ảnh tham chiếu cho từng cảnh ("Same characters … New scene: …").
- Cảnh nào nhân vật chưa xuất hiện thì ghi "No wolf / No bear … in this picture" (ảnh bìa có đủ nhân vật).
- Chạy tối đa khoảng 5 ảnh cùng lúc. Chạy nhiều hơn thì cinai.tv báo "Failed to fetch" hoặc **gắn nhầm ảnh của
  thẻ này sang thẻ khác**, nên phải xem lại từng ảnh trước khi nhập.

**Ảnh từ vựng: xong, 795 ảnh cho 815 từ** (20 từ chỉ số cố ý dùng emoji) trong `assets/word_art/` (`lib/widgets/item_picture.dart`: có ảnh thì dùng ảnh,
không thì emoji như cũ).
- Bộ prompt: `docs/WORD_ART.md`, `tool/word_art/prompts.json` (93 bảng lưới 3×3, ảnh vuông 1:1, 1K).
- `python3 tool/word_art/import_art.py <thư mục>` tự cắt mỗi bảng thành 9 ảnh WebP 448 px.
- Các từ chỉ số (zero…twenty) cố ý giữ emoji vì AI hay vẽ sai số lượng.
**Chưa làm:** 8 tư thế 3D của Bi (`bi_<pose>`). Lưu ý: khi có ảnh 3D, `lib/widgets/bi_mascot.dart` bỏ các món đồ
(outfit) mà bé mở khoá theo cấp, vì chúng chỉ vẽ chồng lên Bi bản SVG. Cần chủ dự án quyết trước khi làm.

## 5. Đã làm xong (build 27–30)

- **Chat với Bi**:
  - Gemma nghe giọng bé, trả lời theo ngữ cảnh, sửa câu nhẹ nhàng.
  - Câu trả lời dùng các thẻ HEARD, FIX, BI, VI, EASY, SAY ×3, NOTE, TEACH.
  - Mỗi chủ đề có câu mở đầu soạn sẵn (`BiChat.topicOpener` trong `lib/features/talk_with_bi/bi_chat.dart`).
  - Có 4 nút trợ giúp: Gõ chữ, Nói thế nào?, Hỏi Bi, Nói chậm. Khi bé im lặng, Bi hỏi lại dễ hơn.
- **Sổ tay của Bi** (`lib/curriculum/bi_notes.dart`):
  - Bi nhớ sở thích của bé và nhắc lại ở câu mở đầu.
  - Ghi chú NOTE của model chỉ được giữ khi đúng là điều bé đã nói. Nếu không, Bi đọc thẳng câu "I like …"
    của bé. Tên con vật được lưu ở số nhiều.
- **Chào Bi mỗi ngày**: 3 phút trò chuyện buổi sáng, cuối buổi giao nhiệm vụ cho bé.
- **Câu bỏ túi**: 52 câu, luyện theo phương pháp Leitner.
- **Khu phụ huynh**: tổng quan tuần, biểu đồ số phút học, gợi ý 3 câu cho cả nhà dùng trong tuần,
  xem Sổ tay của Bi, bộ từ riêng của bố mẹ.
- Giao diện mới theo màu mật ong, thẻ bo tròn mềm.
- `PillButton` giờ có node trợ năng riêng, để TalkBack và smoke test bấm đúng nút nằm trong thẻ.
- Smoke test cuộn để tìm từng mục trong Khu phụ huynh (lệnh `ui.py seek`). Smoke test kiểm tra Sổ tay
  (phải ghi "cat", không được ghi "toys") và kiểm tra lượt luyện Câu bỏ túi có lưu kết quả.

## 6. Ghi chú

- Muốn dùng Chat với Bi, phụ huynh phải tải bộ não Gemma trước, trong Khu phụ huynh → Quản lý model.
- Ở cấp 0, bài học mỗi ngày vẫn có phần tập viết chữ cái.
- Thêm `[skip ci]` vào commit chỉ sửa tài liệu, để khỏi build lại.
