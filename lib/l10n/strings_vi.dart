// lib/l10n/strings_vi.dart
//
// Every Vietnamese string shown or spoken by the app lives here.

class S {
  const S._();

  static const appName = 'Ong Bi English';

  // ---- Common ----
  static const ok = 'Đồng ý';
  static const cancel = 'Huỷ';
  static const back = 'Quay lại';
  static const retry = 'Thử lại';
  static const close = 'Đóng';
  static const save = 'Lưu';
  static const delete = 'Xoá';
  static const continueLabel = 'Tiếp tục';
  static const loading = 'Đang chuẩn bị…';
  static const listenAgain = 'Nghe lại';

  // ---- Home (kid mode) ----
  static const homeLearn = 'Học hôm nay';
  static const homeTalk = 'Nói chuyện với Bi';
  static const homeWrite = 'Tập viết';
  static const homeParent = 'Phụ huynh';
  static const homeGreetingSpoken =
      'Chào cậu! Tớ là Bi. Cậu bấm vào hình quyển sách để học cùng tớ nhé!';
  static const soonSpoken =
      'Tớ đang chuẩn bị phần này cho cậu. Hẹn gặp cậu ở lần cập nhật tới nhé!';
  static const soonTitle = 'Bi đang chuẩn bị';
  static const soonBody = 'Phần này sẽ có ở bản cập nhật tiếp theo.';
  static const talkDisabledSpoken = 'Hôm nay mình học bài nhé! Lần khác mình nói chuyện sau.';

  // ---- First-time setup ----
  static const setupTitle = 'Cài đặt lần đầu';
  static const setupForParents = 'Phần này dành cho bố mẹ';
  static const setupIntro =
      'Ong Bi cần tải giọng đọc và bộ nghe về máy một lần. Sau đó app chạy hoàn toàn '
      'không cần mạng. Hãy kết nối Wi‑Fi trước khi tải.';
  static const setupDevice = 'Máy của bạn';
  static const setupTotal = 'Tổng dung lượng cần tải';
  static const setupDownloadAll = 'Tải tất cả qua Wi‑Fi';
  static const setupDownloading = 'Đang tải…';
  static const setupContinue = 'Vào học';
  static const setupRequired = 'Bắt buộc';
  static const setupOptional = 'Tuỳ chọn';
  static const setupImport = 'Nhập file đã tải sẵn';
  static const setupDownloadOne = 'Tải';
  static const setupInk = 'Nhận dạng chữ viết tay';
  static const setupInkPurpose = 'Dùng cho phần tập viết từ (khoảng 20 MB)';
  static const setupSkipOptional =
      'Gói tuỳ chọn có thể tải sau trong khu phụ huynh. Bài học vẫn chạy đầy đủ khi thiếu gói này.';
  static const setupManualTitle = 'Tải thủ công';
  static const setupManualBody =
      'Nếu không tải được trong app: dùng máy tính hoặc trình duyệt của điện thoại mở địa chỉ '
      'dưới đây, tải đúng file có tên bên dưới vào thư mục Download, rồi bấm '
      '"Nhập file đã tải sẵn" và chọn file đó.';
  static const setupManualFile = 'Tên file';
  static const setupManualPage = 'Địa chỉ trang tải';
  static const setupApproxPrefix = 'khoảng ';

  static const phaseMissing = 'Chưa tải';
  static const phaseDownloading = 'Đang tải';
  static const phaseVerifying = 'Đang kiểm tra file';
  static const phaseExtracting = 'Đang giải nén';
  static const phaseImporting = 'Đang nhập file';
  static const phaseInstalled = 'Đã sẵn sàng';
  static const phaseFailed = 'Chưa tải được';
  static const phaseNeedsManual = 'Cần tải thủ công';
  static const checksumUnverified =
      'File dùng được nhưng mã kiểm tra khác bản đã ghi nhận (nhà phát hành có thể đã cập nhật).';

