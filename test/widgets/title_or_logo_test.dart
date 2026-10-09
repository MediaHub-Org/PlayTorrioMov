// The name stands in for the logo wherever there is none: the details page,
// the sources page and the loading screen all share this fallback.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playtorriomov/widgets/common/title_or_logo.dart';

Widget build({String? logoUrl, int? maxLines}) => MaterialApp(
  home: Scaffold(
    body: Center(
      child: TitleOrLogo(
        logoUrl: logoUrl,
        name: 'Dune',
        maxLogoWidth: 200,
        maxLogoHeight: 80,
        fontSize: 28,
        letterSpacing: -0.5,
        color: Colors.white,
        shadowBlur: 4,
        shadowOffsetY: 2,
        maxLines: maxLines,
      ),
    ),
  ),
);

void main() {
  testWidgets('no logo shows the name', (tester) async {
    await tester.pumpWidget(build());

    expect(find.text('Dune'), findsOneWidget);
  });

  testWidgets('an empty logo address is no logo', (tester) async {
    await tester.pumpWidget(build(logoUrl: ''));

    expect(find.text('Dune'), findsOneWidget);
  });

  testWidgets('the name keeps its shadow, which keeps it legible', (tester) async {
    await tester.pumpWidget(build());

    final style = tester.widget<Text>(find.text('Dune')).style!;
    expect(style.shadows, isNotEmpty);
    expect(style.fontWeight, FontWeight.w800);
  });

  testWidgets('a line limit ellipsizes', (tester) async {
    await tester.pumpWidget(build(maxLines: 2));

    final text = tester.widget<Text>(find.text('Dune'));
    expect(text.maxLines, 2);
    expect(text.overflow, TextOverflow.ellipsis);
  });
}
