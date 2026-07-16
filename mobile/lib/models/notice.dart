/// An admin-broadcast notification from the NetWix backend
/// (`GET /api/app/notifications`). Categories map to the user's per-topic
/// mute toggles: new_content (หนังมาใหม่) · news (ข่าวจากทีมงาน) · other (อื่น ๆ).
class AppNotice {
  const AppNotice({
    required this.id,
    required this.category,
    required this.title,
    required this.body,
    this.imageUrl,
    this.linkUrl,
    this.publishedAt,
  });

  final int id;
  final String category; // new_content | news | other
  final String title;
  final String body;
  final String? imageUrl;
  final String? linkUrl;
  final DateTime? publishedAt;

  static AppNotice? fromJson(Map<String, dynamic> j) {
    final id = (j['id'] as num?)?.toInt();
    final title = (j['title'] as String?) ?? '';
    if (id == null || title.isEmpty) return null;
    return AppNotice(
      id: id,
      category: (j['category'] as String?) ?? 'other',
      title: title,
      body: (j['body'] as String?) ?? '',
      imageUrl: (j['image_url'] as String?),
      linkUrl: (j['link_url'] as String?),
      publishedAt: DateTime.tryParse('${j['published_at'] ?? ''}')?.toLocal(),
    );
  }
}

/// An admin-controlled promo banner for the top of Home
/// (`GET /api/app/banners`). Scheduling + hide-for-Pro are server-resolved.
class PromoBanner {
  const PromoBanner({required this.id, required this.image, this.title, this.linkUrl});

  final int id;
  final String image;
  final String? title;
  final String? linkUrl;

  static PromoBanner? fromJson(Map<String, dynamic> j) {
    final id = (j['id'] as num?)?.toInt();
    final image = (j['image'] as String?) ?? '';
    if (id == null || image.isEmpty) return null;
    return PromoBanner(
      id: id,
      image: image,
      title: j['title'] as String?,
      linkUrl: j['link_url'] as String?,
    );
  }
}
