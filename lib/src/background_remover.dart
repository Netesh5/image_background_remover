import 'dart:async';
import 'dart:developer';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_background_remover/assets.dart';
import 'package:onnxruntime/onnxruntime.dart';
import 'package:image/image.dart' as img;

class BackgroundRemover {
  BackgroundRemover._internal();

  static final BackgroundRemover _instance = BackgroundRemover._internal();

  static BackgroundRemover get instance => _instance;

  // The ONNX session used for inference.
  OrtSession? _session;

  // ImageNet mean and standard deviation for normalization
  final List<double> _mean = [0.485, 0.456, 0.406];
  final List<double> _std = [0.229, 0.224, 0.225];

  int modelSize = 320;

  /// Initializes the ONNX environment and creates a session.
  ///
  /// This method should be called once before using the [removeBg] method.
  Future<void> initializeOrt() async {
    try {
      /// Initialize the ONNX runtime environment.
      OrtEnv.instance.init();

      /// Create the ONNX session.
      await _createSession();
    } catch (e) {
      log(e.toString());
    }
  }

  /// Creates an ONNX session using the model from assets.
  Future<void> _createSession() async {
    try {
      /// Session configuration options.
      final sessionOptions = OrtSessionOptions();

      /// Load the model as a raw asset.
      final rawAssetFile = await rootBundle.load(Assets.modelPath);

      /// Convert the asset to a byte array.
      final bytes = rawAssetFile.buffer.asUint8List();

      /// Create the ONNX session.
      _session = OrtSession.fromBuffer(bytes, sessionOptions);
      sessionOptions.release();
      if (kDebugMode) {
        log('ONNX session created successfully.', name: "BackgroundRemover");
      }
    } catch (e) {
      if (kDebugMode) {
        log('Error creating ONNX session: $e', name: "BackgroundRemover");
      }
    }
  }

  /// Removes the background from an image.
  ///
  /// This function processes the input image and removes its background,
  /// returning a new image with the background removed.
  ///
  /// - [imageBytes]: The input image as a byte array.
  /// - [threshold]: The threshold value for foreground/background separation (default: 0.5).
  /// - [smoothMask]: Whether to apply smoothing to the output mask (default: true).
  /// - Returns: A [ui.Image] with the background removed.
  ///
  /// Example usage:
  /// ```dart
  /// final imageBytes = await File('path_to_image').readAsBytes();
  /// final ui.Image imageWithoutBackground = await removeBackground(imageBytes);
  /// ```
  ///
  /// Note: This function may take some time to process depending on the size
  /// and complexity of the input image.
  Future<ui.Image> removeBg(
    Uint8List imageBytes, {
    double threshold = 0.5,
    bool smoothMask = true,
    bool enhanceEdges = true,
  }) async {
    if (_session == null) {
      throw Exception("ONNX session not initialized");
    }

    /// Decode the input image
    final originalImage = await decodeImageFromList(imageBytes);
    log('Original image size: ${originalImage.width}x${originalImage.height}');

    final resizedImage = await _resizeImage(originalImage, 320, modelSize);

    /// Convert the resized image into a tensor format required by the ONNX model.
    final rgbFloats = await _imageToFloatTensor(resizedImage);
    final inputTensor = OrtValueTensor.createTensorWithDataList(
      Float32List.fromList(rgbFloats),
      [1, 3, modelSize, modelSize],
    );

    /// Prepare the inputs and run inference on the ONNX model.
    final inputs = {'input.1': inputTensor};
    final runOptions = OrtRunOptions();
    final outputs = await _session!.runAsync(runOptions, inputs);
    inputTensor.release();
    runOptions.release();

    /// Process the output tensor and generate the final image with the background removed.
    final outputTensor = outputs?[0]?.value;
    if (outputTensor is List) {
      final mask = outputTensor[0][0];

      outputTensor.forEach((tensor) {
        tensor.release();
      });

      /// Generate and refine the mask
      final resizedMask = smoothMask
          ? resizeMaskBilinear(mask, originalImage.width, originalImage.height)
          : resizeMaskNearest(mask, originalImage.width, originalImage.height);

      /// Apply edge enhancement if requested
      final finalMask = enhanceEdges
          ? await _enhanceMaskEdges(originalImage, resizedMask)
          : resizedMask;

      /// Apply the mask to the original image
      return await _applyMaskToOriginalSizeImage(originalImage, finalMask,
          threshold: threshold, smooth: smoothMask);
    } else {
      throw Exception('Unexpected output format from ONNX model.');
    }
  }

