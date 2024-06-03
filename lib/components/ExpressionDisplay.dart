import 'dart:async';

import 'package:flutter/material.dart';

import '../models/operation.dart';

class EditableTextWithCursor extends StatefulWidget {
  final List<Model> config;
  final Function(int) onUpdateCursorPosition;

  const EditableTextWithCursor({
    super.key,
    required this.config,
    required this.onUpdateCursorPosition,
  });

  @override
  State<EditableTextWithCursor> createState() => _EditableTextWithCursorState();
}

class _EditableTextWithCursorState extends State<EditableTextWithCursor> {
  late TextPainter _textPainter;
  late int _cursorIndex;
  
  static bool _transparent = false;
  static int _lastConfigLength = 0;

  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _cursorIndex = widget.config.length;
    _textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.left,
    );

    _timer = Timer.periodic(const Duration(milliseconds: 750), (timer) {
      setState(() {
        _transparent = !_transparent;
      });
    });

    if (_lastConfigLength == 0 && widget.config.isNotEmpty) {
      _lastConfigLength = widget.config.length;
    }
  }

  @override
  void dispose() {
    super.dispose();
    _timer.cancel();
  }


  @override
  void didUpdateWidget(EditableTextWithCursor oldWidget) {
    super.didUpdateWidget(oldWidget);
    int configChange = widget.config.length - _lastConfigLength;

    if (configChange > 0) {
      _cursorIndex += configChange;
    } else if (configChange < 0) {
      _cursorIndex = (_cursorIndex + configChange).clamp(0, widget.config.length);
    }
    _lastConfigLength = widget.config.length;
  }

  void _updateTextWidth() {
    _textPainter.text = TextSpan(
      text: widget.config.map((e) => displayString(e)).join(),
      style: TextStyle(
        fontSize: 30,
        fontWeight: FontWeight.bold,
        color: Colors.white.withOpacity(0.8),
      ),
    );
    _textPainter.layout();
  }

  @override
  Widget build(BuildContext context) {
    _updateTextWidth();

    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        RenderBox renderBox = context.findRenderObject() as RenderBox;
        Offset localPosition = renderBox.globalToLocal(details.globalPosition);
        double dx = localPosition.dx;

        int newCursorPosition = _textPainter.getPositionForOffset(Offset(dx, 0)).offset;
        if (newCursorPosition != _cursorIndex) {
          setState(() {
            _cursorIndex = newCursorPosition;
          });
          widget.onUpdateCursorPosition(_cursorIndex);
        }
      },
      onTapDown: (details) {
        RenderBox renderBox = context.findRenderObject() as RenderBox;
        Offset localPosition = renderBox.globalToLocal(details.globalPosition);
        double dx = localPosition.dx;

        int newCursorPosition =
            _textPainter.getPositionForOffset(Offset(dx, 0)).offset;
        if (newCursorPosition != _cursorIndex) {
          setState(() {
            _cursorIndex = newCursorPosition;
          });
          widget.onUpdateCursorPosition(_cursorIndex);
        }
      },
      child: CustomPaint(
        size: const Size(double.infinity, 40),
        painter: _TextPainter(
          config: widget.config,
          cursorIndex: _cursorIndex,
          textPainter: _textPainter,
          transparent: _transparent,
        ),
      ),
    );
  }
}

class _TextPainter extends CustomPainter {
  final List<Model> config;
  final int cursorIndex;
  final TextPainter textPainter;
  final bool transparent;

  _TextPainter({
    required this.config,
    required this.cursorIndex,
    required this.textPainter,
    required this.transparent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    textPainter.text = TextSpan(
      text: config.map((e) => displayString(e)).join(),
      style: TextStyle(
        fontSize: 30,
        fontWeight: FontWeight.bold,
        color: Colors.white.withOpacity(0.8),
      ),
    );
    textPainter.layout(minWidth: size.width, maxWidth: size.width);
    textPainter.paint(canvas, const Offset(0, 0));

    if (cursorIndex <= config.length) {
      int offset = 0;
      for (int i = 0; i < cursorIndex; i++) {
        offset += (config[i].value ?? config[i].operation)!.length;
      }

      Offset cursorOffset = textPainter.getOffsetForCaret(TextPosition(offset: offset), Rect.zero);
      Paint paint = Paint()..color = Color.fromARGB(transparent ? 0: 255, 72, 158, 216);
      canvas.drawRect(
        Rect.fromLTWH(cursorOffset.dx, cursorOffset.dy, 2, textPainter.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

String displayString(Model model) {
  if (model.value != "null" && model.value != null) {
    return model.isDecimal ? model.value.toString() : model.value.toString().replaceAll(".0", "");
  } else {
    return model.operation ?? "";
  }
}
