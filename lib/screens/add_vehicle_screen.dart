import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import '../models/vehicle_models.dart';
import '../services/feature_service.dart';
import '../services/vehicle_service.dart';
import '../widgets/common_widgets.dart';
import 'location_picker_screen.dart';

class AddVehicleScreen extends StatefulWidget {
  const AddVehicleScreen({super.key});
  @override
  State<AddVehicleScreen> createState() => _AddVehicleScreenState();
}

class _AddVehicleScreenState extends State<AddVehicleScreen> {
  final _formKey = GlobalKey<FormState>();

  final _plateCtrl = TextEditingController();
  final _makeCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _yearCtrl = TextEditingController();
  final _vinCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _seatsCtrl = TextEditingController();

  String? _transmission;
  String? _fuelType;
  int? _categoryId;
  List<VehicleCategory> _categories = [];

  Uint8List? _imageBytes;
  String? _imageFilename;
  final _picker = ImagePicker();

  // US65 — required map-picked location; no manual lat/lon fields.
  LatLng? _pickedLocation;

  // Features/amenidades — GET /api/v1/features para el catálogo completo;
  // ninguna preseleccionada por defecto en modo creación.
  List<VehicleFeature> _availableFeatures = [];
  final Set<String> _selectedFeatureNames = {};
  bool _loadingFeatures = true;

  // Características nuevas escritas por el usuario que no existen en el
  // catálogo (_availableFeatures). No se crean en el backend por separado:
  // quedan en memoria y se envían junto con las seleccionadas del catálogo
  // en el mismo payload de creación del vehículo (featureNames).
  final List<String> _newFeatureNames = [];
  final _newFeatureCtrl = TextEditingController();

  bool _loadingCategories = true;
  bool _saving = false;
  String? _errorMsg;

