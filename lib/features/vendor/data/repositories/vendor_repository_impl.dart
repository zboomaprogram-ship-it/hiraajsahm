import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../data/datasources/vendor_remote_datasource.dart';
import '../../domain/repositories/vendor_repository.dart';

class VendorRepositoryImpl implements VendorRepository {
  final VendorRemoteDataSource remoteDataSource;

  VendorRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, bool>> upgradeUserToVendor({
    required int userId,
    required String shopName,
    required String phone,
    String? shopLink,
  }) async {
    return await remoteDataSource.upgradeUserToVendor(
      userId: userId,
      shopName: shopName,
      phone: phone,
      shopLink: shopLink,
    );
  }
}
