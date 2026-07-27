import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Utility class for image processing operations
class ImageProcessor {
  /// ImageNet mean values for normalization
  static const List<double> mean = [0.485, 0.456, 0.406];

  /// ImageNet standard deviation values for normalization
  static const List<double> std = [0.229, 0.224, 0.225];

  /// Resizes the input image to the specified dimensions.
  static Future<ui.Image> resizeImage(
    ui.Image image,
    int targetWidth,
    int targetHeight,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()..filterQuality = FilterQuality.high;

    final srcRect =
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    final dstRect =
        Rect.fromLTWH(0, 0, targetWidth.toDouble(), targetHeight.toDouble());
    canvas.drawImageRect(image, srcRect, dstRect, paint);

    final picture = recorder.endRecording();
    return picture.toImage(targetWidth, targetHeight);
  }

  /// Converts an image into a floating-point tensor with proper normalization.
  /// Uses ImageNet mean and standard deviation for normalization.
  static Future<List<double>> imageToFloatTensor(ui.Image image) async {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) throw Exception("Failed to get image ByteData");
    final rgbaBytes = byteData.buffer.asUint8List();
    final pixelCount = image.width * image.height;
    final floats = List<double>.filled(pixelCount * 3, 0);

    /// Extract and normalize RGB channels with ImageNet mean/std.
    for (int i = 0; i < pixelCount; i++) {
      floats[i] = (rgbaBytes[i * 4] / 255.0 - mean[0]) / std[0]; // Red
      floats[pixelCount + i] =
          (rgbaBytes[i * 4 + 1] / 255.0 - mean[1]) / std[1]; // Green
      floats[2 * pixelCount + i] =
          (rgbaBytes[i * 4 + 2] / 255.0 - mean[2]) / std[2]; // Blue
    }
    return floats;
  }

  /// Applies the mask to the original image with configurable threshold and smoothing.
  static Future<ui.Image> applyMaskToImage(
    ui.Image image,
    List mask, {
    double threshold = 0.5,
    bool smooth = true,
  }) async {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) throw Exception("Failed to get image ByteData");

    final rgbaBytes = byteData.buffer.asUint8List();
    final pixelCount = image.width * image.height;
    final outRgbaBytes = Uint8List(4 * pixelCount);

    // Apply smoothing if requested
    List smoothedMask = mask;
    if (smooth) {
      smoothedMask = _smoothMask(mask, 3); // 3x3 blur kernel
    }

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final i = y * image.width + x;

        // Apply threshold for binary decision with feathering
        double maskValue = smoothedMask[y][x];
        int alpha;

        if (maskValue > threshold + 0.05) {
          alpha = 255; // Full opacity for foreground
        } else if (maskValue < threshold - 0.05) {
          alpha = 0; // Full transparency for background
        } else {
          // Smooth transition in the boundary region
          alpha = ((maskValue - (threshold - 0.05)) / 0.1 * 255)
              .round()
              .clamp(0, 255);
        }

        outRgbaBytes[i * 4] = rgbaBytes[i * 4]; // Red
        outRgbaBytes[i * 4 + 1] = rgbaBytes[i * 4 + 1]; // Green
        outRgbaBytes[i * 4 + 2] = rgbaBytes[i * 4 + 2]; // Blue
        outRgbaBytes[i * 4 + 3] = alpha; // Alpha
      }
    }

    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      outRgbaBytes,
      image.width,
      image.height,
      ui.PixelFormat.rgba8888,
      (ui.Image img) {
        completer.complete(img);
      },
    );

    return completer.future;
  }

  /// Helper method for mask smoothing using a box blur.
  static List _smoothMask(List mask, int kernelSize) {
    final height = mask.length;
    final width = mask[0].length;
    final smoothed = List.generate(
      height,
      (_) => List.filled(width, 0.0),
    );

    final halfKernel = kernelSize ~/ 2;

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        double sum = 0.0;
        int count = 0;

        for (int ky = -halfKernel; ky <= halfKernel; ky++) {
          for (int kx = -halfKernel; kx <= halfKernel; kx++) {
            final ny = y + ky;
            final nx = x + kx;

            if (nx >= 0 && nx < width && ny >= 0 && ny < height) {
              sum += mask[ny][nx];
              count++;
            }
          }
        }

        smoothed[y][x] = sum / count;
      }
    }

    return smoothed;
  }
}
