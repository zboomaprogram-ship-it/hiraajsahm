import 'dart:convert';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../shop/data/models/product_model.dart';

// ============ CART ITEM MODEL ============
class CartItem extends Equatable {
  final ProductModel product;
  final int quantity;
  final bool isDeposit;
  final double depositPercentage;
  final double? customPrice;
  final int? privateOfferMessageId;
  final int? privateConversationId;
  final int? bidCommentId;

  CartItem({
    required this.product,
    this.quantity = 1,
    this.isDeposit = false,
    double? depositPercentage,
    this.customPrice,
    this.privateOfferMessageId,
    this.privateConversationId,
    this.bidCommentId,
  }) : depositPercentage = depositPercentage ?? product.depositPercentage;

  CartItem copyWith({
    ProductModel? product,
    int? quantity,
    bool? isDeposit,
    double? depositPercentage,
    double? customPrice,
    int? privateOfferMessageId,
    int? privateConversationId,
    int? bidCommentId,
  }) {
    return CartItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      isDeposit: isDeposit ?? this.isDeposit,
      depositPercentage: depositPercentage ?? this.depositPercentage,
      customPrice: customPrice ?? this.customPrice,
      privateOfferMessageId:
          privateOfferMessageId ?? this.privateOfferMessageId,
      privateConversationId:
          privateConversationId ?? this.privateConversationId,
      bidCommentId: bidCommentId ?? this.bidCommentId,
    );
  }

  double get unitPrice {
    if (customPrice != null && customPrice! > 0) {
      return customPrice!;
    }
    return double.tryParse(product.price) ?? 0.0;
  }

  double get totalPrice {
    final price = unitPrice;
    if (isDeposit) {
      return (price * depositPercentage) * quantity;
    }
    return price * quantity;
  }

  @override
  List<Object?> get props => [
    product,
    quantity,
    isDeposit,
    depositPercentage,
    customPrice,
    privateOfferMessageId,
    privateConversationId,
    bidCommentId,
  ];
}

// ============ CART STATES ============
abstract class CartState extends Equatable {
  const CartState();

  @override
  List<Object?> get props => [];
}

class CartInitial extends CartState {
  const CartInitial();
}

class CartLoaded extends CartState {
  final List<CartItem> items;

  const CartLoaded({this.items = const []});

  CartLoaded copyWith({List<CartItem>? items}) {
    return CartLoaded(items: items ?? this.items);
  }

  int get totalItems => items.length;

  double get subtotal => items.fold(0.0, (sum, item) => sum + item.totalPrice);

  double get shipping => 0; // Transport arranged via separate service

  double get total => subtotal + shipping;

  bool get isEmpty => items.isEmpty;

  @override
  List<Object?> get props => [items];
}

/// State emitted when user tries to add a second item to the cart
class CartReplaceConfirmation extends CartState {
  final ProductModel pendingProduct;
  final int pendingQuantity;
  final bool pendingIsDeposit;
  final double pendingDepositPercentage;

  const CartReplaceConfirmation({
    required this.pendingProduct,
    this.pendingQuantity = 1,
    this.pendingIsDeposit = false,
    required this.pendingDepositPercentage,
  });

  @override
  List<Object?> get props => [
    pendingProduct.id,
    pendingQuantity,
    pendingIsDeposit,
    pendingDepositPercentage,
  ];
}

// ============ CART CUBIT ============
class CartCubit extends Cubit<CartState> {
  static const _storageKey = 'persisted_marketplace_cart_v1';
  final SharedPreferences _preferences;

  CartCubit({required SharedPreferences preferences})
    : _preferences = preferences,
      super(CartLoaded(items: _restoreItems(preferences)));

  // Cached state for after confirmation
  List<CartItem> _lastItems = [];

