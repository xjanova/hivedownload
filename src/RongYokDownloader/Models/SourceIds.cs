namespace RongYokDownloader.Models;

/// <summary>Stable identifiers for the content sources the app can browse/download from.</summary>
public static class SourceIds
{
    public const string RongYok = "rongyok";
    public const string WowDrama = "wowdrama";

    /// <summary>
    /// Sources are stored side-by-side in one SQLite <c>series</c> table keyed by a single int id.
    /// rongyok uses the site's own (positive) numeric ids. Sites that key series by a string slug
    /// (wow-drama) need a synthetic int id derived from that slug. We map those into the NEGATIVE
    /// int range so they can never collide with rongyok's positive ids, and stay stable across runs
    /// so re-scanning a series keeps the same id (and therefore its download state).
    /// </summary>
    public static int StableNegativeId(string sourceId, string slug)
    {
        // 32-bit FNV-1a over "source:slug", folded into a negative int.
        unchecked
        {
            const uint prime = 16777619;
            uint hash = 2166136261;
            foreach (char ch in $"{sourceId}:{slug}")
            {
                hash = (hash ^ ch) * prime;
            }
            // Keep it in [1 .. int.MaxValue] then negate → always < 0, never 0.
            int positive = (int)(hash & 0x7FFFFFFF);
            if (positive == 0) positive = 1;
            return -positive;
        }
    }
}
