import 'package:geolocator/geolocator.dart';

class LocationService {
  Future<Position> obtenerUbicacion() async {
    bool activo = await Geolocator.isLocationServiceEnabled();
    if (!activo) return Future.error('GPS desactivado');

    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    // Adición mía (no está en el PDF): evita un error si el permiso se negó para siempre
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      return Future.error('Permiso de ubicación denegado');
    }

    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }
}