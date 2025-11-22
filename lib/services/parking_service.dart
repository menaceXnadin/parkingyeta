import '../models/parking_spot.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class ParkingService {
  final CollectionReference _parkingSpotsCollection = FirebaseFirestore.instance
      .collection('parkingSpots');

  // Stream of all parking spots
  Stream<List<ParkingSpot>> getParkingSpotsStream() {
    return _parkingSpotsCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => ParkingSpot.fromFirestore(doc))
              .toList();
        })
        .handleError((error) {
          debugPrint('Firestore stream error: $error');
          return <ParkingSpot>[];
        });
  }

  // Add a new parking spot
  Future<void> addParkingSpot(ParkingSpot spot) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User must be logged in to add parking spots');
    }

    try {
      await _parkingSpotsCollection.add(spot.toMap());

      // Update user contribution count
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {'contributionsCount': FieldValue.increment(1)},
      );
    } catch (e) {
      debugPrint('Error adding parking spot: $e');
      rethrow;
    }
  }

  // Verify a parking spot (Upvote)
  Future<void> verifySpot(String spotId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final spotRef = _parkingSpotsCollection.doc(spotId);
    final voteRef = spotRef.collection('votes').doc(user.uid);

    final voteDoc = await voteRef.get();
    if (!voteDoc.exists) {
      await voteRef.set({'votedAt': FieldValue.serverTimestamp()});
      await spotRef.update({'verifications': FieldValue.increment(1)});
    }
  }

  // Report a parking spot (Downvote)
  Future<void> reportSpot(String spotId) async {
    await _parkingSpotsCollection.doc(spotId).update({
      'reports': FieldValue.increment(1),
    });
  }
}
