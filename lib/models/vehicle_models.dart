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

/// Feature/amenidad de vehículo (GET /api/v1/features). Solo se consume aquí
/// para poblar la selección múltiple del formulario de vehículo — no hay UI
/// de administración de catálogo (crear/editar/eliminar features) en Flutter.
class VehicleFeature {
  final int id;
  final String name;
  const VehicleFeature({required this.id, required this.name});

  factory VehicleFeature.fromJson(Map<String, dynamic> json) {
    return VehicleFeature(
      id: json['id'] as int,
      name: json['name'] ?? '',
    );
  }
}

/// Sprint 5 (US75/TS22) — full `PagedResponse` projection (content/page/size/
/// totalElements/totalPages), mirroring Kotlin's `PagedVehicleResponse` /
/// `VehicleListState` pagination fields (currentPage/totalPages/hasMorePages).
/// Backend contract shape is unchanged (`VehicleController.toPagedResponse`);
/// previously the Flutter client only read `content` and silently discarded
/// page/totalPages, making "load more" impossible.
class PagedVehicles {
  final List<VehicleData> content;
  final int page;
  final int size;
  final int totalElements;
  final int totalPages;

  const PagedVehicles({
    required this.content,
    required this.page,
    required this.size,
    required this.totalElements,
    required this.totalPages,
  });

  bool get hasMorePages => page < totalPages - 1;

  factory PagedVehicles.fromJson(Map<String, dynamic> json) {
    final content = (json['content'] as List? ?? [])
        .map((v) => VehicleData.fromJson(v as Map<String, dynamic>))
        .toList();
    return PagedVehicles(
      content: content,
      page: json['page'] as int? ?? 0,
      size: json['size'] as int? ?? content.length,
      totalElements: json['totalElements'] as int? ?? content.length,
      totalPages: json['totalPages'] as int? ?? 1,
    );
  }
}