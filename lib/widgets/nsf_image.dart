import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models/image_ref.dart';
import '../core/providers/theme_provider.dart';

/// Displays a [CachedNetworkImage], automatically blurring it when the image
/// is flagged as sexual/violent and the user hasn't disabled the blur.
///
/// [sexual] / [violence] come from [ImageRef] (0-2 scale, null = unknown).
/// When blur is active, a small tap hint is overlaid; tapping toggles the
/// reveal for the current session of the widget.
class NsfImage extends ConsumerStatefulWidget {
  const NsfImage({
    super.key,
    required this.imageUrl,
    this.sexual,
    this.violence,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
  });

  final String? imageUrl;
  final num? sexual;
  final num? violence;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;

  @override
  ConsumerState<NsfImage> createState() => _NsfImageState();
}

class _NsfImageState extends ConsumerState<NsfImage> {
  bool _revealed = false;

  bool get _isNsfw =>
      (widget.sexual != null && widget.sexual! > 0) ||
      (widget.violence != null && widget.violence! > 0);

  bool get _shouldBlur => _isNsfw && ref.watch(themeNotifierProvider).blurNsfw && !_revealed;

  @override
  Widget build(BuildContext context) {
    final url = widget.imageUrl;
    if (url == null || url.isEmpty) {
      return widget.placeholder ?? const SizedBox.shrink();
    }

    Widget image = CachedNetworkImage(
      imageUrl: url,
      fit: widget.fit,
      width: widget.width,
      height: widget.height,
      placeholder: (_, __) =>
          widget.placeholder ?? const ColoredBox(color: Colors.black12, child: SizedBox.expand()),
      errorWidget: (_, __, ___) =>
          widget.errorWidget ?? const ColoredBox(color: Colors.black12, child: SizedBox.expand()),
    );

    if (_shouldBlur) {
      image = Stack(
        fit: StackFit.passthrough,
        children: [
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: image,
          ),
          Positioned.fill(
            child: Center(
              child: GestureDetector(
                onTap: () => setState(() => _revealed = true),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.visibility_off, color: Colors.white, size: 16),
                      SizedBox(width: 6),
                      Text('点击查看', style: TextStyle(color: Colors.white, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (widget.borderRadius != null) {
      image = ClipRRect(borderRadius: widget.borderRadius!, child: image);
    }

    return image;
  }
}

/// Convenience: builds an [NsfImage] from an [ImageRef].
NsfImage nsfImageFromRef(
  ImageRef? ref, {
  Key? key,
  BoxFit fit = BoxFit.cover,
  double? width,
  double? height,
  BorderRadius? borderRadius,
  Widget? placeholder,
  Widget? errorWidget,
}) {
  return NsfImage(
    key: key,
    imageUrl: ref?.url ?? ref?.thumbnail,
    sexual: ref?.sexual,
    violence: ref?.violence,
    fit: fit,
    width: width,
    height: height,
    borderRadius: borderRadius,
    placeholder: placeholder,
    errorWidget: errorWidget,
  );
}
