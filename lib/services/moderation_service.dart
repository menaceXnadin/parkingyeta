import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ModerationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Check if user can add a parking spot (rate limiting)
  Future<bool> canUserAddParkingSpot() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return false;

    // Check submissions in the last 24 hours
    final yesterday = DateTime.now().subtract(const Duration(hours: 24));

    final recentSubmissions = await _firestore
        .collection('parkingSpots')
        .where('contributedBy', isEqualTo: userId)
        .where('createdAt', isGreaterThan: yesterday)
        .get();

    // Limit to 5 submissions per day
    return recentSubmissions.docs.length < 5;
  }

  // Validate parking spot location (basic checks)
  bool isValidParkingLocation(double latitude, double longitude) {
    // Check if coordinates are within Nepal boundaries
    bool isInNepal = latitude >= 26.3 && latitude <= 30.5 &&
                     longitude >= 80.0 && longitude <= 88.3;

    // Check if coordinates are within Kathmandu valley (more restrictive)
    // bool isInKathmandu = latitude >= 27.6 && latitude <= 27.8 &&
    //                      longitude >= 85.2 && longitude <= 85.4;

    return isInNepal; // You can make this more restrictive by using isInKathmandu if needed
  }

  // Report a parking spot as inappropriate
  Future<void> reportParkingSpot(String spotId, String reason) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    // Add report to reports collection
    await _firestore.collection('reports').add({
      'spotId': spotId,
      'reportedBy': userId,
      'reason': reason,
      'timestamp': FieldValue.serverTimestamp(),
    });

    // Increment report count on the parking spot
    await _firestore.collection('parkingSpots').doc(spotId).update({
      'reportCount': FieldValue.increment(1),
    });
  }

  // Check user reputation (based on verified spots and reports)
  Future<bool> isUserTrusted() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return false;

    // Count verified spots contributed by user
    final verifiedSpots = await _firestore
        .collection('parkingSpots')
        .where('contributedBy', isEqualTo: userId)
        .where('isVerified', isEqualTo: true)
        .get();

    // Count reports against user's contributions
    final userSpots = await _firestore
        .collection('parkingSpots')
        .where('contributedBy', isEqualTo: userId)
        .get();

    int totalReports = 0;
    for (var doc in userSpots.docs) {
      totalReports += (doc.data()['reportCount'] as int? ?? 0);
    }

    // User is trusted if they have at least 3 verified spots and less than 5 total reports
    return verifiedSpots.docs.length >= 3 && totalReports < 5;
  }
}
