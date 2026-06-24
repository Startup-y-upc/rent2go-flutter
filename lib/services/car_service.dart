import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:latlong2/latlong.dart';
import '../screens/explore_screen.dart';

class CarService {
  static final CarService _instance = CarService._internal();
  factory CarService() => _instance;
  CarService._internal();

  final ValueNotifier<List<CarData>> carsNotifier = ValueNotifier<List<CarData>>([]);

  Future<void> init() async {
    final box = await Hive.openBox('cars');
    final storedCars = box.get('car_list', defaultValue: []);
    
    List<CarData> loadedCars = [];
    if (storedCars.isEmpty) {
      // Use demo cars if box is empty
      loadedCars = List.from(demoCars);
      await saveCars(loadedCars);
    } else {
      loadedCars = (storedCars as List).map((c) {
        final map = Map<String, dynamic>.from(c);
        return CarData(
          id: map['id'],
          name: map['name'],
          type: map['type'],
          owner: map['owner'],
          price: map['price'].toDouble(),
          rating: map['rating'].toDouble(),
          trips: map['trips'],
          fuel: map['fuel'],
          seats: map['seats'],
          range: map['range'],
          year: map['year'],
          imageUrl: map['imageUrl'],
          location: LatLng(map['lat'], map['lng']),
          address: map['address'],
          description: map['description'],
        );
      }).toList();
    }
    carsNotifier.value = loadedCars;
  }

  Future<void> addCar(CarData car) async {
    final currentCars = List<CarData>.from(carsNotifier.value);
    currentCars.add(car);
    carsNotifier.value = currentCars;
    await saveCars(currentCars);
  }

  Future<void> saveCars(List<CarData> cars) async {
    final box = Hive.box('cars');
    final data = cars.map((c) => {
      'id': c.id,
      'name': c.name,
      'type': c.type,
      'owner': c.owner,
      'price': c.price,
      'rating': c.rating,
      'trips': c.trips,
      'fuel': c.fuel,
      'seats': c.seats,
      'range': c.range,
      'year': c.year,
      'imageUrl': c.imageUrl,
      'lat': c.location.latitude,
      'lng': c.location.longitude,
      'address': c.address,
      'description': c.description,
    }).toList();
    await box.put('car_list', data);
  }
}