  static const errNoWifi = 'Chưa kết nối Wi‑Fi. App chỉ tải qua Wi‑Fi để không tốn dữ liệu di động.';
  static const errNoSpace = 'Máy không đủ bộ nhớ trống. Hãy xoá bớt ảnh hoặc app rồi thử lại.';
  static const errLogin =
      'Trang tải yêu cầu đăng nhập. Hãy tải thủ công rồi bấm "Nhập file đã tải sẵn".';
  static const errNetwork = 'Mạng bị gián đoạn. Bấm tải lại, app sẽ tải tiếp từ chỗ đang dở.';
  static const errChecksum = 'File tải về bị lỗi. Hãy tải lại.';
  static const errIncomplete = 'File không đúng hoặc bị hỏng. Hãy kiểm tra tên file rồi thử lại.';
  static const errCancelled = 'Đã dừng tải.';
  static const errHttp = 'Máy chủ trả về lỗi. Hãy thử lại sau hoặc tải thủ công.';

  // ---- Parent gate ----
  static const gateTitle = 'Dành cho bố mẹ';
  static const gateQuestionPrefix = 'Bố mẹ hãy tính:';
  static const gatePinPrompt = 'Nhập mã PIN của bố mẹ';
  static const gateWrong = 'Chưa đúng, mời thử lại.';
  static const gateLocked = 'Sai nhiều lần. Vui lòng chờ một chút rồi thử lại.';
  static const gateUseMath = 'Quên mã PIN? Xoá dữ liệu app trong Cài đặt Android để đặt lại.';

  // ---- Parent area ----
  static const parentTitle = 'Khu phụ huynh';
  static const parentSettings = 'Cài đặt học';
  static const parentModels = 'Quản lý model';
  static const parentDiagnostics = 'Kiểm tra hệ thống';
  static const parentDailyLimit = 'Giới hạn mỗi ngày (phút)';
  static const parentSession = 'Độ dài một buổi học (phút)';
  static const parentHours = 'Khung giờ được học';
  static const parentVoice = 'Giọng đọc tiếng Anh';
  static const parentSlow = 'Đọc chậm (0,7x)';
  static const parentDifficulty = 'Độ khó chấm phát âm';
  static const parentTalk = 'Cho phép "Nói chuyện với Bi"';
  static const parentDelayReading = 'Hoãn đọc chữ tiếng Anh (bé đang học vần lớp 1)';
  static const parentRetention = 'Tự xoá ghi âm của bé sau (ngày)';
  static const parentPin = 'Mã PIN phụ huynh';
  static const parentPinSet = 'Đặt mã PIN 4 số';
  static const parentPinClear = 'Bỏ mã PIN (dùng phép nhân)';
  static const parentPinHint = '4 chữ số';
  static const parentPinInvalid = 'Mã PIN phải gồm đúng 4 chữ số.';
  static const parentPinSaved = 'Đã lưu mã PIN.';
  static const parentPinCleared = 'Đã bỏ mã PIN.';
  static const parentProgressSoon = 'Bảng tiến độ sẽ có sau khi bé bắt đầu học.';

  static const voiceUsFemale = 'Mỹ – nữ';
  static const voiceUsMale = 'Mỹ – nam';
  static const voiceUkFemale = 'Anh – nữ';
  static const voiceUkMale = 'Anh – nam';
  static const difficultyEasy = 'Dễ';
  static const difficultyMedium = 'Vừa';
  static const difficultyStrict = 'Chuẩn';

  // ---- Model manager ----
  static const modelsStorage = 'Dung lượng model trên máy';
  static const modelsAudioCache = 'Bộ nhớ đệm âm thanh';
  static const modelsClearCache = 'Xoá bộ nhớ đệm âm thanh';
  static const modelsCacheCleared = 'Đã xoá bộ nhớ đệm âm thanh.';
  static const modelsDelete = 'Xoá gói này';
  static const modelsRedownload = 'Tải lại';
  static const modelsLicense = 'Giấy phép';

