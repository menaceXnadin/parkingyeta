import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:location/location.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:io';
import '../models/parking_spot.dart';
import '../providers/parking_provider.dart';
import '../services/moderation_service.dart';
import 'map_selector_screen.dart'; // Import the MapSelectorScreen

class AddParkingScreen extends StatefulWidget {
  const AddParkingScreen({super.key});

  @override
  State<AddParkingScreen> createState() => _AddParkingScreenState();
}

class _AddParkingScreenState extends State<AddParkingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  bool _isPaid = false;
  File? _image;
  bool _isSubmitting = false;
  bool _isLoadingLocation = false;
  final ModerationService _moderationService = ModerationService();
  final Location _location = Location();
  LatLng? _selectedLocation; // Add a variable to store the selected location

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
    );

    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSubmitting = true;
      });

      try {
        // Check if user can add a parking spot (rate limiting)
        final canAdd = await _moderationService.canUserAddParkingSpot();
        if (!canAdd) {
          throw Exception('You can only add 5 parking spots per day. Please try again tomorrow.');
        }

        // Validate coordinates
        final lat = double.parse(_latitudeController.text);
        final lng = double.parse(_longitudeController.text);

        // Check if location is within Kathmandu Valley bounds
        if (!_isWithinKathmanduValley(lat, lng)) {
          throw Exception('Sorry! This app only supports parking spots within Kathmandu Valley (Kathmandu, Lalitpur, and Bhaktapur districts). Please select a location within this region.');
        }

        if (!_moderationService.isValidParkingLocation(lat, lng)) {
          throw Exception('Location must be within Nepal. Please check your coordinates.');
        }

        // Create a new parking spot
        final newSpot = ParkingSpot(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: _nameController.text,
          latitude: lat,
          longitude: lng,
          isPaid: _isPaid,
          photoUrl: _image?.path,
        );

        // Add to provider (which will save to Firestore)
        await Provider.of<ParkingProvider>(context, listen: false)
            .addParkingSpot(newSpot);

        // Show success message with moderation notice
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Parking spot submitted! It will appear after review.'),
              backgroundColor: Colors.green,
            ),
          );

          // Go back to home screen
          Navigator.pop(context);
        }
      } catch (e) {
        // Show error message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString()),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isSubmitting = false;
          });
        }
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      final locationData = await _location.getLocation();
      _latitudeController.text = locationData.latitude.toString();
      _longitudeController.text = locationData.longitude.toString();

      // Optionally, move the map camera to the current location
      // final GoogleMapController controller = await _controller.future;
      // controller.animateCamera(
      //   CameraUpdate.newLatLng(
      //     LatLng(locationData.latitude!, locationData.longitude!),
      //   ),
      // );
    } catch (e) {
      // Handle permission denied or other errors
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not get current location: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoadingLocation = false;
      });
    }
  }

  Future<void> _openMapSelector() async {
    final LatLng? result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MapSelectorScreen()),
    );

    if (result != null) {
      setState(() {
        _selectedLocation = result;
        _latitudeController.text = '${result.latitude}';
        _longitudeController.text = '${result.longitude}';
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Parking Spot'),
        backgroundColor: Colors.blue,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              const Text(
                'Contribute a new parking spot',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),

              // Name field
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Parking Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.local_parking),
                ),
                validator: (value) => value == null || value.isEmpty
                    ? 'Please enter a name' : null,
              ),
              const SizedBox(height: 16),

              // Location Selection Section
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Set Location',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Location selection buttons
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: _isLoadingLocation
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.my_location),
                              label: const Text('Current Location'),
                              onPressed: _isLoadingLocation ? null : _getCurrentLocation,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.map),
                              label: const Text('Choose on Map'),
                              onPressed: _openMapSelector,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Show selected location info
                      if (_latitudeController.text.isNotEmpty && _longitudeController.text.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.location_on, color: Colors.green, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Location Selected ✓',
                                        style: TextStyle(
                                          color: Colors.green,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Lat: ${double.tryParse(_latitudeController.text)?.toStringAsFixed(6) ?? _latitudeController.text}',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12,
                                        ),
                                      ),
                                      Text(
                                        'Lng: ${double.tryParse(_longitudeController.text)?.toStringAsFixed(6) ?? _longitudeController.text}',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // Warning message if no location selected
                      if (_latitudeController.text.isEmpty || _longitudeController.text.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange.withOpacity(0.3)),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Please select a location using one of the buttons above. Only locations within Kathmandu Valley are supported.',
                                    style: TextStyle(
                                      color: Colors.orange,
                                      fontSize: 13,
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
              ),
              const SizedBox(height: 8),
              const SizedBox(height: 16),

              // Paid or Free toggle
              SwitchListTile(
                title: const Text('Is this a paid parking spot?'),
                subtitle: Text(_isPaid ? 'Paid Parking' : 'Free Parking'),
                value: _isPaid,
                activeColor: Colors.blue,
                onChanged: (value) {
                  setState(() {
                    _isPaid = value;
                  });
                },
              ),
              const SizedBox(height: 20),

              // Photo upload section
              const Text(
                'Add a photo (optional)',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: _pickImage,
                child: Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey),
                  ),
                  child: _image != null
                      ? Image.file(_image!, fit: BoxFit.cover)
                      : const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_a_photo, size: 40, color: Colors.grey),
                              SizedBox(height: 8),
                              Text('Tap to add a photo'),
                            ],
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 30),

              // Submit button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'ADD PARKING SPOT',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isWithinKathmanduValley(double latitude, double longitude) {
    // Define the bounding coordinates for Kathmandu Valley
    const kathmanduValleyBounds = {
      'minLat': 27.4474,
      'maxLat': 27.8006,
      'minLng': 85.324,
      'maxLng': 85.5244,
    };

    return latitude >= kathmanduValleyBounds['minLat']! &&
           latitude <= kathmanduValleyBounds['maxLat']! &&
           longitude >= kathmanduValleyBounds['minLng']! &&
           longitude <= kathmanduValleyBounds['maxLng']!;
  }
}
