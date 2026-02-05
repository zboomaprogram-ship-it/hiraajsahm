class RequestModel {
  final String livestockType;
  final String ownerPrice;
  final String? pricePerKg; // Optional, might be delivery only
  final String address;
  final String phone;
  final String type; // 'inspection' or 'delivery'

  // New fields
  final String? carrierName;
  final String? city;
  final String? region;
  final String? plateNumber;
  final String? transferType; // Internal / External
  final String? vehicleImage;

  RequestModel({
    required this.livestockType,
    required this.ownerPrice,
    this.pricePerKg,
    required this.address,
    required this.phone,
    required this.type,
    this.carrierName,
    this.city,
    this.region,
    this.plateNumber,
    this.transferType,
    this.vehicleImage,
  });

  Map<String, dynamic> toJson() {
    return {
      'livestock_type': livestockType,
      'owner_price': ownerPrice,
      'price_per_kg': pricePerKg,
      'address': address,
      'phone': phone,
      'request_type': type,
      'carrier_name': carrierName,
      'city': city,
      'region': region,
      'plate_number': plateNumber,
      'transfer_type': transferType,
      'vehicle_image': vehicleImage,
    };
  }
}
