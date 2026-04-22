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

  Future<void> verifyIapPurchase({
    required int userId,
    required String productId,
    required String receiptData,
  }) async {
    emit(VendorUpgradeLoading());

    final result = await vendorRepository.verifyIapReceipt(
      userId: userId,
      productId: productId,
      receiptData: receiptData,
    );

    result.fold(
      (failure) => emit(VendorUpgradeFailure(message: failure.message)),
      (success) =>
          emit(const VendorUpgradeSuccess(message: 'تم تفعيل الاشتراك بنجاح!')),
    );
  }

  Future<void> restoreIapPurchase({
    required int userId,
    required String receiptData,
  }) async {
    emit(VendorUpgradeLoading());

    final result = await vendorRepository.restoreIapReceipt(
      userId: userId,
      receiptData: receiptData,
    );

    result.fold(
      (failure) => emit(VendorUpgradeFailure(message: failure.message)),
      (success) =>
          emit(const VendorUpgradeSuccess(message: 'تم استعادة الاشتراك بنجاح!')),
    );
  }
}