  // ---- Diagnostics ----
  static const diagTitle = 'Kiểm tra hệ thống';
  static const diagIntro =
      'Dùng trang này để thử từng thành phần sau khi cài. Mọi thứ ở đây chạy không cần mạng.';
  static const diagEn = 'Thử giọng tiếng Anh';
  static const diagVi = 'Thử giọng tiếng Việt';
  static const diagStt = 'Thử nghe bé nói';
  static const diagSttPrompt = 'Hãy nói một câu tiếng Anh, ví dụ: "I like apples".';
  static const diagLlm = 'Thử bộ não của Bi';
  static const diagLlmMissing = 'Chưa tải gói Gemma. Các phần học khác không cần gói này.';
  static const diagMicDenied = 'App chưa được phép dùng micro. Hãy cấp quyền trong Cài đặt Android.';
  static const diagViSample = 'Chào cậu! Tớ là Bi. Mình cùng học tiếng Anh nhé!';
  static const diagEnSample = "Hi! I'm Bi. Let's learn English together!";
  static const diagRunning = 'Đang chạy…';
  static const diagHeard = 'Máy nghe được';
  static const diagNothingHeard = '(không nghe thấy gì)';
  static const diagFirstRun = 'lần đầu, chưa có trong bộ nhớ đệm';
  static const diagCached = 'đã có trong bộ nhớ đệm';
  static const diagSystemVoice = 'đang dùng giọng hệ thống của Android';
  static const diagFiltered = 'Câu trả lời bị bộ lọc thay bằng câu an toàn';

  // ---- Kid activities (spoken by Bi) ----
  static const sayRetry = 'Mình thử lại nhé!';
  static const sayEffort = 'Cậu đã cố gắng lắm rồi! Mình sẽ luyện lại sau nhé.';
  static const praiseLines = ['Giỏi lắm!', 'Tuyệt vời!', 'Đúng rồi!', 'Hay quá!', 'Cậu làm tốt lắm!'];
  static const insListenPick = 'Nghe rồi chọn hình đúng nhé!';
  static const insBubble = 'Nghe rồi chạm vào bong bóng đúng nhé!';
  static const insMatch = 'Bấm vào cái loa để nghe, rồi chọn hình giống thế nhé!';
  static const insColor = 'Nghe Bi nói rồi chọn màu đúng nhé!';
  static const insSeeSay = 'Nhìn hình rồi nói bằng tiếng Anh nhé! Bấm vào micro.';
  static const insNewItem = 'Từ mới này! Nghe Bi đọc rồi nói theo nhé.';
  static const insNewSound = 'Chữ mới này! Nghe âm của chữ nhé.';
  static const insShadow = 'Nghe Bi nói rồi nói lại cả câu nhé!';
  static const insReadPick = 'Đọc chữ rồi chọn hình đúng nhé!';
  static const insTrace = 'Tô theo nét chấm nhé! Bắt đầu từ chấm tròn.';
  static const insCopy = 'Nhìn chữ mẫu rồi viết lại nhé!';
  static const insDictate = 'Nghe Bi đọc rồi viết từ đó nhé!';
  static const insTiles = 'Chạm vào các chữ cái theo đúng thứ tự nhé!';
  static const insDialogue = 'Mình cùng đóng vai nhé! Đến lượt cậu thì bấm micro và nói.';
  static const insChoice = 'Đọc rồi chọn câu trả lời đúng nhé!';
  static const insMicDenied = 'Bố mẹ ơi, hãy cho phép app dùng micro giúp con nhé!';
  static const traceDirection = 'Nhớ đi theo mũi tên nhé!';
  static const tipFinalSound = 'Nhớ đọc cả âm cuối nhé!';
  static const hearBi = 'Nghe Bi';
  static const hearMe = 'Nghe con';
  static const next = 'Tiếp';
  static const done = 'Xong';
  static const clear = 'Xoá';
  static const keyboard = 'Bàn phím';
  static const handwriting = 'Viết tay';

