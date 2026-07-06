import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import '../models/vehicle_models.dart';
import '../services/feature_service.dart';
import '../services/vehicle_service.dart';
import '../widgets/common_widgets.dart';
import 'location_picker_screen.dart';

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

  // US65 — pre-seeded with the vehicle's existing coordinates, re-editable via the
  // same LocationPickerScreen used by add_vehicle_screen.dart.
  LatLng? _pickedLocation;

  // Subida de nueva imagen — endpoint dedicado POST /vehicles/{id}/images/upload,
  // independiente del guardado del resto de campos del formulario.
  final _picker = ImagePicker();
  Uint8List? _newImageBytes;
  String? _newImageFilename;
  bool _newImageIsPrimary = false;
  bool _uploadingImage = false;

  // Features/amenidades — GET /api/v1/features para el catálogo completo;
  // preseleccionadas con los nombres que ya trae VehicleData.features.
  List<VehicleFeature> _availableFeatures = [];
  Set<String> _selectedFeatureNames = {};
  bool _loadingFeatures = true;

  // Características nuevas escritas por el usuario que no existen en el
  // catálogo (_availableFeatures). No se crean en el backend por separado:
  // quedan en memoria y se envían junto con las seleccionadas del catálogo
  // en el mismo payload de actualización del vehículo (features).
  final List<String> _newFeatureNames = [];
  final _newFeatureCtrl = TextEditingController();

  // Vehículo con datos actualizados tras subir una nueva imagen (para refrescar
  // primaryImageUrl en pantalla sin recargar toda la screen).
  VehicleData? _refreshedVehicle;
  VehicleData get _currentVehicle => _refreshedVehicle ?? widget.vehicle;

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
    _pickedLocation = (v.latitude != null && v.longitude != null && (v.latitude != 0 || v.longitude != 0))
        ? LatLng(v.latitude!, v.longitude!)
        : null;
    _selectedFeatureNames = v.features.toSet();
    _loadCategories();
    _loadFeatures();
  }

  Future<void> _loadFeatures() async {
    final features = await FeatureService.getFeatures();
    if (!mounted) return;
    setState(() {
      _availableFeatures = features;
      _loadingFeatures = false;
    });
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

  Future<void> _pickNewImage() async {
    final img = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (img == null) return;
    final bytes = await img.readAsBytes();
    setState(() {
      _newImageBytes = bytes;
      _newImageFilename = img.name;
    });
  }

  Future<void> _uploadNewImage() async {
    if (_newImageBytes == null) return;
    setState(() {
      _uploadingImage = true;
      _errorMsg = null;
    });
    try {
      await VehicleService.uploadVehicleImage(
        vehicleId: widget.vehicle.id,
        imageBytes: _newImageBytes!,
        imageFilename: _newImageFilename ?? 'vehicle.jpg',
        isPrimary: _newImageIsPrimary,
        // No se dispone de la lista completa de imágenes del vehículo en esta
        // pantalla (VehicleData solo expone primaryImageUrl), así que se usa
        // un valor incremental simple basado en si ya existe una foto principal.
        imageOrder: widget.vehicle.primaryImageUrl != null && widget.vehicle.primaryImageUrl!.isNotEmpty ? 1 : 0,
      );
      if (!mounted) return;
      setState(() {
        _uploadingImage = false;
        _newImageBytes = null;
        _newImageFilename = null;
        _newImageIsPrimary = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Imagen subida correctamente'), backgroundColor: Colors.green),
      );
      // Refresca los datos del vehículo (incluyendo primaryImageUrl) desde el backend.
      final refreshed = await VehicleService.getVehicleById(widget.vehicle.id);
      if (!mounted) return;
      setState(() => _refreshedVehicle = refreshed);
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploadingImage = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: Colors.redAccent),
      );
    }
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
    // US65 — required, same as add_vehicle_screen.dart.
    if (_pickedLocation == null) {
      setState(() => _errorMsg = 'Marca la ubicación del vehículo en el mapa');
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
        features: {..._selectedFeatureNames, ..._newFeatureNames}.toList(),
        latitude: _pickedLocation!.latitude,
        longitude: _pickedLocation!.longitude,
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
    _newFeatureCtrl.dispose();
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
    final v = _currentVehicle;
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
            const SizedBox(height: 16),

            // Subida de nueva imagen — endpoint dedicado, independiente del resto
            // del formulario (POST /vehicles/{id}/images/upload).
            const Text('Agregar nueva foto', style: TextStyle(color: Colors.black54, fontSize: 12)),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: _uploadingImage ? null : _pickNewImage,
              child: Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                  image: _newImageBytes != null
                      ? DecorationImage(image: MemoryImage(_newImageBytes!), fit: BoxFit.cover)
                      : null,
                ),
                child: _newImageBytes == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo_outlined, size: 28, color: Colors.grey[500]),
                          const SizedBox(height: 6),
                          Text('Toca para elegir una imagen', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                        ],
                      )
                    : Align(
                        alignment: Alignment.bottomRight,
                        child: Container(
                          margin: const EdgeInsets.all(8),
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                          child: const Icon(Icons.edit, size: 16, color: Colors.black),
                        ),
                      ),
              ),
            ),
            if (_newImageBytes != null) ...[
              const SizedBox(height: 10),
              CheckboxListTile(
                value: _newImageIsPrimary,
                onChanged: _uploadingImage ? null : (val) => setState(() => _newImageIsPrimary = val ?? false),
                title: const Text('Usar como foto principal', style: TextStyle(color: Colors.black87, fontSize: 13)),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton(
                  onPressed: _uploadingImage ? null : _uploadNewImage,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black,
                    side: BorderSide(color: Colors.grey.shade400),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _uploadingImage
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Subir imagen', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
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
              label: 'Precio por día (S/)', controller: _priceCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 14),
            _Field(label: 'Ubicación', controller: _locationCtrl),
            const SizedBox(height: 14),

            // US65 — required map-picked location, pre-seeded with the vehicle's
            // current coordinates and re-editable.
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
                            selectedColor: kCyan.withValues(alpha: 0.2),
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
        Text(label, style: const TextStyle(color: Colors.black54, fontSize: 12)),
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