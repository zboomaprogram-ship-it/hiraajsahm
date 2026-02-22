import 'package:equatable/equatable.dart';

class ServiceProviderModel extends Equatable {
  final String name;
  final String phone;
  final String city;
  final String role;
  final String vehicleDetails;
  final String pricePerKilo;
  final String imageUrl;

  const ServiceProviderModel({
    required this.name,
    required this.phone,
    required this.city,
    required this.role,
    required this.vehicleDetails,
    required this.pricePerKilo,
    required this.imageUrl,
  });

  factory ServiceProviderModel.fromJson(Map<String, dynamic> json) {
    return ServiceProviderModel(
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      city: json['city'] ?? '',
      role: json['role'] ?? '',
      vehicleDetails: json['vehicle_details'] ?? '',
      pricePerKilo: json['price_per_kilo'] ?? '',
      imageUrl: json['image_url'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'phone': phone,
      'city': city,
      'role': role,
      'vehicle_details': vehicleDetails,
      'price_per_kilo': pricePerKilo,
      'image_url': imageUrl,
    };
  }

  @override
  List<Object?> get props => [
    name,
    phone,
    city,
    role,
    vehicleDetails,
    pricePerKilo,
    imageUrl,
  ];
}
