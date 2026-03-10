import 'package:equatable/equatable.dart';

/// Address Model for saved user addresses
class AddressModel extends Equatable {
  final String id;
  final String label; // المنزل, العمل, أخرى
  final String fullName;
  final String phone;
  final String city;
  final String street;
  final String? latLng;
  final bool isDefault;

  const AddressModel({
    required this.id,
    required this.label,
    required this.fullName,
    required this.phone,
    required this.city,
    required this.street,
    this.latLng,
    this.isDefault = false,
  });

  AddressModel copyWith({
    String? id,
    String? label,
    String? fullName,
    String? phone,
    String? city,
    String? street,
    String? latLng,
    bool? isDefault,
  }) {
    return AddressModel(
      id: id ?? this.id,
      label: label ?? this.label,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      city: city ?? this.city,
      street: street ?? this.street,
      latLng: latLng ?? this.latLng,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  factory AddressModel.fromJson(Map<String, dynamic> json) {
    return AddressModel(
      id: json['id']?.toString() ?? '',
      label: json['label'] ?? 'أخرى',
      fullName: json['full_name'] ?? '',
      phone: json['phone'] ?? '',
      city: json['city'] ?? '',
      street: json['street'] ?? '',
      latLng: json['lat_lng'],
      isDefault: json['is_default'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'full_name': fullName,
      'phone': phone,
      'city': city,
      'street': street,
      'lat_lng': latLng,
      'is_default': isDefault,
    };
  }

  String get fullAddress => '$street, $city';

  @override
  List<Object?> get props => [
    id,
    label,
    fullName,
    phone,
    city,
    street,
    latLng,
    isDefault,
  ];
}
