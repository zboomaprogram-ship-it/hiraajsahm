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
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  // Product IDs as defined in App Store Connect
  // Only include IDs that ACTUALLY exist in App Store Connect
  static const String tierSilver = 'tier_silver_monthly';
  static const String tierZabayeh = 'tier_zabayeh_monthly';

  // Keep constants for mapping but these don't exist in App Store Connect
  static const String tierBronze = 'tier_bronze_monthly';
  static const String tierGold = 'tier_gold_monthly';
  
  // List of all valid App Store Product IDs
  static const List<String> _productIds = [
    tierSilver,
    tierZabayeh,
    tierGold,
  ];


  List<ProductDetails> _products = [];
  List<ProductDetails> get products => _products;

  // Callback for when a purchase is successful and needs verification
  Function(PurchaseDetails)? onPurchaseComplete;
  Function(String)? onError;

  Future<void> initialize() async {
    if (Platform.isAndroid) return; // Only for iOS
    if (_isInitialized) {
      debugPrint('ℹ️ IAP already initialized with ${_products.length} products');
      return;
    }

    debugPrint('🔄 IAP: Starting initialization...');

    final bool available = await _iap.isAvailable();
    if (!available) {
      debugPrint('⚠️ IAP is not available on this device');
      onError?.call('متجر التطبيقات غير متاح على هذا الجهاز');
      return;
    }

    debugPrint('✅ IAP: Store is available');

    // Subscribe to purchase updates
    _subscription = _iap.purchaseStream.listen(
      _listenToPurchaseUpdated,
      onDone: () => _subscription?.cancel(),
      onError: (error) {
        debugPrint('❌ IAP Stream Error: $error');
        onError?.call(error.toString());
      },
    );

    await fetchProducts();
    _isInitialized = true;
    debugPrint('✅ IAP: Initialization complete');
  }

  Future<void> fetchProducts() async {
    try {
      debugPrint('🔄 IAP: Fetching products: $_productIds');
      final ProductDetailsResponse response =
          await _iap.queryProductDetails(_productIds.toSet());

      if (response.notFoundIDs.isNotEmpty) {
        debugPrint('⚠️ IAP: Products NOT found in App Store Connect: ${response.notFoundIDs}');
        debugPrint('   ↳ Make sure these product IDs exist in App Store Connect');
        debugPrint('   ↳ Subscriptions must be submitted with a new app version first');
      }

      if (response.error != null) {
        debugPrint('❌ IAP: Query error: ${response.error}');
      }

      _products = response.productDetails;
      debugPrint('✅ IAP: Fetched ${_products.length} products:');
      for (final p in _products) {
        debugPrint('   ↳ ${p.id} — ${p.title} — ${p.price}');
      }
    } catch (e) {
      debugPrint('❌ IAP: Error fetching products: $e');
    }
  }

  Future<void> buyProduct(ProductDetails product) async {
    debugPrint('🔄 IAP: Starting purchase for ${product.id} (${product.price})');
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);
    
    // Auto-Renewable Subscriptions use buyNonConsumable
    try {
      final bool success = await _iap.buyNonConsumable(purchaseParam: purchaseParam);
      debugPrint('🔄 IAP: buyNonConsumable returned: $success');
    } catch (e) {
      debugPrint('❌ IAP: Error starting purchase: $e');
      onError?.call(e.toString());
    }
  }

  Future<void> restorePurchases() async {
    debugPrint('🔄 IAP: Restoring purchases...');
    try {
      await _iap.restorePurchases();
    } catch (e) {
      debugPrint('❌ IAP: Error restoring purchases: $e');
      onError?.call(e.toString());
    }
  }

  void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) {
    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      debugPrint('🔔 IAP: Purchase update - status: ${purchaseDetails.status}, '
          'product: ${purchaseDetails.productID}');

      if (purchaseDetails.status == PurchaseStatus.pending) {
        debugPrint('⏳ IAP: Purchase pending...');
      } else if (purchaseDetails.status == PurchaseStatus.canceled) {
        debugPrint('🚫 IAP: Purchase canceled by user');
        onError?.call('تم إلغاء عملية الشراء');
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          debugPrint('❌ IAP: Purchase Error: ${purchaseDetails.error?.code} - '
              '${purchaseDetails.error?.message}');
          onError?.call(purchaseDetails.error?.message ?? 'فشلت عملية الشراء');
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
            purchaseDetails.status == PurchaseStatus.restored) {
          
          debugPrint('✅ IAP: Purchase Success/Restored: ${purchaseDetails.productID}');
          debugPrint('   ↳ Server verification data available: '
              '${purchaseDetails.verificationData.serverVerificationData.isNotEmpty}');
          
          // Trigger the completion callback which will handle backend verification
          onPurchaseComplete?.call(purchaseDetails);
        }

        // Always finish the transaction
        if (purchaseDetails.pendingCompletePurchase) {
          debugPrint('🔄 IAP: Completing purchase...');
          _iap.completePurchase(purchaseDetails);
        }
      }
    }
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _isInitialized = false;
  }
}
