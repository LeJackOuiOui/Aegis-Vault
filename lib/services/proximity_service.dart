import 'dart:async';
import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:vibration/vibration.dart';

class ProximityService {
  // === RAMA: feature/geiger-vibration ===
  // Coordenadas exactas del Neon-Vault (SENA Mosquera)
  static const double _neonVaultLat = 4.7068;
  static const double _neonVaultLng = -74.2210;
  static const double _alertRadiusMeters = 100.0;

  StreamSubscription<Position>? _positionStream;
  bool _geigerActive = false;
  Timer? _geigerTimer;

  // Solicitar permisos de ubicación al sistema operativo
  Future<bool> requestPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }
    if (permission == LocationPermission.deniedForever) return false;

    return true;
  }

  // Iniciar monitoreo de proximidad al Neon-Vault
  void startProximityMonitoring(Function(bool isNear) onProximityChange) async {
    final hasPermission = await requestPermissions();
    if (!hasPermission) return;

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Actualizar cada 10 metros de movimiento
    );

    _positionStream =
        Geolocator.getPositionStream(locationSettings: locationSettings)
            .listen((Position position) {
      final distanceMeters = _calculateDistance(
        position.latitude,
        position.longitude,
        _neonVaultLat,
        _neonVaultLng,
      );

      final isNear = distanceMeters <= _alertRadiusMeters;
      onProximityChange(isNear);

      if (isNear && !_geigerActive) {
        _startGeigerVibration();
      } else if (!isNear && _geigerActive) {
        _stopGeigerVibration();
      }
    });
  }

  // Ráfagas de vibración intermitente simulando contador Geiger
  void _startGeigerVibration() async {
    _geigerActive = true;
    final hasVibrator = await Vibration.hasVibrator() ?? false;
    if (!hasVibrator) return;

    // Patrón Geiger: pulsos cortos con intervalos aleatorios
    _geigerTimer = Timer.periodic(const Duration(milliseconds: 300), (_) {
      if (!_geigerActive) return;
      final random = Random();
      // Simular la aleatoriedad de un contador Geiger
      if (random.nextDouble() > 0.4) {
        Vibration.vibrate(duration: 60 + random.nextInt(80));
      }
    });
  }

  void _stopGeigerVibration() {
    _geigerActive = false;
    _geigerTimer?.cancel();
    Vibration.cancel();
  }

  // Fórmula de Haversine para calcular distancia entre dos coordenadas GPS
  double _calculateDistance(
    double lat1, double lon1,
    double lat2, double lon2,
  ) {
    const double earthRadiusMeters = 6371000;
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusMeters * c;
  }

  double _toRadians(double degrees) => degrees * pi / 180;

  void dispose() {
    _positionStream?.cancel();
    _stopGeigerVibration();
  }
}
