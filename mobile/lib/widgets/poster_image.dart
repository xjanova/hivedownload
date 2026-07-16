import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Poster/artwork image with a cinematic gradient fallback (used while loading
/// and when a title has no artwork). NetWix serves public poster/backdrop URLs,
/// so no auth header is needed.
class PosterImage extends StatelessWidget {
  const PosterImage({
    super.key,
    required this.url,
    this.seed = 0,
    this.fit = BoxFit.cover,
    this.radius = T.rMedia,
    this.memCacheWidth = 400,
  });

  final String url;
  final int seed;
  final BoxFit fit;
  final double radius;

  /// Decode width cap. Posters render at ~118-200 logical px, so decoding the
  /// full-size artwork into memory (the default) wastes tens of MB across a
  /// grid. 400px covers 3x-density screens; pass a larger cap for hero images.
  final int memCacheWidth;

  @override
  Widget build(BuildContext context) {
    final fallback = DecoratedBox(
      decoration: BoxDecoration(gradient: T.posterFill(seed)),
    );

    final Widget img = url.isEmpty
        ? fallback
        : CachedNetworkImage(
            imageUrl: url,
            fit: fit,
            memCacheWidth: memCacheWidth,
            placeholder: (_, _) => fallback,
            errorWidget: (_, _, _) => fallback,
            fadeInDuration: const Duration(milliseconds: 200),
          );

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox.expand(child: img),
    );
  }
}
