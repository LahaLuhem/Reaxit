import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';
import 'package:reaxit/utilities/cache_manager.dart' as cache;

/// Wrapper for [CachedNetworkImage] with sensible defaults.
class CachedImage extends CachedNetworkImage {
  CachedImage({
    required super.imageUrl,
    BoxFit super.fit = BoxFit.cover,
    Duration super.fadeOutDuration = const Duration(milliseconds: 200),
    super.fadeInDuration = const Duration(milliseconds: 200),
    String? placeholder,
  }) : super(
         key: ValueKey(imageUrl),
         cacheManager: cache.ThaliaCacheManager(),
         cacheKey: _getCacheKey(imageUrl),
         placeholder:
             placeholder == null
                 ? null
                 : (_, __) => Image.asset(placeholder, fit: fit),
       );
}

/// Wrapper for [CachedNetworkImageProvider] with sensible defaults.
class CachedImageProvider extends CachedNetworkImageProvider {
  CachedImageProvider(super.imageUrl)
    : super(
        cacheManager: cache.ThaliaCacheManager(),
        cacheKey: _getCacheKey(imageUrl),
      );
}

/// If the image is from thalia.nu, remove the query part of the url from its
/// key in the cache. Private images from concrexit have a signature in the url
/// that expires every few hours. Removing this signature makes sure that the
/// same cache object can be used regardless of the signature.
///
/// This assumes that the query part is only used for authentication,
/// not to identify the image, so the remaining path is a unique key.
///
/// If the url is not from thalia.nu, use the full url as the key.
String _getCacheKey(String url) {
  final uri = Uri.parse(url);
  if (uri.host
      case 'thalia.nu' ||
          'staging.thalia.nu' ||
          'cdn.thalia.nu' ||
          'cdn.staging.thalia.nu') {
    return uri.replace(query: '').toString();
  }
  return url;
}
