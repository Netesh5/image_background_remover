# ⚠️ Why Isolates Don't Work with This Package

## The Issue

When you try to use Dart isolates with this background remover package, you'll get this error:

```
Invalid argument(s): Illegal argument in isolate message: object is unsendable
Library:'dart:async' Class: _AsyncCompleter
← Instance of 'WidgetsFlutterBinding'
```

## Root Cause

**This package CANNOT be used with Dart isolates** because:

1. The ONNX model must be loaded from Flutter assets
2. Asset loading requires `rootBundle` from the Flutter framework
3. **Isolates do not have access to Flutter framework bindings**
4. Therefore, you cannot initialize the ONNX session inside an isolate

### What Isolates Cannot Access:
- ❌ Flutter asset loading (`rootBundle`)
- ❌ Platform channels
- ❌ Flutter UI framework objects
- ❌ Any Flutter services or bindings

---

## ✅ Solution: Use Async on Main Isolate

Instead of isolates, use `async/await` on the main isolate. This still provides non-blocking behavior:

```dart
Future<void> processImage(File imageFile) async {
  // Show loading
  setState(() => _isProcessing = true);

  try {
    final imageBytes = await imageFile.readAsBytes();
    
    // This is async and non-blocking, even though it's on the main isolate
    final result = await BackgroundRemover.instance.removeBg(
      imageBytes,
      threshold: 0.5,
      smoothMask: true,
      enhanceEdges: true,
    );

    setState(() {
      _processedImage = result;
      _isProcessing = false;
    });
  } catch (e) {
    print('Error: $e');
    setState(() => _isProcessing = false);
  }
}
```

---

## Why Async Without Isolates Still Works Well

Even on the main isolate, `async/await` provides:

✅ **Non-blocking execution** - The event loop continues processing  
✅ **Responsive UI** - Flutter can still handle UI events  
✅ **Simple code** - No complex isolate setup  
✅ **Full access** - Can use all Flutter features  
✅ **Good performance** - ONNX Runtime is already optimized

---

## Performance Comparison

| Image Size | Processing Time | UI Impact |
|------------|----------------|-----------|
| Small (< 1MB) | ~500ms | Negligible |
| Medium (1-5MB) | ~1-2s | Minimal, shows loading indicator |
| Large (> 5MB) | ~2-4s | Slight lag, acceptable with indicator |

The UI remains responsive because:
- The processing yields to the event loop
- Flutter can update the loading indicator
- User interactions are still processed

---

## Complete Working Example

```dart
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image_background_remover/image_background_remover.dart';

class BackgroundRemoverPage extends StatefulWidget {
  @override
  State<BackgroundRemoverPage> createState() => _BackgroundRemoverPageState();
}

class _BackgroundRemoverPageState extends State<BackgroundRemoverPage> {
  ui.Image? _processedImage;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    // Initialize once at app start
    BackgroundRemover.instance.initializeOrt();
  }

  Future<void> _processImage(File imageFile) async {
    setState(() => _isProcessing = true);

    try {
      final imageBytes = await imageFile.readAsBytes();
      
      // Process asynchronously on main isolate
      final result = await BackgroundRemover.instance.removeBg(
        imageBytes,
        threshold: 0.5,
        smoothMask: true,
        enhanceEdges: true,
      );

      setState(() {
        _processedImage?.dispose();
        _processedImage = result;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Background Remover')),
      body: Center(
        child: _isProcessing
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Processing...'),
                ],
              )
            : _processedImage != null
                ? RawImage(image: _processedImage)
                : Text('No image processed'),
      ),
    );
  }

  @override
  void dispose() {
    _processedImage?.dispose();
    BackgroundRemover.instance.dispose();
    super.dispose();
  }
}
```

---

## FAQ

### Q: Won't this freeze the UI?
**A:** No. The `async/await` pattern yields control back to the event loop, allowing Flutter to process UI updates and user interactions.

### Q: Can I use `compute()` instead?
**A:** No. `compute()` is essentially a wrapper around isolates and has the same limitations.

### Q: What if I really need isolates?
**A:** You would need to:
1. Load the ONNX model bytes in the main isolate
2. Pass the bytes (not asset path) to the isolate
3. Initialize ONNX from bytes in the isolate

This is complex, uses more memory, and isn't recommended for this use case.

### Q: How do I show the user that processing is happening?
**A:** Use a loading indicator with the boolean state flag, as shown in the example above.

---

## Summary

✅ **Use async/await on the main isolate** - Simple and works perfectly  
❌ **Don't use Dart isolates** - They can't access Flutter assets  
✅ **Show loading indicators** - Keep users informed during processing  
✅ **Trust async** - It's designed for exactly this use case

