import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/services/favorites_service.dart';
import '../../../../core/theme/colors.dart';
import '../../data/models/product_model.dart';
import '../cubit/products_cubit.dart';
import '../widgets/product_card.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    FavoritesService.instance.productIds.addListener(_reload);
    _load();
  }

  Future<void> _load() async {
    await FavoritesService.instance.load(sl<Dio>(), force: true);
    if (mounted) setState(() => _loading = false);
  }

  void _reload() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    FavoritesService.instance.productIds.removeListener(_reload);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ids = FavoritesService.instance.productIds.value.toList();
    return Scaffold(
      appBar: AppBar(title: const Text('المفضلة')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ids.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.favorite_border_rounded,
                    size: 72,
                    color: AppColors.textSecondary,
                  ),
                  SizedBox(height: 16),
                  Text('لا توجد إعلانات في المفضلة'),
                ],
              ),
            )
          : FutureBuilder<List<ProductModel?>>(
              future: Future.wait(
                ids.map(context.read<ProductsCubit>().getProductById),
              ),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final products = snapshot.data!
                    .whereType<ProductModel>()
                    .toList();
                return RefreshIndicator(
                  onRefresh: _load,
                  child: GridView.builder(
                    padding: EdgeInsets.all(16.w),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: MediaQuery.sizeOf(context).width >= 600
                          ? 3
                          : 2,
                      childAspectRatio: .68,
                      crossAxisSpacing: 12.w,
                      mainAxisSpacing: 12.h,
                    ),
                    itemCount: products.length,
                    itemBuilder: (_, index) =>
                        ProductCard(product: products[index]),
                  ),
                );
              },
            ),
    );
  }
}
