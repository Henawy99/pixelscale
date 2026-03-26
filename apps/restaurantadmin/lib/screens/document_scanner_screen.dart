import 'dart:async';
import 'dart:ui' as ui; // For ui.Image
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // For compute
// import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart'; // Temporarily disabled for iOS build

import 'package:restaurantadmin/models/scan_type.dart';

class DocumentScannerScreen extends StatefulWidget {
  final ScanType scanType;
  const DocumentScannerScreen({super.key, required this.scanType});

  @override
  State<DocumentScannerScreen> createState() => _DocumentScannerScreenState();
}

class _DocumentScannerScreenState extends State<DocumentScannerScreen> {
  CameraController? _controller;
  CameraDescription? _selectedCamera;
  bool _isCameraInitialized = false;
  bool _isTakingPicture = false;
  bool _isProcessingFrame = false;
  final int _frameThrottleCounter = 0;
  final int _throttleRate = 5; // Process 1 out of every 5 frames

  // late TextRecognizer _textRecognizer; // Temporarily disabled
  Rect? _detectedDocumentBounds;

  @override
  void initState() {
    super.initState();
    // _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin); // Temporarily disabled
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No cameras available on this device.'),
            ),
          );
          Navigator.of(context).pop();
        }
        return;
      }
      _selectedCamera = cameras[0]; // Use the first available camera

      _controller = CameraController(
        _selectedCamera!,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup
            .nv21, // Or yuv420 for Android, bgra8888 for iOS if issues
      );

      await _controller!.initialize();
      if (!mounted) return;

      await _controller!.startImageStream(_processCameraImage);

      setState(() {
        _isCameraInitialized = true;
      });
    } catch (e) {
      print("Error initializing camera: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error initializing camera: ${e.toString()}')),
        );
        Navigator.of(context).pop();
      }
    }
  }

  @override
  void dispose() {
    _controller?.stopImageStream().catchError((e) {
      print("Error stopping image stream: $e");
    });
    _controller?.dispose();
    // _textRecognizer.close(); // Temporarily disabled
    super.dispose();
  }

  Future<void> _processCameraImage(CameraImage image) async {
    // Temporarily disabled for iOS build
    if (mounted) {
      setState(() {
        _isProcessingFrame = false;
      });
    }
    return;

    // if (_isProcessingFrame || !mounted) return;

    // _frameThrottleCounter++;
    // if (_frameThrottleCounter % _throttleRate != 0) {
    //   return;
    // }

    // setState(() {
    //   _isProcessingFrame = true;
    // });

    // try {
    //   final inputImage = await _convertCameraImageToInputImage(image, _selectedCamera!);
    //   if (inputImage == null) {
    //     setState(() { _isProcessingFrame = false; });
    //     return;
    //   }

    //   final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);

    //   Rect? encompassingRect;
    //   if (recognizedText.blocks.isNotEmpty) {
    //     for (final block in recognizedText.blocks) {
    //       if (encompassingRect == null) {
    //         encompassingRect = block.boundingBox;
    //       } else {
    //         encompassingRect = encompassingRect.expandToInclude(block.boundingBox);
    //       }
    //     }
    //   }

    //   if (mounted) {
    //     setState(() {
    //       _detectedDocumentBounds = encompassingRect;
    //       _isProcessingFrame = false;
    //     });
    //   }
    // } catch (e) {
    //   print("Error processing image frame: $e");
    //   if (mounted) {
    //     setState(() {
    //       _isProcessingFrame = false;
    //     });
    //   }
    // }
  }

  // Helper function to convert CameraImage to InputImage
  // This is a complex part and might need adjustments based on specific device behaviors
  // Future<InputImage?> _convertCameraImageToInputImage(CameraImage image, CameraDescription cameraDescription) async { // Temporarily disabled
  // final WriteBuffer allBytes = WriteBuffer();
  // for (final Plane plane in image.planes) {
  //   allBytes.putUint8List(plane.bytes);
  // }
  // final bytes = allBytes.done().buffer.asUint8List();

  // final Size imageSize = Size(image.width.toDouble(), image.height.toDouble());

  // final InputImageRotation imageRotation = InputImageRotationValue.fromRawValue(cameraDescription.sensorOrientation) ?? InputImageRotation.rotation0deg;

  // final InputImageFormat inputImageFormat = InputImageFormatValue.fromRawValue(image.format.raw) ?? InputImageFormat.nv21;

  // On iOS, the format is often bgra8888, on Android it's often nv21 (yuv420)
  // This might need platform-specific handling if imageFormatGroup in CameraController is not sufficient
  // For example:
  // final inputImageFormat = Platform.isIOS ? InputImageFormat.bgra8888 : InputImageFormat.nv21;

  // For versions of google_ml_kit_commons (e.g., ~0.9.0) that expect bytesPerRow directly
  // If the API expects a single int for bytesPerRow, use the first plane's value.
  // final int firstPlaneBytesPerRow = image.planes.isNotEmpty ? image.planes[0].bytesPerRow : 0;

  // final inputImageMetadata = InputImageMetadata(
  //   size: imageSize,
  //   rotation: imageRotation, // Corrected to 'rotation'
  //   format: inputImageFormat,   // Corrected to 'format'
  //   bytesPerRow: firstPlaneBytesPerRow, // Using bytesPerRow from the first plane
  // );

  // return InputImage.fromBytes(bytes: bytes, metadata: inputImageMetadata);
  // }

  Future<void> _onTakePictureButtonPressed() async {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        _isTakingPicture) {
      return;
    }
    setState(() {
      _isTakingPicture = true;
    });

    // Stop image stream before taking picture to avoid conflicts
    await _controller?.stopImageStream().catchError((e) {
      print("Error stopping stream before pic: $e");
    });

    try {
      final XFile imageFile = await _controller!.takePicture();
      if (mounted) {
        Navigator.of(context).pop(imageFile.path);
      }
    } catch (e) {
      print("Error taking picture: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error taking picture: ${e.toString()}')),
        );
        // Optionally restart stream if picture fails and user stays on screen
        // if (_controller != null && _controller!.value.isInitialized && !_controller!.value.isStreamingImages) {
        //   await _controller!.startImageStream(_processCameraImage);
        // }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTakingPicture = false;
        });
        // Consider if stream should be restarted if user cancels or picture fails
        // For now, popping the screen means stream restart isn't strictly needed here
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized || _controller == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Initializing Camera...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final mediaSize = MediaQuery.of(context).size;
    final previewSize =
        _controller!.value.previewSize ??
        mediaSize; // Fallback, should be available

    // Calculate scale to fit preview within mediaSize, maintaining aspect ratio
    final scaleX =
        mediaSize.width /
        previewSize.height; // Preview is landscape, screen is portrait
    final scaleY = mediaSize.height / previewSize.width;
    final scale = scaleX < scaleY ? scaleX : scaleY;

    return Scaffold(
      appBar: AppBar(title: const Text('Scan Document')),
      body: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Positioned.fill(
            child: OverflowBox(
              // To handle aspect ratio differences
              maxWidth: double.infinity,
              maxHeight: double.infinity,
              alignment: Alignment.center,
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: previewSize.height, // Camera preview is landscape
                  height: previewSize.width,
                  child: CameraPreview(_controller!),
                ),
              ),
            ),
          ),
          // Dynamic overlay for document guidance
          if (_detectedDocumentBounds != null &&
              _controller!.value.previewSize != null)
            CustomPaint(
              size: mediaSize, // Use the full screen size for the painter
              painter: DocumentFramePainter(
                bounds: _detectedDocumentBounds!,
                previewImageSize: Size(
                  previewSize.width,
                  previewSize.height,
                ), // Original preview size
                cameraSensorOrientation:
                    _selectedCamera?.sensorOrientation ??
                    90, // Default to 90 if null
                screenSize: mediaSize,
              ),
            ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.large(
        onPressed: _onTakePictureButtonPressed,
        child: _isTakingPicture
            ? const CircularProgressIndicator(color: Colors.white)
            : const Icon(Icons.camera_alt),
      ),
    );
  }
}