  // ---- Lesson flow ----
  static const lessonLoading = 'Bi đang chuẩn bị bài…';
  static const lessonEmpty = 'Hôm nay chưa có bài mới. Mai mình học tiếp nhé!';
  static const rewardTitle = 'Hoàn thành!';
  static const rewardSpoken = 'Cậu học xong rồi! Giỏi quá! Tặng cậu một hình dán nhé.';
  static const rewardHome = 'Về nhà';
  static const sleepSpoken = 'Hôm nay mình học đủ rồi. Bi đi ngủ đây. Hẹn gặp cậu ngày mai nhé!';
  static const sleepTitle = 'Bi đi ngủ rồi';
  static const sleepBody = 'Hẹn gặp lại ngày mai nhé!';
  static String sleepParentLimit(int studied, int limit) =>
      'Dành cho bố mẹ: hôm nay bé đã học $studied phút, giới hạn là $limit phút mỗi ngày. '
      'Đổi trong Khu phụ huynh (nút bánh răng ở màn hình chính) → Cài đặt học → Giới hạn mỗi ngày.';
  static String sleepParentHours(int start, int end) =>
      'Dành cho bố mẹ: khung giờ học đang là $start:00 – $end:00. '
      'Đổi trong Khu phụ huynh (nút bánh răng ở màn hình chính) → Cài đặt học → Khung giờ được học.';
  static const outsideHoursSpoken = 'Bây giờ chưa đến giờ học. Lát nữa mình gặp nhau nhé!';
  static const writeMenuSpoken = 'Cậu muốn tô chữ nào? Chạm vào chữ đó nhé!';
  static const exitLesson = 'Nghỉ học';

  // ---- Tests ----
  static const placementSpoken = 'Mình chơi một trò để Bi biết cậu đã biết những gì nhé! Không biết cũng không sao.';
  static const placementSkip = 'Bỏ qua (dành cho bố mẹ)';
  static const unitTestSpoken = 'Hôm nay mình làm bài kiểm tra nhỏ nhé! Cậu cứ bình tĩnh.';
  static const levelTestSpoken = 'Hôm nay là bài thi lên cấp! Bi tin là cậu làm được.';
  static const testPassedSpoken = 'Chúc mừng cậu! Cậu đã qua bài kiểm tra rồi!';
  static const testRetrySpoken = 'Cậu đã cố gắng lắm! Mình ôn thêm một chút rồi thử lại nhé.';
  static const levelUpSpoken = 'Tuyệt vời! Cậu đã lên cấp mới rồi! Bi cũng lớn hơn rồi này!';
  static const levelUpTitle = 'Lên cấp!';
  static const testDoneTitle = 'Xong bài kiểm tra!';
  static const certificateTitle = 'GIẤY KHEN';
  static const certificateBody = 'đã hoàn thành xuất sắc';
  static const certificateSave = 'Lưu giấy khen (dành cho bố mẹ)';
  static const certificateSaved = 'Đã lưu giấy khen vào thư mục Download.';
  static const sectionListen = 'Nghe';
  static const sectionReadWrite = 'Đọc và viết';
  static const sectionSpeak = 'Nói';
  static const sectionHandwriting = 'Viết tay';
  static const examinerName = "What's your name?";
  static const examinerAge = 'How old are you?';

  // ---- Microphone ----
  static const iSaidIt = 'Con nói rồi';
  static const micLabel = 'Micro';

  // ---- More activity instructions ----
  static const insPickMeaning = 'Nghe Bi đọc rồi chọn nghĩa tiếng Việt đúng nhé!';
  static const insLetterSound = 'Nghe các từ rồi chọn chữ cái của âm đầu nhé!';
  static const insTrueFalse = 'Đọc câu rồi nhìn hình. Đúng thì chọn ngón tay cái hướng lên, sai thì chọn hướng xuống nhé!';
  static const insFillBlank = 'Chọn từ còn thiếu trong câu nhé!';
  static const pickColorFirst = 'Cậu chọn một màu trước nhé!';

  static const insNewSoundNoLetter = 'Âm mới này! Nghe Bi đọc các từ rồi nói theo nhé.';
  static const insAnswer = 'Nghe Bi hỏi rồi trả lời bằng tiếng Anh nhé!';
  static const meaningPrefix = 'Nghĩa là:';
  static const saySayAfter = 'Đến lượt cậu! Bấm micro rồi nói nhé.';

