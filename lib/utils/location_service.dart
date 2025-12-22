import 'package:geolocator/geolocator.dart';

class LocationService {
  static Future<void> ensurePermission() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      throw 'GPS/Location Service belum aktif. Nyalakan Location di pengaturan HP.';
    }

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }

    if (perm == LocationPermission.denied) {
      throw 'Izin lokasi ditolak.';
    }

    if (perm == LocationPermission.deniedForever) {
      throw 'Izin lokasi ditolak permanen. Buka Settings > App > Permission.';
    }
  }

  static Future<Position> getCurrentHighAccuracy() async {
    await ensurePermission();
    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }
}