  static List<CartItem> _restoreItems(SharedPreferences preferences) {
    final encoded = preferences.getString(_storageKey);
    if (encoded == null || encoded.isEmpty) return const [];
    try {
      final data = Map<String, dynamic>.from(jsonDecode(encoded) as Map);
      final productData = Map<String, dynamic>.from(data['product'] as Map);
      final product = ProductModel.fromJson(productData);
      if (product.id <= 0) return const [];
      return [
        CartItem(
          product: product,
          quantity: 1,
          isDeposit: data['is_deposit'] == true,
          depositPercentage:
              double.tryParse(data['deposit_percentage']?.toString() ?? '') ??
              product.depositPercentage,
          customPrice: double.tryParse(data['custom_price']?.toString() ?? ''),
          privateOfferMessageId: int.tryParse(
            data['private_offer_message_id']?.toString() ?? '',
          ),
          privateConversationId: int.tryParse(
            data['private_conversation_id']?.toString() ?? '',
          ),
          bidCommentId: int.tryParse(data['bid_comment_id']?.toString() ?? ''),
        ),
      ];
    } catch (_) {
      preferences.remove(_storageKey);
      return const [];
    }
  }

  void _emitLoaded(List<CartItem> items) {
    if (items.isEmpty) {
      _preferences.remove(_storageKey);
    } else {
      final item = items.first;
      final product = item.product;
      _preferences.setString(
        _storageKey,
        jsonEncode({
          'product': {
            ...product.toJson(),
            'permalink': product.permalink,
            'purchasable': product.purchasable,
            'virtual': product.virtual,
            'stock_status': product.stockStatus,
            'stock_quantity': product.stockQuantity,
            'manage_stock': product.manageStock,
            'store': {
              'id': product.vendorId,
              'store_name': product.vendorName,
              'phone': product.vendorPhone,
              'gravatar': product.vendorAvatar,
              'vendor_tier': product.vendorTier,
            },
          },
          'is_deposit': item.isDeposit,
          'deposit_percentage': item.depositPercentage,
          'custom_price': item.customPrice,
          'private_offer_message_id': item.privateOfferMessageId,
          'private_conversation_id': item.privateConversationId,
          'bid_comment_id': item.bidCommentId,
        }),
      );
    }
    emit(CartLoaded(items: items));
  }

  /// Add item to cart (enforces single-item rule for animals)
  void addItem(
    ProductModel product, {
    int quantity = 1,
    bool isDeposit = false,
    double? depositPercentage,
    int? privateOfferMessageId,
    int? privateConversationId,
    int? bidCommentId,
  }) {
    final currentState = state;

    // If currently in confirmation state, ignore
    if (currentState is CartReplaceConfirmation) return;

    if (currentState is CartLoaded) {
      _lastItems = currentState.items;

      // BUSINESS RULE: Single item cart for animals
      if (currentState.items.isNotEmpty) {
        // Check if it's the same product (allow quantity/mode update)
        final existingIndex = currentState.items.indexWhere(
          (item) => item.product.id == product.id,
        );

        if (existingIndex >= 0) {
          // Marketplace listings are single items. Re-adding the same product
          // updates its price/mode/offer metadata without increasing quantity.
          final updatedItems = List<CartItem>.from(currentState.items);
          final existingItem = updatedItems[existingIndex];
          final hasNewAgreement =
              privateOfferMessageId != null || bidCommentId != null;
          final hasStoredAgreement =
              existingItem.privateOfferMessageId != null ||
              existingItem.bidCommentId != null;
          updatedItems[existingIndex] = CartItem(
            product: hasNewAgreement || !hasStoredAgreement
                ? product
                : existingItem.product,
            quantity: 1,
            isDeposit: hasStoredAgreement && !hasNewAgreement
                ? existingItem.isDeposit
                : isDeposit,
            depositPercentage: hasStoredAgreement && !hasNewAgreement
                ? existingItem.depositPercentage
                : (depositPercentage ?? product.depositPercentage),
            privateOfferMessageId: hasNewAgreement
                ? privateOfferMessageId
                : existingItem.privateOfferMessageId,
            privateConversationId: hasNewAgreement
                ? privateConversationId
                : existingItem.privateConversationId,
            bidCommentId: hasNewAgreement
                ? bidCommentId
                : existingItem.bidCommentId,
          );
          _emitLoaded(updatedItems);
        } else {
          // Different product - require confirmation
          emit(
            CartReplaceConfirmation(
              pendingProduct: product,
              pendingQuantity: quantity,
              pendingIsDeposit: isDeposit,
              pendingDepositPercentage:
                  depositPercentage ?? product.depositPercentage,
            ),
          );
        }
        return;
      }

      // Cart is empty, add normally
      _emitLoaded([
        CartItem(
          product: product,
          quantity: 1,
          isDeposit: isDeposit,
          depositPercentage: depositPercentage ?? product.depositPercentage,
          privateOfferMessageId: privateOfferMessageId,
          privateConversationId: privateConversationId,
          bidCommentId: bidCommentId,
        ),
      ]);
    }
  }

