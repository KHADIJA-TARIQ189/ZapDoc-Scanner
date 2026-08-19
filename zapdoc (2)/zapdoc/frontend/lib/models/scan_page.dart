/// Represents one scanned page as it moves through the pipeline:
/// raw camera photo -> detected corners -> processed (cropped+filtered) image.
class ScanPage {
  final String rawImagePath;
  String? processedImagePath;
  List<List<double>>? corners; // [[x,y],[x,y],[x,y],[x,y]] in raw image px
  String filterMode; // "color" | "gray" | "bw" | "enhance"

  ScanPage({
    required this.rawImagePath,
    this.processedImagePath,
    this.corners,
    this.filterMode = "enhance",
  });

  /// The best image currently available to show the user.
  String get displayPath => processedImagePath ?? rawImagePath;
}