  /// Resizes the input image to the specified dimensions.
  Future<ui.Image> _resizeImage(
      ui.Image image, int targetWidth, int targetHeight) async {
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

  /// Resizes the mask using nearest neighbor interpolation.
  List resizeMaskNearest(List mask, int originalWidth, int originalHeight) {
    final resizedMask = List.generate(
      originalHeight,
      (_) => List.filled(originalWidth, 0.0),
    );

    for (int y = 0; y < originalHeight; y++) {
      for (int x = 0; x < originalWidth; x++) {
        final scaledX = x * 320 ~/ originalWidth;
        final scaledY = y * 320 ~/ originalHeight;
        resizedMask[y][x] = mask[scaledY][scaledX];
      }
    }
    return resizedMask;
  }

  /// Resizes the mask using bilinear interpolation for smoother edges.
  List resizeMaskBilinear(List mask, int originalWidth, int originalHeight) {
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

  /// Converts an image into a floating-point tensor with proper normalization.
  Future<List<double>> _imageToFloatTensor(ui.Image image) async {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) throw Exception("Failed to get image ByteData");
    final rgbaBytes = byteData.buffer.asUint8List();
    final pixelCount = image.width * image.height;
    final floats = List<double>.filled(pixelCount * 3, 0);

    /// Extract and normalize RGB channels with ImageNet mean/std.
    for (int i = 0; i < pixelCount; i++) {
      floats[i] = (rgbaBytes[i * 4] / 255.0 - _mean[0]) / _std[0]; // Red
      floats[pixelCount + i] =
          (rgbaBytes[i * 4 + 1] / 255.0 - _mean[1]) / _std[1]; // Green
      floats[2 * pixelCount + i] =
          (rgbaBytes[i * 4 + 2] / 255.0 - _mean[2]) / _std[2]; // Blue
    }
    return floats;
  }

  /// Enhances mask edges using image gradients.
  Future<List> _enhanceMaskEdges(ui.Image originalImage, List mask) async {
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
        // final idx = (y * width + x) * 4;
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
        if (gradMagnitude > 30) {
          // Threshold can be adjusted
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

  /// Applies the mask to the original image with configurable threshold and smoothing.
  Future<ui.Image> _applyMaskToOriginalSizeImage(ui.Image image, List mask,
      {double threshold = 0.5, bool smooth = true}) async {
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
        outRgbaBytes, image.width, image.height, ui.PixelFormat.rgba8888,
        (ui.Image img) {
      completer.complete(img);
    });

    return completer.future;
  }

  /// Helper method for mask smoothing using a box blur.
  List _smoothMask(List mask, int kernelSize) {
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

  /// Adds a background color to the given image.
  ///
  /// This method takes an image in the form of a [Uint8List] and a background
  /// color as a [Color]. It decodes the image, creates a new image with the
  /// same dimensions, fills it with the specified background color, and then
  /// composites the original image onto the new image with the background color.
  ///
  /// Returns a [Future] that completes with the modified image as a [Uint8List].
  ///
  /// - Parameters:
  ///   - image: The original image as a [Uint8List].
  ///   - bgColor: The background color as a [Color].
  ///
  /// - Returns: A [Future] that completes with the modified image as a [Uint8List].
  Future<Uint8List> addBackground(
      {required Uint8List image, required Color bgColor}) async {
    final img.Image decodedImage = img.decodeImage(image)!;
    final newImage =
        img.Image(width: decodedImage.width, height: decodedImage.height);
    img.fill(newImage,
        color: img.ColorRgb8(bgColor.red, bgColor.green, bgColor.blue));
    img.compositeImage(newImage, decodedImage);
    final jpegBytes = img.encodeJpg(newImage);
    final completer = Completer<Uint8List>();
    completer.complete(jpegBytes.buffer.asUint8List());
    return completer.future;
  }

  /// Release resources
  void dispose() {
    _session?.release();
    _session = null;
    OrtEnv.instance.release();
  }
}
