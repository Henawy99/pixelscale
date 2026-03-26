import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:playmakerappstart/field_booking_screen.dart';
import 'package:playmakerappstart/models/footballfield_model.dart';
import 'package:playmakerappstart/models/user_model.dart';
import 'package:playmakerappstart/services/supabase_service.dart';

class FieldsMapScreen extends StatefulWidget {
  final Position? currentPosition;
  final PlayerProfile playerProfile;

  const FieldsMapScreen({
    super.key,
    this.currentPosition,
    required this.playerProfile,
  });

  @override
  State<FieldsMapScreen> createState() => _FieldsMapScreenState();
}

class _FieldsMapScreenState extends State<FieldsMapScreen> {
  late GoogleMapController _mapController;
  late LatLng _center;
  final _supabaseService = SupabaseService();
  Set<Marker> _markers = {};
  BitmapDescriptor? _customIcon;
  bool _isLoading = true;
  OverlayEntry? _currentOverlayEntry;

  @override
  void initState() {
    super.initState();
    print("Initializing map screen");
    _initializeMap();
  }

  Future<void> _initializeMap() async {
    try {
      print("Starting map initialization");
      _initializeCenter();
      await _loadCustomMarker();
      await _fetchFootballFields();
      print("Map initialization completed");
      setState(() => _isLoading = false);
    } catch (e) {
      print("Error initializing map: $e");
      if (mounted) {
        _showError('Error initializing map');
        setState(() => _isLoading = false);
      }
    }
  }

  void _initializeCenter() {
    try {
      _center = widget.currentPosition != null
          ? LatLng(widget.currentPosition!.latitude, widget.currentPosition!.longitude)
          : const LatLng(30.0444, 31.2357); // Cairo coordinates as default
      print("Map center initialized to: $_center");
    } catch (e) {
      print("Error setting map center: $e");
      _center = const LatLng(30.0444, 31.2357); // Fallback to Cairo coordinates
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    print("Map creation started");
    _mapController = controller;
    _setMapVisibleArea();
    
    // Add error handling and debug logging
    controller.setMapStyle(null).then((_) {
      print("Map style set successfully");
    }).catchError((error) {
      print("Error setting map style: $error");
      _showError('Error loading map style');
    });
  }

  void _setMapVisibleArea() {
    if (_markers.isNotEmpty) {
      final bounds = _calculateLatLngBounds(_markers);
      _mapController.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
    }
  }

  LatLngBounds _calculateLatLngBounds(Set<Marker> markers) {
    if (markers.isEmpty) return LatLngBounds(
      southwest: _center,
      northeast: _center,
    );

    double? minLat, minLng, maxLat, maxLng;

    for (final marker in markers) {
      if (minLat == null || marker.position.latitude < minLat) {
        minLat = marker.position.latitude;
      }
      if (maxLat == null || marker.position.latitude > maxLat) {
        maxLat = marker.position.latitude;
      }
      if (minLng == null || marker.position.longitude < minLng) {
        minLng = marker.position.longitude;
      }
      if (maxLng == null || marker.position.longitude > maxLng) {
        maxLng = marker.position.longitude;
      }
    }

    return LatLngBounds(
      southwest: LatLng(minLat!, minLng!),
      northeast: LatLng(maxLat!, maxLng!),
    );
  }

  Future<void> _goToCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showError('Location services are disabled');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showError('Location permissions are denied');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showError('Location permissions are permanently denied');
        return;
      }

      setState(() => _isLoading = true);
      final position = await Geolocator.getCurrentPosition();
      final location = LatLng(position.latitude, position.longitude);

