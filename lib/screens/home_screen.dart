import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // Add this import for kDebugMode
import 'package:flutter/scheduler.dart'; // Add this import for scheduleMicrotask
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:location/location.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:ui' as ui;
import '../models/parking_spot.dart';
import '../providers/parking_provider.dart';
import '../providers/theme_provider.dart';
import '../services/places_service.dart';
import '../widgets/profile_avatar.dart'; // Add this import
import 'dart:async';
import 'dart:math' as math;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  GoogleMapController? mapController; // Changed from late to nullable
  final LatLng _center = const LatLng(27.7046, 85.3206); // Kathmandu
  final PlacesService _placesService = PlacesService();
  final TextEditingController _searchController = TextEditingController();
  final Location _location = Location();
  bool _isSearching = false;
  List<Map<String, dynamic>> _searchResults = [];
  Timer? _debounce;
  bool _locationPermissionGranted = false;
  LatLng? _currentPosition;

  // Custom marker icons cache with different sizes
  final Map<String, BitmapDescriptor> _markerCache = {};
  double _currentZoom = 12.0; // Track current zoom level

  // Dark map style
  String? _darkMapStyle;
  bool _isDarkModeApplied = false; // Track current map theme state

  // Kathmandu Valley bounds
  static final LatLngBounds _kathmanduBounds = LatLngBounds(
    southwest: const LatLng(27.6000, 85.2000), // Southwest corner
    northeast: const LatLng(27.8000, 85.4500), // Northeast corner
  );

  // Zoom limits
  static const double _minZoom = 10.0;
  static const double _maxZoom = 20.0;

  bool _isSubmitting = false;
  bool _isLoadingLocation = false;
  ParkingSpot? _selectedParkingSpot; // Add selected parking spot state

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _requestLocationPermission();
    _createCustomMarkers();
    _loadMapStyle();
  }

  // Load dark map style from assets
  Future<void> _loadMapStyle() async {
    try {
      // Load the JSON file from the assets
      final String jsonString = await rootBundle.loadString('assets/map_styles/dark_map_style.json');
      _darkMapStyle = jsonString;
    } catch (e) {
      if (kDebugMode) {
        print('Error loading map style: $e');
      }
    }
  }

  // Update map style based on theme with optimization
  void _updateMapStyle(bool isDarkMode) {
    // Only update if the theme actually changed and mapController is available
    if (_isDarkModeApplied == isDarkMode || mapController == null) return;

    _isDarkModeApplied = isDarkMode;

    if (isDarkMode && _darkMapStyle != null) {
      mapController!.setMapStyle(_darkMapStyle);
    } else {
      mapController!.setMapStyle(null); // Reset to default light style
    }
  }

  // Create custom parking markers with responsive sizing - optimized to prevent buffer overflow
  Future<void> _createCustomMarkers() async {
    // Reduce zoom levels to prevent buffer overflow - only create essential sizes
    final zoomLevels = [10.0, 14.0, 18.0]; // Reduced from 8 to 3 levels

    for (double zoom in zoomLevels) {
      final size = _getMarkerSizeForZoom(zoom);

      try {
        // Create markers one at a time with small delays to prevent buffer overflow
        _markerCache['free_$zoom'] = await _createCustomMarker(
          color: Colors.green,
          text: 'FREE',
          size: size,
        );

        // Small delay between marker creations to prevent buffer overflow
        await Future.delayed(const Duration(milliseconds: 10));

        _markerCache['paid_$zoom'] = await _createCustomMarker(
          color: Colors.orange,
          text: 'PAID',
          size: size,
        );

        // Small delay between marker creations
        await Future.delayed(const Duration(milliseconds: 10));

      } catch (e) {
        if (kDebugMode) {
          print('Error creating marker for zoom $zoom: $e');
        }
        // Fallback to default markers if custom creation fails
        _markerCache['free_$zoom'] = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
        _markerCache['paid_$zoom'] = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
      }
    }

    setState(() {}); // Refresh to update markers
  }

  // Calculate marker size based on zoom level - made even smaller
  double _getMarkerSizeForZoom(double zoom) {
    // Smaller sizes that are more proportional to the map
    if (zoom <= 10) return 30;  // Very small for far zoom
    if (zoom <= 12) return 35;  // Small for city level
    if (zoom <= 14) return 40;  // Medium for district level
    if (zoom <= 16) return 45;  // Normal for street level
    if (zoom <= 18) return 50;  // Slightly larger for close zoom
    return 55; // Max size for very close zoom - much smaller than before
  }

  // Get appropriate marker for current zoom level
  BitmapDescriptor? _getMarkerForSpot(ParkingSpot spot) {
    final zoomKey = _getNearestZoomKey(_currentZoom);
    final markerKey = spot.isPaid ? 'paid_$zoomKey' : 'free_$zoomKey';
    return _markerCache[markerKey];
  }

  // Get the nearest zoom level key for marker selection - updated for fewer levels
  double _getNearestZoomKey(double currentZoom) {
    final zoomLevels = [10.0, 14.0, 18.0]; // Reduced set
    return zoomLevels.reduce((a, b) =>
      (currentZoom - a).abs() < (currentZoom - b).abs() ? a : b);
  }

  // Create a responsive custom marker with large SP text only
  Future<BitmapDescriptor> _createCustomMarker({
    required Color color,
    required String text,
    required double size,
  }) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);

    // Draw marker background (rounded rectangle)
    final Paint bgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final RRect bgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size, size * 0.8),
      Radius.circular(size * 0.1),
    );
    canvas.drawRRect(bgRect, bgPaint);

    // Draw white border (scales with size)
    final Paint borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = size * 0.03;
    canvas.drawRRect(bgRect, borderPaint);

    // Draw large "SP" in the center (much bigger than before)
    final spFontSize = size * 0.35; // Much larger SP text
    final spPainter = TextPainter(
      text: TextSpan(
        text: 'SP',
        style: TextStyle(
          fontSize: spFontSize,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    spPainter.layout();
    spPainter.paint(
      canvas,
      Offset(
        (size - spPainter.width) / 2,
        (size * 0.8 - spPainter.height) / 2 - size * 0.05, // Center vertically with slight offset up
      ),
    );

    // Draw FREE/PAID text at the bottom (smaller than SP)
    final textFontSize = size * 0.15; // Slightly larger than before
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: textFontSize,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        (size - textPainter.width) / 2,
        size * 0.8 - textPainter.height - size * 0.03,
      ),
    );

    // Draw pointer/arrow at bottom (responsive size)
    final arrowWidth = size * 0.12;
    final Path arrowPath = Path();
    arrowPath.moveTo(size / 2 - arrowWidth, size * 0.8);
    arrowPath.lineTo(size / 2, size);
    arrowPath.lineTo(size / 2 + arrowWidth, size * 0.8);
    arrowPath.close();

    final Paint arrowPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(arrowPath, arrowPaint);
    canvas.drawPath(arrowPath, borderPaint);

    final ui.Picture picture = pictureRecorder.endRecording();
    final ui.Image image = await picture.toImage(size.toInt(), size.toInt());
    final ByteData? bytes = await image.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
  }

  // Request location permission and get current location
  Future<void> _requestLocationPermission() async {
    bool serviceEnabled;
    PermissionStatus permissionGranted;

    // Check if location service is enabled
    serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) {
        return;
      }
    }

    // Check location permission
    permissionGranted = await _location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await _location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) {
        return;
      }
    }

    // Configure location settings for better accuracy
    await _location.changeSettings(
      accuracy: LocationAccuracy.high,
      interval: 10000, // Update every 10 seconds
      distanceFilter: 5.0, // Only update if moved 5+ meters
    );

    setState(() {
      _locationPermissionGranted = true;
    });

    // Get current location with better accuracy
    try {
      final locationData = await _location.getLocation();
      if (locationData.latitude != null && locationData.longitude != null) {
        // Only update if accuracy is reasonable (less than 50 meters)
        if (locationData.accuracy != null && locationData.accuracy! < 50.0) {
          setState(() {
            _currentPosition = LatLng(locationData.latitude!, locationData.longitude!);
          });
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error getting current location: $e');
      }
    }
  }

  void _getCurrentLocation() async {
    try {
      if (!_locationPermissionGranted) {
        await _requestLocationPermission();
      }

      final locationData = await _location.getLocation();
      if (locationData.latitude != null && locationData.longitude != null) {
        // Only update if accuracy is reasonable (less than 50 meters)
        if (locationData.accuracy == null || locationData.accuracy! < 50.0) {
          final currentLocation = LatLng(locationData.latitude!, locationData.longitude!);

          setState(() {
            _currentPosition = currentLocation;
          });

          // Only animate camera if mapController is available
          if (mapController != null) {
            mapController!.animateCamera(
              CameraUpdate.newLatLngZoom(currentLocation, 18.0),
            );
          }
        } else {
          // Show message if accuracy is poor
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Location accuracy is low (${locationData.accuracy?.toInt()}m). Try moving to an open area.'),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error getting current location: $e');
      }
    }
  }

  // Search for parking spots near current location
  void _searchNearMe() async {
    try {
      if (!_locationPermissionGranted) {
        await _requestLocationPermission();
        return;
      }

      final locationData = await _location.getLocation();
      if (locationData.latitude != null && locationData.longitude != null) {
        final currentLocation = LatLng(locationData.latitude!, locationData.longitude!);

        setState(() {
          _currentPosition = currentLocation;
        });

        // Move map to current location with appropriate zoom level only if mapController is available
        if (mapController != null) {
          mapController!.animateCamera(
            CameraUpdate.newLatLngZoom(currentLocation, 16.0),
          );
        }

        // Get nearby parking spots
        final parkingProvider = Provider.of<ParkingProvider>(context, listen: false);
        final nearbySpots = _getNearbyParkingSpots(
          currentLocation,
          parkingProvider.getAllParkingSpots()
        );

        // Show parking list directly in a slideable bottom sheet
        if (mounted) {
          if (nearbySpots.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No parking spots found within 2km of your location'),
                duration: Duration(seconds: 2),
              ),
            );
          } else {
            _showNearbyParkingBottomSheet(nearbySpots);
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error searching near current location: $e');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error getting your location. Please try again.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  // Google Maps integration functions - direct launch without canLaunchUrl checks
  Future<void> _openGoogleMapsDirections(ParkingSpot spot) async {
    try {
      // Try Google Maps app with intent scheme first (most reliable on Android)
      final googleMapsIntent = Uri.parse(
        'google.navigation:q=${spot.latitude},${spot.longitude}&mode=d'
      );

      try {
        await launchUrl(googleMapsIntent, mode: LaunchMode.externalApplication);
        return;
      } catch (e) {
        // If that fails, try geo intent
      }

      // Try geo intent for any navigation app
      final geoIntent = Uri.parse(
        'geo:0,0?q=${spot.latitude},${spot.longitude}(${Uri.encodeComponent(spot.name)})'
      );

      try {
        await launchUrl(geoIntent, mode: LaunchMode.externalApplication);
        return;
      } catch (e) {
        // If that fails, try web fallback
      }

      // Fallback to web browser
      final webUrl = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=${spot.latitude},${spot.longitude}'
      );

      await launchUrl(webUrl, mode: LaunchMode.platformDefault);

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open maps: $e'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _openGoogleMapsLocation(ParkingSpot spot) async {
    try {
      // Try Google Maps app intent first
      final googleMapsIntent = Uri.parse(
        'geo:${spot.latitude},${spot.longitude}?q=${spot.latitude},${spot.longitude}(${Uri.encodeComponent(spot.name)})'
      );

      try {
        await launchUrl(googleMapsIntent, mode: LaunchMode.externalApplication);
        return;
      } catch (e) {
        // If that fails, try simple geo intent
      }

      // Try generic map intent
      final mapIntent = Uri.parse(
        'geo:${spot.latitude},${spot.longitude}?z=17'
      );

      try {
        await launchUrl(mapIntent, mode: LaunchMode.externalApplication);
        return;
      } catch (e) {
        // If that fails, try web fallback
      }

      // Fallback to web browser
      final webUrl = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${spot.latitude},${spot.longitude}'
      );

      await launchUrl(webUrl, mode: LaunchMode.platformDefault);

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open maps: $e'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // Called when search text changes
  void _onSearchChanged() {
    if (_searchController.text.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    // Debounce the search to prevent too many API calls
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      // Only search if text is not empty
      if (_searchController.text.isNotEmpty) {
        _searchLocation(_searchController.text);
      }
    });
  }

  Set<Marker> _buildMarkers(List<ParkingSpot> spots) {
    return spots.map((spot) {
      final markerId = MarkerId(spot.id);
      final position = LatLng(spot.latitude, spot.longitude);
      final infoWindow = InfoWindow(
        title: spot.name,
        snippet: spot.isPaid ? 'Paid' : 'Free',
        onTap: () {
          Navigator.pushNamed(context, '/details', arguments: spot);
        },
      );

      // Use zoom-responsive custom icons
      final icon = _getMarkerForSpot(spot);

      return Marker(
        markerId: markerId,
        position: position,
        infoWindow: infoWindow,
        icon: icon ?? BitmapDescriptor.defaultMarker,
        onTap: () {
          // Select the parking spot to show Google Maps buttons
          setState(() {
            _selectedParkingSpot = spot;
          });
        },
      );
    }).toSet();
  }

  Future<void> _searchLocation(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final placesResult = await _placesService.searchPlaces(query);

      if (placesResult != null && placesResult['results'] != null) {
        final results = List<Map<String, dynamic>>.from(placesResult['results']);

        if (results.isNotEmpty) {
          setState(() {
            _searchResults = results;
          });
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error during place search: $e');
      }
    }

    setState(() {
      _isSearching = false;
    });
  }

  void _selectSearchResult(Map<String, dynamic> result) {
    final location = _placesService.getLocationFromPlaceResult(result);

    // Move map to that location only if mapController is available
    if (mapController != null) {
      mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(location, 15.0)
      );
    }

    // Clear search results but keep the text in the search field
    setState(() {
      _searchResults = [];
    });

    // Show parking spots near the searched location
    _showParkingNearLocation(location, result['name'] ?? 'Selected Location');
  }

  // Show parking spots near a specific location (like searched destination)
  void _showParkingNearLocation(LatLng location, String locationName) {
    final parkingProvider = Provider.of<ParkingProvider>(context, listen: false);
    final nearbySpots = _getNearbyParkingSpots(
      location,
      parkingProvider.getAllParkingSpots(),
      5.0 // 5km radius for destination searches
    );

    if (nearbySpots.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No parking spots found near $locationName'),
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      _showDestinationParkingBottomSheet(nearbySpots, locationName, location);
    }
  }

  // Show bottom sheet with parking spots near destination
  void _showDestinationParkingBottomSheet(List<ParkingSpot> nearbySpots, String locationName, LatLng destinationLocation) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.only(top: 8, bottom: 16),
                height: 4,
                width: 40,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Parking Near',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.grey[600],
                                ),
                              ),
                              Text(
                                locationName,
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '${nearbySpots.length} parking spot${nearbySpots.length == 1 ? '' : 's'} found',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Parking spots list
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: nearbySpots.length,
                  itemBuilder: (context, index) {
                    final spot = nearbySpots[index];
                    final distance = _calculateDistance(destinationLocation, LatLng(spot.latitude, spot.longitude));

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: spot.isPaid ? Colors.orange.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            spot.isPaid ? Icons.paid : Icons.free_breakfast,
                            color: spot.isPaid ? Colors.orange : Colors.green,
                            size: 24,
                          ),
                        ),
                        title: Text(
                          spot.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on,
                                  size: 16,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(width: 4),
                                Text('${distance.toStringAsFixed(1)}km from destination'),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(
                                  spot.isPaid ? Icons.payment : Icons.free_breakfast,
                                  size: 16,
                                  color: spot.isPaid ? Colors.orange : Colors.green,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  spot.isPaid ? 'Paid Parking' : 'Free Parking',
                                  style: TextStyle(
                                    color: spot.isPaid ? Colors.orange : Colors.green,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.arrow_forward_ios, size: 16),
                            const SizedBox(height: 4),
                            Text(
                              'View',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          // Navigate to spot on map only if mapController is available
                          if (mapController != null) {
                            mapController!.animateCamera(
                              CameraUpdate.newLatLngZoom(
                                LatLng(spot.latitude, spot.longitude),
                                18.0
                              ),
                            );
                          }
                          // Show spot details after a delay
                          Future.delayed(const Duration(milliseconds: 500), () {
                            Navigator.pushNamed(context, '/details', arguments: spot);
                          });
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Calculate distance between two LatLng points in kilometers
  double _calculateDistance(LatLng from, LatLng to) {
    const double earthRadius = 6371; // Earth's radius in kilometers

    final double lat1Rad = from.latitude * (math.pi / 180);
    final double lat2Rad = to.latitude * (math.pi / 180);
    final double deltaLatRad = (to.latitude - from.latitude) * (math.pi / 180);
    final double deltaLngRad = (to.longitude - from.longitude) * (math.pi / 180);

    final double a = math.sin(deltaLatRad / 2) * math.sin(deltaLatRad / 2) +
        math.cos(lat1Rad) * math.cos(lat2Rad) *
        math.sin(deltaLngRad / 2) * math.sin(deltaLngRad / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  // Get nearby parking spots within a certain radius
  List<ParkingSpot> _getNearbyParkingSpots(LatLng location, List<ParkingSpot> allSpots, [double radiusKm = 2.0]) {
    final List<ParkingSpot> nearbySpots = [];

    for (final spot in allSpots) {
      final spotLocation = LatLng(spot.latitude, spot.longitude);
      final distance = _calculateDistance(location, spotLocation);

      if (distance <= radiusKm) {
        nearbySpots.add(spot);
      }
    }

    // Sort by distance (closest first)
    nearbySpots.sort((a, b) {
      final distanceA = _calculateDistance(location, LatLng(a.latitude, a.longitude));
      final distanceB = _calculateDistance(location, LatLng(b.latitude, b.longitude));
      return distanceA.compareTo(distanceB);
    });

    return nearbySpots;
  }

  // Show bottom sheet with nearby parking spots (for current location search)
  void _showNearbyParkingBottomSheet(List<ParkingSpot> nearbySpots) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.only(top: 8, bottom: 16),
                height: 4,
                width: 40,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Nearby Parking (${nearbySpots.length})',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Parking spots list
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: nearbySpots.length,
                  itemBuilder: (context, index) {
                    final spot = nearbySpots[index];
                    final distance = _currentPosition != null
                        ? _calculateDistance(_currentPosition!, LatLng(spot.latitude, spot.longitude))
                        : 0.0;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: spot.isPaid ? Colors.orange.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            spot.isPaid ? Icons.paid : Icons.free_breakfast,
                            color: spot.isPaid ? Colors.orange : Colors.green,
                            size: 24,
                          ),
                        ),
                        title: Text(
                          spot.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text('${distance.toStringAsFixed(1)}km away'),
                            Text(spot.isPaid ? 'Paid Parking' : 'Free Parking'),
                          ],
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, '/details', arguments: spot);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ParkingProvider, ThemeProvider>(
      builder: (context, parkingProvider, themeProvider, child) {
        // Update map style when theme changes
        SchedulerBinding.instance.addPostFrameCallback((_) {
          _updateMapStyle(themeProvider.isDarkMode);
        });

        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'Parking Yeta',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
            elevation: 0,
            actions: [
              // Search Near Me button
              IconButton(
                icon: const Icon(Icons.search_outlined),
                onPressed: _searchNearMe,
                tooltip: 'Search Near Me',
              ),
              // Dark mode toggle
              IconButton(
                icon: Icon(
                  themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode,
                ),
                onPressed: () {
                  themeProvider.toggleTheme();
                },
                tooltip: themeProvider.isDarkMode ? 'Light Mode' : 'Dark Mode',
              ),
              // Profile avatar with picture
              Padding(
                padding: const EdgeInsets.only(right: 8.0, top: 8.0, bottom: 8.0),
                child: ProfileAvatar(
                  size: 36,
                  onTap: () {
                    Navigator.pushNamed(context, '/profile');
                  },
                ),
              ),
            ],
          ),
          body: Stack(
            children: [
              // Google Map
              GoogleMap(
                onMapCreated: (GoogleMapController controller) {
                  mapController = controller;
                  // Apply theme immediately after map creation
                  _updateMapStyle(themeProvider.isDarkMode);
                },
                initialCameraPosition: CameraPosition(
                  target: _center,
                  zoom: _currentZoom,
                ),
                mapType: MapType.normal, // Use normal 2D map instead of 3D
                buildingsEnabled: false, // Explicitly disable 3D buildings
                markers: _buildMarkers(parkingProvider.getAllParkingSpots()),
                myLocationEnabled: _locationPermissionGranted,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false, // Disable zoom controls (+/-)
                minMaxZoomPreference: const MinMaxZoomPreference(_minZoom, _maxZoom),
                cameraTargetBounds: CameraTargetBounds(_kathmanduBounds),
                onCameraMove: (CameraPosition position) {
                  _currentZoom = position.zoom;
                },
              ),
              // Search bar
              Positioned(
                top: 10,
                left: 16,
                right: 16,
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search for a place...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _isSearching
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: Padding(
                                padding: EdgeInsets.all(12.0),
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : (_searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _searchResults = [];
                                    });
                                  },
                                )
                              : null),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Theme.of(context).scaffoldBackgroundColor,
                    ),
                  ),
                ),
              ),
              // Search results
              if (_searchResults.isNotEmpty)
                Positioned(
                  top: 70,
                  left: 16,
                  right: 16,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final result = _searchResults[index];
                        return ListTile(
                          leading: const Icon(Icons.location_on),
                          title: Text(result['name'] ?? 'Unknown'),
                          subtitle: Text(result['formatted_address'] ?? ''),
                          onTap: () => _selectSearchResult(result),
                        );
                      },
                    ),
                  ),
                ),
            ],
          ),
          floatingActionButton: Stack(
            children: [
              // Left side Google Maps buttons (only show when parking spot is selected)
              if (_selectedParkingSpot != null) ...[
                // Google Maps Directions button
                Positioned(
                  left: 16,
                  bottom: 80,
                  child: FloatingActionButton(
                    heroTag: "directions",
                    onPressed: () async {
                      try {
                        await _openGoogleMapsDirections(_selectedParkingSpot!);
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
                    },
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    child: const Icon(Icons.directions),
                  ),
                ),
                // Google Maps View Location button
                Positioned(
                  left: 16,
                  bottom: 0,
                  child: FloatingActionButton(
                    heroTag: "view_on_map",
                    onPressed: () async {
                      try {
                        await _openGoogleMapsLocation(_selectedParkingSpot!);
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
                    },
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    child: const Icon(Icons.map),
                  ),
                ),
                // Close/Deselect button
                Positioned(
                  left: 16,
                  bottom: 160,
                  child: FloatingActionButton(
                    heroTag: "close_selection",
                    onPressed: () {
                      setState(() {
                        _selectedParkingSpot = null;
                      });
                    },
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    mini: true,
                    child: const Icon(Icons.close),
                  ),
                ),
              ],
              // Right side buttons (existing)
              // Use Current Location button
              Positioned(
                right: 0,
                bottom: 80,
                child: FloatingActionButton(
                  heroTag: "location",
                  onPressed: _getCurrentLocation,
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  child: const Icon(Icons.my_location),
                ),
              ),
              // Add Parking Spot button (add location icon)
              Positioned(
                right: 0,
                bottom: 0,
                child: FloatingActionButton(
                  heroTag: "add_parking",
                  onPressed: () {
                    Navigator.pushNamed(context, '/add');
                  },
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  child: const Icon(Icons.add_location),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
