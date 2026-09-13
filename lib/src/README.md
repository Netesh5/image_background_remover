## Directory Structure

```
lib/src/
├── background_remover.dart       # Main public API
├── services/
│   └── onnx_session_manager.dart # ONNX Runtime session management
└── utils/
    ├── image_processor.dart       # Image processing utilities
    ├── mask_processor.dart        # Mask processing utilities
    └── background_composer.dart   # Background composition utilities
```

## Module Responsibilities

### Main Module

#### `background_remover.dart`
- **Purpose**: Main public API for background removal
- **Key Methods**:
  - `initializeOrt()`: Initialize ONNX Runtime session
  - `removeBg()`: Remove background from an image
  - `addBackground()`: Add a colored background to an image
  - `dispose()`: Release resources

---

### Services

#### `services/onnx_session_manager.dart`
- **Purpose**: Manages ONNX Runtime session lifecycle
- **Responsibilities**:
  - Creating and initializing ONNX session from assets
  - Managing session state and lifecycle
  - Providing session access to inference operations
  - Proper cleanup and resource disposal
- **Key Features**:
  - Singleton pattern through BackgroundRemover
  - Session validation before inference
  - Detailed logging for debugging

---

### Utilities

#### `utils/image_processor.dart`
- **Purpose**: Core image processing operations
- **Key Methods**:
  - `resizeImage()`: Resize images to target dimensions
  - `imageToFloatTensor()`: Convert images to normalized float tensors
  - `applyMaskToImage()`: Apply alpha mask to images
- **Features**:
  - ImageNet normalization (mean/std)
  - High-quality image resizing
  - Alpha blending with feathering
  - Optional mask smoothing

#### `utils/mask_processor.dart`
- **Purpose**: Mask processing and enhancement
- **Key Methods**:
  - `resizeMaskNearest()`: Resize masks using nearest neighbor interpolation
  - `resizeMaskBilinear()`: Resize masks using bilinear interpolation
  - `enhanceMaskEdges()`: Enhance mask edges using gradient detection
- **Features**:
  - Multiple interpolation methods
  - Edge-aware mask enhancement
  - Sobel-like gradient detection
  - Configurable enhancement parameters

#### `utils/background_composer.dart`
- **Purpose**: Background composition and image manipulation
- **Key Methods**:
  - `addBackground()`: Composite images with colored backgrounds
- **Features**:
  - Color background addition
  - Image encoding/decoding
  - Image composition

---

## Migration Notes

This codebase has been migrated from `onnxruntime` to `flutter_onnxruntime`. Key changes include:

1. **Session Management**: Simplified session creation using `createSessionFromAsset()`
2. **Tensor Operations**: Updated to use `OrtValue.fromList()` API
3. **Inference**: Streamlined with `session.run()` method
4. **Resource Management**: Proper async disposal with `close()` and `dispose()`

All migration-related code is marked with `// Migration:` comments.

---

## Usage Example

```dart
import 'package:image_background_remover/image_background_remover.dart';

// Initialize once at app startup
await BackgroundRemover.instance.initializeOrt();

// Remove background from image
final imageBytes = await File('path/to/image.jpg').readAsBytes();
final imageWithoutBg = await BackgroundRemover.instance.removeBg(
  imageBytes,
  threshold: 0.5,
  smoothMask: true,
  enhanceEdges: true,
);

// Add colored background
final imageData = await imageWithoutBg.toByteData(format: ui.ImageByteFormat.png);
final withBackground = await BackgroundRemover.instance.addBackground(
  image: imageData!.buffer.asUint8List(),
  bgColor: Colors.blue,
);

// Clean up when done
await BackgroundRemover.instance.dispose();
```

