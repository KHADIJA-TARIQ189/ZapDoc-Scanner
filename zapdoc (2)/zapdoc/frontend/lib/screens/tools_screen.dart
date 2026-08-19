import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'document_viewer_screen.dart';

class _Tool {
  final String title;
  final IconData icon;
  final Color color;
  final bool multiFile;
  const _Tool(this.title, this.icon, this.color, {this.multiFile = false});
}

/// Grid of iLovePDF-style tools. Tapping one opens a file picker, runs the
/// matching backend endpoint, then shows the result.
class ToolsScreen extends StatefulWidget {
  const ToolsScreen({super.key});

  @override
  State<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends State<ToolsScreen> {
  bool _busy = false;

  final _tools = const [
    _Tool("Merge PDF", Icons.merge_type, Colors.indigo, multiFile: true),
    _Tool("Split PDF", Icons.call_split, Colors.orange),
    _Tool("Compress PDF", Icons.compress, Colors.teal),
    _Tool("Rotate PDF", Icons.rotate_right, Colors.purple),
    _Tool("Watermark", Icons.branding_watermark, Colors.brown),
    _Tool("Protect PDF", Icons.lock, Colors.red),
    _Tool("Unlock PDF", Icons.lock_open, Colors.green),
    _Tool("Extract Text (OCR)", Icons.text_snippet, Colors.blue),
    _Tool("Searchable PDF (OCR)", Icons.document_scanner, Colors.deepPurple),
  ];

  Future<void> _run(_Tool tool) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ["pdf"],
      allowMultiple: tool.multiFile,
    );
    if (result == null || result.files.isEmpty) return;

    setState(() => _busy = true);
    try {
      String outputPath;
      final path = result.files.first.path!;

      switch (tool.title) {
        case "Merge PDF":
          final paths = result.files.map((f) => f.path!).toList();
          outputPath = await ApiService.mergePdfs(paths);
          break;
        case "Split PDF":
          final ranges = await _askText("Page ranges (e.g. 1-2,3-5)", "Leave blank to split every page");
          outputPath = await ApiService.splitPdf(path, ranges: ranges);
          break;
        case "Compress PDF":
          outputPath = await ApiService.compressPdf(path);
          break;
        case "Rotate PDF":
          outputPath = await ApiService.rotatePdf(path, degrees: 90);
          break;
        case "Watermark":
          final text = await _askText("Watermark text", "e.g. CONFIDENTIAL") ?? "ZapDoc";
          outputPath = await ApiService.watermarkPdf(path, text);
          break;
        case "Protect PDF":
          final pw = await _askText("Set a password", "");
          if (pw == null || pw.isEmpty) throw Exception("Password required");
          outputPath = await ApiService.protectPdf(path, pw);
          break;
        case "Unlock PDF":
          final pw = await _askText("Current password", "");
          if (pw == null || pw.isEmpty) throw Exception("Password required");
          outputPath = await ApiService.unlockPdf(path, pw);
          break;
        case "Extract Text (OCR)":
          outputPath = await ApiService.ocrPdf(path, outputType: "text");
          break;
        case "Searchable PDF (OCR)":
          outputPath = await ApiService.ocrPdf(path, outputType: "searchable_pdf");
          break;
        default:
          throw Exception("Unknown tool");
      }

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => DocumentViewerScreen(filePath: outputPath, title: tool.title)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${tool.title} failed: $e")));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _askText(String label, String hint) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(label),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: hint),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text("OK")),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("PDF Tools")),
      body: Stack(
        children: [
          GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.85,
            ),
            itemCount: _tools.length,
            itemBuilder: (context, i) {
              final tool = _tools[i];
              return InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _busy ? null : () => _run(tool),
                child: Container(
                  decoration: BoxDecoration(
                    color: tool.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(tool.icon, size: 36, color: tool.color),
                      const SizedBox(height: 8),
                      Text(tool.title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              );
            },
          ),
          if (_busy)
            Container(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
