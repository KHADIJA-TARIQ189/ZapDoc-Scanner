import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Central place that talks to the ZapDoc Python backend.
///
/// IMPORTANT: set [baseUrl] to match where you're running the backend:
///   - Android emulator -> "http://10.0.2.2:8000"
///   - iOS simulator    -> "http://127.0.0.1:8000"
///   - Real device      -> "http://<your-computer-LAN-IP>:8000"
///   - Deployed server  -> "https://your-domain.com"
class ApiService {
  static const String baseUrl = "http://10.0.2.2:8000";

  // ---------------------------------------------------------------------
  // Scan (CamScanner-style)
  // ---------------------------------------------------------------------

  /// Uploads a raw photo, returns the detected 4 corners + image dimensions.
  static Future<Map<String, dynamic>> detectEdges(String imagePath) async {
    final uri = Uri.parse("$baseUrl/scan/detect");
    final request = http.MultipartRequest("POST", uri)
      ..files.add(await http.MultipartFile.fromPath("file", imagePath));
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    _checkOk(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Crops (perspective-corrects) + filters one page. Returns the local path
  /// of the downloaded, processed JPG.
  static Future<String> processScan({
    required String imagePath,
    List<List<double>>? corners,
    String mode = "enhance",
  }) async {
    final uri = Uri.parse("$baseUrl/scan/process");
    final request = http.MultipartRequest("POST", uri)
      ..fields["mode"] = mode
      ..files.add(await http.MultipartFile.fromPath("file", imagePath));
    if (corners != null) {
      request.fields["corners"] = jsonEncode(corners);
    }
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    _checkOk(response);
    return _saveBytes(response.bodyBytes, "processed.jpg");
  }

  /// Sends all processed page images (in order) and gets back one PDF.
  static Future<String> createPdf(List<String> processedImagePaths) async {
    final uri = Uri.parse("$baseUrl/scan/create-pdf");
    final request = http.MultipartRequest("POST", uri);
    for (final path in processedImagePaths) {
      request.files.add(await http.MultipartFile.fromPath("files", path));
    }
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    _checkOk(response);
    return _saveBytes(response.bodyBytes, "scan_${DateTime.now().millisecondsSinceEpoch}.pdf");
  }

  // ---------------------------------------------------------------------
  // PDF tools (iLovePDF-style)
  // ---------------------------------------------------------------------

  static Future<String> mergePdfs(List<String> pdfPaths) async {
    final request = http.MultipartRequest("POST", Uri.parse("$baseUrl/pdf/merge"));
    for (final path in pdfPaths) {
      request.files.add(await http.MultipartFile.fromPath("files", path));
    }
    final response = await http.Response.fromStream(await request.send());
    _checkOk(response);
    return _saveBytes(response.bodyBytes, "merged.pdf");
  }

  static Future<String> splitPdf(String pdfPath, {String? ranges}) async {
    final request = http.MultipartRequest("POST", Uri.parse("$baseUrl/pdf/split"));
    request.files.add(await http.MultipartFile.fromPath("file", pdfPath));
    if (ranges != null) request.fields["ranges"] = ranges;
    final response = await http.Response.fromStream(await request.send());
    _checkOk(response);
    return _saveBytes(response.bodyBytes, "split.zip");
  }

  static Future<String> compressPdf(String pdfPath, {int quality = 60}) async {
    final request = http.MultipartRequest("POST", Uri.parse("$baseUrl/pdf/compress"));
    request.files.add(await http.MultipartFile.fromPath("file", pdfPath));
    request.fields["quality"] = "$quality";
    final response = await http.Response.fromStream(await request.send());
    _checkOk(response);
    return _saveBytes(response.bodyBytes, "compressed.pdf");
  }

  static Future<String> rotatePdf(String pdfPath, {int degrees = 90, String? pages}) async {
    final request = http.MultipartRequest("POST", Uri.parse("$baseUrl/pdf/rotate"));
    request.files.add(await http.MultipartFile.fromPath("file", pdfPath));
    request.fields["degrees"] = "$degrees";
    if (pages != null) request.fields["pages"] = pages;
    final response = await http.Response.fromStream(await request.send());
    _checkOk(response);
    return _saveBytes(response.bodyBytes, "rotated.pdf");
  }

  static Future<String> watermarkPdf(String pdfPath, String text, {double opacity = 0.3}) async {
    final request = http.MultipartRequest("POST", Uri.parse("$baseUrl/pdf/watermark"));
    request.files.add(await http.MultipartFile.fromPath("file", pdfPath));
    request.fields["text"] = text;
    request.fields["opacity"] = "$opacity";
    final response = await http.Response.fromStream(await request.send());
    _checkOk(response);
    return _saveBytes(response.bodyBytes, "watermarked.pdf");
  }

  static Future<String> protectPdf(String pdfPath, String password) async {
    final request = http.MultipartRequest("POST", Uri.parse("$baseUrl/pdf/protect"));
    request.files.add(await http.MultipartFile.fromPath("file", pdfPath));
    request.fields["password"] = password;
    final response = await http.Response.fromStream(await request.send());
    _checkOk(response);
    return _saveBytes(response.bodyBytes, "protected.pdf");
  }

  static Future<String> unlockPdf(String pdfPath, String password) async {
    final request = http.MultipartRequest("POST", Uri.parse("$baseUrl/pdf/unlock"));
    request.files.add(await http.MultipartFile.fromPath("file", pdfPath));
    request.fields["password"] = password;
    final response = await http.Response.fromStream(await request.send());
    _checkOk(response);
    return _saveBytes(response.bodyBytes, "unlocked.pdf");
  }

  /// output_type: "text" | "searchable_pdf"
  static Future<String> ocrPdf(String pdfPath, {String outputType = "text", String lang = "eng"}) async {
    final request = http.MultipartRequest("POST", Uri.parse("$baseUrl/pdf/ocr"));
    request.files.add(await http.MultipartFile.fromPath("file", pdfPath));
    request.fields["output_type"] = outputType;
    request.fields["lang"] = lang;
    final response = await http.Response.fromStream(await request.send());
    _checkOk(response);
    if (outputType == "searchable_pdf") {
      return _saveBytes(response.bodyBytes, "searchable.pdf");
    }
    // plain text result: save to a .txt file and return its path
    return _saveBytes(response.bodyBytes, "ocr_text.txt");
  }

  // ---------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------

  static void _checkOk(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception("Backend error (${response.statusCode}): ${response.body}");
    }
  }

  static Future<String> _saveBytes(List<int> bytes, String filename) async {
    final dir = await getApplicationDocumentsDirectory();
    final uniqueName = "${DateTime.now().millisecondsSinceEpoch}_$filename";
    final file = File("${dir.path}/$uniqueName");
    await file.writeAsBytes(bytes);
    return file.path;
  }
}
