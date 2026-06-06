class Safehouse {
  final String id;
  final String codename;
  final String sector;
  final double latitude;
  final double longitude;
  final int capacity;
  final bool isCompromised;

  Safehouse({
    required this.id,
    required this.codename,
    required this.sector,
    required this.latitude,
    required this.longitude,
    required this.capacity,
    required this.isCompromised,
  });

  factory Safehouse.fromJson(Map<String, dynamic> json) {
    return Safehouse(
      id: json['id'] as String,
      codename: json['codename'] as String,
      sector: json['sector'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      capacity: json['capacity'] as int,
      isCompromised: json['is_compromised'] as bool? ?? false,
    );
  }

  // Necesario para serializar al caché encriptado local
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'codename': codename,
      'sector': sector,
      'latitude': latitude,
      'longitude': longitude,
      'capacity': capacity,
      'is_compromised': isCompromised,
    };
  }
}