  static const insWriteLetter = 'Nghe Bi đọc chữ cái rồi viết vào ô nhé!';
  static const insTilesListen = 'Nghe Bi đọc rồi chạm các chữ cái theo đúng thứ tự nhé!';
  static const insWriteSentences = 'Viết vài câu về chủ đề này nhé! Có thể bắt đầu bằng câu gợi ý.';
  static const writeMoreSentences = 'Cậu viết thêm một vài câu nữa nhé!';
  static const addSentence = 'Thêm câu';

  static const insDialogueListen = 'Nghe các bạn nói chuyện nhé!';
  static const insDialogueShadow = 'Nghe từng câu rồi nói theo nhé!';
  static const insDialogueRole = 'Mình cùng đóng vai nhé! Cậu chọn vai nào? Chạm vào một bạn.';
  static const insDialogueVariation = 'Bây giờ mình đổi từ một chút. Nhìn hình rồi nói câu mới nhé!';

  // ---- Lesson intros ----
  static String lessonIntro(String topic) =>
      topic.isEmpty ? 'Mình cùng học bài mới nhé!' : 'Hôm nay mình học chủ đề: $topic!';
  static const reviewIntro = 'Hôm nay mình ôn lại cả bài nhé!';
  static const remedialIntro = 'Mình luyện lại những từ còn khó nhé!';
  static const practiceIntro = 'Mình cùng luyện tập cho thật giỏi nhé!';
  static const levelReviewIntro = 'Mình ôn tập để chuẩn bị thi lại nhé!';
  static const exitConfirmSpoken = 'Cậu muốn nghỉ à? Chạm ngôi nhà để về, hoặc nút xanh để học tiếp nhé.';
  static const stickerAlbumSpoken = 'Đây là bộ hình dán của cậu!';
  static const placementDoneLevel0 = 'Cảm ơn cậu! Mình bắt đầu từ những bài vui nhất nhé!';
  static const placementDoneLevel1 = 'Cậu biết nhiều từ quá! Mình học tiếp ở cấp Starters nhé!';
  static const levelTestRetrySpoken = 'Cậu đã cố gắng rất nhiều! Mình ôn thêm một tuần rồi thi lại nhé.';
  static const certificateAwardedTo = 'Chứng nhận bạn nhỏ';
  static const certificateFailed = 'Chưa lưu được giấy khen. Hãy thử lại.';
  static String certificateDate(DateTime d) => 'Ngày ${d.day} tháng ${d.month} năm ${d.year}';

  // ---- Writing home ----
  static const writeHomeSpoken = 'Cậu muốn tô chữ cái hay viết từ? Chạm vào một nút nhé!';
  static const writeLetters = 'Tô chữ cái';
  static const writeWords = 'Viết từ';
  static const writeNoWordsYet = 'Mình học thêm vài từ trong Học hôm nay rồi quay lại viết nhé!';
  static const talkUnavailableSpoken = 'Bi đang ngủ trưa rồi. Mình học bài nhé!';

  // ---- Talk with Bi ----
  static const talkChooseSpoken = 'Cậu muốn trò chuyện, đóng vai hay nghe Bi kể chuyện? Chạm vào một hình nhé!';
  static const talkModeChat = 'Trò chuyện';
  static const talkModeRole = 'Đóng vai';
  static const talkModeStory = 'Kể chuyện';
  static const talkChooseScenario = 'Cậu muốn chơi ở đâu?';
  static const talkChooseStory = 'Cậu muốn nghe chuyện nào?';
  static const talkWaking = 'Bi đang thức dậy…';
  static const talkErrorSpoken = 'Bi hơi mệt rồi. Mình học bài nhé!';
  static const talkTimeUpEn = 'That was fun! See you next time!';
  static const talkTimeUpSpoken = 'Hôm nay mình nói chuyện vui quá! Hẹn gặp cậu lần sau nhé!';
  static String flagLabel(String reason) {
    switch (reason) {
      case 'distress':
        return 'Bé có thể đang buồn, sợ hoặc bị đau. Bi đã khuyên bé kể với bố mẹ.';
      case 'inappropriate_input':
        return 'Bé nói từ không phù hợp. Bi đã chuyển chủ đề.';
      case 'filtered_output':
        return 'Câu trả lời của mô hình bị bộ lọc chặn và thay bằng câu an toàn.';
      case 'too_hard':
        return 'Câu trả lời của mô hình quá dài hoặc quá khó, đã thay bằng câu đơn giản.';
      default:
        return 'Mô hình gặp lỗi, Bi dùng câu dự phòng.';
    }
  }

