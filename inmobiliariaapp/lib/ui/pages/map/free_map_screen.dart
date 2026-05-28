// ui/pages/map/free_map_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:inmobiliariaapp/utils/themes.dart';

class FreeMapScreen extends StatefulWidget {
  final TextEditingController addressController;
  final Function(String)?
  onCityUpdate; // Callback para despachar la ciudad detectada al formulario padre

  const FreeMapScreen({
    super.key,
    required this.addressController,
    this.onCityUpdate,
  });

  @override
  State<FreeMapScreen> createState() => FreeMapScreenState();
}

class FreeMapScreenState extends State<FreeMapScreen> {
  final MapController _mapController = MapController();
  LatLng _currentPosition = const LatLng(
    7.1193,
    -73.1227,
  ); // Bucaramanga por defecto
  bool _isLoading = false;
  bool _isMovingMap = false; // Control de escala animada del Pin central

  // --- 1. GEOCODIFICACIÓN DIRECTA: TEXTO -> COORDENADAS (CONFINADO A COLOMBIA) ---
  Future<void> searchCurrentAddress() async {
    final address = widget.addressController.text.trim();
    if (address.isEmpty) return;

    setState(() => _isLoading = true);

    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(address)}&format=json&limit=1&countrycodes=co',
    );

    try {
      final response = await http.get(
        url,
        headers: {'User-Agent': 'InmobiliariaApp_Flutter_Client'},
      );

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        if (data.isNotEmpty) {
          final lat = double.parse(data[0]['lat']);
          final lon = double.parse(data[0]['lon']);

          setState(() {
            _currentPosition = LatLng(lat, lon);
          });
          _mapController.move(_currentPosition, 16.0);
        }
      }
    } catch (e) {
      debugPrint("Error al geolocalizar directo: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // --- 2. GEOCODIFICACIÓN INVERSA INTELIGENTE: COORDENADAS -> TEXTO Y CIUDAD ---
  Future<void> _getAddressFromCoordinates(LatLng position) async {
    setState(() => _isLoading = true);

    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/reverse?lat=${position.latitude}&lon=${position.longitude}&format=json&addressdetails=1',
    );

    try {
      final response = await http.get(
        url,
        headers: {'User-Agent': 'InmobiliariaApp_Flutter_Client'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final String? displayName = data['display_name'];
        final Map<String, dynamic>? addressDetails = data['address'];

        // A. Formatear la dirección corta para el Input de texto
        if (displayName != null) {
          final parts = displayName.split(',');
          final shortAddress = parts.length > 2
              ? "${parts[0].trim()}, ${parts[1].trim()}, ${parts[2].trim()}"
              : displayName;

          setState(() {
            widget.addressController.text = shortAddress;
          });
        }

        // B. Extraer la Ciudad desglosada del JSON de OpenStreetMap
        if (addressDetails != null && widget.onCityUpdate != null) {
          // OpenStreetMap varía el nombre de la clave según la densidad demográfica
          final String city =
              addressDetails['city'] ??
              addressDetails['town'] ??
              addressDetails['village'] ??
              addressDetails['county'] ??
              "Ciudad desconocida";

          // Despachamos el valor string directo al padre
          widget.onCityUpdate!(city);
          debugPrint("📍 Ubicación e Inmueble vinculados a la ciudad: $city");
        }
      }
    } catch (e) {
      debugPrint("Error en detección de dirección/ciudad inversa: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _currentPosition,
            initialZoom: 14.0,
            onMapEvent: (event) {
              if (event is MapEventMove) {
                setState(() {
                  _isMovingMap = true;
                });
              } else if (event is MapEventMoveEnd) {
                setState(() {
                  _isMovingMap = false;
                  _currentPosition = event.camera.center;
                });
                _getAddressFromCoordinates(event.camera.center);
              }
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.inmobiliariaapp',
            ),
          ],
        ),

        // PIN FIJO CENTRAL CON EFECTO DE ELEVACIÓN TÁCTIL (ANIMATED SCALE)
        Center(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 35),
            child: AnimatedScale(
              scale: _isMovingMap ? 1.25 : 1.0,
              duration: const Duration(milliseconds: 150),
              child: Icon(
                Icons.location_on_rounded,
                color: context.secondaryColor,
                size: 45,
                shadows: const [
                  Shadow(
                    blurRadius: 6.0,
                    color: Colors.black,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
            ),
          ),
        ),

        // CARGA EN TIEMPO REAL
        if (_isLoading)
          Positioned(
            bottom: 16,
            right: 16,
            child: CircleAvatar(
              backgroundColor: context.surfaceColor,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: context.primaryColor,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
