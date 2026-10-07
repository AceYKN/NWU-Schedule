import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('different Chinese words render different glyphs, not boxes',
      (tester) async {
    Future<List<int>> pixels(String text) async {
      const key = ValueKey('text-image');
      await tester.pumpWidget(MaterialApp(
          home: Center(
        child: RepaintBoundary(
            key: key,
            child: SizedBox(
              width: 240,
              height: 64,
              child: ColoredBox(
                  color: Colors.white,
                  child: Text(
                    text,
                    style: const TextStyle(fontFamily: 'Roboto', fontSize: 24),
                  )),
            )),
      )));
      await tester.pumpAndSettle();
      final boundary =
          tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
      return (await tester.runAsync(() async {
        final image = await boundary.toImage();
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        final result = data!.buffer.asUint8List().toList();
        image.dispose();
        return result;
      }))!;
    }

    final first = await pixels('软件测试');
    final second = await pixels('计算机网');
    expect(second, isNot(equals(first)));
    expect(tester.takeException(), isNull);
  });
}
