import 'package:flutter_test/flutter_test.dart';
import 'package:hiraajsahm/features/orders/data/models/order_model.dart';
import 'package:hiraajsahm/features/auth/data/models/user_model.dart';
import 'package:hiraajsahm/features/cart/presentation/cubit/cart_cubit.dart';
import 'package:hiraajsahm/features/messages/data/message_models.dart';
import 'package:hiraajsahm/features/shop/data/models/product_model.dart';
import 'package:hiraajsahm/features/shop/data/models/question_model.dart';
import 'package:hiraajsahm/features/vendor/presentation/cubit/add_product_cubit.dart';
import 'package:hiraajsahm/features/vendor/data/models/order_model.dart'
    as vendor_order;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('API model contracts', () {
    test('answered question is inferred from a non-empty answer', () {
      final question = QuestionModel.fromJson({
        'id': 7,
        'question': 'هل المنتج متوفر؟',
        'answer': 'نعم',
        'date': '2026-07-28',
      });

      expect(question.isAnswered, isTrue);
      expect(question.answer, 'نعم');
    });

    test('order preserves customer ownership and custom status', () {
      final order = OrderModel.fromJson({
        'id': 91,
        'customer_id': 74,
        'status': 'awaiting-vendor',
        'date_created': '2026-07-28T10:00:00',
        'total': '0.00',
        'billing': <String, dynamic>{},
        'shipping': <String, dynamic>{},
        'line_items': <dynamic>[],
      });

      expect(order.customerId, 74);
      expect(order.status, 'awaiting-vendor');
      expect(order.total, '0.00');
    });

    test('vendor order preserves buyer contact details', () {
      final order = vendor_order.OrderModel.fromJson({
        'id': 92,
        'customer_id': 74,
        'status': 'processing',
        'date_created': '2026-07-29T10:00:00',
        'total': '500.00',
        'billing': {
          'first_name': 'محمد',
          'last_name': 'علي',
          'phone': '0551234567',
          'email': 'buyer@example.com',
          'address_1': 'حي النخيل',
          'city': 'الرياض',
        },
        'line_items': <dynamic>[],
      });

      expect(order.customerId, 74);
      expect(order.buyerName, 'محمد علي');
      expect(order.buyerPhone, '0551234567');
      expect(order.buyerEmail, 'buyer@example.com');
      expect(order.buyerAddress, 'حي النخيل، الرياض');
    });

    test('malformed optional product fields do not remove core data', () {
      final product = ProductModel.fromJson({
        'id': 32653,
        'name': 'نعيم',
        'price': '0',
        'images': [
          {'src': 'https://example.com/image.jpg'},
        ],
      });

      expect(product.id, 32653);
      expect(product.price, '0');
      expect(product.images, hasLength(1));
    });

    test('product reads the server vendor phone fallback', () {
      final product = ProductModel.fromJson({
        'id': 32654,
        'name': 'منتج تجريبي',
        'price': '0',
        'vendor_phone': '0501234567',
        'store': {'id': 99, 'store_name': 'متجر البائع'},
      });

      expect(product.vendorPhone, '0501234567');
    });

    test('chat message preserves attachments and private price offers', () {
      final message = PrivateMessageModel.fromJson({
        'id': 44,
        'sender_id': 8,
        'sender_name': 'البائع',
        'message': 'صورة المنتج',
        'created_at': '2026-07-28T12:00:00Z',
        'attachment_url': 'https://example.com/photo.jpg',
        'attachment_mime': 'image/jpeg',
        'offer_amount': '1250.00',
        'offer_status': 'pending',
      });

      expect(message.hasAttachment, isTrue);
      expect(message.isImage, isTrue);
      expect(message.hasOffer, isTrue);
      expect(message.offerAmount, 1250);
      expect(message.offerStatus, 'pending');
    });

    test('conversation preserves its server-backed unread count', () {
      final conversation = ConversationModel.fromJson({
        'id': 61,
        'product_id': 51,
        'buyer_id': 7,
        'vendor_id': 8,
        'other_user_id': 8,
        'other_user_name': 'البائع',
        'unread_count': '4',
        'updated_at': '2026-07-29T10:00:00Z',
      });

      expect(conversation.unreadCount, 4);
    });

    test('legacy Dokan seller without package metadata gets Bronze access', () {
      final user = UserModel.fromJson({
        'id': 74,
        'email': 'seller@example.com',
        'display_name': 'البائع',
        'roles': ['seller'],
      });

      expect(user.isVendor, isTrue);
      expect(user.subscriptionPackId, 29026);
      expect(user.tier, UserTier.bronze);
    });

    test('direct WordPress package metadata selects the correct tier', () {
      final user = UserModel.fromJson({
        'id': 75,
        'email': 'gold@example.com',
        'display_name': 'البائع الذهبي',
        'role': 'seller',
        'product_package_id': '29030',
      });

      expect(user.subscriptionPackId, 29030);
      expect(user.tier, UserTier.gold);
    });

    test('daily quota accepts WordPress boolean and numeric values', () {
      final quota = AdQuota.fromJson({
        'pack_id': '29030',
        'daily_limit': 5,
        'ads_today': '2',
        'remaining_today': 3,
        'can_add': true,
      });

      expect(quota.packId, 29030);
      expect(quota.dailyLimit, 5);
      expect(quota.adsToday, 2);
      expect(quota.remainingToday, 3);
      expect(quota.canAdd, isTrue);
    });

    test('public auction bid is parsed from the comments API', () {
      final bid = QuestionModel.fromJson({
        'id': 81,
        'author_id': 8,
        'author': 'المزايد',
        'question': 'مزايدة: 900.00 ر.س',
        'date': '2026-07-28',
        'bid_amount': '900.00',
        'bid_status': 'accepted',
      });

      expect(bid.isBid, isTrue);
      expect(bid.authorId, 8);
      expect(bid.bidAmount, 900);
      expect(bid.bidStatus, 'accepted');
    });

    test(
      'cart keeps and restores an accepted public bid as one item',
      () async {
        SharedPreferences.setMockInitialValues({});
        final preferences = await SharedPreferences.getInstance();
        final cart = CartCubit(preferences: preferences);
        const product = ProductModel(id: 50, name: 'إعلان', price: '0');

        cart.addItem(product, quantity: 4);
        cart.addItem(
          product.copyWith(price: '900'),
          quantity: 3,
          bidCommentId: 81,
        );

        final state = cart.state as CartLoaded;
        expect(state.items.single.quantity, 1);
        expect(state.items.single.product.price, '900');
        expect(state.items.single.bidCommentId, 81);
        expect(state.totalItems, 1);
        expect(state.total, 900);
        await cart.close();

        final restored = CartCubit(preferences: preferences);
        final restoredState = restored.state as CartLoaded;
        expect(restoredState.items.single.product.id, 50);
        expect(restoredState.items.single.product.price, '900');
        expect(restoredState.items.single.quantity, 1);
        expect(restoredState.items.single.bidCommentId, 81);
        restored.clearCart();
        await restored.close();

        final afterClear = CartCubit(preferences: preferences);
        expect((afterClear.state as CartLoaded).items, isEmpty);
        await afterClear.close();
      },
    );

    test('cart keeps and restores an accepted private offer', () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final cart = CartCubit(preferences: preferences);
      const product = ProductModel(id: 51, name: 'إعلان خاص', price: '0');

      cart.addItem(
        product.copyWith(price: '750'),
        privateOfferMessageId: 91,
        privateConversationId: 61,
      );
      await cart.close();

      final restored = CartCubit(preferences: preferences);
      final item = (restored.state as CartLoaded).items.single;
      expect(item.product.price, '750');
      expect(item.quantity, 1);
      expect(item.privateOfferMessageId, 91);
      expect(item.privateConversationId, 61);
      restored.clearCart();
      await restored.close();
    });
  });
}
