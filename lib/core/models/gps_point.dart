class GpsPoint {
  final double lat;
  final double lng;

  const GpsPoint({required this.lat, required this.lng});

  factory GpsPoint.fromJson(Map<String, dynamic> json) => GpsPoint(
    lat: (json['lat'] as num).toDouble(),
    lng: (json['lng'] as num).toDouble(),
  );

  Map<String, dynamic> toJson() => {'lat': lat, 'lng': lng};
}
