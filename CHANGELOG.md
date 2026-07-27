## 2.0.1

### Fix
- **Bounded memory use during mask compositing.** `removeBg`/`removeBgBytes` previously held the full-resolution decoded source image through the entire RGBA decode/mask-apply/encode pipeline. For typical 12MP+ camera photos this could hold 2-3 full-resolution buffers in memory at once, causing out-of-memory crashes on release builds and mid/low-RAM devices (the model itself only ever used a 320x320 copy). Added `BackgroundRemover.instance.maxWorkingDimension` (default `1600`) — source images with a longest side above this are downscaled, preserving aspect ratio, before mask compositing.

## 2.0.0

### 🎉 Major Update: Migration to flutter_onnxruntime

#### Breaking Changes
- **Migrated from `onnxruntime` to `flutter_onnxruntime`** package for better maintenance and support
- `dispose()` method is now asynchronous internally (no user code changes required)

#### New Features
- **Modular Architecture**: Refactored codebase into organized modules for better maintainability
  - `services/onnx_session_manager.dart` - ONNX Runtime session management
  - `utils/image_processor.dart` - Image processing utilities
  - `utils/mask_processor.dart` - Mask processing utilities
  - `utils/background_composer.dart` - Background composition utilities
- **Better Resource Management**: Improved memory management with proper tensor disposal
- **Enhanced Error Handling**: More informative error messages and validation

#### Improvements
- **16KB Android Page Size Support**: Compatible with Google Play's 16KB requirement for Android 15+ devices
- Simplified ONNX session initialization (no manual buffer loading required)
- Better documentation with inline migration comments
- Improved code organization and separation of concerns
- Added comprehensive architecture documentation in `lib/src/README.md`

#### Important Notes
- **Isolate Support**: This package cannot be used with Dart isolates because ONNX model loading requires Flutter asset access. See `WHY_NO_ISOLATES.md` for detailed explanation.
- **Async/Await**: Use async processing on the main isolate - it provides non-blocking behavior without isolate complexity
- **Migration Guide**: All changes are marked with `// Migration:` comments in the code

#### API Changes
- Session management simplified (internal changes, no user-facing API changes)
- Tensor creation and disposal updated to new API (handled internally)

#### Files Added
- `lib/src/services/onnx_session_manager.dart` - Session lifecycle management
- `lib/src/utils/image_processor.dart` - Image processing utilities
- `lib/src/utils/mask_processor.dart` - Mask manipulation utilities
- `lib/src/utils/background_composer.dart` - Background composition
- `lib/src/README.md` - Architecture documentation
- `WHY_NO_ISOLATES.md` - Isolate limitations explanation

#### Migration from v1.x
If upgrading from v1.x:
1. **No code changes required!** The dispose call remains the same:
   ```dart
   @override
   void dispose() {
     BackgroundRemover.instance.dispose();
     super.dispose();
   }
   ```
   Note: Even though `dispose()` is async internally, you should **not** await it in your widget's dispose method because Flutter's dispose must be synchronous.

2. The public API remains completely backward compatible!

---

## 1.0.0

### Fix
- Minor Bug fix
- Readme file updated

## 0.0.7

### Added
- Implemented threshold-based segmentation to refine background removal.
- Integrated a smooth edge method using bilinear interpolation and average neighboring to improve output quality  and reduce harsh edges.
- Implemented edge enhancement for mask refinement using a Sobel-like gradient detection method.

## 0.0.6

### Feat
- Added `addBackground` function to change background of color

## 0.0.5

### Fix
- Minor bug fixes

## 0.0.4

### Fix
- Solved ONNX session creation error

## 0.0.3

### Added
- Added assets file.

## 0.0.2

### Fix
- Removed incompatible platform support.

## 0.0.1

### Added
- Initial release of the **Background Remover Service** Flutter package.
- ONNX Runtime integration for background removal using the `onnx` model.
- Functions to initialize ONNX session:
  - `initializeOrt()`: Initialize the ONNX environment and session.
- Image processing capabilities:
  - `removeBg(Uint8List imageBytes)`: Removes the background from an input image and returns the image with a transparent background.
  - `_resizeImage()`: Resizes an image to 320x320 for ONNXy model compatibility.
  - `_imageToFloatTensor()`: Converts RGBA image data into a normalized float tensor for model input.
  - `_applyMaskToOriginalSizeImage()`: Applies the generated mask back to the original image size.
- Utility methods:
  - `resizeMask()`: Resizes the ONNX output mask to match the original image dimensions.
- Designed for cross-platform support (iOS, Android, Web, and Desktop).
