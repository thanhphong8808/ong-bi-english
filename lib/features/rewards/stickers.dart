// lib/features/rewards/stickers.dart
//
// Collectable stickers (emoji artwork from Noto Color Emoji, OFL).

class Sticker {
  const Sticker(this.id, this.emoji, this.nameVi);

  final String id;
  final String emoji;
  final String nameVi;
}

const List<Sticker> stickers = [
  Sticker('s01', '🦄', 'Kỳ lân'),
  Sticker('s02', '🐼', 'Gấu trúc'),
  Sticker('s03', '🦊', 'Cáo nhỏ'),
  Sticker('s04', '🐸', 'Ếch xanh'),
  Sticker('s05', '🐙', 'Bạch tuộc'),
  Sticker('s06', '🦋', 'Bướm'),
  Sticker('s07', '🐢', 'Rùa'),
  Sticker('s08', '🦁', 'Sư tử'),
  Sticker('s09', '🐬', 'Cá heo'),
  Sticker('s10', '🦉', 'Cú mèo'),
  Sticker('s11', '🐧', 'Chim cánh cụt'),
  Sticker('s12', '🦒', 'Hươu cao cổ'),
  Sticker('s13', '🐨', 'Gấu túi'),
  Sticker('s14', '🦖', 'Khủng long'),
  Sticker('s15', '🐳', 'Cá voi'),
  Sticker('s16', '🦜', 'Vẹt'),
  Sticker('s17', '🐞', 'Bọ rùa'),
  Sticker('s18', '🦔', 'Nhím'),
  Sticker('s19', '🐿️', 'Sóc'),
  Sticker('s20', '🦩', 'Hồng hạc'),
  Sticker('s21', '🌈', 'Cầu vồng'),
  Sticker('s22', '⭐', 'Ngôi sao'),
  Sticker('s23', '🌻', 'Hoa hướng dương'),
  Sticker('s24', '🍉', 'Dưa hấu'),
  Sticker('s25', '🍩', 'Bánh vòng'),
  Sticker('s26', '🧁', 'Bánh nướng nhỏ'),
  Sticker('s27', '🍭', 'Kẹo mút'),
  Sticker('s28', '🎈', 'Bóng bay'),
  Sticker('s29', '🪁', 'Diều'),
  Sticker('s30', '🚀', 'Tên lửa'),
  Sticker('s31', '🛸', 'Đĩa bay'),
  Sticker('s32', '🚂', 'Tàu hoả'),
  Sticker('s33', '⛵', 'Thuyền buồm'),
  Sticker('s34', '🎠', 'Ngựa gỗ'),
  Sticker('s35', '🏰', 'Lâu đài'),
  Sticker('s36', '🎸', 'Đàn ghi-ta'),
  Sticker('s37', '🥁', 'Trống'),
  Sticker('s38', '🎨', 'Bảng màu'),
  Sticker('s39', '🧩', 'Mảnh ghép'),
  Sticker('s40', '🪀', 'Yo-yo'),
  Sticker('s41', '🌙', 'Mặt trăng'),
  Sticker('s42', '☀️', 'Mặt trời'),
  Sticker('s43', '❄️', 'Bông tuyết'),
  Sticker('s44', '🍀', 'Cỏ bốn lá'),
  Sticker('s45', '🐝', 'Bạn ong'),
  Sticker('s46', '🌵', 'Xương rồng'),
  Sticker('s47', '🍄', 'Cây nấm'),
  Sticker('s48', '🐠', 'Cá nhiệt đới'),
  Sticker('s49', '🦀', 'Cua'),
  Sticker('s50', '🦕', 'Khủng long cổ dài'),
  Sticker('s51', '🐹', 'Chuột hamster'),
  Sticker('s52', '🐰', 'Thỏ'),
  Sticker('s53', '🐻', 'Gấu nâu'),
  Sticker('s54', '🐯', 'Hổ'),
  Sticker('s55', '🐮', 'Bò sữa'),
  Sticker('s56', '🐷', 'Heo hồng'),
  Sticker('s57', '🐵', 'Khỉ'),
  Sticker('s58', '🦓', 'Ngựa vằn'),
  Sticker('s59', '🐘', 'Voi'),
  Sticker('s60', '🦘', 'Chuột túi'),
];

/// The next sticker the child does not own yet; after the full album,
/// stickers repeat in order.
Sticker nextSticker(Set<String> owned) {
  for (final sticker in stickers) {
    if (!owned.contains(sticker.id)) {
      return sticker;
    }
  }
  final count = owned.where((id) => !id.startsWith('badge:')).length;
  return stickers[count % stickers.length];
}

Sticker? stickerById(String id) {
  for (final sticker in stickers) {
    if (sticker.id == id) {
      return sticker;
    }
  }
  return null;
}