  // ---- Parent: progress ----
  static const progressTitle = 'Bảng tiến độ';
  static const skillsWeekly = 'Điểm kỹ năng theo tuần';
  static const lastFourWeeks = '(4 tuần gần nhất, cũ → mới)';
  static const minutesDaily = 'Số phút học mỗi ngày (14 ngày)';
  static const frequentMistakes = 'Mục bé hay sai';
  static const noMistakes = 'Chưa có mục nào sai nhiều.';
  static const testsHistory = 'Lịch sử kiểm tra';
  static const noTests = 'Chưa có bài kiểm tra nào.';
  static const canDoTitle = 'Bé làm được';
  static const weakSections = 'Phần cần ôn';
  static const unitTestLabel = 'Kiểm tra unit';
  static const levelTestLabel = 'Thi lên cấp';
  static const placementLabel = 'Kiểm tra đầu vào';
  static const levelTestReady = 'Đã học xong các unit của cấp này. Bài thi lên cấp đang chờ bé.';
  static String currentUnit(int n, int total, String topic) => 'Đang học unit $n/$total: $topic';
  static String masteredSummary(int mastered, int met, int patterns) =>
      'Đã thuộc $mastered mục (đã gặp $met mục) · $patterns mẫu câu';
  static String starsSummary(int stars) => 'Tổng số sao: $stars';
  static String wrongTimes(int n) => 'sai $n lần';
  static String skillName(String skill) =>
      const {'listen': 'Nghe', 'speak': 'Nói', 'read': 'Đọc', 'write': 'Viết'}[skill] ?? skill;
  static String sectionLabel(String key) => const {
        'listening': 'Nghe',
        'readingWriting': 'Đọc và viết',
        'speaking': 'Nói',
        'handwriting': 'Viết tay',
      }[key] ??
      key;

  // ---- Parent: settings additions ----
  static const parentVietnameseSupport = 'Mức hỗ trợ tiếng Việt khi nói chuyện với Bi';
  static const parentReminder = 'Nhắc giờ học (thông báo trên máy)';
  static const parentReminderTime = 'Giờ nhắc';
  static const reminderTitle = 'Ong Bi English';
  static const reminderBody = 'Đến giờ học tiếng Anh với Bi rồi! 🐝';
  static const reminderDenied = 'Chưa được phép gửi thông báo. Hãy cho phép trong Cài đặt Android.';
  static String reminderAt(int h, int m) => 'Lúc ${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} mỗi ngày';
  static String vietnameseSupportLabel(String key) =>
      const {'low': 'Ít', 'normal': 'Vừa', 'high': 'Nhiều'}[key] ?? key;
  static const pinningHint =
      'Mẹo: bật "Ghim ứng dụng" của Android để bé không thoát sang app khác (xem README).';

  // ---- Parent: profiles ----
  static const profilesTitle = 'Hồ sơ của bé';
  static const addProfile = 'Thêm hồ sơ';
  static const profileName = 'Tên của bé';
  static const rename = 'Đổi tên';
  static const setLevel = 'Chọn cấp';
  static const redoPlacement = 'Làm lại kiểm tra đầu vào';
  static const skipPlacement = 'Bỏ qua kiểm tra đầu vào';
  static const profilesHint =
      'Tối đa 3 hồ sơ. Chạm vào tên để chọn bé đang học. Mỗi bé có tiến độ, sao và hình dán riêng.';
  static String deleteProfileConfirm(String name) => 'Xoá hồ sơ "$name" và toàn bộ tiến độ của bé?';

