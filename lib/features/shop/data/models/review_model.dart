class ReviewModel {
  final int id;
  final String review;
  final int rating;
  final String reviewer;
  final String reviewerEmail;
  final String dateCreated;

  ReviewModel({
    required this.id,
    required this.review,
    required this.rating,
    required this.reviewer,
    required this.reviewerEmail,
    required this.dateCreated,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    return ReviewModel(
      id: json['id'] ?? 0,
      review: json['review'] ?? '',
      rating: json['rating'] ?? 0,
      reviewer: json['reviewer'] ?? '',
      reviewerEmail: json['reviewer_email'] ?? '',
      dateCreated: json['date_created'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'review': review,
      'rating': rating,
      'reviewer': reviewer,
      'reviewer_email': reviewerEmail,
      'date_created': dateCreated,
    };
  }
}
