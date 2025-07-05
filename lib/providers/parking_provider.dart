import 'package:flutter/material.dart';
import '../models/parking_spot.dart';
import '../services/parking_service.dart';

class ParkingProvider extends ChangeNotifier {
  final ParkingService _parkingService = ParkingService();
  bool _isInitialized = false;
  bool _isLoading = false;

  bool get isLoading => _isLoading;

  // Initialize the provider
  Future<void> initialize() async {
    if (_isInitialized) return;

    _isLoading = true;
    notifyListeners();

    await _parkingService.initialize();

    _isInitialized = true;
    _isLoading = false;
    notifyListeners();
  }

  // Get all parking spots
  List<ParkingSpot> getAllParkingSpots() {
    return _parkingService.getAllParkingSpots();
  }

  // Add a new parking spot
  Future<void> addParkingSpot(ParkingSpot spot) async {
    await _parkingService.addParkingSpot(spot);
    notifyListeners();
  }

  // Get a parking spot by ID
  ParkingSpot? getParkingSpotById(String id) {
    return _parkingService.getParkingSpotById(id);
  }

  // Search for parking spots near a location
  List<ParkingSpot> searchNearby(double latitude, double longitude, {double radiusKm = 2}) {
    return _parkingService.searchNearby(latitude, longitude, radiusKm: radiusKm);
  }
}
