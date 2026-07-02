import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';
import '../widgets/common_widgets.dart';
import '../services/car_service.dart';
import 'explore_screen.dart';

class AddCarScreen extends StatefulWidget {
  const AddCarScreen({super.key});

  @override
  State<AddCarScreen> createState() => _AddCarScreenState();
}

class _AddCarScreenState extends State<AddCarScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _descController = TextEditingController();
  final _addressController = TextEditingController();
  final _yearController = TextEditingController();
  
  String _selectedType = 'Gasolina · Manual';
  String _selectedFuel = 'Gasolina';
  int _seats = 5;
  String _imageUrl = 'https://images.unsplash.com/photo-1533473359331-0135ef1b58bf?w=600&q=80'; // Default SUV image

  Future<void> _publish() async {
    if (!_formKey.currentState!.validate()) return;

    final newCar = CarData(
      id: const Uuid().v4(),
      name: _nameController.text,
      type: _selectedType,
      owner: 'Diego Sánchez', // Mock owner
      price: double.parse(_priceController.text),
      rating: 5.0,
      trips: 0,
      fuel: _selectedFuel,
      seats: _seats,
      range: '–',
      year: int.parse(_yearController.text),
      imageUrl: _imageUrl,
      location: const LatLng(40.4168, -3.7038), // Default to Madrid center for demo
      address: _addressController.text,
      description: _descController.text,
    );

    await CarService().addCar(newCar);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Vehículo publicado con éxito!')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDarkBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Publicar vehículo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Información del vehículo', style: TextStyle(color: kCyan, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 20),
              CustomInput(
                label: 'Nombre del coche (ej: Tesla Model 3)',
                controller: _nameController,
                validator: (v) => v!.isEmpty ? 'Campo requerido' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: CustomInput(
                      label: 'Precio por día (€)',
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      validator: (v) => v!.isEmpty ? 'Requerido' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: CustomInput(
                      label: 'Año',
                      controller: _yearController,
                      keyboardType: TextInputType.number,
                      validator: (v) => v!.isEmpty ? 'Requerido' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Tipo de vehículo', style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: kInputBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedType,
                    isExpanded: true,
                    dropdownColor: kInputBg,
                    style: const TextStyle(color: Colors.white),
                    items: ['Gasolina · Manual', 'Gasolina · Auto', 'Diesel · Manual', 'Eléctrico · Auto']
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedType = v!),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              CustomInput(
                label: 'Dirección de recogida',
                controller: _addressController,
                validator: (v) => v!.isEmpty ? 'Campo requerido' : null,
              ),
              const SizedBox(height: 16),
              const Text('Descripción', style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _descController,
                maxLines: 4,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: kInputBg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 32),
              CustomButton(
                label: 'Publicar ahora',
                onPressed: _publish,
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
