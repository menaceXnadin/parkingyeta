import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/parking_spot.dart';
import '../services/moderation_service.dart';

class ParkingDetailsScreen extends StatelessWidget {
  const ParkingDetailsScreen({super.key});

  void _reportSpot(BuildContext context, ParkingSpot spot) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report This Parking Spot'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Why are you reporting this spot?'),
            const SizedBox(height: 16),
            ...['Not a parking spot', 'Incorrect location', 'Spam/Fake', 'Other']
                .map((reason) => ListTile(
                      title: Text(reason),
                      onTap: () async {
                        Navigator.pop(context);
                        await ModerationService().reportParkingSpot(spot.id, reason);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Report submitted. Thank you!')),
                        );
                      },
                    )),
          ],
        ),
      ),
    );
  }

  Future<void> _openGoogleMapsDirections(ParkingSpot spot) async {
    // Opens Google Maps with directions to the parking spot
    final url = 'https://www.google.com/maps/dir/?api=1&destination=${spot.latitude},${spot.longitude}';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      throw 'Could not open Google Maps';
    }
  }

  Future<void> _openGoogleMapsLocation(ParkingSpot spot) async {
    // Opens Google Maps just showing the location without directions
    final url = 'https://www.google.com/maps/search/?api=1&query=${spot.latitude},${spot.longitude}';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      throw 'Could not open Google Maps';
    }
  }

  @override
  Widget build(BuildContext context) {
    final ParkingSpot spot = ModalRoute.of(context)!.settings.arguments as ParkingSpot;

    return Scaffold(
      appBar: AppBar(
        title: Text(spot.name),
        backgroundColor: spot.isPaid ? Colors.orangeAccent : Colors.greenAccent,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image placeholder (or actual image if available)
            Container(
              height: 200,
              width: double.infinity,
              color: Colors.grey[300],
              child: spot.photoUrl != null
                ? Image.network(spot.photoUrl!, fit: BoxFit.cover)
                : const Center(
                    child: Icon(Icons.local_parking, size: 80, color: Colors.grey),
                  ),
            ),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Parking type badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: spot.isPaid ? Colors.orange : Colors.green,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      spot.isPaid ? 'PAID PARKING' : 'FREE PARKING',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Parking details
                  const Text(
                    'Location Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Latitude: ${spot.latitude}'),
                  Text('Longitude: ${spot.longitude}'),

                  const SizedBox(height: 24),

                  // Actions section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildActionButton(
                        icon: Icons.directions,
                        label: 'Directions',
                        onTap: () async {
                          try {
                            await _openGoogleMapsDirections(spot);
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e')),
                            );
                          }
                        },
                      ),
                      _buildActionButton(
                        icon: Icons.map,
                        label: 'View on Map',
                        onTap: () async {
                          try {
                            await _openGoogleMapsLocation(spot);
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e')),
                            );
                          }
                        },
                      ),
                      _buildActionButton(
                        icon: Icons.share,
                        label: 'Share',
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Sharing parking location...'))
                          );
                        },
                      ),
                      _buildActionButton(
                        icon: Icons.report_problem,
                        label: 'Report',
                        onTap: () => _reportSpot(context, spot),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[100],
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.blue[700]),
          ),
          const SizedBox(height: 8),
          Text(label),
        ],
      ),
    );
  }
}
