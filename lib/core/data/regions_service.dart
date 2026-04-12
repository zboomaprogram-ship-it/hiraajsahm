import 'dart:async';
import 'package:dio/dio.dart';
import '../../core/config/app_config.dart';

/// Model for a Saudi region with its cities
class RegionModel {
  final String label; // Arabic display name
  final String name; // Slug/key
  final List<String> cities;

  const RegionModel({
    required this.label,
    required this.name,
    required this.cities,
  });

  factory RegionModel.fromJson(Map<String, dynamic> json) {
    List<String> cities = [];
    if (json['cities'] is List) {
      cities = (json['cities'] as List).map((e) => e.toString()).toList();
    } else if (json['sub_fields'] is List) {
      // ACF sub_fields structure
      for (final sf in json['sub_fields']) {
        if (sf['choices'] is Map) {
          cities.addAll(
            (sf['choices'] as Map).values.map((e) => e.toString()),
          );
        }
      }
    } else if (json['choices'] is Map) {
      // Direct ACF choices map (e.g. when fetching raw fields list)
      cities.addAll(
        (json['choices'] as Map).values.map((e) => e.toString()),
      );
    }

    String label = json['label']?.toString() ?? json['name']?.toString() ?? '';
    if (label.startsWith('مناطق ')) {
      label = label.replaceFirst('مناطق ', '').trim();
    }

    return RegionModel(
      label: label,
      name: json['name']?.toString() ?? '',
      cities: cities,
    );
  }
}

/// Singleton service for fetching Saudi regions/cities
/// Fetches from WordPress `/custom/v1/regions` with hardcoded fallback
class RegionsService {
  static final RegionsService _instance = RegionsService._internal();
  factory RegionsService() => _instance;
  RegionsService._internal();

  List<RegionModel>? _cachedRegions;

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  Completer<List<RegionModel>>? _fetchCompleter;

  /// Get all regions (fetches from API on first call, then cached)
  Future<List<RegionModel>> getRegions() async {
    if (_cachedRegions != null) return _cachedRegions!;
    
    if (_fetchCompleter != null) {
      return _fetchCompleter!.future;
    }

    _fetchCompleter = Completer<List<RegionModel>>();
    
    try {
      final siteUrl = AppConfig.baseUrl.replaceAll('/wp-json', '');
      final response = await _dio.get('$siteUrl/wp-json/custom/v1/regions');

      if (response.statusCode == 200 && response.data is List) {
        final data = response.data as List;
        _cachedRegions = data
            .map((e) => RegionModel.fromJson(e as Map<String, dynamic>))
            .where((r) => r.name != 'areas' && r.label.isNotEmpty && r.cities.isNotEmpty)
            .toList();
        
        if (_cachedRegions!.isNotEmpty) {
          _fetchCompleter!.complete(_cachedRegions);
          _fetchCompleter = null;
          return _cachedRegions!;
        }
      }
    } catch (e) {
      print('Error fetching regions: $e');
    }

    _cachedRegions = [];
    _fetchCompleter!.complete(_cachedRegions);
    _fetchCompleter = null;
    return _cachedRegions!;
  }

  /// Get region names for dropdown
  Future<List<String>> getRegionNames() async {
    final regions = await getRegions();
    return regions.map((r) => r.label).toList();
  }

  /// Get cities for a given region label
  Future<List<String>> getCitiesForRegion(String regionLabel) async {
    final regions = await getRegions();
    final region = regions.firstWhere(
      (r) => r.label == regionLabel,
      orElse: () => const RegionModel(label: '', name: '', cities: []),
    );
    return region.cities;
  }

  /// Get region label for a given city
  Future<String?> getRegionForCity(String city) async {
    final regions = await getRegions();
    for (final r in regions) {
      if (r.cities.contains(city)) return r.label;
    }
    return null;
  }

  /// Clear cache (e.g., on app restart)
  void clearCache() {
    _cachedRegions = null;
  }
}