  /// Atomically replaces the cart with an accepted marketplace agreement.
  /// This keeps the accepted item persisted even if navigation is interrupted.
  void replaceWithAgreement(
    ProductModel product, {
    int? privateOfferMessageId,
    int? privateConversationId,
    int? bidCommentId,
  }) {
    _emitLoaded([
      CartItem(
        product: product,
        quantity: 1,
        isDeposit: false,
        depositPercentage: product.depositPercentage,
        privateOfferMessageId: privateOfferMessageId,
        privateConversationId: privateConversationId,
        bidCommentId: bidCommentId,
      ),
    ]);
  }

  /// Confirm cart replacement (user accepted to clear and add new item)
  void confirmReplace() {
    final currentState = state;
    if (currentState is CartReplaceConfirmation) {
      _emitLoaded([
        CartItem(
          product: currentState.pendingProduct,
          quantity: 1,
          isDeposit: currentState.pendingIsDeposit,
          depositPercentage: currentState.pendingDepositPercentage,
        ),
      ]);
    }
  }

  /// Cancel cart replacement (user rejected)
  void cancelReplace() {
    if (state is CartReplaceConfirmation) {
      _emitLoaded(_lastItems);
    }
  }

  /// Remove item from cart
  void removeItem(int productId) {
    final currentState = state;
    if (currentState is CartLoaded) {
      final updatedItems = currentState.items
          .where((item) => item.product.id != productId)
          .toList();
      _emitLoaded(updatedItems);
    }
  }

  /// Marketplace products are unique listings, so their quantity is fixed at 1.
  void updateQuantity(int productId, int quantity) {
    final currentState = state;
    if (currentState is CartLoaded) {
      if (quantity <= 0) {
        removeItem(productId);
        return;
      }

      final updatedItems = currentState.items.map((item) {
        if (item.product.id == productId) {
          return item.copyWith(quantity: 1);
        }
        return item;
      }).toList();

      _emitLoaded(updatedItems);
    }
  }

  /// Update custom entered price for a product (nullable to reset to original price)
  void updateCustomPrice(int productId, double? price) {
    final currentState = state;
    if (currentState is CartLoaded) {
      final updatedItems = currentState.items.map((item) {
        if (item.product.id == productId) {
          // If price is null or 0, clear customPrice override
          final newPrice = (price != null && price > 0) ? price : null;
          return CartItem(
            product: item.product,
            quantity: item.quantity,
            isDeposit: item.isDeposit,
            depositPercentage: item.depositPercentage,
            customPrice: newPrice,
            privateOfferMessageId: item.privateOfferMessageId,
            privateConversationId: item.privateConversationId,
            bidCommentId: item.bidCommentId,
          );
        }
        return item;
      }).toList();
      _emitLoaded(updatedItems);
    }
  }

  /// Clear all items from cart
  void clearCart() {
    _emitLoaded(const []);
  }

  /// Check if product is in cart
  bool isInCart(int productId) {
    final currentState = state;
    if (currentState is CartLoaded) {
      return currentState.items.any((item) => item.product.id == productId);
    }
    return false;
  }

  /// Get item quantity in cart
  int getQuantity(int productId) {
    final currentState = state;
    if (currentState is CartLoaded) {
      final item = currentState.items.firstWhere(
        (item) => item.product.id == productId,
        orElse: () => CartItem(
          product: const ProductModel(id: 0, name: '', price: '0'),
          quantity: 0,
        ),
      );
      return item.quantity;
    }
    return 0;
  }
}
