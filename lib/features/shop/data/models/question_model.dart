import 'package:equatable/equatable.dart';

class QuestionModel extends Equatable {
  final int id;
  final String productName;
  final int authorId;
  final String author;
  final String question;
  final String? answer;
  final String? answerDate;
  final String date;
  final bool isAnswered;
  final double? bidAmount;
  final String bidStatus;

  const QuestionModel({
    required this.id,
    this.productName = '',
    this.authorId = 0,
    this.author = '',
    required this.question,
    this.answer,
    this.answerDate,
    required this.date,
    required this.isAnswered,
    this.bidAmount,
    this.bidStatus = '',
  });

  factory QuestionModel.fromJson(Map<String, dynamic> json) {
    return QuestionModel(
      id: int.tryParse(json['id'].toString()) ?? 0,
      productName: json['product_name'] ?? '',
      authorId: int.tryParse(json['author_id']?.toString() ?? '') ?? 0,
      author: json['author']?.toString() ?? '',
      question: json['question'] ?? '',
      answer: json['answer']?.toString(),
      answerDate: json['answer_date']?.toString(),
      date: json['date'] ?? '',
      isAnswered:
          json['is_answered'] == true ||
          json['is_answered'] == 1 ||
          json['is_answered'] == '1' ||
          json['is_answered'] == 'true' ||
          (json['answer'] != null &&
              json['answer'].toString().trim().isNotEmpty),
      bidAmount: double.tryParse(json['bid_amount']?.toString() ?? ''),
      bidStatus: json['bid_status']?.toString() ?? '',
    );
  }

  bool get isBid => bidAmount != null && bidAmount! > 0;

  @override
  List<Object?> get props => [
    id,
    productName,
    authorId,
    author,
    question,
    answer,
    answerDate,
    date,
    isAnswered,
    bidAmount,
    bidStatus,
  ];
}

class AcceptedBidModel {
  final int bidId;
  final int productId;
  final double amount;

  const AcceptedBidModel({
    required this.bidId,
    required this.productId,
    required this.amount,
  });

  factory AcceptedBidModel.fromJson(Map<String, dynamic> json) {
    return AcceptedBidModel(
      bidId: int.tryParse(json['bid_id']?.toString() ?? '') ?? 0,
      productId: int.tryParse(json['product_id']?.toString() ?? '') ?? 0,
      amount: double.tryParse(json['amount']?.toString() ?? '') ?? 0,
    );
  }
}
