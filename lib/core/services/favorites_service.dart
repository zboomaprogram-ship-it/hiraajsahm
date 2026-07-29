import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';

class FavoritesService {
  FavoritesService._();

  static final FavoritesService instance = FavoritesService._();
  static const _cacheKey = 'favorite_product_ids_v1';

  final ValueNotifier<Set<int>> productIds = ValueNotifier(<int>{});
  bool _loaded = false;

  bool contains(int productId) => productIds.value.contains(productId);

  Future<void> load(Dio dio, {bool force = false}) async {
    if (_loaded && !force) return;
    final prefs = await SharedPreferences.getInstance();
    final local = (prefs.getStringList(_cacheKey) ?? const [])
        .map(int.tryParse)
        .whereType<int>()
        .where((id) => id > 0)
        .toSet();
    productIds.value = local;
    try {
      final response = await dio.get(
        '${AppConfig.baseUrl}/custom/v1/favorites',
      );
      final data = response.data is Map ? response.data as Map : const {};
      final remote = (data['product_ids'] as List<dynamic>? ?? const [])
          .map((id) => int.tryParse(id.toString()))
          .whereType<int>()
          .toSet();
      final merged = {...remote, ...local};
      productIds.value = merged;
      await _persist();
      for (final id in local.difference(remote)) {
        await dio.post(
          '${AppConfig.baseUrl}/custom/v1/favorites',
          data: {'product_id': id, 'favorite': true},
        );
      }
    } catch (_) {
      // Guests and offline users keep a local favorites list.
    }
    _loaded = true;
  }

  Future<bool> toggle(Dio dio, int productId) async {
    final next = {...productIds.value};
    final favorite = !next.contains(productId);
    favorite ? next.add(productId) : next.remove(productId);
    productIds.value = next;
    await _persist();
    try {
      await dio.post(
        '${AppConfig.baseUrl}/custom/v1/favorites',
        data: {'product_id': productId, 'favorite': favorite},
      );
    } catch (_) {
      // The optimistic local change is synchronized after the next login/load.
    }
    return favorite;
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _cacheKey,
      productIds.value.map((id) => id.toString()).toList(),
    );
  }
}
