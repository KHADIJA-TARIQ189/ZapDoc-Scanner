import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

/// Generic "here's your result" screen shown after scanning to PDF or
/// running any PDF tool. Lets the user open the file in another app,
/// share it, or just go back.
class DocumentViewerScreen extends StatelessWidget {
  final String filePath;
  final String title;

  const DocumentViewerScreen({super.key, required this.filePath, required this.title});

  @override
  Widget build(BuildContext context) {
    final fileName = filePath.split('/').last;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.insert_drive_file, size: 96, color: Colors.blueAccent),
              const SizedBox(height: 16),
              Text(fileName, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              const Text("Saved to your ZapDoc documents.", style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: () => OpenFilex.open(filePath),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text("Open"),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () => Share.shareXFiles([XFile(filePath)]),
                    icon: const Icon(Icons.share),
                    label: const Text("Share"),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
                child: const Text("Done"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
