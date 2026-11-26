import 'package:geolocator/geolocator.dart';

class UserPosition {
  final double lat, lon;
  const UserPosition(this.lat, this.lon);
}

enum LocationFailure { serviceOff, denied, deniedForever, failed }

class LocationException implements Exception {
  final LocationFailure reason;
  LocationException(this.reason);
}

abstract class LocationService {
  Future<UserPosition> current();
}

class DeviceLocationService implements LocationService {
  @override
  Future<UserPosition> current() async {
    if (!await Geolocator.isLocationServiceEnabled()) throw LocationException(LocationFailure.serviceOff);
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied) throw LocationException(LocationFailure.denied);
    if (perm == LocationPermission.deniedForever) throw LocationException(LocationFailure.deniedForever);
    try {
      final p = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 20)));
      return UserPosition(p.latitude, p.longitude);
    } catch (_) {
      throw LocationException(LocationFailure.failed);
    }
  }
}

/// Great-circle distance in meters (haversine).
double distanceMeters(double lat1, double lon1, double lat2, double lon2) =>
    Geolocator.distanceBetween(lat1, lon1, lat2, lon2);

/// Free OpenStreetMap directions link (opens in browser or a maps app).
Uri directionsUri(UserPosition? from, double toLat, double toLon) => Uri.https('www.openstreetmap.org', '/directions', {
      'engine': 'fossgis_osrm_car',
      'route': '${from == null ? '' : '${from.lat},${from.lon}'};$toLat,$toLon',
    });