  static const _transmissions = ['MANUAL', 'AUTOMATIC'];
  static const _fuelTypes = ['GASOLINE', 'DIESEL', 'ELECTRIC', 'HYBRID'];

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadFeatures();
  }

  Future<void> _loadCategories() async {
    final cats = await VehicleService.getCategories();
    if (mounted) setState(() { _categories = cats; _loadingCategories = false; });
  }

  Future<void> _loadFeatures() async {
    final features = await FeatureService.getFeatures();
    if (mounted) setState(() { _availableFeatures = features; _loadingFeatures = false; });
  }

  /// Agrega una característica nueva a la lista local en memoria (sin llamar
  /// a ningún endpoint). Si ya existe una con el mismo nombre (comparación
  /// case-insensitive) en el catálogo o entre las ya agregadas localmente,
  /// simplemente la selecciona en vez de agregar un duplicado. El nombre se
  /// envía recién al guardar el vehículo, junto con los features del
  /// catálogo seleccionados.
  void _addNewFeature() {
    final name = _newFeatureCtrl.text.trim();
    if (name.isEmpty) return;

    final matches = _availableFeatures.where(
      (f) => f.name.toLowerCase() == name.toLowerCase(),
    );
    if (matches.isNotEmpty) {
      setState(() {
        _selectedFeatureNames.add(matches.first.name);
        _newFeatureCtrl.clear();
      });
      return;
    }

    final alreadyAddedLocally = _newFeatureNames.any(
      (n) => n.toLowerCase() == name.toLowerCase(),
    );
    if (alreadyAddedLocally) {
      setState(() => _newFeatureCtrl.clear());
      return;
    }

    setState(() {
      _newFeatureNames.add(name);
      _newFeatureCtrl.clear();
    });
  }

  Future<void> _pickImage() async {
    final img = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (img == null) return;
    final bytes = await img.readAsBytes();
    setState(() {
      _imageBytes = bytes;
      _imageFilename = img.name;
    });
  }

  Future<void> _openLocationPicker() async {
    final picked = await showLocationPicker(context, initialLocation: _pickedLocation);
    if (picked != null) {
      setState(() {
        _pickedLocation = picked;
        _errorMsg = null;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_imageBytes == null) {
      setState(() => _errorMsg = 'Sube una foto del vehículo');
      return;
    }
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
    // US65 — a real map-picked location is required, mirroring the existing
    // category/transmission/fuel required-field validation pattern above.
    if (_pickedLocation == null) {
      setState(() => _errorMsg = 'Marca la ubicación del vehículo en el mapa');
      return;
    }

    setState(() {
      _saving = true;
      _errorMsg = null;
    });

    try {
      await VehicleService.createVehicle(
        licensePlate: _plateCtrl.text.trim(),
        make: _makeCtrl.text.trim(),
        model: _modelCtrl.text.trim(),
        year: int.parse(_yearCtrl.text.trim()),
        vin: _vinCtrl.text.trim(),
        dailyPrice: double.parse(_priceCtrl.text.trim()),
        categoryId: _categoryId!,
        location: _locationCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        seats: _seatsCtrl.text.trim().isNotEmpty ? int.parse(_seatsCtrl.text.trim()) : null,
        transmission: _transmission!,
        fuelType: _fuelType!,
        latitude: _pickedLocation!.latitude,
        longitude: _pickedLocation!.longitude,
        featureNames: {..._selectedFeatureNames, ..._newFeatureNames}.toList(),
        imageBytes: _imageBytes!,
        imageFilename: _imageFilename ?? 'vehicle.jpg',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Vehículo publicado!'), backgroundColor: Colors.green),
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
    _plateCtrl.dispose();
    _makeCtrl.dispose();
    _modelCtrl.dispose();
    _yearCtrl.dispose();
    _vinCtrl.dispose();
    _priceCtrl.dispose();
    _locationCtrl.dispose();
    _descCtrl.dispose();
    _seatsCtrl.dispose();
    _newFeatureCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.close, color: Colors.black), onPressed: () => Navigator.pop(context)),
        title: const Text('Publicar vehículo', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 17)),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Foto
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(14),
                  image: _imageBytes != null
                      ? DecorationImage(image: MemoryImage(_imageBytes!), fit: BoxFit.cover)
                      : null,
                ),
                child: _imageBytes == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo_outlined, size: 36, color: Colors.grey[500]),
                          const SizedBox(height: 8),
                          Text('Subir foto del vehículo', style: TextStyle(color: Colors.grey[500])),
                        ],
                      )
                    : Align(
                        alignment: Alignment.bottomRight,
                        child: Container(
                          margin: const EdgeInsets.all(10),
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                          child: const Icon(Icons.edit, size: 16, color: Colors.black),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 20),

            if (_errorMsg != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3))),
                child: Text(_errorMsg!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
              ),
            ],

            Row(children: [
              Expanded(child: _Field(label: 'Marca', controller: _makeCtrl, hint: 'Tesla')),
              const SizedBox(width: 12),
              Expanded(child: _Field(label: 'Modelo', controller: _modelCtrl, hint: 'Model 3')),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: _Field(
                  label: 'Año', controller: _yearCtrl, hint: '2024',
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Field(
                  label: 'Asientos', controller: _seatsCtrl, hint: '5', required: false,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(2)],
                ),
              ),
            ]),
            const SizedBox(height: 14),
            _Field(label: 'Placa', controller: _plateCtrl, hint: 'ABC-123'),
            const SizedBox(height: 14),
            _Field(label: 'VIN', controller: _vinCtrl, hint: 'Número de chasis'),
            const SizedBox(height: 14),
            _Field(
              label: 'Precio por día (S/)', controller: _priceCtrl, hint: '49',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 14),
            _Field(label: 'Ubicación', controller: _locationCtrl, hint: 'Miraflores, Lima'),
            const SizedBox(height: 14),

            const Text('Ubicación exacta en el mapa *', style: TextStyle(color: Colors.black54, fontSize: 12)),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: _openLocationPicker,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _pickedLocation == null ? Colors.grey.shade300 : kCyan),
                ),
                child: Row(
                  children: [
                    Icon(Icons.map_outlined, color: _pickedLocation == null ? Colors.grey[500] : kCyan),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _pickedLocation == null
                            ? 'Toca para marcar la ubicación en el mapa (obligatorio)'
                            : 'Ubicación marcada: ${_pickedLocation!.latitude.toStringAsFixed(5)}, ${_pickedLocation!.longitude.toStringAsFixed(5)}',
                        style: TextStyle(color: _pickedLocation == null ? Colors.grey[500] : Colors.black87, fontSize: 13),
                      ),
                    ),
                    Icon(Icons.chevron_right, color: Colors.grey[400]),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Categoría
            const Text('Categoría', style: TextStyle(color: Colors.black54, fontSize: 12)),
            const SizedBox(height: 6),
            _loadingCategories
                ? const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: LinearProgressIndicator())
                : DropdownButtonFormField<int>(
                    initialValue: _categoryId,
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
                      initialValue: _transmission,
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
                      initialValue: _fuelType,
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
                hintText: 'Cuenta algo sobre el coche...',
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.all(12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
              ),
            ),
            const SizedBox(height: 20),

            const Text('Características', style: TextStyle(color: Colors.black54, fontSize: 12)),
            const SizedBox(height: 6),
            _loadingFeatures
                ? const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: LinearProgressIndicator())
                : _availableFeatures.isEmpty
                    ? Text('No hay features disponibles', style: TextStyle(color: Colors.grey[500], fontSize: 13))
                    : Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _availableFeatures.map((f) {
                          final selected = _selectedFeatureNames.contains(f.name);
                          return FilterChip(
                            label: Text(f.name),
                            selected: selected,
                            selectedColor: kCyan,
                            checkmarkColor: Colors.black,
                            labelStyle: const TextStyle(color: Colors.black87, fontSize: 13),
                            backgroundColor: Colors.white,
                            side: BorderSide(color: Colors.grey.shade300),
                            onSelected: (val) => setState(() {
                              if (val) {
                                _selectedFeatureNames.add(f.name);
                              } else {
                                _selectedFeatureNames.remove(f.name);
                              }
                            }),
                          );
                        }).toList(),
                      ),
            if (_newFeatureNames.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _newFeatureNames.map((name) {
                  return FilterChip(
                    label: Text(name),
                    selected: true,
                    selectedColor: kCyan.withValues(alpha: 0.2),
                    checkmarkColor: Colors.black,
                    labelStyle: const TextStyle(color: Colors.black87, fontSize: 13),
                    backgroundColor: Colors.white,
                    side: BorderSide(color: Colors.grey.shade300),
                    onSelected: (_) => setState(() => _newFeatureNames.remove(name)),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: TextField(
                    controller: _newFeatureCtrl,
                    style: const TextStyle(color: Colors.black, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Agregar otra característica...',
                      isDense: true,
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _addNewFeature(),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 44,
                  child: ElevatedButton(
                    onPressed: _addNewFeature,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                    child: const Icon(Icons.add, size: 20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _saving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _saving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Publicar vehículo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
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
}

class _Field extends StatelessWidget {
  final String label, hint;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final bool required;
  const _Field({
    required this.label,
    required this.controller,
    required this.hint,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
    this.required = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.black54, fontSize: 12)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          style: const TextStyle(color: Colors.black, fontSize: 14),
          validator: required ? (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null : null,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[400]),
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