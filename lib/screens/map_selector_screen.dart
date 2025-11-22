import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'dart:async'; // Added for Timer

class MapSelectorScreen extends StatefulWidget {
  const MapSelectorScreen({super.key, this.initialLocation});

  // Optional initial location to show on map
  final LatLng? initialLocation;

  @override
  State<MapSelectorScreen> createState() => _MapSelectorScreenState();
}

class _MapSelectorScreenState extends State<MapSelectorScreen> {
  // Default to Kathmandu as fallback
  LatLng _selectedLocation = const LatLng(27.7172, 85.3240);
  final Location _location = Location();
  bool _isLoading = true;
  late GoogleMapController _mapController;
  String _addressText = "Loading address...";
  bool _addressLoading = false;

  // For floating panel
  OverlayEntry? _floatingPanelEntry;
  Timer? _panelTimer;

  @override
  void initState() {
    super.initState();

    // If an initial location was provided, use it
    if (widget.initialLocation != null) {
      _selectedLocation = widget.initialLocation!;
      _isLoading = false;
    } else {
      _getCurrentLocation();
    }
  }

  // Get user's current location
  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _location.requestService();
        if (!serviceEnabled) {
          setState(() => _isLoading = false);
          return;
        }
      }

      PermissionStatus permissionStatus = await _location.hasPermission();
      if (permissionStatus == PermissionStatus.denied) {
        permissionStatus = await _location.requestPermission();
        if (permissionStatus != PermissionStatus.granted) {
          setState(() => _isLoading = false);
          return;
        }
      }

      final locationData = await _location.getLocation();
      if (locationData.latitude != null && locationData.longitude != null) {
        setState(() {
          _selectedLocation = LatLng(
            locationData.latitude!,
            locationData.longitude!,
          );
          _isLoading = false;
        });

        // Fetch address for initial location
        _getAddressFromLatLng(_selectedLocation);
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
      setState(() => _isLoading = false);
    }
  }

  // Get address from latitude and longitude
  Future<void> _getAddressFromLatLng(LatLng position) async {
    setState(() {
      _addressLoading = true;
    });

    try {
      // Google Maps Geocoding API requires an API key - using a mock response here
      // In production, you should use a proper geocoding service with your API key
      // Example URL: https://maps.googleapis.com/maps/api/geocode/json?latlng=${position.latitude},${position.longitude}&key=YOUR_API_KEY

      // Mock delay to simulate network request
      await Future.delayed(const Duration(milliseconds: 500));

      // Create a simple address based on coordinates - Replace with actual geocoding in production
      final String address =
          "Near ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}";

      setState(() {
        _addressText = address;
        _addressLoading = false;
      });
    } catch (e) {
      setState(() {
        _addressText = "Address unavailable";
        _addressLoading = false;
      });
    }
  }

  void _onCameraIdle() {
    // When camera stops moving, update the selected location and fetch address
    _mapController.getVisibleRegion().then((bounds) {
      // Calculate the center point
      final center = LatLng(
        (bounds.northeast.latitude + bounds.southwest.latitude) / 2,
        (bounds.northeast.longitude + bounds.southwest.longitude) / 2,
      );

      setState(() {
        _selectedLocation = center;
      });

      _getAddressFromLatLng(center);
    });
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose on Map'), elevation: 0),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                // Google Map
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _selectedLocation,
                    zoom: 17.0,
                  ),
                  onMapCreated: _onMapCreated,
                  onCameraIdle: _onCameraIdle,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  compassEnabled: true,
                ),

                // Center Pin (fixed position)
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(
                          bottom: 40,
                        ), // Offset for pin base
                        child: Icon(
                          Icons.location_pin,
                          color: Theme.of(context).primaryColor,
                          size: 50,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 5,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Bottom address card and confirm button
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Column(
                    children: [
                      // Address card
                      Container(
                        margin: const EdgeInsets.all(16.0),
                        padding: const EdgeInsets.all(16.0),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Address',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            _addressLoading
                                ? const SizedBox(
                                    height: 20,
                                    child: LinearProgressIndicator(
                                      backgroundColor: Colors.transparent,
                                    ),
                                  )
                                : Text(
                                    _addressText,
                                    style: const TextStyle(fontSize: 14),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(context, _selectedLocation);
                                },
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text(
                                  'Confirm Location',
                                  style: TextStyle(fontSize: 16),
                                ),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          setState(() => _isLoading = true);

          // Show information panel that we're getting location
          _showFloatingInfoPanel('Finding your current location...');

          await _getCurrentLocation();

          if (!_isLoading && mounted) {
            // Check if map controller is initialized before using it
            try {
              // Only animate camera if the controller is available
              _mapController.animateCamera(
                CameraUpdate.newLatLngZoom(_selectedLocation, 17.0),
              );

              // Show success message when location is found
              _showFloatingInfoPanel(
                'Location found! Map updated to your current position.',
              );
            } catch (e) {
              // Handle the case when map controller is not initialized yet
              _showFloatingInfoPanel(
                'Location found, but map is not ready yet.',
                isError: true,
              );
              debugPrint('Error with map controller: $e');
            }
          } else if (mounted) {
            // Show error message if we couldn't get location
            _showFloatingInfoPanel(
              'Could not access your current location. Please check your permissions.',
              isError: true,
            );
          }
        },
        tooltip: 'My Location',
        child: const Icon(Icons.my_location),
      ),
    );
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  // Method to show floating information panel
  void _showFloatingInfoPanel(String message, {bool isError = false}) {
    // Remove existing panel if any
    _removeFloatingPanel();

    // Create an overlay entry
    final overlayState = Overlay.of(context);
    _floatingPanelEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 16,
        left: 16,
        right: 16,
        child: Material(
          elevation: 6.0,
          borderRadius: BorderRadius.circular(8),
          color: isError
              ? Colors.red.shade700
              : Colors.black.withValues(alpha: 0.8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  isError ? Icons.error_outline : Icons.info_outline,
                  color: Colors.white,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 20),
                  onPressed: _removeFloatingPanel,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    overlayState.insert(_floatingPanelEntry!);

    // Auto-dismiss after 4 seconds
    _panelTimer = Timer(const Duration(seconds: 4), () {
      _removeFloatingPanel();
    });
  }

  // Method to remove the floating panel
  void _removeFloatingPanel() {
    _panelTimer?.cancel();
    _floatingPanelEntry?.remove();
    _floatingPanelEntry = null;
  }
}
