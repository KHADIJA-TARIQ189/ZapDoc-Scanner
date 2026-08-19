import 'dart:io';
import 'package:flutter/material.dart';
import 'package:reorderables/reorderables.dart';
import '../models/scan_page.dart';
import '../services/api_service.dart';
import 'document_viewer_screen.dart';

/// Shows all pages scanned so far as a reorderable grid of thumbnails.
/// From here the user can add more pages, delete a page, or export
/// everything as a single PDF.
class MultipageScreen extends StatefulWidget {
  final List<ScanPage> pages;
  const MultipageScreen({super.key, required this.pages});

  @override
  State<MultipageScreen> createState() => _MultipageScreenState();
}

class _MultipageScreenState extends State<MultipageScreen> {
  bool _saving = false;

  Future<void> _saveAsPdf() async {
    setState(() => _saving = true);
    try {
      final paths = widget.pages.map((p) => p.displayPath).toList();
      final pdfPath = await ApiService.createPdf(paths);
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => DocumentViewerScreen(filePath: pdfPath, title: "Scanned Document")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Could not create PDF: $e")));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("${widget.pages.length} page(s)"),
        actions: [
          IconButton(
            tooltip: "Save as PDF",
            icon: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.picture_as_pdf),
            onPressed: _saving || widget.pages.isEmpty ? null : _saveAsPdf,
          ),
        ],
      ),
      body: widget.pages.isEmpty
          ? const Center(child: Text("No pages yet. Go back and scan one!"))
          : Padding(
              padding: const EdgeInsets.all(12),
              child: ReorderableWrap(
                spacing: 12,
                runSpacing: 12,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    final item = widget.pages.removeAt(oldIndex);
                    widget.pages.insert(newIndex, item);
                  });
                },
                children: widget.pages.asMap().entries.map((entry) {
                  final i = entry.key;
                  final page = entry.value;
                  return _PageThumb(
                    page: page,
                    index: i + 1,
                    onDelete: () => setState(() => widget.pages.removeAt(i)),
                  );
                }).toList(),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pop(context),
        child: const Icon(Icons.add_a_photo),
      ),
    );
  }
}

class _PageThumb extends StatelessWidget {
  final ScanPage page;
  final int index;
  final VoidCallback onDelete;

  const _PageThumb({required this.page, required this.index, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: 120,
          height: 160,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
            image: DecorationImage(image: FileImage(File(page.displayPath)), fit: BoxFit.cover),
          ),
        ),
        Positioned(
          bottom: 4,
          left: 4,
          child: CircleAvatar(radius: 12, backgroundColor: Colors.black54, child: Text("$index", style: const TextStyle(fontSize: 12, color: Colors.white))),
        ),
        Positioned(
          top: -4,
          right: -4,
          child: IconButton(
            icon: const Icon(Icons.cancel, color: Colors.redAccent),
            onPressed: onDelete,
          ),
        ),
      ],
    );
  }
}