class DocumentFramePainter extends CustomPainter {
  final Rect bounds;
  final Size previewImageSize; // The actual size of the image from the camera
  final int cameraSensorOrientation;
  final Size screenSize; // The size of the widget/screen where this is painted

  DocumentFramePainter({
    required this.bounds,
    required this.previewImageSize,
    required this.cameraSensorOrientation,
    required this.screenSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // size here is the CustomPaint widget's size (screenSize)
    final Paint paint = Paint()
      ..color = Colors.greenAccent
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    // The bounds are relative to the previewImageSize.
    // We need to transform these bounds to the coordinate system of the CustomPaint widget.

    // Determine if the preview image is rotated relative to the screen.
    // Typically, camera preview is landscape, and screen is portrait.
    // sensorOrientation is 0, 90, 180, 270.
    // For a typical phone held in portrait, sensorOrientation is often 90 or 270.

    bool isPreviewLandscape = previewImageSize.width > previewImageSize.height;
    bool isScreenPortrait = screenSize.height > screenSize.width;

    double scaleX, scaleY, offsetX, offsetY;
    Rect transformedBounds;

    // This logic assumes the CameraPreview widget handles fitting the preview image
    // onto the screen, maintaining aspect ratio. We need to replicate that scaling.
    // The CameraPreview is often scaled to fit or cover.
    // We need to map coordinates from the `previewImageSize` (potentially rotated)
    // to the `screenSize`.

    // Simplified scenario: Assuming preview is displayed 'aspectFit' within the screen.
    // This is a common case but might need adjustment if CameraPreview uses 'aspectFill' or other modes.

    // Coordinates from ML Kit are based on the image buffer, which corresponds to previewImageSize.
    // If sensorOrientation is 90 or 270, the image buffer's width/height are swapped relative to natural device orientation.

    Size
    displaySizeForBounds; // The size of the image as ML Kit sees it (after rotation for processing)
    if (cameraSensorOrientation == 90 || cameraSensorOrientation == 270) {
      displaySizeForBounds = Size(
        previewImageSize.height,
        previewImageSize.width,
      );
    } else {
      displaySizeForBounds = previewImageSize;
    }

    // Calculate scaling factors to map displaySizeForBounds to screenSize
    scaleX = screenSize.width / displaySizeForBounds.width;
    scaleY = screenSize.height / displaySizeForBounds.height;

    // Use the smaller scale factor to maintain aspect ratio (fit)
    double scale = (scaleX < scaleY) ? scaleX : scaleY;

    // Calculate the size of the scaled preview on the screen
    double scaledPreviewWidth = displaySizeForBounds.width * scale;
    double scaledPreviewHeight = displaySizeForBounds.height * scale;

    // Calculate offsets to center the scaled preview on the screen
    offsetX = (screenSize.width - scaledPreviewWidth) / 2;
    offsetY = (screenSize.height - scaledPreviewHeight) / 2;

    // Transform the bounds from the image coordinate system to the screen coordinate system
    // This needs to account for the rotation ML Kit expects.
    // The `bounds` from ML Kit are relative to the image passed to it.
    // If sensorOrientation is 90: (x,y) in image becomes (y, previewImageSize.width - x) in display
    // If sensorOrientation is 270: (x,y) in image becomes (previewImageSize.height - y, x) in display
    // This transformation is complex and depends on how InputImageRotation was set.
    // For simplicity here, we assume bounds are already in the coordinate system of displaySizeForBounds.
    // A more robust solution would pass the InputImageRotation to the painter.

    // Let's assume bounds are already in the coordinate system of displaySizeForBounds
    // (i.e., if image was rotated for MLKit, bounds are relative to that rotated image)
    transformedBounds = Rect.fromLTRB(
      bounds.left * scale + offsetX,
      bounds.top * scale + offsetY,
      bounds.right * scale + offsetX,
      bounds.bottom * scale + offsetY,
    );

    canvas.drawRect(transformedBounds, paint);

    // Optional: Draw corner markers or more sophisticated UI elements
    // Example: draw small circles at corners
    // canvas.drawCircle(transformedBounds.topLeft, 8, paint..style = PaintingStyle.fill);
    // canvas.drawCircle(transformedBounds.topRight, 8, paint..style = PaintingStyle.fill);
    // canvas.drawCircle(transformedBounds.bottomLeft, 8, paint..style = PaintingStyle.fill);
    // canvas.drawCircle(transformedBounds.bottomRight, 8, paint..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(covariant DocumentFramePainter oldDelegate) {
    return oldDelegate.bounds != bounds ||
        oldDelegate.previewImageSize != previewImageSize ||
        oldDelegate.cameraSensorOrientation != cameraSensorOrientation ||
        oldDelegate.screenSize != screenSize;
  }
}
