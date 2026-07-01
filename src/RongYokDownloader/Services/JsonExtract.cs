namespace RongYokDownloader.Services;

/// <summary>
/// rongyok.com renders its data as JavaScript literals embedded in the page
/// (e.g. <c>seriesData = [ {...}, ... ]</c>, or an episodes object inside the watch page).
/// These helpers pull a balanced JSON array/object out of the surrounding script text,
/// respecting string literals and escapes so brackets inside Thai descriptions don't confuse it.
/// The returned substring is valid JSON and can be handed straight to System.Text.Json.
/// </summary>
public static class JsonExtract
{
    /// <summary>
    /// Finds <paramref name="marker"/> in <paramref name="source"/>, then returns the balanced
    /// bracketed literal that begins at the next <paramref name="openChar"/> after it.
    /// Returns null if not found or unbalanced.
    /// </summary>
    public static string? BalancedAfter(string source, string marker, char openChar)
    {
        char closeChar = openChar switch { '[' => ']', '{' => '}', _ => throw new ArgumentException("openChar") };

        int at = source.IndexOf(marker, StringComparison.Ordinal);
        if (at < 0) return null;

        int i = at + marker.Length;
        // advance to the first opening bracket
        while (i < source.Length && source[i] != openChar) i++;
        if (i >= source.Length) return null;

        int start = i;
        int depth = 0;
        bool inStr = false, esc = false;
        for (; i < source.Length; i++)
        {
            char ch = source[i];
            if (inStr)
            {
                if (esc) esc = false;
                else if (ch == '\\') esc = true;
                else if (ch == '"') inStr = false;
            }
            else
            {
                if (ch == '"') inStr = true;
                else if (ch == openChar) depth++;
                else if (ch == closeChar)
                {
                    depth--;
                    if (depth == 0) return source.Substring(start, i - start + 1);
                }
            }
        }
        return null; // unbalanced
    }

    /// <summary>Extracts the whole <c>seriesData = [ ... ]</c> catalog array as JSON.</summary>
    public static string? CatalogArray(string html) => BalancedAfter(html, "seriesData", '[');

    /// <summary>Extracts the <c>"episodes":[ ... ]</c> array from a watch page as JSON.</summary>
    public static string? EpisodesArray(string html) => BalancedAfter(html, "\"episodes\"", '[');
}
