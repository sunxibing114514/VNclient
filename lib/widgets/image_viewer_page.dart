import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Fullscreen image viewer with pinch/zoom, share and save-to-photos.
///
/// Used for VN screenshots and cover images:
///  - 预览/缩放: [InteractiveViewer] with pan + zoom between 0.5x and 5x;
///  - 分享: downloads the image to the app cache and hands it to the
///    Android share sheet through the `vnclient/media` platform channel;
///  - 保存到相册: downloads the image and inserts it into MediaStore
///    (Pictures/VNclient) through the same channel.
class ImageViewerPage extends StatefulWidget {
  const ImageViewerPage({super.key, required this.url, this.title});

  final String url;
  final String? title;

  @override
  State<ImageViewerPage> createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends State<ImageViewerPage> {
  static const _channel = MethodChannel('vnclient/media');

  final TransformationController _transformController =
      TransformationController();
  TapDownDetails? _doubleTapDetails;

  bool _busy = false;

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  /// Downloads the image into the cache directory and returns the file path.
  Future<String> _downloadToLocal() async {
    final dir = await getTemporaryDirectory();
    final name = widget.url.split('/').last.split('?').first;
    final ext = name.contains('.') ? name.substring(name.lastIndexOf('.')) : '.jpg';
    final safeExt = RegExp(r'^\.(jpg|jpeg|png|webp|gif)$').hasMatch(ext)
        ? ext
        : '.jpg';
    final file = File(
        '${dir.path}/vnclient_share_${DateTime.now().millisecondsSinceEpoch}$safeExt');
    await Dio().download(widget.url, file.path);
    return file.path;
  }

  Future<void> _share() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final path = await _downloadToLocal();
      final result = await _channel.invokeMethod<String>('shareImage', {
        'path': path,
        'title': widget.title ?? '',
      });
      if (mounted && result != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('分享失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveToPhotos() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final path = await _downloadToLocal();
      final result = await _channel.invokeMethod<String>('saveImage', {
        'path': path,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result ?? '已保存')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _handleDoubleTapDown(TapDownDetails details) {
    _doubleTapDetails = details;
  }

  void _handleDoubleTap() {
    final position = _doubleTapDetails?.localPosition;
    if (position == null) return;
    final current = _transformController.value.getMaxScaleOnAxis() > 1.05;
    if (current) {
      _transformController.value = Matrix4.identity();
    } else {
      // Zoom 2.5x around the tapped point: the translation keeps the
      // tapped point anchored after the scale. Built explicitly
      // (column-major) to avoid deprecated Matrix4 helpers.
      const s = 2.5;
      _transformController.value = Matrix4(
        s, 0.0, 0.0, 0.0, //
        0.0, s, 0.0, 0.0, //
        0.0, 0.0, 1.0, 0.0, //
        -position.dx * (s - 1), -position.dy * (s - 1), 0.0, 1.0,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.5),
        foregroundColor: Colors.white,
        title: Text(
          widget.title ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: '分享',
            onPressed: _busy ? null : _share,
          ),
          IconButton(
            icon: const Icon(Icons.save_alt),
            tooltip: '保存到相册',
            onPressed: _busy ? null : _saveToPhotos,
          ),
        ],
      ),
      body: _busy
          ? Stack(
              children: [
                _buildViewer(),
                const Center(child: CircularProgressIndicator()),
              ],
            )
          : _buildViewer(),
    );
  }

  Widget _buildViewer() {
    return Center(
      child: InteractiveViewer(
        transformationController: _transformController,
        minScale: 0.5,
        maxScale: 5.0,
        panEnabled: true,
        clipBehavior: Clip.none,
        child: GestureDetector(
          onDoubleTapDown: _handleDoubleTapDown,
          onDoubleTap: _handleDoubleTap,
          child: CachedNetworkImage(
            imageUrl: widget.url,
            fit: BoxFit.contain,
            placeholder: (_, __) => const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            errorWidget: (_, __, ___) => const Center(
              child: Icon(Icons.broken_image, size: 64, color: Colors.white54),
            ),
          ),
        ),
      ),
    );
  }
}
