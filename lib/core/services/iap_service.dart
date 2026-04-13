import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_wrappers.dart';

/// Service to handle native Apple In-App Purchases
class IAPService {
  static final IAPService _instance = IAPService._internal();
  factory IAPService() => _instance;
  IAPService._internal();

  final InAppPurchase _iap = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;

  // Product IDs as defined in App Store Connect
  static const String tierBronze = 'tier_bronze_monthly';
  static const String tierSilver = 'tier_silver_monthly';
  static const String tierGold = 'tier_gold_monthly';
  static const String tierZabayeh = 'tier_zabayeh_monthly';

  static const List<String> _productIds = [
    tierBronze,
    tierSilver,
    tierGold,
    tierZabayeh,
  ];

  List<ProductDetails> _products = [];
  List<ProductDetails> get products => _products;

  // Callback for when a purchase is successful and needs verification
  Function(PurchaseDetails)? onPurchaseComplete;
  Function(String)? onError;

  Future<void> initialize() async {
    if (Platform.isAndroid) return; // Only for iOS as per plan

    final bool available = await _iap.isAvailable();
    if (!available) {
      debugPrint('⚠️ IAP is not available on this device');
      return;
    }

    // Subscribe to purchase updates
    _subscription = _iap.purchaseStream.listen(
      _listenToPurchaseUpdated,
      onDone: () => _subscription.cancel(),
      onError: (error) {
        debugPrint('❌ IAP Stream Error: $error');
        onError?.call(error.toString());
      },
    );

    await fetchProducts();
  }

  Future<void> fetchProducts() async {
    try {
      final ProductDetailsResponse response =
          await _iap.queryProductDetails(_productIds.toSet());

      if (response.notFoundIDs.isNotEmpty) {
        debugPrint('⚠️ Products not found: ${response.notFoundIDs}');
      }

      _products = response.productDetails;
      debugPrint('✅ Fetched ${_products.length} IAP products');
    } catch (e) {
      debugPrint('❌ Error fetching IAP products: $e');
    }
  }

  Future<void> buyProduct(ProductDetails product) async {
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);
    
    // We are using Auto-Renewable Subscriptions
    try {
      await _iap.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      debugPrint('❌ Error starting purchase: $e');
      onError?.call(e.toString());
    }
  }

  Future<void> restorePurchases() async {
    try {
      await _iap.restorePurchases();
    } catch (e) {
      debugPrint('❌ Error restoring purchases: $e');
      onError?.call(e.toString());
    }
  }

  void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) {
    purchaseDetailsList.forEach((PurchaseDetails purchaseDetails) async {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        // Show loading in UI
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          debugPrint('❌ Purchase Error: ${purchaseDetails.error}');
          onError?.call(purchaseDetails.error?.message ?? 'Purchase failed');
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
            purchaseDetails.status == PurchaseStatus.restored) {
          
          debugPrint('✅ Purchase Success/Restored: ${purchaseDetails.productID}');
          
          // Trigger the completion callback which will handle backend verification
          onPurchaseComplete?.call(purchaseDetails);
        }

        // Always finish the transaction
        if (purchaseDetails.pendingCompletePurchase) {
          await _iap.completePurchase(purchaseDetails);
        }
      }
    });
  }

  void dispose() {
    _subscription.cancel();
  }
}
