class VolunteerOpportunity {
  final String id;
  final String title;
  final String description;
  final double latitude;
  final double longitude;
  final String imageUrl;
  final String category;
  final DateTime date;
  final int volunteersNeeded;

  VolunteerOpportunity({
    required this.id,
    required this.title,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.imageUrl,
    required this.category,
    required this.date,
    required this.volunteersNeeded,
  });
}
