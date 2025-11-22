import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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
import '../widgets/profile_avatar.dart';
import 'dart:async';
import 'dart:math' as math;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  GoogleMapController? mapController;
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
  double _currentZoom = 12.0;

  // Dark map style
  String? _darkMapStyle;

  // Kathmandu Valley bounds
  static final LatLngBounds _kathmanduBounds = LatLngBounds(
    southwest: const LatLng(27.6000, 85.2000),
    northeast: const LatLng(27.8000, 85.4500),
  );

  // Zoom limits
  static const double _minZoom = 10.0;
  static const double _maxZoom = 20.0;

  ParkingSpot? _selectedParkingSpot;
  bool _areButtonsVisible = false;

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
      final String jsonString = await rootBundle.loadString(
        'assets/map_styles/dark_map_style.json',
      );
      _darkMapStyle = jsonString;
    } catch (e) {
      if (kDebugMode) {
        print('Error loading map style: $e');
      }
    }
  }

  // Create custom parking markers with responsive sizing
  Future<void> _createCustomMarkers() async {
    final zoomLevels = [10.0, 14.0, 18.0];

    for (double zoom in zoomLevels) {
      final size = _getMarkerSizeForZoom(zoom);

      try {
        _markerCache['free_$zoom'] = await _createCustomMarker(
          color: Colors.green,
          text: 'FREE',
          size: size,
        );

        await Future.delayed(const Duration(milliseconds: 10));

        _markerCache['paid_$zoom'] = await _createCustomMarker(
          color: Colors.orange,
          text: 'PAID',
          size: size,
        );

        await Future.delayed(const Duration(milliseconds: 10));
      } catch (e) {
        if (kDebugMode) {
          print('Error creating marker for zoom $zoom: $e');
        }
        _markerCache['free_$zoom'] = BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueGreen,
        );
        _markerCache['paid_$zoom'] = BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueOrange,
        );
      }
    }

    setState(() {});
  }

  double _getMarkerSizeForZoom(double zoom) {
    if (zoom <= 10) return 30;
    if (zoom <= 12) return 35;
    if (zoom <= 14) return 40;
    if (zoom <= 16) return 45;
    if (zoom <= 18) return 50;
    return 55;
  }

  BitmapDescriptor? _getMarkerForSpot(ParkingSpot spot) {
    final zoomKey = _getNearestZoomKey(_currentZoom);
    final markerKey = spot.isPaid ? 'paid_$zoomKey' : 'free_$zoomKey';
    return _markerCache[markerKey];
  }

  double _getNearestZoomKey(double currentZoom) {
    final zoomLevels = [10.0, 14.0, 18.0];
    return zoomLevels.reduce(
      (a, b) => (currentZoom - a).abs() < (currentZoom - b).abs() ? a : b,
    );
  }

  Future<BitmapDescriptor> _createCustomMarker({
    required Color color,
    required String text,
    required double size,
  }) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);

    // Draw marker background
    final Paint bgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final RRect bgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size, size * 0.8),
      Radius.circular(size * 0.1),
    );
    canvas.drawRRect(bgRect, bgPaint);

    // Draw white border
    final Paint borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = size * 0.03;
    canvas.drawRRect(bgRect, borderPaint);

    // Draw "SP" text
    final spFontSize = size * 0.35;
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
        (size * 0.8 - spPainter.height) / 2 - size * 0.05,
      ),
    );

    // Draw FREE/PAID text
    final textFontSize = size * 0.15;
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

    // Draw pointer/arrow
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
    final ByteData? bytes = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );

    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
  }

  Future<void> _requestLocationPermission() async {
    bool serviceEnabled;
    PermissionStatus permissionGranted;

    serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) {
        return;
      }
    }

    permissionGranted = await _location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await _location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) {
        return;
      }
    }

    await _location.changeSettings(
      accuracy: LocationAccuracy.high,
      interval: 10000,
      distanceFilter: 5.0,
    );

    setState(() {
      _locationPermissionGranted = true;
    });

    try {
      final locationData = await _location.getLocation();
      if (locationData.latitude != null && locationData.longitude != null) {
        if (locationData.accuracy != null && locationData.accuracy! < 50.0) {
          setState(() {
            _currentPosition = LatLng(
              locationData.latitude!,
              locationData.longitude!,
            );
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
        if (locationData.accuracy == null || locationData.accuracy! < 50.0) {
          final currentLocation = LatLng(
            locationData.latitude!,
            locationData.longitude!,
          );

          setState(() {
            _currentPosition = currentLocation;
          });

          if (mapController != null) {
            mapController!.animateCamera(
              CameraUpdate.newLatLngZoom(currentLocation, 18.0),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Location accuracy is low (${locationData.accuracy?.toInt()}m). Try moving to an open area.',
                ),
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

  void _searchNearMe() async {
    try {
      if (!_locationPermissionGranted) {
        await _requestLocationPermission();
        return;
      }

      final locationData = await _location.getLocation();
      if (locationData.latitude != null && locationData.longitude != null) {
        final currentLocation = LatLng(
          locationData.latitude!,
          locationData.longitude!,
        );

        setState(() {
          _currentPosition = currentLocation;
        });

        if (mapController != null) {
          mapController!.animateCamera(
            CameraUpdate.newLatLngZoom(currentLocation, 16.0),
          );
        }

        if (!mounted) return;
        final parkingProvider = Provider.of<ParkingProvider>(
          context,
          listen: false,
        );
        final nearbySpots = _getNearbyParkingSpots(
          currentLocation,
          parkingProvider.spots,
        );

        if (mounted) {
          if (nearbySpots.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'No parking spots found within 2km of your location',
                ),
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

  Future<void> _openGoogleMapsDirections(ParkingSpot spot) async {
    try {
      final googleMapsIntent = Uri.parse(
        'google.navigation:q=${spot.latitude},${spot.longitude}&mode=d',
      );

      try {
        await launchUrl(googleMapsIntent, mode: LaunchMode.externalApplication);
        return;
      } catch (e) {
        // Try geo intent
      }

      final geoIntent = Uri.parse(
        'geo:0,0?q=${spot.latitude},${spot.longitude}(${Uri.encodeComponent(spot.name)})',
      );

      try {
        await launchUrl(geoIntent, mode: LaunchMode.externalApplication);
        return;
      } catch (e) {
        // Try web fallback
      }

      final webUrl = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=${spot.latitude},${spot.longitude}',
      );

      await launchUrl(webUrl, mode: LaunchMode.platformDefault);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open maps: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _openGoogleMapsLocation(ParkingSpot spot) async {
    try {
      final googleMapsIntent = Uri.parse(
        'geo:${spot.latitude},${spot.longitude}?q=${spot.latitude},${spot.longitude}(${Uri.encodeComponent(spot.name)})',
      );

      try {
        await launchUrl(googleMapsIntent, mode: LaunchMode.externalApplication);
        return;
      } catch (e) {
        // Try simple geo intent
      }

      final mapIntent = Uri.parse(
        'geo:${spot.latitude},${spot.longitude}?z=17',
      );

      try {
        await launchUrl(mapIntent, mode: LaunchMode.externalApplication);
        return;
      } catch (e) {
        // Try web fallback
      }

      final webUrl = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${spot.latitude},${spot.longitude}',
      );

      await launchUrl(webUrl, mode: LaunchMode.platformDefault);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open maps: $e'),
            duration: const Duration(seconds: 3),
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

  void _onSearchChanged() {
    if (_searchController.text.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
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

      final icon = _getMarkerForSpot(spot);

      return Marker(
        markerId: markerId,
        position: position,
        infoWindow: infoWindow,
        icon: icon ?? BitmapDescriptor.defaultMarker,
        onTap: () {
          if (_selectedParkingSpot == spot && _areButtonsVisible) return;

          setState(() {
            _selectedParkingSpot = spot;
            _areButtonsVisible = true;
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
        final results = List<Map<String, dynamic>>.from(
          placesResult['results'],
        );

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

    if (mapController != null) {
      mapController!.animateCamera(CameraUpdate.newLatLngZoom(location, 15.0));
    }

    setState(() {
      _searchResults = [];
    });

    _showParkingNearLocation(location, result['name'] ?? 'Selected Location');
  }

  void _showParkingNearLocation(LatLng location, String locationName) {
    final parkingProvider = Provider.of<ParkingProvider>(
      context,
      listen: false,
    );
    final nearbySpots = _getNearbyParkingSpots(
      location,
      parkingProvider.spots,
      5.0,
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

  void _showDestinationParkingBottomSheet(
    List<ParkingSpot> nearbySpots,
    String locationName,
    LatLng destinationLocation,
  ) {
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
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8, bottom: 16),
                height: 4,
                width: 40,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Parking Near',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: Colors.grey[600]),
                          ),
                          Text(
                            locationName,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${nearbySpots.length} parking spot${nearbySpots.length == 1 ? '' : 's'} found',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: Colors.grey[600]),
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
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: nearbySpots.length,
                  itemBuilder: (context, index) {
                    final spot = nearbySpots[index];
                    final distance = _calculateDistance(
                      destinationLocation,
                      LatLng(spot.latitude, spot.longitude),
                    );

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: spot.isPaid
                                ? Colors.orange.withValues(alpha: 0.1)
                                : Colors.green.withValues(alpha: 0.1),
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
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on,
                                  size: 16,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${distance.toStringAsFixed(1)}km from destination',
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(
                                  spot.isPaid
                                      ? Icons.payment
                                      : Icons.free_breakfast,
                                  size: 16,
                                  color: spot.isPaid
                                      ? Colors.orange
                                      : Colors.green,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  spot.isPaid ? 'Paid Parking' : 'Free Parking',
                                  style: TextStyle(
                                    color: spot.isPaid
                                        ? Colors.orange
                                        : Colors.green,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          Navigator.pop(context);
                          if (mapController != null) {
                            mapController!.animateCamera(
                              CameraUpdate.newLatLngZoom(
                                LatLng(spot.latitude, spot.longitude),
                                18.0,
                              ),
                            );
                          }
                          Future.delayed(const Duration(milliseconds: 500), () {
                            if (context.mounted) {
                              Navigator.pushNamed(
                                context,
                                '/details',
                                arguments: spot,
                              );
                            }
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
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8, bottom: 16),
                height: 4,
                width: 40,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Nearby Parking (${nearbySpots.length})',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: nearbySpots.length,
                  itemBuilder: (context, index) {
                    final spot = nearbySpots[index];
                    final distance = _currentPosition != null
                        ? _calculateDistance(
                            _currentPosition!,
                            LatLng(spot.latitude, spot.longitude),
                          )
                        : 0.0;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: spot.isPaid
                                ? Colors.orange.withValues(alpha: 0.1)
                                : Colors.green.withValues(alpha: 0.1),
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
                          if (mounted) {
                            Navigator.pushNamed(
                              context,
                              '/details',
                              arguments: spot,
                            );
                          }
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

  double _calculateDistance(LatLng from, LatLng to) {
    const double earthRadius = 6371;

    final double lat1Rad = from.latitude * (math.pi / 180);
    final double lat2Rad = to.latitude * (math.pi / 180);
    final double deltaLatRad = (to.latitude - from.latitude) * (math.pi / 180);
    final double deltaLngRad =
        (to.longitude - from.longitude) * (math.pi / 180);

    final double a =
        math.sin(deltaLatRad / 2) * math.sin(deltaLatRad / 2) +
        math.cos(lat1Rad) *
            math.cos(lat2Rad) *
            math.sin(deltaLngRad / 2) *
            math.sin(deltaLngRad / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  List<ParkingSpot> _getNearbyParkingSpots(
    LatLng location,
    List<ParkingSpot> allSpots, [
    double radiusKm = 2.0,
  ]) {
    final List<ParkingSpot> nearbySpots = [];

    for (final spot in allSpots) {
      final spotLocation = LatLng(spot.latitude, spot.longitude);
      final distance = _calculateDistance(location, spotLocation);

      if (distance <= radiusKm) {
        nearbySpots.add(spot);
      }
    }

    nearbySpots.sort((a, b) {
      final distanceA = _calculateDistance(
        location,
        LatLng(a.latitude, a.longitude),
      );
      final distanceB = _calculateDistance(
        location,
        LatLng(b.latitude, b.longitude),
      );
      return distanceA.compareTo(distanceB);
    });

    return nearbySpots;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ParkingProvider, ThemeProvider>(
      builder: (context, parkingProvider, themeProvider, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'Parking Yeta',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.near_me_outlined),
                onPressed: _searchNearMe,
                tooltip: 'Search Near Me',
              ),
              IconButton(
                icon: Icon(
                  themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode,
                ),
                onPressed: () {
                  themeProvider.toggleTheme();
                },
                tooltip: themeProvider.isDarkMode ? 'Light Mode' : 'Dark Mode',
              ),
              Padding(
                padding: const EdgeInsets.only(
                  right: 8.0,
                  top: 8.0,
                  bottom: 8.0,
                ),
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
              GoogleMap(
                onMapCreated: (GoogleMapController controller) {
                  mapController = controller;
                },
                initialCameraPosition: CameraPosition(
                  target: _center,
                  zoom: _currentZoom,
                ),
                style: themeProvider.isDarkMode ? _darkMapStyle : null,
                mapType: MapType.normal,
                buildingsEnabled: false,
                markers: _buildMarkers(parkingProvider.spots),
                myLocationEnabled: _locationPermissionGranted,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
                compassEnabled: false,
                rotateGesturesEnabled: true,
                scrollGesturesEnabled: true,
                tiltGesturesEnabled: false,
                zoomGesturesEnabled: true,
                minMaxZoomPreference: const MinMaxZoomPreference(
                  _minZoom,
                  _maxZoom,
                ),
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
                        color: Colors.black.withValues(alpha: 0.1),
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
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
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
                          color: Colors.black.withValues(alpha: 0.1),
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
              // Left side buttons (when parking spot is selected)
              if (_selectedParkingSpot != null) ...[
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  left: _areButtonsVisible ? 32 : -60,
                  bottom: 80,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 300),
                    opacity: _areButtonsVisible ? 1.0 : 0.0,
                    child: FloatingActionButton(
                      heroTag: "directions",
                      onPressed: _areButtonsVisible
                          ? () async {
                              try {
                                await _openGoogleMapsDirections(
                                  _selectedParkingSpot!,
                                );
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error: $e')),
                                  );
                                }
                              }
                            }
                          : null,
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      child: const Icon(Icons.directions),
                    ),
                  ),
                ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeInOut,
                  left: _areButtonsVisible ? 32 : -60,
                  bottom: 0,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 350),
                    opacity: _areButtonsVisible ? 1.0 : 0.0,
                    child: FloatingActionButton(
                      heroTag: "view_on_map",
                      onPressed: _areButtonsVisible
                          ? () async {
                              try {
                                await _openGoogleMapsLocation(
                                  _selectedParkingSpot!,
                                );
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error: $e')),
                                  );
                                }
                              }
                            }
                          : null,
                      backgroundColor: const Color(0xFF06D6A0),
                      foregroundColor: Colors.white,
                      child: const Icon(Icons.map),
                    ),
                  ),
                ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  left: _areButtonsVisible ? 32 : -60,
                  bottom: 160,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 250),
                    opacity: _areButtonsVisible ? 1.0 : 0.0,
                    child: FloatingActionButton(
                      heroTag: "close_selection",
                      onPressed: _areButtonsVisible
                          ? () {
                              setState(() {
                                _areButtonsVisible = false;
                                Future.delayed(
                                  const Duration(milliseconds: 300),
                                  () {
                                    if (mounted) {
                                      setState(() {
                                        _selectedParkingSpot = null;
                                      });
                                    }
                                  },
                                );
                              });
                            }
                          : null,
                      backgroundColor: const Color(0xFFEF4444),
                      foregroundColor: Colors.white,
                      mini: true,
                      child: const Icon(Icons.close),
                    ),
                  ),
                ),
              ],
              // Right side buttons
              Positioned(
                right: 16,
                bottom: 80,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: FloatingActionButton(
                    heroTag: "location",
                    onPressed: _getCurrentLocation,
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    child: const Icon(Icons.my_location, size: 24),
                  ),
                ),
              ),
              Positioned(
                right: 16,
                bottom: 16,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: FloatingActionButton(
                    heroTag: "add_parking",
                    onPressed: () {
                      Navigator.pushNamed(context, '/add');
                    },
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    child: const Icon(Icons.add_location, size: 24),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
