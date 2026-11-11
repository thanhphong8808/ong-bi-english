// lib/features/write/big_keyboard.dart
import 'package:material_ui/material_ui.dart';

import '../../app/theme.dart';

/// Large on-screen keyboard for children (level 4 up). Lower-case letters,
/// apostrophe, space, delete and done.
class BigKeyboard extends StatelessWidget {
  const BigKeyboard({
    super.key,
    required this.onKey,
    required this.onBackspace,
    required this.onDone,
    this.punctuation = false,
  });

  final void Function(String key) onKey;
  final VoidCallback onBackspace;
  final VoidCallback onDone;

  /// Adds . , ? ! for sentence writing.
  final bool punctuation;

  static const List<String> _rows = ['qwertyuiop', 'asdfghjkl', 'zxcvbnm'];

  Widget _key(String label, VoidCallback onTap, {int flex = 1, Color color = AppColors.white, IconData? icon}) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Material(
          color: color,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Container(
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.ink, width: 2),
              ),
              child: icon != null
                  ? Icon(icon, size: 30, color: AppColors.ink)
                  : Text(
                      label,
                      style: const TextStyle(
                        fontFamily: AppTheme.writingFont,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in _rows)
          Row(children: [for (final c in row.split('')) _key(c, () => onKey(c))]),
        Row(
          children: [
            _key("'", () => onKey("'")),
            if (punctuation) ...[
              _key('.', () => onKey('.')),
              _key(',', () => onKey(',')),
              _key('?', () => onKey('?')),
            ],
            _key('', () => onKey(' '), flex: 4, color: const Color(0xFFF3EEDD)),
            _key('', onBackspace, flex: 2, icon: Icons.backspace_outlined),
            _key('', onDone, flex: 2, color: AppColors.leaf, icon: Icons.check_rounded),
          ],
        ),
      ],
    );
  }
}
