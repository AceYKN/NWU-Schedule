# Golden test fonts

`NwuScheduleGolden-Regular.ttf` and `NwuScheduleGolden-Bold.ttf` are modified
subsets of Noto Sans SC, licensed under the adjacent SIL Open Font License.
Source: google/fonts commit `24ecb0bbdc3a52d6fddef160b769c61463f455d9`,
`ofl/notosanssc/NotoSansSC[wght].ttf`.
Source SHA-256: `a3041811a78c361b1de50f953c805e0244951c21c5bd412f7232ef0d899af0da`.
The checked-in subsets were generated with fontTools 4.62.1.

These files are loaded offline only in `test/golden/flutter_test_config.dart`.
They are not declared as application assets, do not increase APK size, and do
not change the application's font family, size, or text scaling behavior.
The test alias `Roboto` covers the Android theme's default text style; the
Material icon font is loaded from Flutter's bundled test assets.

The subsets contain common GB2312 Chinese characters, printable ASCII, and
characters in the current Dart/JSON/HTML source and fixtures. If a new fixture
needs a missing character, regenerate both faces with Python and fontTools:

```text
python tool/generate_golden_font.py
flutter test --update-goldens test/golden
flutter test
```

The five text-bearing golden suites use `ScheduleGoldenComparator`. Windows
references retain their original `goldens/` paths; Linux references live under
`goldens/linux/`. Generate and review each set on its own host with the pinned
Flutter SDK before committing them. Loading the same font avoids missing glyphs,
but Windows and Linux still rasterize text differently. Comparison tolerances
remain unchanged, and Linux CI compares against Linux-rendered references.
The color-only palette fixture uses a shared reference.

Regeneration downloads the pinned upstream font. Normal test runs never
download fonts or depend on installed system fonts. Review the rendered
Chinese text and layout before accepting updated golden images.
