import 'dart:ui' as ui;

/// Utility class for mask processing operations
class MaskProcessor {
  /// Resizes the mask using nearest neighbor interpolation.
  static List resizeMaskNearest(
    List mask,
    int originalWidth,
    int originalHeight, {
    int maskSize = 320,
  }) {
    final resizedMask = List.generate(
      originalHeight,
      (_) => List.filled(originalWidth, 0.0),
    );

    for (int y = 0; y < originalHeight; y++) {
      for (int x = 0; x < originalWidth; x++) {
        final scaledX = x * maskSize ~/ originalWidth;
        final scaledY = y * maskSize ~/ originalHeight;
        resizedMask[y][x] = mask[scaledY][scaledX];
      }
    }
    return resizedMask;
  }

  /// Resizes the mask using bilinear interpolation for smoother edges.
  static List resizeMaskBilinear(
    List mask,
    int originalWidth,
    int originalHeight,
  ) {
    final resizedMask = List.generate(
      originalHeight,
      (_) => List.filled(originalWidth, 0.0),
    );

    final maskHeight = mask.length;
    final maskWidth = mask[0].length;

    for (int y = 0; y < originalHeight; y++) {
      for (int x = 0; x < originalWidth; x++) {
        // Map to floating point coordinates in the source mask
        final srcX = x * maskWidth / originalWidth;
        final srcY = y * maskHeight / originalHeight;

        // Get integer coordinates for the four surrounding pixels
        final x1 = srcX.floor();
        final y1 = srcY.floor();
        final x2 = (x1 + 1).clamp(0, maskWidth - 1);
        final y2 = (y1 + 1).clamp(0, maskHeight - 1);

        // Calculate interpolation weights
        final wx = srcX - x1;
        final wy = srcY - y1;

        // Perform bilinear interpolation
        resizedMask[y][x] = mask[y1][x1] * (1 - wx) * (1 - wy) +
            mask[y1][x2] * wx * (1 - wy) +
            mask[y2][x1] * (1 - wx) * wy +
            mask[y2][x2] * wx * wy;
      }
    }
    return resizedMask;
  }

  /// Enhances mask edges using image gradients for better edge quality.
  static Future<List> enhanceMaskEdges(
    ui.Image originalImage,
    List mask, {
    double gradientThreshold = 30.0,
  }) async {
    final byteData =
        await originalImage.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) throw Exception("Failed to get image ByteData");
    final rgbaBytes = byteData.buffer.asUint8List();

    final width = originalImage.width;
    final height = originalImage.height;
    final enhancedMask = List.generate(
      height,
      (y) => List.generate(width, (x) => mask[y][x]),
    );

    // Calculate image gradients (simple Sobel-like edge detection)
    for (int y = 1; y < height - 1; y++) {
      for (int x = 1; x < width - 1; x++) {
        // Calculate gradient magnitude using adjacent pixels
        final idxLeft = (y * width + (x - 1)) * 4;
        final idxRight = (y * width + (x + 1)) * 4;
        final idxUp = ((y - 1) * width + x) * 4;
        final idxDown = ((y + 1) * width + x) * 4;

        // Calculate gradient for each channel (R,G,B)
        final gradR = (rgbaBytes[idxRight] - rgbaBytes[idxLeft]).abs() +
            (rgbaBytes[idxDown] - rgbaBytes[idxUp]).abs();
        final gradG = (rgbaBytes[idxRight + 1] - rgbaBytes[idxLeft + 1]).abs() +
            (rgbaBytes[idxDown + 1] - rgbaBytes[idxUp + 1]).abs();
        final gradB = (rgbaBytes[idxRight + 2] - rgbaBytes[idxLeft + 2]).abs() +
            (rgbaBytes[idxDown + 2] - rgbaBytes[idxUp + 2]).abs();

        // Average gradient across channels
        final gradMagnitude = (gradR + gradG + gradB) / 3.0;

        // High gradient (edge) should sharpen the mask boundary
        if (gradMagnitude > gradientThreshold) {
          // If we're in a transition area (mask value between 0.3-0.7)
          if (mask[y][x] > 0.3 && mask[y][x] < 0.7) {
            // Push values closer to 0 or 1 based on neighbors
            double sum = 0;
            int count = 0;
            for (int ny = y - 1; ny <= y + 1; ny++) {
              for (int nx = x - 1; nx <= x + 1; nx++) {
                if (ny >= 0 && ny < height && nx >= 0 && nx < width) {
                  sum += mask[ny][nx];
                  count++;
                }
              }
            }
            final avg = sum / count;
            // Strengthen the decision at edges
            enhancedMask[y][x] = avg > 0.5
                ? (mask[y][x] + 0.1).clamp(0.0, 1.0)
                : (mask[y][x] - 0.1).clamp(0.0, 1.0);
          }
        }
      }
    }

    return enhancedMask;
  }
}
