import 'package:flutter/material.dart';
import '../widgets/common_widgets.dart';

/// US63 (Flutter half) — structured search filters, mirroring Kotlin's FilterSheet
/// (price/seats/transmission/fuel) and forwarding to the same backend query params
/// (VehicleController.searchAvailableVehicles) — no backend change required.
class VehicleFilters {
  final double? minPrice;
  final double? maxPrice;
  final int? seats;
  final String? transmission;
  final String? fuelType;
  final double? centerLatitude;
  final double? centerLongitude;
  final double? radiusKm;

  const VehicleFilters({
    this.minPrice,
    this.maxPrice,
    this.seats,
    this.transmission,
    this.fuelType,
    this.centerLatitude,
    this.centerLongitude,
    this.radiusKm,
  });

  bool get isEmpty =>
      minPrice == null &&
      maxPrice == null &&
      seats == null &&
      transmission == null &&
      fuelType == null &&
      !hasRadius;

  bool get hasRadius => centerLatitude != null && centerLongitude != null && radiusKm != null;

  VehicleFilters copyWith({
    double? minPrice,
    double? maxPrice,
    int? seats,
    String? transmission,
    String? fuelType,
    double? centerLatitude,
    double? centerLongitude,
    double? radiusKm,
    bool clearRadius = false,
  }) {
    return VehicleFilters(
      minPrice: minPrice ?? this.minPrice,
      maxPrice: maxPrice ?? this.maxPrice,
      seats: seats ?? this.seats,
      transmission: transmission ?? this.transmission,
      fuelType: fuelType ?? this.fuelType,
      centerLatitude: clearRadius ? null : (centerLatitude ?? this.centerLatitude),
      centerLongitude: clearRadius ? null : (centerLongitude ?? this.centerLongitude),
      radiusKm: clearRadius ? null : (radiusKm ?? this.radiusKm),
    );
  }
}

/// Shows the filter sheet and returns the applied filters, or null if the sheet was
/// dismissed with "Limpiar" (caller should reset filters) — distinguishing that from a
/// plain cancel (no return value change) via the [onClear] callback.
Future<VehicleFilters?> showVehicleFilterSheet(
  BuildContext context, {
  required VehicleFilters initialFilters,
}) {
  return showModalBottomSheet<VehicleFilters>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => _VehicleFilterSheetContent(initialFilters: initialFilters),
  );
}

class _VehicleFilterSheetContent extends StatefulWidget {
  final VehicleFilters initialFilters;
  const _VehicleFilterSheetContent({required this.initialFilters});

  @override
  State<_VehicleFilterSheetContent> createState() => _VehicleFilterSheetContentState();
}

class _VehicleFilterSheetContentState extends State<_VehicleFilterSheetContent> {
  late final TextEditingController _minPriceCtrl;
  late final TextEditingController _maxPriceCtrl;
  late final TextEditingController _seatsCtrl;
  String? _transmission;
  String? _fuelType;

  static const _transmissions = ['MANUAL', 'AUTOMATIC'];
  static const _fuelTypes = ['GASOLINE', 'DIESEL', 'ELECTRIC', 'HYBRID'];

  @override
  void initState() {
    super.initState();
    _minPriceCtrl = TextEditingController(text: widget.initialFilters.minPrice?.toInt().toString() ?? '');
    _maxPriceCtrl = TextEditingController(text: widget.initialFilters.maxPrice?.toInt().toString() ?? '');
    _seatsCtrl = TextEditingController(text: widget.initialFilters.seats?.toString() ?? '');
    _transmission = widget.initialFilters.transmission;
    _fuelType = widget.initialFilters.fuelType;
  }

  @override
  void dispose() {
    _minPriceCtrl.dispose();
    _maxPriceCtrl.dispose();
    _seatsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const Text('Filtrar vehículos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
              const SizedBox(height: 16),

              _SectionLabel('Precio por día'),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _minPriceCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Mínimo', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _maxPriceCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Máximo', border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),

              const _SectionDivider(),
              _SectionLabel('Asientos mínimos'),
              const SizedBox(height: 8),
              TextField(
                controller: _seatsCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(hintText: 'Ej. 4', border: OutlineInputBorder()),
              ),

              const _SectionDivider(),
              _SectionLabel('Transmisión'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _transmissions.map((option) {
                  final selected = _transmission == option;
                  return ChoiceChip(
                    label: Text(option == 'MANUAL' ? 'Manual' : 'Automática'),
                    selected: selected,
                    selectedColor: kCyan.withOpacity(0.2),
                    onSelected: (_) => setState(() => _transmission = selected ? null : option),
                  );
                }).toList(),
              ),

              const _SectionDivider(),
              _SectionLabel('Combustible'),
              const SizedBox(height: 8),
              // Wrap (equivalente a FlowRow en Kotlin) para que las opciones de combustible
              // salten de línea en pantallas angostas, en vez de recortarse en un Row fijo.
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _fuelTypes.map((option) {
                  final selected = _fuelType == option;
                  return ChoiceChip(
                    label: Text(option[0] + option.substring(1).toLowerCase()),
                    selected: selected,
                    selectedColor: kCyan.withOpacity(0.2),
                    onSelected: (_) => setState(() => _fuelType = selected ? null : option),
                  );
                }).toList(),
              ),

              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, const VehicleFilters()),
                      child: const Text('Limpiar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: kCyan, foregroundColor: Colors.black),
                      onPressed: () {
                        Navigator.pop(
                          context,
                          VehicleFilters(
                            minPrice: double.tryParse(_minPriceCtrl.text),
                            maxPrice: double.tryParse(_maxPriceCtrl.text),
                            seats: int.tryParse(_seatsCtrl.text),
                            transmission: _transmission,
                            fuelType: _fuelType,
                            // Preserva cualquier búsqueda por radio activa — los filtros
                            // estructurados y el radio geográfico se combinan, no se pisan.
                            centerLatitude: widget.initialFilters.centerLatitude,
                            centerLongitude: widget.initialFilters.centerLongitude,
                            radiusKm: widget.initialFilters.radiusKm,
                          ),
                        );
                      },
                      child: const Text('Aplicar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) =>
      Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black));
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Divider(height: 1, color: Colors.black.withOpacity(0.08)),
  );
}
