import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/vehicle_models.dart';
import '../services/vehicle_service.dart';
import '../widgets/common_widgets.dart';

class EditVehicleScreen extends StatefulWidget {
  final VehicleData vehicle;
  const EditVehicleScreen({super.key, required this.vehicle});

  @override
  State<EditVehicleScreen> createState() => _EditVehicleScreenState();
}

class _EditVehicleScreenState extends State<EditVehicleScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _makeCtrl;
  late TextEditingController _modelCtrl;
  late TextEditingController _yearCtrl;
  late TextEditingController _priceCtrl;
  late TextEditingController _locationCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _seatsCtrl;

  String? _transmission;
  String? _fuelType;
  int? _categoryId;
  List<VehicleCategory> _categories = [];

  bool _loadingCategories = true;
  bool _saving = false;
  String? _errorMsg;

  static const _transmissions = ['MANUAL', 'AUTOMATIC'];
  static const _fuelTypes = ['GASOLINE', 'DIESEL', 'ELECTRIC', 'HYBRID'];

  @override
  void initState() {
    super.initState();
    final v = widget.vehicle;
    _makeCtrl = TextEditingController(text: v.make);
    _modelCtrl = TextEditingController(text: v.model);
    _yearCtrl = TextEditingController(text: v.year.toString());
    _priceCtrl = TextEditingController(text: v.dailyPrice.toStringAsFixed(0));
    _locationCtrl = TextEditingController(text: v.location);
    _descCtrl = TextEditingController(text: v.description ?? '');
    _seatsCtrl = TextEditingController(text: v.seats?.toString() ?? '');
    _transmission = _transmissions.contains(v.transmission?.toUpperCase())
        ? v.transmission!.toUpperCase()
        : null;
    _fuelType = _fuelTypes.contains(v.fuelType?.toUpperCase())
        ? v.fuelType!.toUpperCase()
        : null;
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final cats = await VehicleService.getCategories();
    if (!mounted) return;
    setState(() {
      _categories = cats;
      _loadingCategories = false;
      final match = cats.where((c) => c.name == widget.vehicle.categoryName).toList();
      if (match.isNotEmpty) _categoryId = match.first.id;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_categoryId == null) {
      setState(() => _errorMsg = 'Selecciona una categoría');
      return;
    }
    if (_transmission == null) {
      setState(() => _errorMsg = 'Selecciona el tipo de transmisión');
      return;
    }
    if (_fuelType == null) {
      setState(() => _errorMsg = 'Selecciona el tipo de combustible');
      return;
    }

    setState(() {
      _saving = true;
      _errorMsg = null;
    });

    try {
      await VehicleService.updateVehicle(
        id: widget.vehicle.id,
        categoryId: _categoryId!,
        make: _makeCtrl.text.trim(),
        model: _modelCtrl.text.trim(),
        year: int.parse(_yearCtrl.text.trim()),
        location: _locationCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        seats: _seatsCtrl.text.trim().isNotEmpty ? int.parse(_seatsCtrl.text.trim()) : null,
        transmission: _transmission!,
        fuelType: _fuelType!,
        latitude: widget.vehicle.latitude,
        longitude: widget.vehicle.longitude,
      );

      // El precio se actualiza con su propio endpoint
      final newPrice = double.tryParse(_priceCtrl.text.trim());
      if (newPrice != null && newPrice != widget.vehicle.dailyPrice) {
        await VehicleService.updatePrice(widget.vehicle.id, newPrice);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vehículo actualizado'), backgroundColor: Colors.green),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() {
        _saving = false;
        _errorMsg = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  void dispose() {
    _makeCtrl.dispose();
    _modelCtrl.dispose();
    _yearCtrl.dispose();
    _priceCtrl.dispose();
    _locationCtrl.dispose();
    _descCtrl.dispose();
    _seatsCtrl.dispose();
    super.dispose();
  }

  String _fuelLabel(String f) {
    switch (f) {
      case 'GASOLINE': return 'Gasolina';
      case 'DIESEL': return 'Diésel';
      case 'ELECTRIC': return 'Eléctrico';
      case 'HYBRID': return 'Híbrido';
      default: return f;
    }
  }

  InputDecoration _dropdownDecoration() => InputDecoration(
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
  );

  @override
  Widget build(BuildContext context) {
    final v = widget.vehicle;
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.close, color: Colors.black), onPressed: () => Navigator.pop(context)),
        title: const Text('Editar vehículo', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 17)),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Foto (solo lectura por ahora, sin endpoint dedicado en esta pantalla)
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: v.primaryImageUrl != null && v.primaryImageUrl!.isNotEmpty
                  ? Image.network(v.primaryImageUrl!, height: 160, width: double.infinity, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(height: 160, color: Colors.grey[300], child: const Icon(Icons.directions_car, size: 50)))
                  : Container(height: 160, color: Colors.grey[300], child: const Icon(Icons.directions_car, size: 50)),
            ),
            const SizedBox(height: 8),
            Text('Placa: ${v.licensePlate} · VIN: ${v.vin}', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
            const SizedBox(height: 20),

            if (_errorMsg != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: Colors.red.withOpacity(0.08), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.redAccent.withOpacity(0.3))),
                child: Text(_errorMsg!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
              ),
            ],

            Row(children: [
              Expanded(child: _Field(label: 'Marca', controller: _makeCtrl)),
              const SizedBox(width: 12),
              Expanded(child: _Field(label: 'Modelo', controller: _modelCtrl)),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: _Field(
                  label: 'Año', controller: _yearCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Field(
                  label: 'Asientos', controller: _seatsCtrl, required: false,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(2)],
                ),
              ),
            ]),
            const SizedBox(height: 14),
            _Field(
              label: 'Precio por día (€)', controller: _priceCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 14),
            _Field(label: 'Ubicación', controller: _locationCtrl),
            const SizedBox(height: 14),

            const Text('Categoría', style: TextStyle(color: Colors.black54, fontSize: 12)),
            const SizedBox(height: 6),
            _loadingCategories
                ? const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: LinearProgressIndicator())
                : DropdownButtonFormField<int>(
                    value: _categoryId,
                    items: _categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                    onChanged: (v) => setState(() => _categoryId = v),
                    decoration: _dropdownDecoration(),
                  ),
            const SizedBox(height: 14),

            Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Transmisión', style: TextStyle(color: Colors.black54, fontSize: 12)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: _transmission,
                      items: _transmissions.map((t) => DropdownMenuItem(value: t, child: Text(t == 'MANUAL' ? 'Manual' : 'Automática'))).toList(),
                      onChanged: (v) => setState(() => _transmission = v),
                      decoration: _dropdownDecoration(),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Combustible', style: TextStyle(color: Colors.black54, fontSize: 12)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: _fuelType,
                      items: _fuelTypes.map((f) => DropdownMenuItem(value: f, child: Text(_fuelLabel(f)))).toList(),
                      onChanged: (v) => setState(() => _fuelType = v),
                      decoration: _dropdownDecoration(),
                    ),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 14),

            const Text('Descripción', style: TextStyle(color: Colors.black54, fontSize: 12)),
            const SizedBox(height: 6),
            TextFormField(
              controller: _descCtrl,
              maxLines: 3,
              style: const TextStyle(color: Colors.black, fontSize: 14),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.all(12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
              ),
            ),
            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _saving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Guardar cambios', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final bool required;
  const _Field({
    required this.label,
    required this.controller,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
    this.required = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.black54, fontSize: 12)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          style: const TextStyle(color: Colors.black, fontSize: 14),
          validator: required ? (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null : null,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kCyan)),
            errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.redAccent)),
          ),
        ),
      ],
    );
  }
}