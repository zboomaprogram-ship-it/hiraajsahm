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

  /// Load categories using BOTH APIs:
  /// - Menu API for WordPress-controlled ordering
  /// - WC Categories API for correct product category IDs
  Future<void> loadCategories() async {
    if (state is CategoriesLoading) return;

    emit(const CategoriesLoading());

    try {
      // Fetch both APIs in parallel
      final results = await Future.wait([
        _cleanDio.get('https://hiraajsahm.com/wp-json/custom/v1/menu'),
        _cleanDio.get(
          'https://hiraajsahm.com/wp-json/wc/v3/products/categories',
          queryParameters: {
            'per_page': 100,
            'consumer_key': AppConfig.wcConsumerKey,
            'consumer_secret': AppConfig.wcConsumerSecret,
          },
        ),
      ]);

      final menuResponse = results[0];
      final wcResponse = results[1];

      if (wcResponse.statusCode == 200 && wcResponse.data is List) {
        // Build slug → WC CategoryModel map
        final wcCategories = (wcResponse.data as List)
            .map((json) => CategoryModel.fromJson(json))
            .where(
              (cat) =>
                  cat.slug != 'uncategorized' &&
                  cat.slug != 'packages' &&
                  cat.name != 'الباقات' &&
                  cat.id != 122 &&
                  cat.id != 15 &&
                  cat.slug.isNotEmpty,
            )
            .toList();

        // Build decoded slug → WC CategoryModel map
        final slugToWc = <String, CategoryModel>{};
        for (final wc in wcCategories) {
          try {
            final decodedSlug = Uri.decodeComponent(wc.slug);
            slugToWc[decodedSlug] = wc;
          } catch (_) {
            slugToWc[wc.slug] = wc;
          }
        }

        // If menu API succeeded, use its order
        if (menuResponse.statusCode == 200 && menuResponse.data is List) {
          final menuItems = menuResponse.data as List;
          final ordered = <CategoryModel>[];
          final seen = <int>{};

          for (final item in menuItems) {
            // Extract slug from the menu item URL (this is already decoded by Uri.parse)
            final menuSlug = _extractSlug(item['url'] ?? '');
            final menuParent = item['parent'] ?? 0;

            if (menuSlug.isNotEmpty && slugToWc.containsKey(menuSlug)) {
              final wc = slugToWc[menuSlug]!;
              if (!seen.contains(wc.id)) {
                // Use WC data but override parent from menu hierarchy
                final parentSlug = menuParent != 0
                    ? _findMenuSlugById(menuItems, menuParent)
                    : null;
                final wcParentId = parentSlug != null && slugToWc.containsKey(parentSlug)
                    ? slugToWc[parentSlug]!.id
                    : wc.parent;

                ordered.add(wc.copyWith(parent: wcParentId));
                seen.add(wc.id);
              }
            }
          }

          // Add any WC categories not in the menu (at the end)
          for (final wc in wcCategories) {
            if (!seen.contains(wc.id)) {
              ordered.add(wc);
              seen.add(wc.id);
            }
          }

          emit(CategoriesLoaded(categories: ordered));
        } else {
          // Menu API failed, use WC categories as-is
          emit(CategoriesLoaded(categories: wcCategories));
        }
      } else {
        _emitMockCategories();
      }
    } on DioException catch (_) {
      _emitMockCategories();
    } catch (e) {
      _emitMockCategories();
    }
  }

  /// Extract slug from a category URL
  String _extractSlug(String urlStr) {
    if (urlStr.isEmpty) return '';
    try {
      final uri = Uri.parse(urlStr);
      final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      if (segments.isNotEmpty) {
        // uri.pathSegments automatically decodes components, so we return it directly
        return segments.last;
      }
    } catch (_) {}
    return '';
  }

  /// Find the slug of a menu item by its menu ID
  String? _findMenuSlugById(List menuItems, int menuId) {
    for (final item in menuItems) {
      if (item['id'] == menuId) {
        return _extractSlug(item['url'] ?? '');
      }
    }
    return null;
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