  // ---- Parent: chat logs ----
  static const chatLogsTitle = 'Nhật ký Nói chuyện với Bi';
  static const chatLogsEmpty = 'Chưa có cuộc trò chuyện nào.';
  static const chatLogsClear = 'Xoá nhật ký';
  static const chatLogsClearConfirm = 'Xoá toàn bộ nhật ký trò chuyện của bé này?';
  static String flaggedCount(int n) => 'Có $n lượt được đánh dấu để bố mẹ xem (biểu tượng lá cờ).';
  static String roleLabel(String role) => const {'bi': 'Bi', 'kid': 'Bé', 'system': 'An toàn'}[role] ?? role;

  // ---- Parent: backup ----
  static const dataTitle = 'Sao lưu và khôi phục';
  static const dataIntro =
      'Sao lưu lưu toàn bộ tiến độ, sao, hình dán và cài đặt vào một file trong thư mục Download/OngBiEnglish. '
      'Chép file đó sang máy mới, cài app, rồi bấm Khôi phục và chọn file.';
  static const backupExport = 'Sao lưu ra thư mục Download';
  static const backupDone = 'Đã sao lưu.';
  static const backupFailed = 'Không thực hiện được. Hãy thử lại.';
  static const restore = 'Khôi phục từ file sao lưu';
  static const restoreConfirm = 'Tiến độ hiện tại trên máy này sẽ được thay bằng nội dung file sao lưu. Tiếp tục?';
  static const restoreDone = 'Đã khôi phục tiến độ.';
  static const dataPrivacy =
      'Ghi âm của bé và bộ nhớ đệm âm thanh không nằm trong file sao lưu. File chỉ lưu trên máy của bạn.';
  static String backupError(String code) => code == 'newer_version'
      ? 'File sao lưu được tạo bởi phiên bản app mới hơn. Hãy cập nhật app trước.'
      : 'File không đúng định dạng sao lưu của Ong Bi English.';

  // ---- Setup: placement ----
  static const placementQuestionTitle = 'Kiểm tra đầu vào';
  static const placementQuestionBody =
      'Lần đầu bấm "Học hôm nay", Bi sẽ cho bé chơi một trò khoảng 5 phút bằng hình và giọng nói '
      'để xếp bé vào Level 0 hoặc Level 1. Nếu bé chưa học tiếng Anh, bạn có thể bỏ qua.';
  static const placementSkipLevel0 = 'Bỏ qua, bắt đầu từ Level 0';
  static const placementDoIt = 'Cho bé làm kiểm tra';

  /// Every fixed Vietnamese line spoken in kid mode, rendered once ahead of time.
  static const spokenInstructions = [
    homeGreetingSpoken, talkDisabledSpoken, talkUnavailableSpoken, sayRetry, sayEffort,
    insListenPick, insBubble, insMatch, insColor, insSeeSay, insNewItem, insNewSound, insNewSoundNoLetter,
    insShadow, insReadPick, insTrace, insCopy, insDictate, insTiles, insTilesListen, insDialogue,
    insDialogueListen, insDialogueShadow, insDialogueRole, insDialogueVariation, insPickMeaning,
    insLetterSound, insTrueFalse, insFillBlank, insWriteLetter, insAnswer, insWriteSentences, insReading,
    saySayAfter, traceDirection, pickColorFirst, lessonLoading, rewardSpoken, sleepSpoken,
    outsideHoursSpoken, writeMenuSpoken, writeHomeSpoken, exitConfirmSpoken, stickerAlbumSpoken,
    placementSpoken, unitTestSpoken, levelTestSpoken, testPassedSpoken, testRetrySpoken,
    levelUpSpoken, levelTestRetrySpoken, placementDoneLevel0, placementDoneLevel1, reviewIntro,
    remedialIntro, practiceIntro, levelReviewIntro, talkChooseSpoken, talkChooseScenario,
    talkChooseStory, talkWaking, talkTimeUpSpoken, insMicDenied,
  ];

