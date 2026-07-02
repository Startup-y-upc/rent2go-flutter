class VehicleData {
  final int id;
  final int ownerId;
  final String licensePlate;
  final String make;
  final String model;
  final int year;
  final String vin;
  final String status;
  final double dailyPrice;
  final String categoryName;
  final String location;
  final String? description;
  final int? seats;
  final String? transmission;
  final String? fuelType;
  final double? latitude;
  final double? longitude;
  final List<String> features;
  final String? primaryImageUrl;
  final String createdAt;
  final String updatedAt;

  VehicleData({
    required this.id,
    required this.ownerId,
    required this.licensePlate,
    required this.make,
    required this.model,
    required this.year,
    required this.vin,
    required this.status,
    required this.dailyPrice,
    required this.categoryName,
    required this.location,
    this.description,
    this.seats,
    this.transmission,
    this.fuelType,
    this.latitude,
    this.longitude,
    required this.features,
    this.primaryImageUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  String get name => '$make $model';

  factory VehicleData.fromJson(Map<String, dynamic> json) {
    return VehicleData(
      id: json['id'] as int,
      ownerId: json['ownerId'] as int? ?? 0,
      licensePlate: json['licensePlate'] ?? '',
      make: json['make'] ?? '',
      model: json['model'] ?? '',
      year: json['year'] as int? ?? 0,
      vin: json['vin'] ?? '',
      status: json['status'] ?? '',
      dailyPrice: (json['dailyPrice'] as num?)?.toDouble() ?? 0,
      categoryName: json['categoryName'] ?? '',
      location: json['location'] ?? '',
      description: json['description'],
      seats: json['seats'] as int?,
      transmission: json['transmission'],
      fuelType: json['fuelType'],
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      features: (json['features'] as List?)?.map((e) => e.toString()).toList() ?? [],
      primaryImageUrl: json['primaryImageUrl'],
      createdAt: json['createdAt'] ?? '',
      updatedAt: json['updatedAt'] ?? '',
    );
  }
}

class VehicleCategory {
  final int id;
  final String name;
  VehicleCategory({required this.id, required this.name});

  factory VehicleCategory.fromJson(Map<String, dynamic> json) {
    return VehicleCategory(id: json['id'] as int, name: json['name'] ?? '');
  }
}