      await _mapController.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: location, zoom: 15),
        ),
      );

      setState(() {
        _center = location;
        _isLoading = false;
      });
    } catch (e) {
      _showError('Failed to get current location');
    }
  }

  Future<void> _loadCustomMarker() async {
    try {
      final data = await DefaultAssetBundle.of(context).load(
        'assets/images/playmakermarker2.png',
      );
      final resized = await _resizeMarker(data.buffer.asUint8List());
      _customIcon = BitmapDescriptor.fromBytes(resized);
    } catch (e) {
      _showError('Failed to load custom marker');
    }
  }

  Future<Uint8List> _resizeMarker(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes, targetWidth: 150);
    final frame = await codec.getNextFrame();
    final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  Future<void> _fetchFootballFields() async {
    List<FootballField> allFieldsList = [];
    int offset = 0;
    bool hasMore = true;
    const int batchSize = 50;

    try {
      while (hasMore) {
        final result = await _supabaseService.getFootballFieldsPaginated(
          limit: batchSize,
          offset: offset,
        );
        allFieldsList.addAll(result);
        offset += batchSize;
        hasMore = result.length == batchSize;
      }

      final glowingMarker = await _createGlowingMarker();
      
      if (mounted) {
        setState(() {
          _markers = {};
          for (var field in allFieldsList) {
            // Main marker
            _markers.add(Marker(
              markerId: MarkerId(field.id),
              position: LatLng(field.latitude, field.longitude),
              icon: _customIcon ?? BitmapDescriptor.defaultMarker,
              onTap: () => _showFieldDetails(field),
              zIndex: 2,
            ));
          
            // Add glow effect marker
            _markers.add(Marker(
              markerId: MarkerId("glow_${field.id}"),
              position: LatLng(field.latitude, field.longitude),
              icon: glowingMarker,
              zIndex: 1,
              alpha: 0.7,
            ));
          }
        });
      }
      
      _setMapVisibleArea();
    } catch (e) {
      print("Error fetching football fields for map: $e");
      if (mounted) {
        _showError('Failed to load fields');
      }
    }
  }

  Future<BitmapDescriptor> _createGlowingMarker() async {
    final size = 180.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    
    final paint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(size / 2, size / 2),
        size / 2,
        [
          const Color(0xFF00BF63).withOpacity(0.4),
          const Color(0xFF00BF63).withOpacity(0.0),
        ],
        [0.7, 1.0],
      );
    
    canvas.drawCircle(Offset(size / 2, size / 2), size / 2, paint);
    
    final picture = recorder.endRecording();
    final img = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    
    return BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
  }

  void _showFieldDetails(FootballField field) {
    final theme = Theme.of(context);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.5),
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.35, // Reduced height since we removed amenities
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            
            // Content area
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Two-column layout: Image + Details
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Field image
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: field.photos.isNotEmpty
                                ? Image.network(
                                    field.photos[0],
                                    width: 120,
                                    height: 120,
                                    fit: BoxFit.cover,
                                    loadingBuilder: (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Container(
                                        width: 120,
                                        height: 120,
                                        color: theme.colorScheme.surfaceVariant,
                                        child: Center(
                                          child: CircularProgressIndicator(
                                            value: loadingProgress.expectedTotalBytes != null
                                                ? loadingProgress.cumulativeBytesLoaded /
                                                    loadingProgress.expectedTotalBytes!
                                                : null,
                                          ),
                                        ),
                                      );
                                    },
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        width: 120,
                                        height: 120,
                                        color: theme.colorScheme.surfaceVariant,
                                        child: Center(
                                          child: Icon(
                                            Icons.broken_image,
                                            size: 36,
                                            color: theme.colorScheme.error,
                                          ),
                                        ),
                                      );
                                    },
                                  )
                                : Container(
                                    width: 120,
                                    height: 120,
                                    color: theme.colorScheme.surfaceVariant,
                                    child: Center(
                                      child: Icon(
                                        Icons.sports_soccer,
                                        size: 36,
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                          ),
                          
                          const SizedBox(width: 16),
                          
                          // Field details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  field.footballFieldName,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                
                                const SizedBox(height: 8),
                                
                                // Location
                                Row(
                                  children: [
                                    Icon(
                                      Icons.location_on,
                                      size: 16,
                                      color: theme.colorScheme.primary,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        field.locationName,
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                
                                const SizedBox(height: 10),
                                
                                // Price
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF00BF63).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.payments_outlined,
                                        size: 16,
                                        color: Color(0xFF00BF63),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${field.priceRange} EGP',
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          color: const Color(0xFF00BF63),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Very small gap before button - reduced spacing here
                    const SizedBox(height: 8),
                    
                    // Book button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => FieldBookingScreen(
                                field: field,
                                playerProfile: widget.playerProfile,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.calendar_today_outlined, size: 18),
                        label: const Text('Book Field'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturePill(ThemeData theme, IconData icon, String label) {
    return Container(
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureChip(ThemeData theme, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSizeCard(ThemeData theme, String size, String dimensions) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            size,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            dimensions,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
          ),
        ),
      ),
      body: Stack(
        children: [
          GoogleMap(
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            myLocationEnabled: true,
            initialCameraPosition: CameraPosition(
              target: _center,
              zoom: 11.0,
            ),
            markers: _markers,
            mapType: MapType.normal,
            compassEnabled: true,
            tiltGesturesEnabled: true,
            rotateGesturesEnabled: true,
            scrollGesturesEnabled: true,
            zoomGesturesEnabled: true,
            liteModeEnabled: false,
            mapToolbarEnabled: false,
            onMapCreated: _onMapCreated,
            onCameraMove: (CameraPosition position) {
              print("Camera moved to: ${position.target}");
              // Remove overlay when map moves
              if (_currentOverlayEntry != null && _currentOverlayEntry!.mounted) {
                _currentOverlayEntry!.remove();
                _currentOverlayEntry = null;
              }
            },
            onCameraIdle: () {
              print("Camera stopped moving");
            },
          ),
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton(
              heroTag: 'location',
              backgroundColor: const Color(0xFF00BF63),
              foregroundColor: Colors.white,
              onPressed: _goToCurrentLocation,
              child: const Icon(FontAwesomeIcons.locationArrow),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black26,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}
