import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:forest_carbon_platform/config/theme.dart';

class ImageViewerWidget extends StatefulWidget {
  final String imageUrl;
  final String imageName;

  const ImageViewerWidget({
    required this.imageUrl,
    required this.imageName,
    super.key,
  });

  @override
  State<ImageViewerWidget> createState() => _ImageViewerWidgetState();
}

class _ImageViewerWidgetState extends State<ImageViewerWidget> {
  late TransformationController _controller;
  TapDownDetails? _tapDownDetails;

  @override
  void initState() {
    super.initState();
    _controller = TransformationController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDoubleTap() {
    if (_controller.value != Matrix4.identity()) {
      _controller.value = Matrix4.identity();
    } else {
      const double scale = 2.0;
      final double x = _tapDownDetails?.globalPosition.dx ?? 0;
      final double y = _tapDownDetails?.globalPosition.dy ?? 0;
      _controller.value = Matrix4.identity()
        ..translate(-x, -y)
        ..scale(scale)
        ..translate(x / scale, y / scale);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: GestureDetector(
              onDoubleTapDown: (details) => _tapDownDetails = details,
              onDoubleTap: _handleDoubleTap,
              child: InteractiveViewer(
                transformationController: _controller,
                boundaryMargin: const EdgeInsets.all(80),
                minScale: 0.5,
                maxScale: 4,
                child: CachedNetworkImage(
                  imageUrl: widget.imageUrl,
                  fit: BoxFit.contain,
                  placeholder: (context, url) => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  errorWidget: (context, url, error) => Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.image_not_supported_outlined,
                        color: AppColors.error,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Không tải được hình ảnh',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.error,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(
              top: BorderSide(color: AppColors.secondary.withValues(alpha: 0.2)),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.imageName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Nhấp đôi để phóng to',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.secondary.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
