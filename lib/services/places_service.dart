import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:flutter/foundation.dart';

class PlacesService {
  final String _apiKey = 'AIzaSyCpLMimAluPFtciWvhmueonTFh1D-NV5ss';

  // Search for places by query text
  Future<Map<String, dynamic>?> searchPlaces(String query) async {
    if (query.isEmpty) return null;

    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/textsearch/json?query=$query+in+Kathmandu&key=$_apiKey'
    );

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        if (kDebugMode) {
          print('Failed to search places. Status: ${response.statusCode}');
        }
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Exception during places search: $e');
      }
      return null;
    }
  }

  // Get place details by place ID
  Future<Map<String, dynamic>?> getPlaceDetails(String placeId) async {
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&key=$_apiKey'
    );

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        if (kDebugMode) {
          print('Failed to get place details. Status: ${response.statusCode}');
        }
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Exception during place details fetch: $e');
      }
      return null;
    }
  }

  // Find nearby parking spots
  Future<List<Map<String, dynamic>>> findNearbyParkingSpots(LatLng location, {double radius = 1500}) async {
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=${location.latitude},${location.longitude}&radius=$radius&type=parking&key=$_apiKey'
    );

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['results']);
      } else {
        if (kDebugMode) {
          print('Failed to find nearby parking. Status: ${response.statusCode}');
        }
        return [];
      }
    } catch (e) {
      if (kDebugMode) {
        print('Exception during nearby parking search: $e');
      }
      return [];
    }
  }

  // Get latitude and longitude from a place search result
  LatLng getLocationFromPlaceResult(Map<String, dynamic> placeResult) {
    final geometry = placeResult['geometry'];
    final location = geometry['location'];

    return LatLng(
      location['lat'].toDouble(),
      location['lng'].toDouble(),
    );
  }

  // Get user's current location
  Future<LatLng?> getCurrentLocation() async {
    final location = Location();

    bool serviceEnabled;
    PermissionStatus permissionGranted;

    // Check if location service is enabled
    serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) {
        if (kDebugMode) {
          print('Location services are disabled');
        }
        return null;
      }
    }

    // Check if permission is granted
    permissionGranted = await location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) {
        if (kDebugMode) {
          print('Location permissions are denied');
        }
        return null;
      }
    }

    // Get user's current location
    try {
      final locationData = await location.getLocation();
      return LatLng(locationData.latitude!, locationData.longitude!);
    } catch (e) {
      if (kDebugMode) {
        print('Error getting location: $e');
      }
      return null;
    }
  }
}
