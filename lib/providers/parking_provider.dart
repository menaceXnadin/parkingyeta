import 'package:flutter/material.dart';
import '../models/parking_spot.dart';
import '../services/parking_service.dart';

class ParkingProvider extends ChangeNotifier {
  final ParkingService _parkingService = ParkingService();
  List<ParkingSpot> _spots = [];
  bool _isLoading = true;

  List<ParkingSpot> get spots => _spots;
  bool get isLoading => _isLoading;

  // Initialize the provider
  Future<void> initialize() async {
    _parkingService.getParkingSpotsStream().listen(
      (spots) {
        _spots = spots;
        _isLoading = false;
        notifyListeners();
      },
      onError: (error) {
        debugPrint('Error loading parking spots: $error');
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  // Add a new parking spot
  Future<void> addParkingSpot(ParkingSpot spot) async {
    await _parkingService.addParkingSpot(spot);
  }

  // Verify spot
  Future<void> verifySpot(String spotId) async {
    await _parkingService.verifySpot(spotId);
  }

  // Report spot
  Future<void> reportSpot(String spotId) async {
    await _parkingService.reportSpot(spotId);
  }
}
