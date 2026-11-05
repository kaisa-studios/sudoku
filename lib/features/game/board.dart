import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../domain/game/game.dart';
import '../../domain/sudoku/grid.dart';

/// The 9x9 board: square, as large as the space allows, thick 3x3 borders.
class Board extends StatelessWidget {
  const Board({super.key, required this.game, required this.onTap});

  final Game game;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return LayoutBuilder(builder: (context, box) {
      final side = box.biggest.shortestSide;
      final cell = side / 9;
      return SizedBox.square(
        dimension: side,
        child: DecoratedBox(
          decoration: BoxDecoration(color: colors.boardBackground),
          child: Stack(children: [
            for (var c = 0; c < cellCount; c++)
              Positioned(
                left: colOf(c) * cell,
                top: rowOf(c) * cell,
                width: cell,
                height: cell,
                child: _Cell(game: game, index: c, size: cell, onTap: onTap),
              ),
            IgnorePointer(
              child: CustomPaint(
                size: Size.square(side),
                painter: _GridPainter(colors.lineThin, colors.lineThick),
              ),
            ),
          ]),
        ),
      );
    });
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.game, required this.index, required this.size, required this.onTap});

  final Game game;
  final int index;
  final double size;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final v = game.values[index];
    final sel = game.selected;
    final given = game.isGiven(index);
    final wrong = game.isWrong(index);

    Color? bg;
    if (sel == index) {
      bg = colors.selected;
    } else if (sel != null && v != 0 && v == game.values[sel]) {
      bg = colors.sameDigit;
    } else if (sel != null &&
        (rowOf(sel) == rowOf(index) || colOf(sel) == colOf(index) || boxOf(sel) == boxOf(index))) {
      bg = colors.related;
    }

    final label = StringBuffer('Zeile ${rowOf(index) + 1}, Spalte ${colOf(index) + 1}, ');
    if (v == 0) {
      label.write('leer');
      final n = game.notes[index];
      if (n != 0) label.write(', Notizen ${digitsOf(n).join(' und ')}');
    } else if (given) {
      label.write('vorgegebene $v, nicht bearbeitbar');
    } else {
      label.write('Eingabe $v${wrong ? ', falsch' : ''}');
    }

    Widget content;
    if (v != 0) {
      content = Stack(alignment: Alignment.center, children: [
        Text(
          '$v',
          style: TextStyle(
            fontSize: size * 0.62,
            height: 1,
            fontWeight: given ? FontWeight.w700 : FontWeight.w500,
            color: wrong ? colors.wrong : (given ? colors.given : colors.entry),
          ),
        ),
        if (wrong)
          Positioned(
            right: size * 0.06,
            top: size * 0.04,
            child: Icon(Icons.close, size: size * 0.24, color: colors.wrong),
          ),
      ]);
    } else if (game.notes[index] != 0) {
      content = _Notes(mask: game.notes[index], size: size, color: colors.note);
    } else {
      content = const SizedBox.shrink();
    }

    return Semantics(
      label: label.toString(),
      selected: sel == index,
      button: true,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap(index),
        child: Container(color: bg, alignment: Alignment.center, child: content),
      ),
    );
  }
}

class _Notes extends StatelessWidget {
  const _Notes({required this.mask, required this.size, required this.color});

  final int mask;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontSize: size * 0.26, height: 1, color: color);
    return Padding(
      padding: EdgeInsets.all(size * 0.06),
      child: Column(children: [
        for (var r = 0; r < 3; r++)
          Expanded(
            child: Row(children: [
              for (var c = 0; c < 3; c++)
                Expanded(
                  child: Center(
                    child: Text(mask & (1 << (r * 3 + c + 1)) != 0 ? '${r * 3 + c + 1}' : '',
                        style: style),
                  ),
                ),
            ]),
          ),
      ]),
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter(this.thin, this.thick);

  final Color thin;
  final Color thick;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / 9;
    final thinPaint = Paint()
      ..color = thin
      ..strokeWidth = 1;
    final thickPaint = Paint()
      ..color = thick
      ..strokeWidth = 2.5;
    for (var i = 0; i <= 9; i++) {
      final p = i % 3 == 0 ? thickPaint : thinPaint;
      final x = (i * cell).clamp(p.strokeWidth / 2, size.width - p.strokeWidth / 2);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
      canvas.drawLine(Offset(0, x), Offset(size.width, x), p);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => old.thin != thin || old.thick != thick;
}
