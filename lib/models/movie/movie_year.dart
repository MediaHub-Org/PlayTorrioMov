/// Year handling for catalog strings, in one place.
///
/// Addons send years as free text: `2024` for a film, `2022–` for a running
/// series, `2020–2023` for an ended one. Two rules cover every use:
///
/// - Numbers only ever want the start. Stripping every non-digit turned
///   `2020–2023` into the year `20192023`, which no title search matches
///   and no sort orders sanely.
/// - Display joins a closed range with ` - `. The raw text mixes hyphens,
///   en dashes and trailing dashes for open ends; one rendering keeps
///   every card and row reading the same way.
library;

/// The year a title started, or null when the string carries none.
int? startYearOf(String? value) {
  final match = RegExp(r'\d{4}').firstMatch(value ?? '');
  return match == null ? null : int.parse(match.group(0)!);
}

/// What a year string reads as on screen.
///
/// A closed range renders `2019 - 2023` however the addon punctuated it;
/// an open one (`2022–`) reads as its bare start year, since an end that
/// has not happened yet cannot be named. Anything else -- a single year,
/// garbage, null -- passes through untouched rather than invented.
String displayYearRange(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return '';
  final years = RegExp(r'\d{4}')
      .allMatches(text)
      .map((m) => m.group(0)!)
      .toList();
  if (years.length >= 2) return '${years.first} - ${years[1]}';
  if (years.length == 1) return years.first;
  return text;
}
