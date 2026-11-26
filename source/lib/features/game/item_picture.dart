import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Draws an item picture: a monochrome emoji glyph (Noto Emoji, OFL) or a simple shape.
class ItemPicture extends StatelessWidget {
  final String pic;
  final double size;
  const ItemPicture(this.pic, {super.key, this.size = 72});

  @override
  Widget build(BuildContext context) {
    if (pic.startsWith('shape:')) {
      return SizedBox(width: size, height: size, child: CustomPaint(painter: _ShapePainter(pic.substring(6))));
    }
    return SizedBox(
        width: size,
        height: size,
        child: Center(
            child: Text(pic,
                style: TextStyle(fontFamily: 'NotoEmoji', fontSize: size * 0.8, color: AppColors.primary))));
  }
}

class _ShapePainter extends CustomPainter {
  final String kind;
  _ShapePainter(this.kind);
  @override
  void paint(Canvas c, Size z) {
    final fill = Paint()..color = AppColors.primary;
    final cut = Paint()..color = Colors.white;
    final w = z.width, h = z.height;
    switch (kind) {
      case 'bottle':
        c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * .42, 0, w * .16, h * .08), const Radius.circular(2)), fill);
        c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * .44, h * .08, w * .12, h * .14), const Radius.circular(2)), fill);
        c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * .26, h * .2, w * .48, h * .78), Radius.circular(w * .14)), fill);
        c.drawRect(Rect.fromLTWH(w * .26, h * .45, w * .48, h * .2), cut);
        break;
      case 'can':
        c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * .24, h * .06, w * .52, h * .88), Radius.circular(w * .08)), fill);
        c.drawRect(Rect.fromLTWH(w * .24, h * .22, w * .52, h * .05), cut);
        c.drawRect(Rect.fromLTWH(w * .24, h * .72, w * .52, h * .05), cut);
        c.drawOval(Rect.fromLTWH(w * .38, h * .1, w * .24, h * .07), cut);
        break;
      default: // foil roll
        c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * .1, h * .3, w * .8, h * .4), Radius.circular(h * .2)), fill);
        c.drawOval(Rect.fromLTWH(w * .08, h * .3, w * .24, h * .4), cut);
        c.drawOval(Rect.fromLTWH(w * .14, h * .38, w * .12, h * .24), fill);
    }
  }
  @override
  bool shouldRepaint(covariant _ShapePainter o) => o.kind != kind;
}
