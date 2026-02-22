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
    // Handle both Product reviews (WC) and Store reviews (Dokan)
    String content =
        json['review'] ??
        json['content'] ??
        json['comment_content'] ??
        (json['content'] is Map ? json['content']['rendered'] : '');

    // Dokan author name/email
    String name = json['reviewer'] ?? '';
    if (name.isEmpty && json['author'] != null && json['author'] is Map) {
      name = json['author']['name'] ?? '';
    }

    String email = json['reviewer_email'] ?? '';
    if (email.isEmpty && json['author'] != null && json['author'] is Map) {
      email = json['author']['email'] ?? '';
    }

    return ReviewModel(
      id: json['id'] ?? 0,
      review: content,
      rating: json['rating'] is int
          ? json['rating']
          : int.tryParse(json['rating']?.toString() ?? '0') ?? 0,
      reviewer: name,
      reviewerEmail: email,
      dateCreated:
          json['date_created'] ?? json['post_date'] ?? json['date'] ?? '',
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
