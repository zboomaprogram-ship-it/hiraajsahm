import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../shop/data/models/product_model.dart';

// ============ CART ITEM MODEL ============
class CartItem extends Equatable {
  final ProductModel product;
  final int quantity;
  final bool isDeposit;
  final double depositPercentage;

  const CartItem({
    required this.product,
    this.quantity = 1,
    this.isDeposit = false,
    this.depositPercentage = 0.10,
  });

  CartItem copyWith({
    int? quantity,
    bool? isDeposit,
    double? depositPercentage,
  }) {
    return CartItem(
      product: product,
      quantity: quantity ?? this.quantity,
      isDeposit: isDeposit ?? this.isDeposit,
      depositPercentage: depositPercentage ?? this.depositPercentage,
    );
  }

  double get totalPrice {
    final price = double.tryParse(product.price) ?? 0;
    if (isDeposit) {
      return (price * depositPercentage) * quantity;
    }
    return price * quantity;
  }

  @override
  List<Object?> get props => [
    product.id,
    quantity,
    isDeposit,
    depositPercentage,
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

  int get totalItems => items.fold(0, (sum, item) => sum + item.quantity);

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

  const CartReplaceConfirmation({
    required this.pendingProduct,
    this.pendingQuantity = 1,
    this.pendingIsDeposit = false,
  });

  @override
  List<Object?> get props => [
    pendingProduct.id,
    pendingQuantity,
    pendingIsDeposit,
  ];
}

// ============ CART CUBIT ============
class CartCubit extends Cubit<CartState> {
  CartCubit() : super(const CartLoaded(items: []));

  // Cached state for after confirmation
  List<CartItem> _lastItems = [];

  /// Add item to cart (enforces single-item rule for animals)
  void addItem(
    ProductModel product, {
    int quantity = 1,
    bool isDeposit = false,
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
          // Same product, update quantity and mode
          final updatedItems = List<CartItem>.from(currentState.items);
          final existingItem = updatedItems[existingIndex];
          // Update mode to the new selection (e.g. user switched from Buy Now to Inspection)
          updatedItems[existingIndex] = existingItem.copyWith(
            quantity: existingItem.quantity + quantity,
            isDeposit: isDeposit,
          );
          emit(CartLoaded(items: updatedItems));
        } else {
          // Different product - require confirmation
          emit(
            CartReplaceConfirmation(
              pendingProduct: product,
              pendingQuantity: quantity,
              pendingIsDeposit: isDeposit,
            ),
          );
        }
        return;
      }

      // Cart is empty, add normally
      emit(
        CartLoaded(
          items: [
            CartItem(
              product: product,
              quantity: quantity,
              isDeposit: isDeposit,
            ),
          ],
        ),
      );
    }
  }

  /// Confirm cart replacement (user accepted to clear and add new item)
  void confirmReplace() {
    final currentState = state;
    if (currentState is CartReplaceConfirmation) {
      emit(
        CartLoaded(
          items: [
            CartItem(
              product: currentState.pendingProduct,
              quantity: currentState.pendingQuantity,
              isDeposit: currentState.pendingIsDeposit,
            ),
          ],
        ),
      );
    }
  }

  /// Cancel cart replacement (user rejected)
  void cancelReplace() {
    if (state is CartReplaceConfirmation) {
      emit(CartLoaded(items: _lastItems));
    }
  }

  /// Remove item from cart
  void removeItem(int productId) {
    final currentState = state;
    if (currentState is CartLoaded) {
      final updatedItems = currentState.items
          .where((item) => item.product.id != productId)
          .toList();
      emit(CartLoaded(items: updatedItems));
    }
  }

  /// Update item quantity
  void updateQuantity(int productId, int quantity) {
    final currentState = state;
    if (currentState is CartLoaded) {
      if (quantity <= 0) {
        removeItem(productId);
        return;
      }

      final updatedItems = currentState.items.map((item) {
        if (item.product.id == productId) {
          return item.copyWith(quantity: quantity);
        }
        return item;
      }).toList();

      emit(CartLoaded(items: updatedItems));
    }
  }

  /// Increment item quantity
  void incrementQuantity(int productId) {
    final currentState = state;
    if (currentState is CartLoaded) {
      final item = currentState.items.firstWhere(
        (item) => item.product.id == productId,
        orElse: () => const CartItem(
          product: ProductModel(id: 0, name: '', price: '0'),
        ),
      );
      if (item.product.id != 0) {
        updateQuantity(productId, item.quantity + 1);
      }
    }
  }

  /// Decrement item quantity
  void decrementQuantity(int productId) {
    final currentState = state;
    if (currentState is CartLoaded) {
      final item = currentState.items.firstWhere(
        (item) => item.product.id == productId,
        orElse: () => const CartItem(
          product: ProductModel(id: 0, name: '', price: '0'),
        ),
      );
      if (item.product.id != 0) {
        updateQuantity(productId, item.quantity - 1);
      }
    }
  }

  /// Clear all items from cart
  void clearCart() {
    emit(const CartLoaded(items: []));
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
        orElse: () => const CartItem(
          product: ProductModel(id: 0, name: '', price: '0'),
          quantity: 0,
        ),
      );
      return item.quantity;
    }
    return 0;
  }
}
