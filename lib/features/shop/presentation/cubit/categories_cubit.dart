import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:dio/dio.dart';
import '../../../../core/config/app_config.dart';
import '../../data/models/category_model.dart';

// ============ CATEGORIES STATES ============
abstract class CategoriesState extends Equatable {
  const CategoriesState();

  @override
  List<Object?> get props => [];
}

class CategoriesInitial extends CategoriesState {
  const CategoriesInitial();
}

class CategoriesLoading extends CategoriesState {
  const CategoriesLoading();
}

class CategoriesLoaded extends CategoriesState {
  final List<CategoryModel> categories;

  const CategoriesLoaded({required this.categories});

  @override
  List<Object?> get props => [categories];
}

class CategoriesError extends CategoriesState {
  final String message;

  const CategoriesError({required this.message});

  @override
  List<Object?> get props => [message];
}

// ============ CATEGORIES CUBIT ============
class CategoriesCubit extends Cubit<CategoriesState> {
  late final Dio _cleanDio;

  CategoriesCubit() : super(const CategoriesInitial()) {
    _cleanDio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );
  }

  /// Load categories from API
  Future<void> loadCategories() async {
    if (state is CategoriesLoading) return;

    emit(const CategoriesLoading());

    try {
      const fullUrl =
          'https://hiraajsahm.com/wp-json/wc/v3/products/categories';

      final response = await _cleanDio.get(
        fullUrl,
        queryParameters: {
          'per_page': 100,
          'hide_empty': false, // CRITICAL: Show all categories even if empty
          'parent': 0, // Only top-level categories
          'consumer_key': AppConfig.wcConsumerKey,
          'consumer_secret': AppConfig.wcConsumerSecret,
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        final categories = data
            .map((json) => CategoryModel.fromJson(json))
            .where(
              (cat) =>
                  cat.slug != 'uncategorized' &&
                  cat.slug != 'packages' &&
                  cat.name != 'الباقات' &&
                  cat.id != 122,
            ) // Exclude uncategorized and packages categories
            .toList();

        emit(CategoriesLoaded(categories: categories));
      } else {
        _emitMockCategories();
      }
    } on DioException catch (_) {
      _emitMockCategories();
    } catch (e) {
      _emitMockCategories();
    }
  }

  /// Fallback mock categories
  void _emitMockCategories() {
    final mockCategories = [
      CategoryModel(
        id: 15,
        name: 'الإبل',
        slug: 'camels',
        count: 10,
        imageUrl: null,
      ),
      CategoryModel(
        id: 16,
        name: 'الغنم',
        slug: 'sheep',
        count: 8,
        imageUrl: null,
      ),
      CategoryModel(
        id: 17,
        name: 'الطيور',
        slug: 'birds',
        count: 5,
        imageUrl: null,
      ),
      CategoryModel(
        id: 18,
        name: 'الذبائح',
        slug: 'slaughtered',
        count: 3,
        imageUrl: null,
      ),
      CategoryModel(
        id: 19,
        name: 'المستلزمات',
        slug: 'equipment',
        count: 6,
        imageUrl: null,
      ),
    ];
    emit(CategoriesLoaded(categories: mockCategories));
  }
}
