# Image Background Remover - Flutter

[![pub package](https://img.shields.io/pub/v/image_background_remover.svg)](https://pub.dev/packages/image_background_remover)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

## ⌗ Overview
A Flutter package that removes the background from images using an ONNX model. The package provides a seamless way to perform image processing, leveraging the power of machine learning through ONNX Runtime. This package works completely offline without any external API dependencies.

### 🆕 Version 2.0.0 - Major Update!

**Version 2.0.0** brings significant improvements with migration to [`flutter_onnxruntime`](https://pub.dev/packages/flutter_onnxruntime) for better maintenance and a modular architecture for easier customization.

#### What's New in v2.0.0:
- ✅ **Migrated to `flutter_onnxruntime`** - Better maintained and more stable
- ✅ **16KB Android Page Size Support** - Compatible with Google Play's 16KB requirement
- ✅ **iOS 16.0+ Support** - Minimum iOS SDK version requirement updated to 16.0
- ✅ **Modular Architecture** - Organized codebase with separate utilities
- ✅ **Improved Memory Management** - Better resource cleanup
- ⚠️ **Important**: Cannot be used with Dart isolates (see [Why No Isolates](WHY_NO_ISOLATES.md))

See [CHANGELOG.md](CHANGELOG.md) for detailed migration notes.

> **⚠️ Experiencing Issues with v2.0.0?**
> 
> If you encounter any problems with version 2.0.0, please:
> 1. **[Open an issue](https://github.com/Netesh5/image_background_remover/issues)** with detailed information (error logs, device info, steps to reproduce)
> 2. Meanwhile, you can use the **stable version v1.0.0**:
>    ```yaml
>    dependencies:
>      image_background_remover: ^1.0.0
>    ```
> We'll work to resolve your issue as soon as possible!

---

## 🌟 Features

- Remove the background from images with high accuracy.
- Works entirely offline, ensuring privacy and reliability.  
- Lightweight and optimized for efficient performance.  
- Simple and seamless integration with Flutter projects. 
- Add a custom background color to images.
- Customizable threshold value for better edge detection.

---

## 🔭 Example
<img src="https://github.com/user-attachments/assets/a306cec8-82eb-482a-92d4-d5d99603aebc" alt="Overview" width="300" height="600" />


## Getting Started

### 🚀 Prerequisites

Before using this package, ensure that the following dependencies are included in your `pubspec.yaml`:

```yaml
dependencies:
  image_background_remover: ^2.0.0
  ```

---

## 📚 Migration Guide (v1.x → v2.0.0)

### What Changed?

The package has been migrated from `onnxruntime` to `flutter_onnxruntime` for better maintenance and stability.

### Do I Need to Change My Code?

**No!** The public API remains the same. Your existing code will continue to work:

```dart
// This works in both v1.x and v2.0.0
await BackgroundRemover.instance.initializeOrt();
final result = await BackgroundRemover.instance.removeBg(imageBytes);
await BackgroundRemover.instance.dispose();
```

### What Should I Know?

1. **Async Dispose** (Optional but Recommended):
   ```dart
   @override
   void dispose() {
     BackgroundRemover.instance.dispose(); // `dispose()` is async internally
     super.dispose();
   }
   ```
---

##  Usage
# Initialization
Before using the `removeBg` method, you must initialize the ONNX environment:
```dart
    import 'package:image_background_remover/image_background_remover.dart';

    @override
    void initState() {
        super.initState();
        BackgroundRemover.instance.initializeOrt();
    }
```

# Dispose
Don't forget to dispose the onnx runtime session :
```dart
  @override
  void dispose() {
    BackgroundRemover.instance.dispose();
    super.dispose();
  }
  ```

---

# Remove Background

To remove the background from an image:
``` dart
import 'dart:typed_data';
import 'package:image_background_remover/image_background_remover.dart';

Uint8List imageBytes = /* Load your image bytes */;
ui.Image resultImage = await BackgroundRemover.instance.removeBg(imageBytes);
/* resultImage will contain image with transparent background*/

```
---

## 🆕 New Feature: Add Background Color

You can now add a custom background color to images after removing the background.

### Usage:

```dart
Uint8List modifiedImage = await BackgroundRemover.instance.addBackground(
  image: originalImageBytes,
  bgColor: Colors.white, // Set your desired background color
);

```

---

  # ⚠️ Important Guidelines

**Why async without isolates is fine:**
- The processing is already non-blocking (async)
- UI remains responsive with proper loading indicators
- ONNX Runtime is already optimized
- Simpler code, no isolate complexity

For detailed explanation, see [WHY_NO_ISOLATES.md](WHY_NO_ISOLATES.md)

### ✅ Best Practices

1. **Initialize Once**: Call `initializeOrt()` once at app startup
2. **Show Loading**: Use loading indicators during processing
3. **Dispose Properly**: Clean up resources when done
4. **Handle Errors**: Wrap calls in try-catch blocks

```dart
// Good example with best practices
class MyWidget extends StatefulWidget {
  @override
  State<MyWidget> createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  bool _isProcessing = false;
  ui.Image? _result;

  @override
  void initState() {
    super.initState();
    BackgroundRemover.instance.initializeOrt();
  }

  Future<void> _processImage(Uint8List bytes) async {
    setState(() => _isProcessing = true);
    
    try {
      final result = await BackgroundRemover.instance.removeBg(bytes);
      setState(() => _result = result);
    } catch (e) {
      // Handle error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  void dispose() {
    _result?.dispose();
    BackgroundRemover.instance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _isProcessing 
      ? CircularProgressIndicator() 
      : /* your UI */;
  }
}
```
---

## API

### Methods

| Method                          | Description                                                                 | Parameters                                      | Returns                           |
|---------------------------------|-----------------------------------------------------------------------------|------------------------------------------------|-----------------------------------|
| `initializeOrt()`               | Initializes the ONNX runtime environment. Call this method once before using `removeBg`. | None                                           | `Future<void>`                   |
| `removeBg(Uint8List imageBytes, { double threshold = 0.5, bool smoothMask = true, bool enhanceEdges = true })` | Removes the background from an image.                                     | `imageBytes` - The image in byte array format. <br><br> `threshold` - The confidence threshold for background removal (default: `0.5`). A higher value removes more background, while a lower value retains more foreground. <br><br> `smoothMask` - Whether to apply bilinear interpolation for smoother edges (default: `true`). <br><br> `enhanceEdges` - Whether to refine mask boundaries using gradient-based edge enhancement (default: `true`). | `Future<ui.Image>` - The processed image with the background removed. |
| `addBackground({required Uint8List image, required Color bgColor})` | Adds a background color to the given image. | `image` - The original image in byte array format. <br> `bgColor` - The background color to be applied. | `Future<Uint8List>` - The modified image with the background color applied. |


## ⛔️ iOS Setup & Issues

### Required iOS Configuration

For the package to work correctly on iOS, you need to configure your iOS project:

1. **Update Podfile** (`ios/Podfile`):
   ```ruby
   platform :ios, '16.0'  # Minimum iOS 16.0 required
   
   target 'Runner' do
     use_frameworks! :linkage => :static
     use_modular_headers!
     
     flutter_install_all_ios_pods File.dirname(File.realpath(__FILE__))
   end
   ```

2. **Run pod install**:
   ```bash
   cd ios
   pod install
   ```

### Common iOS Issues

<details>
  <summary>Exception: ONNX session not initialized (iOS Release Mode & TestFlight)</summary>
  <br>

  To resolve this issue, update the following settings in Xcode:<br>

  Open Xcode and navigate to:<br>
  Runner.xcodeproj → Targets → Runner → Build Settings<br><br>

  Under the Deployment section:<br>
  Set "Strip Linked Product" to "No"<br>
  Set "Strip Style" to "Non-Global-Symbols"<br>

</details>


## ⚠️ Warning

This package uses an offline model to process images, which is bundled with the application. **This may increase the size of your app**. 


## ⚠️ Warning

This package uses an offline model to process images, which is bundled with the application. **This may increase the size of your app by approximately 30MB**.

## 📱 Android 16KB Page Size Support

Version 2.0.0 uses `flutter_onnxruntime` v1.6.1+, which fully supports **Google Play's 16KB page size requirement** for devices launching with Android 15 and beyond. This ensures your app will be compatible with all Android devices, including those with 16KB page size configurations.

**No additional configuration needed** - the package handles this automatically. 

---

## 📖 Additional Documentation

- **[CHANGELOG.md](CHANGELOG.md)** - Version history and migration notes
- **[WHY_NO_ISOLATES.md](WHY_NO_ISOLATES.md)** - Detailed explanation of isolate limitations
- **[lib/src/README.md](lib/src/README.md)** - Architecture documentation for contributors
- **Example App** - See [example/](example/) for a complete working example

---

## 🏗️ Architecture

Version 2.0.0 features a modular architecture:

```
lib/src/
├── background_remover.dart       # Main public API
├── services/
│   └── onnx_session_manager.dart # ONNX session lifecycle
└── utils/
    ├── image_processor.dart       # Image processing
    ├── mask_processor.dart        # Mask manipulation  
    └── background_composer.dart   # Background composition
```


---

## 🔗 Contributing
Contributions are welcome! If you encounter any issues or have suggestions for improvements, feel free to create an issue or submit a pull request.

## ☕ Support This Project
If you find this package helpful and want to support its development, you can buy me a coffee! Your support helps maintain and improve this package. 😊

[![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-donate-orange?style=flat-square&logo=buy-me-a-coffee)](https://www.buymeacoffee.com/neteshpaudel)
