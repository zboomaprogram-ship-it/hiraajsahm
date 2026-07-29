class ConversationModel {
  final int id;
  final int productId;
  final String productName;
  final int buyerId;
  final int vendorId;
  final int otherUserId;
  final String otherUserName;
  final String lastMessage;
  final int unreadCount;
  final DateTime updatedAt;

  const ConversationModel({
    required this.id,
    required this.productId,
    required this.productName,
    required this.buyerId,
    required this.vendorId,
    required this.otherUserId,
    required this.otherUserName,
    required this.lastMessage,
    this.unreadCount = 0,
    required this.updatedAt,
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    return ConversationModel(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      productId: int.tryParse(json['product_id']?.toString() ?? '') ?? 0,
      productName: json['product_name']?.toString() ?? '',
      buyerId: int.tryParse(json['buyer_id']?.toString() ?? '') ?? 0,
      vendorId: int.tryParse(json['vendor_id']?.toString() ?? '') ?? 0,
      otherUserId: int.tryParse(json['other_user_id']?.toString() ?? '') ?? 0,
      otherUserName: json['other_user_name']?.toString() ?? 'مستخدم',
      lastMessage: json['last_message']?.toString() ?? '',
      unreadCount: int.tryParse(json['unread_count']?.toString() ?? '') ?? 0,
      updatedAt:
          DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class PrivateMessageModel {
  final int id;
  final int senderId;
  final String senderName;
  final String message;
  final DateTime createdAt;
  final String attachmentUrl;
  final String attachmentName;
  final String attachmentMime;
  final double? offerAmount;
  final String offerStatus;

  const PrivateMessageModel({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.message,
    required this.createdAt,
    this.attachmentUrl = '',
    this.attachmentName = '',
    this.attachmentMime = '',
    this.offerAmount,
    this.offerStatus = '',
  });

  factory PrivateMessageModel.fromJson(Map<String, dynamic> json) {
    return PrivateMessageModel(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      senderId: int.tryParse(json['sender_id']?.toString() ?? '') ?? 0,
      senderName: json['sender_name']?.toString() ?? 'مستخدم',
      message: json['message']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      attachmentUrl: json['attachment_url']?.toString() ?? '',
      attachmentName: json['attachment_name']?.toString() ?? '',
      attachmentMime: json['attachment_mime']?.toString() ?? '',
      offerAmount: double.tryParse(json['offer_amount']?.toString() ?? ''),
      offerStatus: json['offer_status']?.toString() ?? '',
    );
  }

  bool get hasAttachment => attachmentUrl.isNotEmpty;
  bool get isImage => attachmentMime.startsWith('image/');
  bool get hasOffer => offerAmount != null && offerAmount! > 0;
}

class AcceptedOfferModel {
  final int conversationId;
  final int messageId;
  final int productId;
  final double amount;

  const AcceptedOfferModel({
    required this.conversationId,
    required this.messageId,
    required this.productId,
    required this.amount,
  });

  factory AcceptedOfferModel.fromJson(Map<String, dynamic> json) {
    return AcceptedOfferModel(
      conversationId:
          int.tryParse(json['conversation_id']?.toString() ?? '') ?? 0,
      messageId: int.tryParse(json['offer_message_id']?.toString() ?? '') ?? 0,
      productId: int.tryParse(json['product_id']?.toString() ?? '') ?? 0,
      amount: double.tryParse(json['amount']?.toString() ?? '') ?? 0,
    );
  }
}
