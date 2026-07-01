import 'package:flutter/material.dart';

import '../models/series.dart';
import '../screens/series_detail_screen.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'common.dart';
import 'poster_image.dart';

void openSeries(BuildContext context, Series s) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => SeriesDetailScreen(series: s)));
}

/// Portrait poster card used in the vertical rail and grid.
class PortraitPosterCard extends StatelessWidget {
  const PortraitPosterCard({super.key, required this.series, this.width = 118});
  final Series series;
  final double width;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => openSeries(context, series),
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
                  PosterImage(url: series.displayImageUrl, seed: series.id),
                  Positioned(
                    left: 6,
                    top: 6,
                    child: Pill(text: series.typeThai, filled: true),
                  ),
                  if (series.viewCount > 0)
                    Positioned(
                      right: 6,
                      bottom: 6,
                      child: Pill(text: '${series.viewCountText} 👁', color: Colors.black54, filled: true, textColor: Colors.white),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 7),
            Text(
              series.cleanTitle.isEmpty ? series.title : series.cleanTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.body(12.5, weight: FontWeight.w600, color: T.textPrimary),
            ),
            if (series.yearText.isNotEmpty)
              Text(series.yearText, style: AppTheme.body(10.5, color: T.textFaint)),
          ],
        ),
      ),
    );
  }
}

/// Wide 16:9 featured card for the "new / popular" section.
class FeaturedCard extends StatelessWidget {
  const FeaturedCard({super.key, required this.series});
  final Series series;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => openSeries(context, series),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            PosterImage(url: series.displayImageUrl, seed: series.id + 1),
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
                    Pill(text: series.typeThai, color: Colors.black54, filled: true, textColor: Colors.white),
                  ]),
                  const SizedBox(height: 8),
                  Text(
                    series.cleanTitle.isEmpty ? series.title : series.cleanTitle,
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
