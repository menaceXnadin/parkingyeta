import '../models/parking_spot.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class ParkingService {
  // Local cache of parking spots
  final List<ParkingSpot> _spots = [];

  // Firestore collection reference
  final CollectionReference _parkingSpotsCollection =
      FirebaseFirestore.instance.collection('parkingSpots');

  // Get current user ID
  String? get _userId => FirebaseAuth.instance.currentUser?.uid;

  // Initialize - load parking spots from Firestore
  Future<void> initialize() async {
    await loadParkingSpots();

    // Add demo parking spots if none exist
    if (_spots.isEmpty) {
      _addDemoSpots();
    }
  }

  // Load parking spots from Firestore
  Future<void> loadParkingSpots() async {
    try {
      final querySnapshot = await _parkingSpotsCollection.get();

      _spots.clear();

      for (var doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;

        _spots.add(ParkingSpot(
          id: doc.id,
          name: data['name'],
          latitude: data['latitude'],
          longitude: data['longitude'],
          isPaid: data['isPaid'],
          photoUrl: data['photoUrl'],
        ));
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading parking spots: $e');
      }
    }
  }

  // Add demo parking spots for testing
  void _addDemoSpots() {
    _spots.addAll([
      ParkingSpot(
        id: 'demo1',
        name: 'Ratna Park Parking',
        latitude: 27.7053,
        longitude: 85.3200,
        isPaid: false,
        photoUrl: null,
      ),
      ParkingSpot(
        id: 'demo2',
        name: 'Thamel Parking Plaza',
        latitude: 27.7115,
        longitude: 85.3107,
        isPaid: true,
        photoUrl: null,
      ),
      ParkingSpot(
        id: 'demo3',
        name: 'New Road Parking',
        latitude: 27.7026,
        longitude: 85.3159,
        isPaid: true,
        photoUrl: null,
      ),
      ParkingSpot(
        id: 'demo4',
        name: 'Durbar Marg Free Parking',
        latitude: 27.7041,
        longitude: 85.3210,
        isPaid: false,
        photoUrl: null,
      ),
      ParkingSpot(
        id: 'demo5',
        name: 'Patan Dhoka Parking',
        latitude: 27.6789,
        longitude: 85.3206,
        isPaid: false,
        photoUrl: null,
      ),
    ]);
  }

  // Get all parking spots
  List<ParkingSpot> getAllParkingSpots() {
    return _spots;
  }

  // Add a new parking spot - saves to Firestore with validation
  Future<void> addParkingSpot(ParkingSpot spot) async {
    // Check if user is authenticated
    if (_userId == null) {
      throw Exception('User must be logged in to add parking spots');
    }

    try {
      // Add to Firestore with moderation status
      final docRef = await _parkingSpotsCollection.add({
        'name': spot.name,
        'latitude': spot.latitude,
        'longitude': spot.longitude,
        'isPaid': spot.isPaid,
        'photoUrl': spot.photoUrl,
        'contributedBy': _userId,
        'contributorEmail': FirebaseAuth.instance.currentUser?.email,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending_review', // Add moderation status
        'reportCount': 0, // Track reports from other users
        'isVerified': false, // Admin verification status
      });

      // Update the spot with the Firestore document ID
      final newSpot = ParkingSpot(
        id: docRef.id,
        name: spot.name,
        latitude: spot.latitude,
        longitude: spot.longitude,
        isPaid: spot.isPaid,
        photoUrl: spot.photoUrl,
      );

      // Add to local cache
      _spots.add(newSpot);
    } catch (e) {
      if (kDebugMode) {
        print('Error adding parking spot: $e');
      }
      // Add to local cache anyway so the user sees their contribution
      _spots.add(spot);
    }
  }

  // Get a parking spot by ID
  ParkingSpot? getParkingSpotById(String id) {
    try {
      return _spots.firstWhere((spot) => spot.id == id);
    } catch (e) {
      return null;
    }
  }

  // Search for parking spots near a location
  List<ParkingSpot> searchNearby(double latitude, double longitude,
      {double radiusKm = 2}) {
    // For a real app, this would use proper distance calculation
    // This is just a simple mock implementation
    return _spots.where((spot) {
      double latDiff = (spot.latitude - latitude).abs();
      double lngDiff = (spot.longitude - longitude).abs();
      // Approximate distance check (not accurate but simple for demo)
      return latDiff < (radiusKm / 111) && lngDiff < (radiusKm / 111);
    }).toList();
  }
}
