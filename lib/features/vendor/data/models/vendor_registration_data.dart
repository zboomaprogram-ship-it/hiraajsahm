class VendorRegistrationData {
  final String shopName;
  final String phone;
  final String? shopLink;

  VendorRegistrationData({
    required this.shopName,
    required this.phone,
    this.shopLink,
  });
}
