import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final supabase = Supabase.instance.client;
  
  List<LeaderboardEntry> topPlayers = [];
  LeaderboardEntry? currentUserEntry;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLeaderboard();
  }

  Future<void> _loadLeaderboard() async {
    setState(() => isLoading = true);

    try {
      final currentUserId = supabase.auth.currentUser?.id;
      if (currentUserId == null) {
        setState(() => isLoading = false);
        return;
      }

      // Récupérer tous les utilisateurs avec leurs stats
      final usersResponse = await supabase
          .from('profiles')
          .select('id, username, avatar_url');

      if (usersResponse.isEmpty) {
        setState(() => isLoading = false);
        return;
      }

      // Pour chaque utilisateur, compter ses posts approuvés
      List<LeaderboardEntry> allEntries = [];

      for (var user in usersResponse) {
        final userId = user['id'] as String;
        final username = user['username'] as String? ?? 'Anonyme';
        final avatarUrl = user['avatar_url'] as String?;

        // Compter les posts approuvés
        final postsResponse = await supabase
            .from('posts')
            .select('id')
            .eq('user_id', userId)
            .eq('status', 'approved');

        final approvedCount = (postsResponse as List).length;
        final points = approvedCount * 3;

        allEntries.add(LeaderboardEntry(
          userId: userId,
          username: username,
          points: points,
          challengesCompleted: approvedCount,
          rank: 0,
          avatarUrl: avatarUrl,
        ));
      }

      // Trier par points décroissants
      allEntries.sort((a, b) => b.points.compareTo(a.points));

      // Assigner les rangs
      for (int i = 0; i < allEntries.length; i++) {
        allEntries[i] = allEntries[i].copyWith(rank: i + 1);
      }

      // Extraire le top 10
      final top10 = allEntries.take(10).toList();

      // Trouver l'utilisateur actuel
      final currentUser = allEntries.firstWhere(
        (entry) => entry.userId == currentUserId,
        orElse: () => LeaderboardEntry(
          userId: currentUserId,
          username: 'Toi',
          points: 0,
          challengesCompleted: 0,
          rank: allEntries.length + 1,
        ),
      );

      setState(() {
        topPlayers = top10;
        currentUserEntry = currentUser;
        isLoading = false;
      });
    } catch (e) {
      print('Erreur chargement leaderboard: $e');
      setState(() => isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          'ChallengeMe.',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white),
            )
          : RefreshIndicator(
              onRefresh: _loadLeaderboard,
              color: Colors.white,
              backgroundColor: Colors.black,
              child: _buildLeaderboard(),
            ),
    );
  }

  Widget _buildLeaderboard() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Titre section top 10
        Row(
          children: [
            const SizedBox(width: 12),
          ],
        ),

        const SizedBox(height: 20),

        // Liste du top 10
        ...topPlayers.asMap().entries.map((entry) {
          return _buildLeaderboardCard(entry.value);
        }),

        // Séparateur si l'utilisateur n'est pas dans le top 10
        if (currentUserEntry != null && currentUserEntry!.rank > 10) ...[
          const SizedBox(height: 32),
          Divider(color: Colors.grey[800], thickness: 1),
          const SizedBox(height: 32),

          // Ta position
          Row(
            children: [
              const Icon(Icons.person, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              const Text(
                'Ta Position',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildLeaderboardCard(currentUserEntry!, isCurrentUser: true),
        ],
      ],
    );
  }

  Widget _buildLeaderboardCard(LeaderboardEntry entry, {bool isCurrentUser = false}) {
    // Couleurs spéciales pour le top 3
    Color? rankColor;
    String? medal;
    
    if (entry.rank == 1) {
      rankColor = const Color.fromARGB(255, 255, 193, 7);
      medal = '🥇';
    } else if (entry.rank == 2) {
      rankColor = const Color.fromARGB(255, 158, 158, 158);
      medal = '🥈';
    } else if (entry.rank == 3) {
      rankColor = const Color.fromARGB(255, 239, 108, 0);
      medal = '🥉';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCurrentUser ? Colors.white.withOpacity(0.1) : Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrentUser ? Colors.white : (rankColor ?? Colors.grey[800]!),
          width: isCurrentUser || rankColor != null ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          // Rang avec médaille pour top 3
          Container(
            width: 50,
            height: 50,
            child: Center(
              child: medal != null
                  ? Text(
                      medal,
                      style: const TextStyle(fontSize: 28),
                    )
                  : Text(
                      '#${entry.rank}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),

          const SizedBox(width: 16),

          // Avatar
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: isCurrentUser ? Colors.white : Colors.transparent,
                width: 2,
              ),
              image: entry.avatarUrl != null && entry.avatarUrl!.isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(entry.avatarUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: entry.avatarUrl == null || entry.avatarUrl!.isEmpty
                ? Center(
                    child: Text(
                      entry.username.isNotEmpty ? entry.username[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                : null,
          ),

          const SizedBox(width: 16),

          // Nom et challenges
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        entry.username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.w600,
                        ),
                      ),
                    ),
                    if (isCurrentUser) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'TOI',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${entry.challengesCompleted} challenges',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),

          // Points
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: rankColor?.withOpacity(0.2) ?? Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${entry.points}',
              style: TextStyle(
                color: rankColor ?? Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LeaderboardEntry {
  final String userId;
  final String username;
  final int points;
  final int challengesCompleted;
  final int rank;
  final String? avatarUrl;

  LeaderboardEntry({
    required this.userId,
    required this.username,
    required this.points,
    required this.challengesCompleted,
    required this.rank,
    this.avatarUrl,
  });

  LeaderboardEntry copyWith({
    String? userId,
    String? username,
    int? points,
    int? challengesCompleted,
    int? rank,
    String? avatarUrl,
  }) {
    return LeaderboardEntry(
      userId: userId ?? this.userId,
      username: username ?? this.username,
      points: points ?? this.points,
      challengesCompleted: challengesCompleted ?? this.challengesCompleted,
      rank: rank ?? this.rank,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }
}