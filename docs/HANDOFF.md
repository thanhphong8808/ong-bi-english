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

## 4. Việc đang dở: tranh minh hoạ truyện trên cinai.tv

Chủ dự án đã quyết định:
- Claude tự thao tác cinai.tv trong trình duyệt của ứng dụng Claude trên máy tính.
- Chủ dự án tự đăng nhập. Claude không nhập mật khẩu hộ.
- Mỗi truyện có 1 bìa và 4–6 cảnh.

**Bộ prompt** (đã viết xong, có sẵn trong repo):
- `docs/STORY_ART.md`: hướng dẫn tiếng Việt kèm toàn bộ prompt.
- `tool/story_art/prompts.json`: các trường `file`, `prompt`, `negative`, `kind`.

Tổng cộng 154 ảnh:
- 23 bảng nhân vật, tên `<story>_cast`. Chỉ dùng làm ảnh tham chiếu, không đưa vào app.
- 123 cảnh, tên `<story>_NN`, trong đó `00` là bìa.
- 8 tư thế của Bi, tên `bi_<pose>`. App hiện chỉ dùng 5 tư thế: `happy, listening, thinking, cheering, sleeping`
  (xem `enum BiMood` trong `lib/widgets/bi_mascot.dart`). Ba tư thế `reading, talking, hello` chưa dùng,
  có thể làm sau.

**Phong cách:** minh hoạ sách tranh thiếu nhi, nhìn như hoạt hình 3D mềm mại, tông vàng mật ong và pastel,
theo ảnh mẫu Learnly mà chủ dự án đã gửi. Câu mô tả phong cách và negative prompt đã có sẵn trong từng prompt.
Ảnh ngang tỉ lệ 16:10 (ví dụ 1536×960), không có chữ, không logo.

**Thứ tự làm:**
1. Mở `https://cinai.tv` và chờ chủ dự án đăng nhập. Công cụ tạo ảnh từ chữ nằm ở `/image`. Trang này còn có
   skill "character-refs" để giữ nhân vật đồng nhất.
2. **Làm thử một truyện: `tortoise_hare` (Rùa và Thỏ).**
   - Tạo `tortoise_hare_cast` trước và chọn bản đẹp nhất.
   - Dùng bản đó làm ảnh tham chiếu để tạo `tortoise_hare_00` … `_05`.
   - Gửi chủ dự án xem phong cách và báo mỗi ảnh tốn bao nhiêu credit. **Chờ chủ dự án đồng ý** rồi mới làm tiếp,
     vì tạo ảnh tốn credit của chủ dự án.
3. Làm 22 truyện còn lại theo cùng cách: tạo bảng nhân vật trước, rồi đến các cảnh.
4. Làm các tư thế của Bi, dùng Remove Background để có PNG nền trong suốt.
5. Tải ảnh về, đặt đúng tên file, rồi chạy:
   `python3 tool/story_art/import_art.py <thư mục ảnh>`
   Lệnh này tự cắt ảnh về 16:10, nén WebP 1280×800 vào `assets/story_art/`, và đưa ảnh Bi (WebP 768 px, giữ nền
   trong suốt) vào `assets/bi3d/`. Bảng nhân vật tự được bỏ qua.
   App tự hiện tranh khi có file (`lib/widgets/story_art.dart`: `StoryScene` có hiệu ứng Ken Burns và cảnh
   chuyển mờ dần; thiếu tranh thì hiện emoji thay thế). Không cần sửa code.
6. Commit rồi push lên `main` để CI build. Kiểm tra trong log smoke:
   - Ảnh chụp `13-story-start` và `13-story-end` phải có tranh.
   - Phải có dòng `SMOKE TEST: OK`.
   - Kích thước APK hiện khoảng 105 MB; 123 ảnh WebP thêm chừng 10–20 MB.
   Xong thì gửi chủ dự án link release `build-<n>` và một ảnh xem trước.

Nếu không có trình duyệt: chủ dự án tự tạo ảnh theo `docs/STORY_ART.md`, nén thành zip gửi lên, rồi chạy bước 5.

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
