class ParkingSpot {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final bool isPaid;
  final String? photoUrl;

  ParkingSpot({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.isPaid,
    this.photoUrl,
  });
}

