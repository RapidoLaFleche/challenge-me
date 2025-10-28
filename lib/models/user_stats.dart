class UserStats {
  final String userId;
  final String username;
  final int totalPoints;
  final int todayCompleted;
  final int totalCompleted;

  UserStats({
    required this.userId,
    required this.username,
    this.totalPoints = 0,
    this.todayCompleted = 0,
    this.totalCompleted = 0,
  });
}