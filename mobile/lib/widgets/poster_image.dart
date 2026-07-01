import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../services/rongyok_client.dart';
import '../theme/tokens.dart';

/// Poster/artwork image with a cinematic gradient fallback (used while loading
/// and when a title has no artwork). Flutter decodes rongyok's .webp posters
/// natively, so no jpg workaround is needed.
class PosterImage extends StatelessWidget {
  const PosterImage({
    super.key,
    required this.url,
    this.seed = 0,
    this.fit = BoxFit.cover,
    this.radius = T.rMedia,
  });

  final String url;
  final int seed;
  final BoxFit fit;
  final double radius;

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
            httpHeaders: const {'User-Agent': RongYokClient.userAgent},
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
