import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../services/location_service.dart';

class MapaScreen extends StatefulWidget {
  const MapaScreen({super.key});

  @override
  State<MapaScreen> createState() => _MapaScreenState();
}

class _MapaScreenState extends State<MapaScreen> {
  final LocationService _locationService = LocationService();
  final Set<Marker> _marcadores = {};
  GoogleMapController? _mapController;
  Position? _posicionActual;
  String? _error;

  @override
  void initState() {
    super.initState();
    _obtenerUbicacionInicial();
  }

  Future<void> _obtenerUbicacionInicial() async {
    try {
      final pos = await _locationService.obtenerUbicacion();
      if (!mounted) return;
      setState(() => _posicionActual = pos);
      _moverCamaraAlUsuario();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  void _moverCamaraAlUsuario() {
    final pos = _posicionActual;
    if (pos == null || _mapController == null) return;
    _mapController!.animateCamera(
      CameraUpdate.newLatLng(LatLng(pos.latitude, pos.longitude)),
    );
  }

  void _agregarMarcador(LatLng punto) {
    setState(() {
      _marcadores
        ..clear()
        ..add(
          Marker(
            markerId: const MarkerId('destino'),
            position: punto,
            infoWindow: const InfoWindow(title: 'Destino'),
          ),
        );
    });
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Localizador de Puntos de Interés')),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(20.2756, -97.9611), // UTXJ
              zoom: 15.5,
            ),
            myLocationEnabled: true,
            markers: _marcadores,
            onMapCreated: (ctrl) {
              _mapController = ctrl;
              _moverCamaraAlUsuario();
            },
            onTap: (LatLng punto) => _agregarMarcador(punto),
          ),
          if (_error != null)
            Positioned(
              top: 8,
              left: 8,
              right: 8,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(_error!),
                ),
              ),
            ),
        ],
      ),
    );
  }
}