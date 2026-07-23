import 'package:flutter/material.dart';

import '../theme.dart';

class EditorToolbar extends StatelessWidget {
  const EditorToolbar({
    super.key,
    required this.onH2,
    required this.onH3,
    required this.onText,
    required this.onQuote,
    required this.onList,
    required this.onDelimiter,
    required this.onAudio,
    required this.onMedia,
  });

  final VoidCallback onH2;
  final VoidCallback onH3;
  final VoidCallback onText;
  final VoidCallback onQuote;
  final VoidCallback onList;
  final VoidCallback onDelimiter;
  final VoidCallback onAudio;
  final VoidCallback onMedia;

  @override
  Widget build(BuildContext context) => Container(
    height: 48,
    decoration: BoxDecoration(
      color: AppColors.bgCard,
      border: const Border(top: BorderSide(color: AppColors.bgElevated)),
    ),
    child: Row(
      children: [
        _text('H2', onH2),
        _text('H3', onH3),
        _text('T', onText),
        _icon(Icons.format_quote, onQuote),
        _icon(Icons.format_list_bulleted, onList),
        _text('* * *', onDelimiter, small: true),
        _icon(Icons.mic_none, onAudio),
        _icon(Icons.image_outlined, onMedia),
      ],
    ),
  );

  Widget _text(String label, VoidCallback onTap, {bool small = false}) =>
      Expanded(
        child: InkWell(
          onTap: onTap,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: small ? 11 : 13,
                fontWeight: FontWeight.w700,
                letterSpacing: small ? 2 : 0,
              ),
            ),
          ),
        ),
      );

  Widget _icon(IconData icon, VoidCallback onTap) => Expanded(
    child: InkWell(
      onTap: onTap,
      child: Center(
        child: Icon(icon, size: 20, color: AppColors.textSecondary),
      ),
    ),
  );
}
