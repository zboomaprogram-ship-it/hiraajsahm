import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:dio/dio.dart';
import '../../../../core/config/app_config.dart';
import '../../data/models/vendor_stats_model.dart';

// ============ DASHBOARD STATES ============
abstract class VendorDashboardState extends Equatable {
  const VendorDashboardState();

  @override
  List<Object?> get props => [];
}

class VendorDashboardInitial extends VendorDashboardState {
  const VendorDashboardInitial();
}

class VendorDashboardLoading extends VendorDashboardState {
  const VendorDashboardLoading();
}

class VendorDashboardLoaded extends VendorDashboardState {
  final VendorStatsModel stats;

  const VendorDashboardLoaded({required this.stats});

  VendorDashboardLoaded copyWith({VendorStatsModel? stats}) {
    return VendorDashboardLoaded(stats: stats ?? this.stats);
  }

  @override
  List<Object?> get props => [stats];
}

class VendorDashboardError extends VendorDashboardState {
  final String message;

  const VendorDashboardError({required this.message});

  @override
  List<Object?> get props => [message];
}

// ============ VENDOR DASHBOARD CUBIT ============
class VendorDashboardCubit extends Cubit<VendorDashboardState> {
  final Dio _dio;

  VendorDashboardCubit({required Dio dio})
    : _dio = dio,
      super(const VendorDashboardInitial());

  /// Load dashboard data
  Future<void> loadDashboard() async {
    emit(const VendorDashboardLoading());

    try {
      // Execute requests in parallel
      final summaryFuture = _dio.get(
        AppConfig.dokanReportsEndpoint,
        options: Options(responseType: ResponseType.plain),
      );

      // Fetch products count (using header X-WP-Total)
      final productsFuture = _dio.get(
        '/dokan/v1/products',
        queryParameters: {'per_page': 1},
      );

      final responses = await Future.wait([
        summaryFuture,
        productsFuture.catchError(
          (e) => Response(
            requestOptions: RequestOptions(path: ''),
            statusCode: 404,
          ),
        ),
      ]);

      final summaryResponse = responses[0];
      final productsResponse = responses[1];

      if (summaryResponse.statusCode == 200) {
        // Parse in background to avoid freezing UI
        var stats = await compute(
          _parseDashboardStats,
          summaryResponse.data.toString(),
        );

        // Update Total Products Count
        if (productsResponse.statusCode == 200) {
          final totalHeader =
              productsResponse.headers.value('x-wp-total') ??
              productsResponse.headers.value('X-WP-Total');
          if (totalHeader != null) {
            final totalProducts = int.tryParse(totalHeader) ?? 0;
            if (totalProducts > 0) {
              stats = stats.copyWith(totalProducts: totalProducts);
            }
          }
        }

        // Fix Products Sold if 0 (fallback to orders count)
        if (stats.productsSold == 0 && stats.ordersCount > 0) {
          stats = stats.copyWith(productsSold: stats.ordersCount);
        }

        emit(VendorDashboardLoaded(stats: stats));
      } else {
        emit(const VendorDashboardError(message: 'Failed to load dashboard'));
      }
    } on DioException catch (e) {
      emit(
        VendorDashboardError(
          message: e.response?.data?['message'] ?? 'Network error',
        ),
      );
    } catch (e) {
      emit(VendorDashboardError(message: e.toString()));
    }
  }

  /// Refresh dashboard
  Future<void> refresh() async {
    await loadDashboard();
  }
}

/// Top-level function for background parsing
VendorStatsModel _parseDashboardStats(String jsonString) {
  final data = jsonDecode(jsonString);
  return VendorStatsModel.fromJson(data);
}
