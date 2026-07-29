import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:dio/dio.dart';
import '../../../../core/config/app_config.dart';
import '../../../shop/data/models/category_model.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/di/injection_container.dart' as di;

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

class AdQuota extends Equatable {
  final int packId;
  final int dailyLimit;
  final int adsToday;
  final int remainingToday;
  final bool canAdd;

  const AdQuota({
    required this.packId,
    required this.dailyLimit,
    required this.adsToday,
    required this.remainingToday,
    required this.canAdd,
  });

  factory AdQuota.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic value, [int fallback = 0]) =>
        int.tryParse(value?.toString() ?? '') ?? fallback;

    return AdQuota(
      packId: parseInt(json['pack_id']),
      dailyLimit: parseInt(json['daily_limit'], 1),
      adsToday: parseInt(json['ads_today']),
      remainingToday: parseInt(json['remaining_today']),
      canAdd: json['can_add'] == true || json['can_add']?.toString() == '1',
    );
  }

  @override
  List<Object?> get props => [
    packId,
    dailyLimit,
    adsToday,
    remainingToday,
    canAdd,
  ];
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

  Future<AdQuota?> fetchQuota() async {
    try {
      final token = await _storageService.getToken();
      if (token == null || token.isEmpty) return null;
      final response = await _cleanDio.get(
        '${AppConfig.baseUrl}/custom/v1/add-product-quota',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (response.statusCode == 200 && response.data is Map) {
        return AdQuota.fromJson(
          Map<String, dynamic>.from(response.data as Map),
        );
      }
    } catch (_) {
      // The create endpoint performs the same authoritative validation. Keep
      // the form usable if quota preview is temporarily unavailable.
    }
    return null;
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
    String? region,
    String? city,
    String? downPayment,
    File? video,
  }) async {
    // 1. Check Limits (Real-time)
    final userId = await _storageService.getUserId();
    if (userId == null) {
      emit(const AddProductError(message: 'يرجى تسجيل الدخول أولاً'));
      return;
    }

    // Immediately emit uploading to disable the button and prevent double-taps
    emit(const AddProductUploading(progress: 0.01));

    emit(const AddProductUploading(progress: 0.05));

    final quota = await fetchQuota();
    if (quota != null && !quota.canAdd) {
      emit(
        AddProductError(
          message:
              'استخدمت ${quota.adsToday} من ${quota.dailyLimit} إعلانات اليوم. '
              'يمكنك الإضافة مجدداً بعد منتصف الليل.',
        ),
      );
      return;
    }

    emit(const AddProductUploading(progress: 0.1));

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

      // Upload Video
      int? videoId;
      if (video != null) {
        videoId = await _uploadImage(video);
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
          if (region != null) {'key': '_product_region', 'value': region},
          if (city != null) {'key': '_product_city', 'value': city},
          if (downPayment != null)
            {'key': 'add_down_payment_field', 'value': downPayment},
          if (videoId != null) {'key': '_product_video_id', 'value': videoId},
        ],
      };

      // 4. Send Request to CUSTOM URL
      final token = await _storageService.getToken();

      // Using _cleanDio to allow standard JSON request
      final response = await _cleanDio.post(
        '${AppConfig.baseUrl}/custom/v1/add-product-v2', // ⬅️ NEW URL V2
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
        emit(const AddProductError(message: 'فشل في إنشاء الاعلان'));
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
    String? region,
    String? city,
    String? downPayment,
    File? video,
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

      int? videoId;
      if (video != null) {
        videoId = await _uploadImage(video);
      }

      // 2. Prepare Update Data
      final productsUrl =
          '${AppConfig.baseUrl}${AppConfig.dokanProductsEndpoint}/$productId';
      final token = await _storageService.getToken();
      final authOptions = Options(
        headers: {
          'Authorization': 'Bearer ${token ?? ""}',
          'Content-Type': 'application/json',
        },
      );

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
        'meta_data': [
          {'key': '_product_location', 'value': address},
          if (region != null) {'key': '_product_region', 'value': region},
          if (city != null) {'key': '_product_city', 'value': city},
          if (downPayment != null)
            {'key': 'add_down_payment_field', 'value': downPayment},
          if (videoId != null) {'key': '_product_video_id', 'value': videoId},
        ],
      };

      if (salePrice != null && salePrice.isNotEmpty) {
        productData['sale_price'] = salePrice;
      }

      // Preserve the current gallery when new files are added. Sending only
      // the new IDs makes WooCommerce replace and delete every old image.
      if (newImageIds.isNotEmpty) {
        final existingResponse = await _cleanDio.get(
          productsUrl,
          options: authOptions,
        );
        final existingImages =
            existingResponse.data is Map &&
                existingResponse.data['images'] is List
            ? (existingResponse.data['images'] as List)
                  .map((image) => int.tryParse(image['id']?.toString() ?? ''))
                  .whereType<int>()
                  .toList()
            : <int>[];
        final allImageIds = <int>{...existingImages, ...newImageIds};
        productData['images'] = allImageIds.map((id) => {'id': id}).toList();
      }

      // 3. Send Request
      final response = await _cleanDio.put(
        productsUrl,
        data: productData,
        options: authOptions,
      );

      if (response.statusCode == 200) {
        // Enforce location saving via WooCommerce API since Dokan sometimes drops meta
        try {
          final wcUrl =
              '${AppConfig.baseUrl}${AppConfig.wcProductsEndpoint}/$productId';
          await _cleanDio.put(
            wcUrl,
            queryParameters: {
              'consumer_key': AppConfig.wcConsumerKey,
              'consumer_secret': AppConfig.wcConsumerSecret,
            },
            data: {
              'meta_data': [
                {'key': '_product_location', 'value': address},
                if (region != null) {'key': '_product_region', 'value': region},
                if (city != null) {'key': '_product_city', 'value': city},
                if (downPayment != null)
                  {'key': 'add_down_payment_field', 'value': downPayment},
                if (videoId != null)
                  {'key': '_product_video_id', 'value': videoId.toString()},
              ],
            },
          );
        } catch (e) {
          print('WC API fallback error on update: $e');
        }

        emit(AddProductSuccess(productId: productId));
      } else {
        emit(const AddProductError(message: 'فشل في تحديث الاعلان'));
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

  void reset() {
    emit(const AddProductInitial());
  }
}
