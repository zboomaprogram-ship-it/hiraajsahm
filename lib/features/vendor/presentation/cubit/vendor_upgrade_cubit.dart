import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/vendor_repository.dart';
import 'vendor_upgrade_state.dart';

class VendorUpgradeCubit extends Cubit<VendorUpgradeState> {
  final VendorRepository vendorRepository;

  VendorUpgradeCubit({required this.vendorRepository})
    : super(VendorUpgradeInitial());

  Future<void> upgradeToVendor({
    required int userId,
    required String shopName,
    required String phone,
    String? shopLink,
  }) async {
    emit(VendorUpgradeLoading());

    final result = await vendorRepository.upgradeUserToVendor(
      userId: userId,
      shopName: shopName,
      phone: phone,
      shopLink: shopLink,
    );

    result.fold(
      (failure) => emit(VendorUpgradeFailure(message: failure.message)),
      (success) =>
          emit(const VendorUpgradeSuccess(message: 'تمت الترقية بنجاح!')),
    );
  }
}
