import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:dio/dio.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/di/injection_container.dart' as di;
import '../../../shop/data/models/category_model.dart';

// ============ ADD PRODUCT STATES ============
abstract class AddProductState extends Equatable {
  const AddProductState();

  @override
  List<Object?> get props => [];
}

class AddProductInitial extends AddProductState {
  const AddProductInitial();
}

class AddProductUploading extends AddProductState {
  final double progress;

  const AddProductUploading({this.progress = 0});

  @override
  List<Object?> get props => [progress];
}

class AddProductSuccess extends AddProductState {
  final int productId;

  const AddProductSuccess({required this.productId});

  @override
  List<Object?> get props => [productId];
}

class AddProductError extends AddProductState {
  final String message;

  const AddProductError({required this.message});

  @override
  List<Object?> get props => [message];
}

class AddProductCategoriesLoaded extends AddProductState {
  final List<CategoryModel> categories;
  const AddProductCategoriesLoaded(this.categories);
  @override
  List<Object?> get props => [categories];
}

// ============ ADD PRODUCT CUBIT ============
/// Manages product upload for vendors
class AddProductCubit extends Cubit<AddProductState> {
  final Dio _cleanDio;
  final StorageService _storageService;

  AddProductCubit()
    : _cleanDio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 60),
          receiveTimeout: const Duration(seconds: 60),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      ),
      _storageService = di.sl<StorageService>(),
      super(const AddProductInitial());

  // Load categories from API
  Future<void> loadCategories() async {
    try {
      final response = await _cleanDio.get(
        'https://hiraajsahm.com/wp-json/wc/v3/products/categories',
        queryParameters: {
          'per_page': 100,
          'consumer_key': AppConfig.wcConsumerKey,
          'consumer_secret': AppConfig.wcConsumerSecret,
          'hide_empty': false,
        },
      );

      if (response.statusCode == 200) {
        final List data = response.data;
        final categories = data.map((e) => CategoryModel.fromJson(e)).toList();
        emit(AddProductCategoriesLoaded(categories));
      }
    } catch (e) {
      print('Categories error: $e');
    }
  }

  /// Upload a new product
  /// Upload a new product using Custom Endpoint
  Future<void> uploadProduct({
    required String name,
    required String price,
    required int categoryId,
    required int stockQuantity,
    String? description,
    List<File>? images,
    String? salePrice,
    required String address, // Changed from location
  }) async {
    // 1. Check Limits (Keep your existing check logic here)
    final canPost = await _checkDailyLimit();
    if (!canPost) {
      // ... keep your existing error logic ...
      return;
    }

    emit(const AddProductUploading());

    try {
      // 2. Upload Images First
      List<int> imageIds = [];
      if (images != null && images.isNotEmpty) {
        final perImageProgress = 0.5 / images.length;
        double currentProgress = 0;

        for (var image in images) {
          final id = await _uploadImage(image);
          if (id != null) imageIds.add(id);
          currentProgress += perImageProgress;
          emit(AddProductUploading(progress: currentProgress));
        }
      }

      // 3. Prepare Data for Custom Endpoint
      // Note: We send simplified data, matching the PHP code above
      final productData = {
        'name': name,
        'regular_price': price,
        'sale_price': salePrice ?? '',
        'description': description ?? '',
        'category_id': categoryId,
        'stock_quantity': stockQuantity,
        'images': imageIds, // Just send the list of IDs [101, 102]
        'meta_data': [
          {'key': '_product_location', 'value': address},
        ],
      };

      // 4. Send Request to CUSTOM URL
      final token = await _storageService.getToken();

      // Using _cleanDio to allow standard JSON request
      final response = await _cleanDio.post(
        '${AppConfig.baseUrl}/custom/v1/add-product', // ⬅️ NEW URL
        data: productData,
        options: Options(
          headers: {
            'Authorization': 'Bearer ${token ?? ""}',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        await _storageService.incrementPostCount();
        final productId = response.data['product_id'];
        emit(AddProductSuccess(productId: productId));
      } else {
        emit(const AddProductError(message: 'فشل في إنشاء المنتج'));
      }
    } on DioException catch (e) {
      String errorMessage = 'خطأ في الاتصال بالخادم';
      // Handle 500 HTML errors gracefully
      if (e.response?.statusCode == 500) {
        errorMessage = 'حدث خطأ في الخادم (500). يرجى المحاولة لاحقاً.';
      } else if (e.response?.data != null && e.response?.data is Map) {
        errorMessage = e.response?.data['message'] ?? errorMessage;
      }
      emit(AddProductError(message: errorMessage));
    } catch (e) {
      emit(AddProductError(message: e.toString()));
    }
  }

  /// Update an existing product
  Future<void> updateProduct({
    required int productId,
    required String name,
    required String price,
    required int categoryId,
    required int stockQuantity,
    String? description,
    List<File>? newImages,
    String? salePrice,
    required String address, // Changed from location
  }) async {
    emit(const AddProductUploading());

    try {
      // 1. Upload new images if any
      List<int> newImageIds = [];
      if (newImages != null && newImages.isNotEmpty) {
        final perImageProgress = 0.5 / newImages.length;
        double currentProgress = 0;

        for (var image in newImages) {
          final id = await _uploadImage(image);
          if (id != null) {
            newImageIds.add(id);
          }
          currentProgress += perImageProgress;
          emit(AddProductUploading(progress: currentProgress));
        }
      }

      // 2. Prepare Update Data
      final productsUrl =
          '${AppConfig.baseUrl}${AppConfig.dokanProductsEndpoint}/$productId';

      final productData = {
        'name': name,
        'regular_price': price,
        'description': description ?? '',
        'short_description': description ?? '',
        'categories': [
          {'id': categoryId},
        ],
        'stock_quantity': stockQuantity,
        'manage_stock': true,
        // FORCE PENDING STATUS ON UPDATE
        'status': 'pending',
        'meta_data': [
          {'key': '_product_location', 'value': address},
        ],
      };

      if (salePrice != null && salePrice.isNotEmpty) {
        productData['sale_price'] = salePrice;
      }

      // If new images were added, append them
      if (newImageIds.isNotEmpty) {
        productData['images'] = newImageIds.map((id) => {'id': id}).toList();
      }

      // 3. Send Request
      final token = await _storageService.getToken();
      final response = await _cleanDio.put(
        productsUrl,
        data: productData,
        options: Options(
          headers: {
            'Authorization': 'Bearer ${token ?? ""}',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        emit(AddProductSuccess(productId: productId));
      } else {
        emit(const AddProductError(message: 'فشل في تحديث المنتج'));
      }
    } on DioException catch (e) {
      String errorMessage = 'خطأ في الاتصال بالخادم';
      if (e.response?.data != null && e.response?.data is Map) {
        errorMessage = e.response?.data['message'] ?? errorMessage;
      }
      emit(AddProductError(message: errorMessage));
    } catch (e) {
      emit(AddProductError(message: e.toString()));
    }
  }

  Future<int?> _uploadImage(File imageFile) async {
    try {
      final mediaUrl = '${AppConfig.baseUrl}/wp/v2/media';

      final fileName = imageFile.path.split('/').last;
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          imageFile.path,
          filename: fileName,
        ),
      });

      final token = await _storageService.getToken();

      final response = await _cleanDio.post(
        mediaUrl,
        data: formData,
        options: Options(
          headers: {if (token != null) 'Authorization': 'Bearer $token'},
        ),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return response.data['id'];
      }
    } catch (e) {
      // Image upload failed
    }
    return null;
  }

  Future<bool> _checkDailyLimit() async {
    final lastPostDateStr = _storageService.getLastPostDate();
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);

    // Reset count if new day (or no date)
    if (lastPostDateStr == null || lastPostDateStr != todayStr) {
      await _storageService.resetDailyPostCount();
      return true;
    }

    final count = _storageService.getDailyPostCount();
    final tier = await _storageService.getUserTier();

    // Limits
    final limit = (tier == 'silver' || tier == 'gold' || tier == 'zabayeh')
        ? 5
        : 1;

    return count < limit;
  }

  void reset() {
    emit(const AddProductInitial());
  }
}
