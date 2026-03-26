import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';

// A singleton class to manage the local server and the latest scanned image.
class LocalScanServer {
  static final LocalScanServer _instance = LocalScanServer._internal();
  factory LocalScanServer() => _instance;
  LocalScanServer._internal();

  HttpServer? _server;
  Uint8List? _latestImageBytes;
  Function(Uint8List)? onImageReceived;

  // A simple getter to check if the server is running.
  bool get isRunning => _server != null;

  // Public method to get the latest image, used by the UI.
  Uint8List? get latestImage {
    final image = _latestImageBytes;
    _latestImageBytes = null; // Clear the image after it's been retrieved once.
    return image;
  }

  Future<void> startServer({int port = 8080}) async {
    if (_server != null) {
      print('Server is already running.');
      return;
    }

    final router = Router();

    // Define the endpoint for uploading the scanned image.
    router.post('/upload-scan', (Request request) async {
      try {
        final imageBytes = await request.read().toList();
        final flatImageBytes = imageBytes.expand((x) => x).toList();
        _latestImageBytes = Uint8List.fromList(flatImageBytes);

        print(
          'Received image from scanner: ${_latestImageBytes!.length} bytes.',
        );

        // If a callback is registered, invoke it.
        onImageReceived?.call(_latestImageBytes!);

        return Response.ok('Image received successfully.');
      } catch (e) {
        print('Error handling image upload: $e');
        return Response.internalServerError(body: 'Error processing image.');
      }
    });

    // Add CORS headers for all responses to allow cross-origin requests from the browser.
    final handler = const Pipeline()
        .addMiddleware(logRequests())
        .addMiddleware(_corsMiddleware)
        .addHandler(router.call);

    try {
      _server = await io.serve(handler, 'localhost', port);
      print('Local scan server started on http://localhost:$port');
    } catch (e) {
      print('Failed to start server: $e');
      _server = null;
    }
  }

  Future<void> stopServer() async {
    await _server?.close(force: true);
    _server = null;
    print('Local scan server stopped.');
  }

  // Middleware to add CORS headers to responses.
  static final Middleware _corsMiddleware = (Handler innerHandler) {
    return (Request request) async {
      if (request.method == 'OPTIONS') {
        return Response.ok(null, headers: _corsHeaders);
      }
      final response = await innerHandler(request);
      return response.change(headers: {...response.headers, ..._corsHeaders});
    };
  };

  // CORS headers that allow requests from any origin.
  static const Map<String, String> _corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Origin, Content-Type',
  };
}
