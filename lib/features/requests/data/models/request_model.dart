class RequestModel {
  final String livestockType;
  final String ownerPrice;
  final String? pricePerKg; // Optional, might be delivery only
  final String address;
  final String phone;
  final String type; // 'inspection' or 'delivery'

  RequestModel({
    required this.livestockType,
    required this.ownerPrice,
    this.pricePerKg,
    required this.address,
    required this.phone,
    required this.type,
  });

  Map<String, dynamic> toJson() {
    return {
      'livestock_type': livestockType,
      'owner_price': ownerPrice,
      'price_per_kg': pricePerKg,
      'address': address,
      'phone': phone,
      'request_type': type,
    };
  }
}
