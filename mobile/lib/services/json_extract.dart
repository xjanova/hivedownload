/// rongyok.com renders its data as JavaScript literals embedded in the page
/// (e.g. `seriesData = [ {...}, ... ]`, or an `"episodes":[...]` array inside the
/// watch page). These helpers pull a *balanced* bracketed literal out of the
/// surrounding script text, respecting string literals and escapes so brackets
/// inside Thai descriptions don't confuse it.
///
/// Direct port of RongYokDownloader.Services.JsonExtract (C#). The returned
/// substring is valid JSON and can be handed straight to `jsonDecode`.
class JsonExtract {
  /// Finds [marker] in [source], then returns the balanced bracketed literal
  /// that begins at the next [openChar] after it. Returns null if not found or
  /// unbalanced.
  static String? balancedAfter(String source, String marker, String openChar) {
    final String closeChar = switch (openChar) {
      '[' => ']',
      '{' => '}',
      _ => throw ArgumentError.value(openChar, 'openChar'),
    };

    final at = source.indexOf(marker);
    if (at < 0) return null;

    var i = at + marker.length;
    // advance to the first opening bracket
    while (i < source.length && source[i] != openChar) {
      i++;
    }
    if (i >= source.length) return null;

    final start = i;
    var depth = 0;
    var inStr = false;
    var esc = false;
    for (; i < source.length; i++) {
      final ch = source[i];
      if (inStr) {
        if (esc) {
          esc = false;
        } else if (ch == r'\') {
          esc = true;
        } else if (ch == '"') {
          inStr = false;
        }
      } else {
        if (ch == '"') {
          inStr = true;
        } else if (ch == openChar) {
          depth++;
        } else if (ch == closeChar) {
          depth--;
          if (depth == 0) return source.substring(start, i + 1);
        }
      }
    }
    return null; // unbalanced
  }

  /// Extracts the whole `seriesData = [ ... ]` catalog array as JSON.
  static String? catalogArray(String html) => balancedAfter(html, 'seriesData', '[');

  /// Extracts the `"episodes":[ ... ]` array from a watch page as JSON.
  static String? episodesArray(String html) => balancedAfter(html, '"episodes"', '[');
}
