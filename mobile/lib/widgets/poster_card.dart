import 'package:flutter/material.dart';

import '../models/content.dart';
import '../screens/series_detail_screen.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'common.dart';
import 'poster_image.dart';

void openContent(BuildContext context, Content c) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => SeriesDetailScreen(content: c)));
}

/// Portrait poster card used in the vertical rail and grid.
class PortraitPosterCard extends StatelessWidget {
  const PortraitPosterCard({super.key, required this.content, this.width = 118});
  final Content content;
  final double width;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => openContent(context, content),
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 2 / 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PosterImage(url: content.displayImageUrl, seed: content.id),
                  Positioned(
                    left: 6,
                    top: 6,
                    child: Pill(text: content.typeThai, filled: true),
                  ),
                  if (content.views > 0)
                    Positioned(
                      right: 6,
                      bottom: 6,
                      child: Pill(text: '${content.viewsText} 👁', color: Colors.black54, filled: true, textColor: Colors.white),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 7),
            Text(
              content.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.body(12.5, weight: FontWeight.w600, color: T.textPrimary),
            ),
            if (content.yearText.isNotEmpty)
              Text(content.yearText, style: AppTheme.body(10.5, color: T.textFaint)),
          ],
        ),
      ),
    );
  }
}

/// Wide 16:9 featured card for the "new / popular" section.
class FeaturedCard extends StatelessWidget {
  const FeaturedCard({super.key, required this.content});
  final Content content;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => openContent(context, content),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            PosterImage(url: content.heroImageUrl, seed: content.id + 1),
            // left-dark gradient overlay
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(T.rMedia),
                gradient: const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Color(0xCC0B0B0C), Colors.transparent],
                ),
              ),
            ),
            Positioned(
              left: 14,
              right: 14,
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Pill(text: 'ดูฟรี', filled: true),
                    const SizedBox(width: 6),
                    Pill(text: content.typeThai, color: Colors.black54, filled: true, textColor: Colors.white),
                  ]),
                  const SizedBox(height: 8),
                  Text(
                    content.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.display(18, weight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            Positioned(
              right: 14,
              top: 0,
              bottom: 0,
              child: Center(
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: T.accentGradient,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: T.accentGlow, blurRadius: 20, spreadRadius: -6)],
                  ),
                  child: const Icon(Icons.play_arrow_rounded, color: T.onAccent, size: 26),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
