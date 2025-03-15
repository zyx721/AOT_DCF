import 'package:latlong2/latlong.dart';

class FundraiserLocation {
  final String id;
  final String title;
  final String description;
  final double latitude;
  final double longitude;
  final String imageUrl;
  final String type; // e.g., 'food_distribution', 'clothing', 'shelter'
  final DateTime dateTime;
  final int volunteersNeeded;

  FundraiserLocation({
    required this.id,
    required this.title,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.imageUrl,
    required this.type,
    required this.dateTime,
    required this.volunteersNeeded,
  });
}
