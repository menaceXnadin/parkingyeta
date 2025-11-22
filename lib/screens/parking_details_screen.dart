import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/parking_spot.dart';

class ParkingDetailsScreen extends StatelessWidget {
  const ParkingDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final spot = ModalRoute.of(context)!.settings.arguments as ParkingSpot;
    final theme = Theme.of(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(spot.name),
              background: spot.photos.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: spot.photos.first,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      color: theme.primaryColor.withValues(alpha: 0.1),
                      child: Icon(
                        Icons.local_parking,
                        size: 100,
                        color: theme.primaryColor,
                      ),
                    ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Chips
                  Row(
                    children: [
                      Chip(
                        label: Text(spot.isPaid ? 'Paid' : 'Free'),
                        backgroundColor: spot.isPaid
                            ? Colors.orange.withValues(alpha: 0.1)
                            : Colors.green.withValues(alpha: 0.1),
                        labelStyle: TextStyle(
                          color: spot.isPaid ? Colors.orange : Colors.green,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (spot.price != null)
                        Chip(
                          label: Text('Rs ${spot.price}/hr'),
                          backgroundColor: theme.primaryColor.withValues(
                            alpha: 0.1,
                          ),
                          labelStyle: TextStyle(color: theme.primaryColor),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Address
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          spot.address,
                          style: theme.textTheme.bodyLarge,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Actions
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              _launchMaps(spot.latitude, spot.longitude),
                          label: const Text('Get Directions'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Share feature coming soon'),
                            ),
                          );
                        },
                        icon: const Icon(Icons.share),
                        label: const Text('Share'),
                      ),
                    ],
                  ),

                  // Map Preview
                  Text('Location', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 12),
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: LatLng(spot.latitude, spot.longitude),
                          zoom: 15,
                        ),
                        markers: {
                          Marker(
                            markerId: const MarkerId('spot'),
                            position: LatLng(spot.latitude, spot.longitude),
                          ),
                        },
                        zoomControlsEnabled: false,
                        scrollGesturesEnabled: false,
                        onTap: (_) =>
                            _launchMaps(spot.latitude, spot.longitude),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchMaps(double lat, double lng) async {
    final url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }
}
