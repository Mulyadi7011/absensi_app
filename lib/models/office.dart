class Office {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final double radiusM;

  Office({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radiusM,
  });

  factory Office.fromJson(Map<String, dynamic> j) => Office(
        id: j['id'].toString(),
        name: j['name'] ?? '',
        latitude: (j['latitude'] as num).toDouble(),
        longitude: (j['longitude'] as num).toDouble(),
        radiusM: (j['radius_m'] as num).toDouble(),
      );
}
