// lib/widgets/image_slider.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class ImageComparisonSlider extends StatefulWidget {
  final String inputUrl;
  final String outputUrl;

  const ImageComparisonSlider({
    super.key,
    required this.inputUrl,
    required this.outputUrl,
  });

  @override
  State<ImageComparisonSlider> createState() => _ImageComparisonSliderState();
}

class _ImageComparisonSliderState extends State<ImageComparisonSlider> {
  double _ratio = 0.5;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      final dividerX = w * _ratio;

      return GestureDetector(
        onHorizontalDragUpdate: (d) {
          setState(() {
            _ratio = ((_ratio * w + d.delta.dx) / w).clamp(0.02, 0.98);
          });
        },
        child: ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Output (right / base)
              CachedNetworkImage(
                imageUrl: widget.outputUrl,
                fit: BoxFit.cover,
              ),
              // Input (left / clipped)
              ClipRect(
                clipper: _LeftClipper(dividerX),
                child: CachedNetworkImage(
                  imageUrl: widget.inputUrl,
                  fit: BoxFit.cover,
                ),
              ),
              // Divider bar
              Positioned(
                left: dividerX - 1,
                top: 0,
                bottom: 0,
                child: Container(width: 2, color: Colors.white),
              ),
              // Handle
              Positioned(
                left: dividerX - 18,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: cs.surface,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.swap_horiz, size: 18),
                  ),
                ),
              ),
              // Labels
              Positioned(
                top: 8,
                left: 8,
                child: _label('Before'),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: _label('After'),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _label(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(text,
            style: const TextStyle(color: Colors.white, fontSize: 11)),
      );
}

class _LeftClipper extends CustomClipper<Rect> {
  final double dividerX;
  const _LeftClipper(this.dividerX);

  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, dividerX, size.height);

  @override
  bool shouldReclip(_LeftClipper old) => old.dividerX != dividerX;
}
