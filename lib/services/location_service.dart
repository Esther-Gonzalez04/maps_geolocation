import 'package:geolocator/geolocator.dart';

class LocationService {
  Future<Position> obtenerUbicacion() async {
    bool activo = await Geolocator.isLocationServiceEnabled();
    if (!activo) return Future.error('GPS desactivado');

    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      return Future.error('Permiso de ubicación denegado');
    }

    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }
    Stream<Position> seguirUbicacion() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // solo actualiza cada 10 metros
      ),
    );
  }
}