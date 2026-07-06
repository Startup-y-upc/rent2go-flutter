import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// US65 — reusable tap-to-pick map location picker, reused by both
/// add_vehicle_screen.dart (required step) and edit_vehicle_screen.dart
/// (pre-seeded with the vehicle's existing coordinates). Reuses the existing
/// flutter_map/latlong2 stack already proven in explore_screen.dart — no new
/// map package or API key needed (OSM tiles).
class LocationPickerScreen extends StatefulWidget {
  final LatLng? initialLocation;
  const LocationPickerScreen({super.key, this.initialLocation});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  static const _limaCenter = LatLng(-12.046374, -77.042793);
  late LatLng _picked;
  final _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _picked = widget.initialLocation ?? _limaCenter;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.close, color: Colors.black), onPressed: () => Navigator.pop(context)),
        title: const Text('Ubicación del vehículo', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 17)),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _picked,
              initialZoom: 14,
              onTap: (_, point) => setState(() => _picked = point),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.rent2go.app',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _picked,
                    width: 40,
                    height: 40,
                    child: const Icon(Icons.location_pin, color: Colors.redAccent, size: 40),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            top: 16, left: 16, right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 8)],
              ),
              child: const Text(
                'Toca el mapa para marcar la ubicación exacta del vehículo',
                style: TextStyle(fontSize: 13, color: Colors.black87),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          Positioned(
            // Bugfix: a hardcoded `bottom: 24` placed this button under the
            // Android gesture/nav bar on devices with a taller system inset,
            // blocking taps. Adding the real bottom safe-area inset
            // (MediaQuery padding.bottom) on top of the visual margin makes
            // the button land above the system bar on every device, matching
            // the Scaffold.bottomNavigationBar + SafeArea(top: false) fix
            // already applied in car_detail_screen.dart (this screen keeps
            // its Stack layout for the tap-to-pick map, so the offset is
            // added here instead of switching to bottomNavigationBar).
            bottom: 24 + MediaQuery.of(context).padding.bottom,
            left: 20, right: 20,
            child: SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, _picked),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  'Confirmar ubicación (${_picked.latitude.toStringAsFixed(5)}, ${_picked.longitude.toStringAsFixed(5)})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Opens the picker and returns the chosen [LatLng], or null if cancelled.
Future<LatLng?> showLocationPicker(BuildContext context, {LatLng? initialLocation}) {
  return Navigator.of(context).push<LatLng>(
    MaterialPageRoute(builder: (_) => LocationPickerScreen(initialLocation: initialLocation)),
  );
}
