import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/scan_page.dart';
import 'crop_screen.dart';
import 'multipage_screen.dart';

/// Landing screen for the "Scan" tab: lets the user open the camera
/// or pick an existing photo, then walks it through crop -> filter -> pages.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _initializing = true;
  final List<ScanPage> _pages = [];

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isNotEmpty) {
        _controller = CameraController(_cameras.first, ResolutionPreset.high, enableAudio: false);
        await _controller!.initialize();
      }
    } catch (_) {
      // No camera available (e.g. running on desktop/emulator without one) -
      // the UI falls back to "Pick from gallery" only.
    }
    if (mounted) setState(() => _initializing = false);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    final file = await _controller!.takePicture();
    await _goToCrop(file.path);
  }

  Future<void> _pickFromGallery() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) await _goToCrop(picked.path);
  }

  Future<void> _goToCrop(String rawPath) async {
    final page = ScanPage(rawImagePath: rawPath);
    final processed = await Navigator.push<ScanPage>(
      context,
      MaterialPageRoute(builder: (_) => CropScreen(page: page)),
    );
    if (processed != null) {
      setState(() => _pages.add(processed));
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => MultipageScreen(pages: _pages)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_initializing) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        if (_controller != null && _controller!.value.isInitialized)
          CameraPreview(_controller!)
        else
          Container(
            color: Colors.black,
            child: const Center(
              child: Text("No camera available.\nUse 'Pick from gallery' below.",
                  style: TextStyle(color: Colors.white), textAlign: TextAlign.center),
            ),
          ),
        // Document-frame guide overlay
        IgnorePointer(
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32, vertical: 100),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white70, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 24,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _RoundIconButton(icon: Icons.photo_library, onTap: _pickFromGallery, tooltip: "Gallery"),
              GestureDetector(
                onTap: _capture,
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                  ),
                  child: Container(
                    margin: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                  ),
                ),
              ),
              _RoundIconButton(
                icon: Icons.description,
                onTap: _pages.isEmpty
                    ? null
                    : () => Navigator.push(
                        context, MaterialPageRoute(builder: (_) => MultipageScreen(pages: _pages))),
                tooltip: "Pages (${_pages.length})",
                badge: _pages.isNotEmpty ? _pages.length : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final String tooltip;
  final int? badge;

  const _RoundIconButton({required this.icon, required this.onTap, required this.tooltip, this.badge});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          IconButton(
            onPressed: onTap,
            icon: Icon(icon, color: Colors.white, size: 32),
            style: IconButton.styleFrom(backgroundColor: Colors.black45, padding: const EdgeInsets.all(14)),
          ),
          if (badge != null)
            Positioned(
              right: -4,
              top: -4,
              child: CircleAvatar(radius: 10, backgroundColor: Colors.red, child: Text("$badge", style: const TextStyle(fontSize: 12, color: Colors.white))),
            ),
        ],
      ),
    );
  }
}
