import 'package:dio/dio.dart';

import '../../../core/config/app_config.dart';
import 'message_models.dart';

class MessageService {
  final Dio _dio;

  MessageService(this._dio);

  Future<List<ConversationModel>> getConversations() async {
    final response = await _dio.get(
      '${AppConfig.conversationsEndpoint}/conversations',
    );
    final data = response.data as List<dynamic>? ?? const [];
    return data
        .map(
          (item) => ConversationModel.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .where((item) => item.id > 0)
        .toList();
  }

  Future<ConversationModel?> getConversation(int conversationId) async {
    final conversations = await getConversations();
    for (final conversation in conversations) {
      if (conversation.id == conversationId) return conversation;
    }
    return null;
  }

  Future<int> startConversation({
    required int vendorId,
    required int productId,
  }) async {
    final response = await _dio.post(
      '${AppConfig.conversationsEndpoint}/start',
      data: {'vendor_id': vendorId, 'product_id': productId},
    );
    return int.tryParse(response.data?['conversation_id']?.toString() ?? '') ??
        0;
  }

  Future<List<PrivateMessageModel>> getMessages(
    int conversationId, {
    int page = 1,
    int perPage = 100,
  }) async {
    final response = await _dio.get(
      '${AppConfig.conversationsEndpoint}/$conversationId',
      queryParameters: {'page': page, 'per_page': perPage},
    );
    final data = response.data as List<dynamic>? ?? const [];
    return data
        .map(
          (item) => PrivateMessageModel.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  Future<void> sendMessage(int conversationId, String message) async {
    await _dio.post(
      '${AppConfig.conversationsEndpoint}/$conversationId',
      data: {'message': message},
    );
  }

  Future<void> sendAttachment(
    int conversationId, {
    required String filePath,
    required String fileName,
    String message = '',
  }) async {
    await _dio.post(
      '${AppConfig.conversationsEndpoint}/$conversationId',
      data: FormData.fromMap({
        'message': message,
        'attachment': await MultipartFile.fromFile(
          filePath,
          filename: fileName,
        ),
      }),
    );
  }

  Future<void> sendPrivateOffer(int conversationId, double amount) async {
    await _dio.post(
      '${AppConfig.conversationsEndpoint}/$conversationId/offer',
      data: {'amount': amount.toStringAsFixed(2)},
    );
  }

  Future<AcceptedOfferModel> acceptPrivateOffer(
    int conversationId,
    int messageId,
  ) async {
    final response = await _dio.post(
      '${AppConfig.conversationsEndpoint}/$conversationId/offers/$messageId/accept',
    );
    return AcceptedOfferModel.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }
}
