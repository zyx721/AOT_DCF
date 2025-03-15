class ServiceMarker {
  final String id;
  final String title;
  final String description;
  final double latitude;
  final double longitude;
  final String serviceType;
  final String imageUrl;
  final String logoUrl;
  final String mainImageUrl;
  final String status;

  ServiceMarker({
    required this.id,
    required this.title,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.serviceType,
    required this.imageUrl,
    required this.logoUrl,
    required this.mainImageUrl,
    this.status = 'active',
  });
}
