import 'package:cloud_firestore/cloud_firestore.dart';

class ParkingSpot {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final bool isPaid;
  final double? price; // Price per hour
  final List<String> photos;
  final String userId;
  final int verifications;
  final int reports;
  final DateTime createdAt;

  ParkingSpot({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.isPaid,
    this.price,
    this.photos = const [],
    required this.userId,
    this.verifications = 0,
    this.reports = 0,
    required this.createdAt,
  });

  factory ParkingSpot.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    // Handle both GeoPoint location and separate lat/lng fields
    double lat;
    double lng;

    if (data['location'] != null && data['location'] is GeoPoint) {
      // New format: GeoPoint
      final location = data['location'] as GeoPoint;
      lat = location.latitude;
      lng = location.longitude;
    } else {
      // Old format: separate latitude/longitude fields
      lat = (data['latitude'] ?? 0.0).toDouble();
      lng = (data['longitude'] ?? 0.0).toDouble();
    }

    return ParkingSpot(
      id: doc.id,
      name: data['name'] ?? '',
      address: data['address'] ?? '',
      latitude: lat,
      longitude: lng,
      isPaid: data['isPaid'] ?? false,
      price: data['price']?.toDouble(),
      photos: List<String>.from(data['photos'] ?? []),
      userId: data['userId'] ?? data['contributedBy'] ?? '',
      verifications: data['verifications'] ?? 0,
      reports: data['reports'] ?? 0,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'address': address,
      'location': GeoPoint(latitude, longitude),
      'isPaid': isPaid,
      'price': price,
      'photos': photos,
      'userId': userId,
      'verifications': verifications,
      'reports': reports,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
