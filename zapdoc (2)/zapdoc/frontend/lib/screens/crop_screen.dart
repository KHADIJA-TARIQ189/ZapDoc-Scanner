import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/scan_page.dart';
import '../services/api_service.dart';

/// Shows the raw photo with 4 draggable corner handles (auto-detected via the
/// backend), lets the user nudge them, pick a filter, then sends both to
/// /scan/process and returns the finished ScanPage.
class CropScreen extends StatefulWidget {
  final ScanPage page;
  const CropScreen({super.key, required this.page});

  @override
  State<CropScreen> createState() => _CropScreenState();
}

class _CropScreenState extends State<CropScreen> {
  bool _loading = true;
  bool _submitting = false;
  String _mode = "enhance";
  List<Offset> _corners = []; // in widget/display coordinates
  Size _imageDisplaySize = Size.zero;
  Size _imageNaturalSize = Size.zero;

  @override
  void initState() {
    super.initState();
    _detect();
  }

  Future<void> _detect() async {
    try {
      final result = await ApiService.detectEdges(widget.page.rawImagePath);
      final w = (result["image_width"] as num).toDouble();
      final h = (result["image_height"] as num).toDouble();
      _imageNaturalSize = Size(w, h);
      final rawCorners = (result["corners"] as List)
          .map((c) => Offset((c[0] as num).toDouble(), (c[1] as num).toDouble()))
          .toList();
      widget.page.corners = rawCorners.map((o) => [o.dx, o.dy]).toList();
      setState(() {
        _corners = rawCorners; // will be re-scaled to display size in build
        _loading = false;
      });
    } catch (e) {
      // Detection failed (e.g. backend unreachable) - fall back to full-image corners.
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Edge detection unavailable: $e")),
        );
      }
    }
  }

  /// Convert a display-space corner back to natural image pixel coordinates.
  List<List<double>> _cornersToNatural() {
    final scaleX = _imageNaturalSize.width / _imageDisplaySize.width;
    final scaleY = _imageNaturalSize.height / _imageDisplaySize.height;
    return _corners.map((o) => [o.dx * scaleX, o.dy * scaleY]).toList();
  }

  Future<void> _confirm() async {
    setState(() => _submitting = true);
    try {
      // Only send corners if we actually know the natural image size -
      // otherwise (e.g. detection failed) let the backend use the full image.
      final corners = (_corners.isNotEmpty && _imageNaturalSize != Size.zero)
          ? _cornersToNatural()
          : null;
      final processedPath = await ApiService.processScan(
        imagePath: widget.page.rawImagePath,
        corners: corners,
        mode: _mode,
      );
      widget.page.processedImagePath = processedPath;
      widget.page.filterMode = _mode;
      if (mounted) Navigator.pop(context, widget.page);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Processing failed: $e")));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text("Adjust & Filter"),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return FutureBuilder<ui.Image>(
                        future: _loadImage(widget.page.rawImagePath),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                          final img = snapshot.data!;
                          final displaySize = _fitSize(
                            Size(img.width.toDouble(), img.height.toDouble()),
                            Size(constraints.maxWidth, constraints.maxHeight),
                          );
                          _imageDisplaySize = displaySize;
                          if (_corners.isEmpty ||
                              _corners.first.dx.isNaN ||
                              _imageNaturalSize == Size.zero) {
                            // no detection yet: default to full-frame corners
                            _corners = [
                              const Offset(0, 0),
                              Offset(displaySize.width, 0),
                              Offset(displaySize.width, displaySize.height),
                              Offset(0, displaySize.height),
                            ];
                          } else if (_imageNaturalSize != Size.zero) {
                            // scale natural-space corners into current display space once
                          }
                          return Center(
                            child: SizedBox(
                              width: displaySize.width,
                              height: displaySize.height,
                              child: Stack(
                                children: [
                                  Image.file(File(widget.page.rawImagePath), fit: BoxFit.fill),
                                  CustomPaint(
                                    size: displaySize,
                                    painter: _QuadPainter(_scaledCorners(displaySize)),
                                  ),
                                  ..._buildHandles(displaySize),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                _buildFilterBar(),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _submitting ? null : _confirm,
                      icon: _submitting
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.check),
                      label: Text(_submitting ? "Processing..." : "Confirm"),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  List<Offset> _scaledCorners(Size displaySize) {
    if (_imageNaturalSize == Size.zero) return _corners;
    final scaleX = displaySize.width / _imageNaturalSize.width;
    final scaleY = displaySize.height / _imageNaturalSize.height;
    // Only rescale if corners are still in natural coordinates (first paint after detect).
    if (_corners.every((o) => o.dx <= _imageNaturalSize.width + 1 && o.dy <= _imageNaturalSize.height + 1) &&
        displaySize != _imageNaturalSize) {
      return _corners.map((o) => Offset(o.dx * scaleX, o.dy * scaleY)).toList();
    }
    return _corners;
  }

  List<Widget> _buildHandles(Size displaySize) {
    final scaled = _scaledCorners(displaySize);
    return List.generate(scaled.length, (i) {
      final pos = scaled[i];
      return Positioned(
        left: pos.dx - 16,
        top: pos.dy - 16,
        child: GestureDetector(
          onPanUpdate: (details) {
            setState(() {
              final updated = List<Offset>.from(scaled);
              updated[i] = Offset(
                (pos.dx + details.delta.dx).clamp(0, displaySize.width),
                (pos.dy + details.delta.dy).clamp(0, displaySize.height),
              );
              _corners = updated;
              _imageNaturalSize = _imageNaturalSize; // keep as-is; corners now in display space
              _imageDisplaySize = displaySize;
            });
          },
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.blueAccent.withOpacity(0.85),
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildFilterBar() {
    final options = const [
      ("enhance", "Enhance", Icons.auto_fix_high),
      ("color", "Color", Icons.palette),
      ("gray", "Gray", Icons.filter_b_and_w),
      ("bw", "B & W", Icons.contrast),
    ];
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: options.map((o) {
          final selected = _mode == o.$1;
          return GestureDetector(
            onTap: () => setState(() => _mode = o.$1),
            child: Column(
              children: [
                Icon(o.$3, color: selected ? Colors.blueAccent : Colors.white70),
                const SizedBox(height: 4),
                Text(o.$2, style: TextStyle(color: selected ? Colors.blueAccent : Colors.white70, fontSize: 12)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<ui.Image> _loadImage(String path) async {
    final data = await File(path).readAsBytes();
    final codec = await ui.instantiateImageCodec(data);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  Size _fitSize(Size natural, Size bounds) {
    // Use the smaller scale so the whole image fits within bounds (letterboxed).
    final s = [bounds.width / natural.width, bounds.height / natural.height].reduce((a, b) => a < b ? a : b);
    return Size(natural.width * s, natural.height * s);
  }
}

class _QuadPainter extends CustomPainter {
  final List<Offset> corners;
  _QuadPainter(this.corners);

  @override
  void paint(Canvas canvas, Size size) {
    if (corners.length < 4) return;
    final paint = Paint()
      ..color = Colors.blueAccent.withOpacity(0.35)
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = Colors.blueAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final path = Path()..addPolygon(corners, true);
    canvas.drawPath(path, paint);
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _QuadPainter oldDelegate) => true;
}
