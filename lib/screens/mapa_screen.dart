import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
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
  final Geocoding _geocoding = Geocoding(); // geocoding 5.x: se usa una instancia
  final Set<Marker> _marcadores = {};
  GoogleMapController? _mapController;
  StreamSubscription<Position>? _subPosicion;

  Position? _posicionActual;
  LatLng? _destino;
  double? _distanciaMetros;
  String? _direccion;
  String? _error;

  @override
  void initState() {
    super.initState();
    _iniciar();
  }

  Future<void> _iniciar() async {
    try {
      final pos = await _locationService.obtenerUbicacion();
      if (!mounted) return;
      setState(() => _posicionActual = pos);
      _moverCamaraAlUsuario();

      // Distancia en vivo: se actualiza cuando el usuario se mueve
      _subPosicion = _locationService.seguirUbicacion().listen((nueva) {
        if (!mounted) return;
        setState(() {
          _posicionActual = nueva;
          _calcularDistancia();
        });
      });
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

  void _calcularDistancia() {
    final pos = _posicionActual;
    final destino = _destino;
    if (pos == null || destino == null) {
      _distanciaMetros = null;
      return;
    }
    _distanciaMetros = Geolocator.distanceBetween(
      pos.latitude,
      pos.longitude,
      destino.latitude,
      destino.longitude,
    );
  }

  Future<void> _obtenerDireccion(LatLng punto) async {
    try {
      final lugares = await _geocoding.placemarkFromCoordinates(
        punto.latitude,
        punto.longitude,
      );
      if (!mounted || _destino != punto) return; // el usuario tocó otro punto
      if (lugares.isEmpty) {
        setState(() => _direccion = 'Sin dirección disponible');
        return;
      }
      final lugar = lugares.first;
      final partes = <String>[];
      final calle = lugar.street;
      final colonia = lugar.subLocality;
      if (calle != null && calle.isNotEmpty) partes.add(calle);
      if (colonia != null && colonia.isNotEmpty) partes.add(colonia);
      setState(() {
        _direccion =
            partes.isEmpty ? 'Sin dirección disponible' : partes.join(', ');
      });
    } catch (e) {
      if (!mounted || _destino != punto) return;
      setState(() => _direccion = 'No se pudo obtener la dirección');
    }
  }

  void _agregarMarcador(LatLng punto) {
    setState(() {
      _destino = punto;
      _direccion = 'Buscando dirección...';
      _marcadores
        ..clear()
        ..add(
          Marker(
            markerId: const MarkerId('destino'),
            position: punto,
            infoWindow: const InfoWindow(title: 'Destino'),
          ),
        );
      _calcularDistancia();
    });
    _obtenerDireccion(punto);
  }

  String _textoDistancia() {
    final d = _distanciaMetros;
    if (d == null) return 'Distancia: calculando...';
    return 'Distancia: ${d.toStringAsFixed(1)} m';
  }

  String _textoDireccion() {
    final dir = _direccion;
    if (dir == null) return 'Dirección:';
    return 'Dirección: $dir';
  }

  @override
  void dispose() {
    _subPosicion?.cancel();
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
          if (_destino != null)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_textoDistancia()),
                      const SizedBox(height: 4),
                      Text(_textoDireccion()),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}