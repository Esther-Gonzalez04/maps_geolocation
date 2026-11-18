import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../services/location_service.dart';

const String _miUbicacionId = 'mi_ubicacion';

class _Punto {
  _Punto({required this.id, required this.nombre, required this.posicion});

  final String id;
  final String nombre;
  final LatLng posicion;
  String direccion = 'Buscando dirección...';
}

class MapaScreen extends StatefulWidget {
  const MapaScreen({super.key});

  @override
  State<MapaScreen> createState() => _MapaScreenState();
}

class _MapaScreenState extends State<MapaScreen> {
  final LocationService _locationService = LocationService();
  final Geocoding _geocoding = Geocoding(); // geocoding 5.x: se usa una instancia
  final List<_Punto> _puntos = [];
  GoogleMapController? _mapController;
  StreamSubscription<Position>? _subPosicion;

  Position? _posicionActual;
  String _origenId = _miUbicacionId;
  String? _destinoId;
  int _contador = 0;
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

      // Coordenadas y distancia en vivo: se actualizan cuando el usuario se mueve
      _subPosicion = _locationService.seguirUbicacion().listen((nueva) {
        if (!mounted) return;
        setState(() => _posicionActual = nueva);
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

  // ---------- Datos ----------

  _Punto? _buscarPunto(String? id) {
    if (id == null) return null;
    for (final p in _puntos) {
      if (p.id == id) return p;
    }
    return null;
  }

  LatLng? _coordenadasDe(String? id) {
    if (id == null) return null;
    if (id == _miUbicacionId) {
      final pos = _posicionActual;
      if (pos == null) return null;
      return LatLng(pos.latitude, pos.longitude);
    }
    return _buscarPunto(id)?.posicion;
  }

  double? get _distanciaActual {
    final a = _coordenadasDe(_origenId);
    final b = _coordenadasDe(_destinoId);
    if (a == null || b == null) return null;
    return Geolocator.distanceBetween(
      a.latitude,
      a.longitude,
      b.latitude,
      b.longitude,
    );
  }

  String _formatoDistancia(double? metros) {
    if (metros == null) return 'Calculando...';
    final m = metros.toStringAsFixed(1);
    if (metros >= 1000) {
      final km = (metros / 1000).toStringAsFixed(2);
      return '$m m ($km km)';
    }
    return '$m m';
  }

  Future<void> _obtenerDireccion(_Punto punto) async {
    String texto;
    try {
      final lugares = await _geocoding.placemarkFromCoordinates(
        punto.posicion.latitude,
        punto.posicion.longitude,
      );
      final partes = <String>[];
      if (lugares.isNotEmpty) {
        final calle = lugares.first.street;
        final colonia = lugares.first.subLocality;
        if (calle != null && calle.isNotEmpty) partes.add(calle);
        if (colonia != null && colonia.isNotEmpty) partes.add(colonia);
      }
      texto = partes.isEmpty ? 'Sin dirección disponible' : partes.join(', ');
    } catch (e) {
      texto = 'No se pudo obtener la dirección';
    }
    if (!mounted) return;
    setState(() => punto.direccion = texto);
  }

  // ---------- Acciones ----------

  void _agregarPunto(LatLng posicion) {
    _contador++;
    final punto = _Punto(
      id: 'punto_$_contador',
      nombre: 'Punto $_contador',
      posicion: posicion,
    );
    setState(() {
      _puntos.add(punto);
      _destinoId = punto.id; // el nuevo punto queda como destino
    });
    _obtenerDireccion(punto);
  }

  void _elegirOrigen(String id) {
    setState(() {
      _origenId = id;
      if (_destinoId == id) _destinoId = null;
    });
  }

  void _elegirDestino(String id) {
    setState(() {
      _destinoId = id;
      if (_origenId == id) _origenId = _miUbicacionId;
    });
  }

  void _limpiar() {
    setState(() {
      _puntos.clear();
      _origenId = _miUbicacionId;
      _destinoId = null;
    });
  }

  // ---------- Elementos del mapa ----------

  Set<Marker> get _marcadores {
    return _puntos.map((p) {
      final esOrigen = p.id == _origenId;
      final esDestino = p.id == _destinoId;
      double tono = BitmapDescriptor.hueAzure;
      String texto = 'Toca para elegirlo como destino';
      if (esOrigen) {
        tono = BitmapDescriptor.hueGreen;
        texto = 'Origen';
      } else if (esDestino) {
        tono = BitmapDescriptor.hueRed;
        texto = 'Destino';
      }
      return Marker(
        markerId: MarkerId(p.id),
        position: p.posicion,
        icon: BitmapDescriptor.defaultMarkerWithHue(tono),
        infoWindow: InfoWindow(title: p.nombre, snippet: texto),
        onTap: () => _elegirDestino(p.id),
      );
    }).toSet();
  }

  Set<Polyline> _lineas(Color color) {
    final a = _coordenadasDe(_origenId);
    final b = _coordenadasDe(_destinoId);
    if (a == null || b == null) return {};
    return {
      Polyline(
        polylineId: const PolylineId('medicion'),
        points: [a, b],
        width: 4,
        color: color,
      ),
    };
  }

  @override
  void dispose() {
    _subPosicion?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  // ---------- Interfaz ----------

  Widget _tarjetaCoordenadas(ColorScheme cs, TextTheme tt) {
    final pos = _posicionActual;
    return Card(
      margin: EdgeInsets.zero,
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: cs.primaryContainer,
              child: Icon(Icons.gps_fixed, color: cs.onPrimaryContainer),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Tu ubicación en tiempo real', style: tt.labelMedium),
                  const SizedBox(height: 2),
                  if (pos == null)
                    Text('Obteniendo coordenadas...', style: tt.titleSmall)
                  else ...[
                    Text(
                      'Lat: ${pos.latitude.toStringAsFixed(6)}',
                      style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      'Lng: ${pos.longitude.toStringAsFixed(6)}',
                      style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tarjetaError(ColorScheme cs, TextTheme tt) {
    return Card(
      margin: EdgeInsets.zero,
      color: cs.errorContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: cs.onErrorContainer),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _error ?? '',
                style: tt.bodyMedium?.copyWith(color: cs.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filaDato(
    IconData icono,
    String titulo,
    String valor,
    ColorScheme cs,
    TextTheme tt,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 20, color: cs.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: tt.labelSmall),
                Text(
                  valor,
                  style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filaChips(String titulo, List<Widget> chips, TextTheme tt) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: tt.labelMedium),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: chips
                  .map((c) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: c,
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _panelInferior(ColorScheme cs, TextTheme tt) {
    final forma = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
    );

    if (_puntos.isEmpty) {
      return Card(
        margin: EdgeInsets.zero,
        elevation: 4,
        shape: forma,
        child: const ListTile(
          leading: Icon(Icons.touch_app_outlined),
          title: Text('Toca el mapa para agregar un punto'),
          subtitle: Text('Cada toque crea un marcador interactivo'),
        ),
      );
    }

    final origen = _buscarPunto(_origenId);
    final destino = _buscarPunto(_destinoId);

    final chipsOrigen = <Widget>[
      ChoiceChip(
        avatar: const Icon(Icons.my_location, size: 18),
        label: const Text('Mi ubicación'),
        selected: _origenId == _miUbicacionId,
        onSelected: (_) => _elegirOrigen(_miUbicacionId),
      ),
      ..._puntos.map(
        (p) => ChoiceChip(
          label: Text(p.nombre),
          selected: p.id == _origenId,
          onSelected: p.id == _destinoId ? null : (_) => _elegirOrigen(p.id),
        ),
      ),
    ];

    final chipsDestino = _puntos
        .map(
          (p) => ChoiceChip(
            label: Text(p.nombre),
            selected: p.id == _destinoId,
            onSelected: p.id == _origenId ? null : (_) => _elegirDestino(p.id),
          ),
        )
        .toList();

    return Card(
      margin: EdgeInsets.zero,
      elevation: 4,
      shape: forma,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.45,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.straighten, color: cs.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Medir distancia',
                      style:
                          tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text('${_puntos.length} en el mapa'),
                  ),
                ],
              ),
              _filaChips('Desde', chipsOrigen, tt),
              _filaChips('Hasta', chipsDestino, tt),
              const Divider(height: 20),
              _filaDato(
                Icons.route,
                'Distancia',
                _destinoId == null
                    ? 'Elige un punto de destino'
                    : _formatoDistancia(_distanciaActual),
                cs,
                tt,
              ),
              if (origen != null)
                _filaDato(
                  Icons.trip_origin,
                  'Dirección de origen (${origen.nombre})',
                  origen.direccion,
                  cs,
                  tt,
                ),
              if (destino != null)
                _filaDato(
                  Icons.place,
                  'Dirección de destino (${destino.nombre})',
                  destino.direccion,
                  cs,
                  tt,
                ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _limpiar,
                  icon: const Icon(Icons.delete_sweep_outlined),
                  label: const Text('Quitar todos los puntos'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Localizador de Puntos de Interés'),
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(20.2756, -97.9611), // UTXJ
              zoom: 15.5,
            ),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            markers: _marcadores,
            polylines: _lineas(cs.primary),
            onMapCreated: (ctrl) {
              _mapController = ctrl;
              _moverCamaraAlUsuario();
            },
            onTap: (LatLng punto) => _agregarPunto(punto),
          ),
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Column(
              children: [
                _tarjetaCoordenadas(cs, tt),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  _tarjetaError(cs, tt),
                ],
              ],
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  FloatingActionButton.small(
                    onPressed: _moverCamaraAlUsuario,
                    tooltip: 'Centrar en mi ubicación',
                    child: const Icon(Icons.my_location),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: _panelInferior(cs, tt),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}