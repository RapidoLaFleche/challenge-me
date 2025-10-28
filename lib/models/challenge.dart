class Challenge {
  final int id;
  final String nom;
  final String? description;
  final int? dailyChallengeId;
  final String? imageUrl;
  bool completed;

  Challenge({
    required this.id,
    required this.nom,
    this.description,
    this.dailyChallengeId,
    this.imageUrl,
    this.completed = false,
  });

  factory Challenge.fromJson(Map<String, dynamic> json) {
    return Challenge(
      id: json['id'] as int,
      nom: json['nom'] as String,
      description: json['description'] as String?,
      dailyChallengeId: json['daily_challenge_id'] as int?,
      completed: json['completed'] as bool? ?? false,
    );
  }
}

class Post {
  final int id;
  final String userId;
  final String username;
  final int challengeId;
  final String mediaUrl;
  final String mediaType;
  final String status;
  final DateTime postedAt;
  final String challengeName;
  final String? avatarUrl;

  // Ces deux champs doivent être modifiables
  int likeCount;
  bool isLiked;

  Post({
    required this.id,
    required this.userId,
    required this.username,
    required this.challengeId,
    required this.mediaUrl,
    required this.mediaType,
    required this.status,
    required this.postedAt,
    required this.challengeName,
    this.likeCount = 0,
    this.isLiked = false,
    this.avatarUrl,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'] as int,
      userId: json['user_id'] as String,
      username: json['username'] as String? ?? 'Anonyme',
      challengeId: json['challenge_id'] as int,
      mediaUrl: json['media_url'] as String,
      mediaType: json['media_type'] as String,
      status: json['status'] as String,
      postedAt: DateTime.parse(json['posted_at'] as String),
      challengeName: json['challenge_name'] as String? ?? 'Défi',
      likeCount: json['like_count'] as int? ?? 0,
      isLiked: json['is_liked'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'username': username,
      'challenge_id': challengeId,
      'media_url': mediaUrl,
      'media_type': mediaType,
      'status': status,
      'posted_at': postedAt.toIso8601String(),
      'challenge_name': challengeName,
      'like_count': likeCount,
      'is_liked': isLiked,
    };
  }
}
