import 'package:equatable/equatable.dart';

class QuestionModel extends Equatable {
  final int id;
  final String productName;
  final String question;
  final String? answer;
  final String date;
  final bool isAnswered;

  const QuestionModel({
    required this.id,
    this.productName = '',
    required this.question,
    this.answer,
    required this.date,
    required this.isAnswered,
  });

  factory QuestionModel.fromJson(Map<String, dynamic> json) {
    return QuestionModel(
      id: int.tryParse(json['id'].toString()) ?? 0,
      productName: json['product_name'] ?? '',
      question: json['question'] ?? '',
      answer: json['answer'],
      date: json['date'] ?? '',
      isAnswered:
          json['is_answered'] == true ||
          json['is_answered'] == 1 ||
          json['is_answered'] == '1' ||
          json['is_answered'] == 'true',
    );
  }

  @override
  List<Object?> get props => [
    id,
    productName,
    question,
    answer,
    date,
    isAnswered,
  ];
}
