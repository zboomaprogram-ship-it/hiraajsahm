import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';

abstract class VendorRepository {
  Future<Either<Failure, bool>> upgradeUserToVendor({
    required int userId,
    required String shopName,
    required String phone,
    String? shopLink,
  });
}
