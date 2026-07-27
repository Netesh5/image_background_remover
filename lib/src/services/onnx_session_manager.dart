import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:image_background_remover/assets.dart';

/// Manages ONNX Runtime session lifecycle
class OnnxSessionManager {
  // Migration: Added OnnxRuntime instance for flutter_onnxruntime package
  final OnnxRuntime _ort = OnnxRuntime();

  // The ONNX session used for inference
  OrtSession? _session;

  /// Gets the current session
  OrtSession? get session => _session;

  /// Checks if session is initialized
  bool get isInitialized => _session != null;

  /// Initializes the ONNX session from assets.
  ///
  /// This method should be called once before performing inference.
  Future<void> initialize() async {
    try {
      /// Migration: Simplified to use createSessionFromAsset() instead of manual buffer loading
      _session = await _ort.createSessionFromAsset(Assets.modelPath);

      if (kDebugMode) {
        log('ONNX session created successfully.', name: "OnnxSessionManager");
        log('Input names: ${_session!.inputNames}', name: "OnnxSessionManager");
        log('Output names: ${_session!.outputNames}',
            name: "OnnxSessionManager");
      }
    } catch (e) {
      if (kDebugMode) {
        log('Error creating ONNX session: $e', name: "OnnxSessionManager");
      }
      rethrow;
    }
  }

  /// Releases session resources
  /// Migration: Changed to async and use close() instead of release()
  Future<void> dispose() async {
    if (_session != null) {
      await _session!.close();
      _session = null;
      if (kDebugMode) {
        log('ONNX session closed successfully.', name: "OnnxSessionManager");
      }
    }
  }
}
