import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

/// Utility class for composing backgrounds and images
class BackgroundComposer {
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
  static Future<Uint8List> addBackground({
    required Uint8List image,
    required Color bgColor,
  }) async {
    final img.Image decodedImage = img.decodeImage(image)!;
    final newImage =
        img.Image(width: decodedImage.width, height: decodedImage.height);
    img.fill(
      newImage,
      color: img.ColorRgb8(bgColor.red, bgColor.green, bgColor.blue),
    );
    img.compositeImage(newImage, decodedImage);
    final jpegBytes = img.encodeJpg(newImage);
    final completer = Completer<Uint8List>();
    completer.complete(jpegBytes.buffer.asUint8List());
    return completer.future;
  }
}