  static const insReading = 'Đọc đoạn văn rồi chọn câu trả lời đúng nhé!';

  static String levelName(int level) =>
      const ['Làm quen âm', 'Starters', 'Movers', 'Flyers', 'A2 nâng cao', 'B1'][level.clamp(0, 5).toInt()];

  static String certificateLevel(int level) => 'Cấp $level – ${levelName(level)}';

  static String sectionName(String key) {
    switch (key) {
      case 'listen':
        return sectionListen;
      case 'read_write':
        return sectionReadWrite;
      case 'speak':
        return sectionSpeak;
      default:
        return sectionHandwriting;
    }
  }

  static String megabytes(int bytes) {
    final mb = bytes / (1024 * 1024);
    if (mb >= 1024) {
      return '${(mb / 1024).toStringAsFixed(2).replaceAll('.', ',')} GB';
    }
    return '${mb.toStringAsFixed(mb >= 10 ? 0 : 1).replaceAll('.', ',')} MB';
  }

  static String ramLabel(int totalRamMb) =>
      'RAM ${(totalRamMb / 1024).toStringAsFixed(1).replaceAll('.', ',')} GB';

  static String gateQuestion(int a, int b) => '$a × $b = ?';
  static const gateErase = 'Xoá';
  static const gateSubmit = 'Xong';

  static String milliseconds(int ms) => '$ms ms';

  static String errorFor(String code) {
    switch (code) {
      case 'no_wifi':
        return errNoWifi;
      case 'no_space':
        return errNoSpace;
      case 'login_required':
        return errLogin;
      case 'checksum':
        return errChecksum;
      case 'incomplete_pack':
        return errIncomplete;
      case 'cancelled':
        return errCancelled;
      case 'network':
        return errNetwork;
      default:
        return code.startsWith('http_') ? errHttp : errNetwork;
    }
  }

  // Crash and start-up reports
  static const crashTitle = 'Lần trước app bị dừng đột ngột';
  static String crashBody(String savedTo) =>
      'Báo cáo lỗi đã được lưu ở "$savedTo" (mở ứng dụng Tệp của tôi → Tải về → OngBiEnglish). '
      'Bố mẹ gửi file này hoặc chụp màn hình này cho người hỗ trợ để sửa lỗi.';
  static const crashClose = 'Đã hiểu';
  static const startupFailedTitle = 'App chưa khởi động được';
  static String startupFailedBody(String savedTo) =>
      'Bố mẹ chụp màn hình này gửi người hỗ trợ. ${savedTo.isEmpty ? '' : 'Báo cáo cũng đã lưu ở "$savedTo". '}'
      'Sau đó đóng hẳn app rồi mở lại.';

  // Crash guard (NativeGuard): engines switched off after a native crash.
  static String guardEngineName(String engine) => switch (engine) {
        'tts' => 'giọng đọc tích hợp (tạm dùng giọng của điện thoại)',
        'stt' => 'chấm điểm phát âm (bé vẫn tập nói, chưa chấm điểm)',
        'ink' => 'nhận dạng chữ viết tay (bé vẫn tập tô chữ)',
        'llm' => '"Nói chuyện với Bi"',
        'llm_gpu' => 'tăng tốc GPU cho Bi (Bi chạy bằng CPU, chậm hơn một chút)',
        _ => engine,
      };
  static String guardSwitchedOff(Iterable<String> engines) =>
      'Để bé học tiếp mà không bị thoát, app đã tạm tắt: '
      '${engines.map(guardEngineName).join('; ')}. '
      'Bố mẹ có thể bật lại trong Khu phụ huynh → Kiểm tra hệ thống.';
  static const guardTitle = 'Tính năng đang tạm tắt sau lỗi';
  static const guardNone = 'Không có tính năng nào bị tắt.';
  static const guardEnableAll = 'Bật lại tất cả';
  static const guardEnabled = 'Đã bật lại. Nếu app lại thoát, tính năng đó sẽ tự tắt lần nữa.';
}
