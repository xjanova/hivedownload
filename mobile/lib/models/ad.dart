/// A single served advertisement (image creative) from the Thaiprompt ad API.
class Ad {
  const Ad({
    required this.id,
    required this.imageUrl,
    this.clickUrl,
    this.weight = 1,
    this.durationMs,
    this.placement,
  });

  final String id;
  final String imageUrl;

  /// Optional destination opened when the ad is tapped.
  final String? clickUrl;

  /// Rotation weight (higher = shown more often). Defaults to 1.
  final int weight;

  /// Optional per-ad display time; falls back to the response `rotate_ms`.
  final int? durationMs;

  final String? placement;

  static Ad? fromJson(Map<String, dynamic> j) {
    final img = (j['image_url'] ?? j['image'] ?? j['url']) as String?;
    if (img == null || img.isEmpty) return null;
    return Ad(
      id: '${j['id'] ?? img.hashCode}',
      imageUrl: img,
      clickUrl: (j['click_url'] ?? j['link'] ?? j['target_url']) as String?,
      weight: (j['weight'] as num?)?.toInt() ?? 1,
      durationMs: (j['duration_ms'] as num?)?.toInt(),
      placement: j['placement'] as String?,
    );
  }
}
