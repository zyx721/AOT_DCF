import 'package:latlong2/latlong.dart';

class CharityLocation {
  final String id;
  final String name;
  final String description;
  final LatLng location;
  final String imageUrl;
  final String type; // e.g., 'food_bank', 'clothing', 'shelter'
  final bool needsVolunteers;
  final DateTime? nextEvent;

  CharityLocation({
    required this.id,
    required this.name,
    required this.description,
    required this.location,
    required this.imageUrl,
    required this.type,
    required this.needsVolunteers,
    this.nextEvent,
  });
}
