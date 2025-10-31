import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserProfileModal extends StatefulWidget {
  final String userId;
  final String username;

  const UserProfileModal({
    super.key,
    required this.userId,
    required this.username,
  });

  @override
  State<UserProfileModal> createState() => _UserProfileModalState();
}

class _UserProfileModalState extends State<UserProfileModal> {
  final supabase = Supabase.instance.client;

  bool isLoading = true;
  String? avatarUrl;
  int totalPoints = 0;
  int rank = 0;
  int followersCount = 0;
  int followingCount = 0;
  bool isFollowing = false;
  List<Map<String, dynamic>> recentPosts = [];

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    setState(() => isLoading = true);

    try {
      final currentUserId = supabase.auth.currentUser?.id;

      // 1. Profil de base
      final profileResponse = await supabase
          .from('profiles')
          .select('username, avatar_url')
          .eq('id', widget.userId)
          .maybeSingle();

      avatarUrl = profileResponse?['avatar_url'];

      // 2. Points totaux
      final postsResponse = await supabase
          .from('posts')
          .select('id')
          .eq('user_id', widget.userId)
          .eq('status', 'approved');

      final approvedCount = (postsResponse as List).length;
      totalPoints = approvedCount * 3;

      // 3. Calcul du rang
      final allUsersResponse = await supabase.from('profiles').select('id');
      List<Map<String, dynamic>> allUsersPoints = [];

      for (var user in allUsersResponse) {
        final userId = user['id'] as String;
        final userPostsResponse = await supabase
            .from('posts')
            .select('id')
            .eq('user_id', userId)
            .eq('status', 'approved');

        final count = (userPostsResponse as List).length;
        allUsersPoints.add({'user_id': userId, 'points': count * 3});
      }

      allUsersPoints.sort((a, b) => b['points'].compareTo(a['points']));

      rank = allUsersPoints.indexWhere((u) => u['user_id'] == widget.userId) + 1;

      // 4. Nombre d'abonnés et abonnements
      final followersResponse = await supabase
          .from('follows')
          .select('id')
          .eq('following_id', widget.userId);

      followersCount = (followersResponse as List).length;

      final followingResponse = await supabase
          .from('follows')
          .select('id')
          .eq('follower_id', widget.userId);

      followingCount = (followingResponse as List).length;

      // 5. Vérifier si on suit déjà cet utilisateur
      if (currentUserId != null && currentUserId != widget.userId) {
        final isFollowingResponse = await supabase
            .from('follows')
            .select('id')
            .eq('follower_id', currentUserId)
            .eq('following_id', widget.userId)
            .maybeSingle();

        isFollowing = isFollowingResponse != null;
      }

      // 6. Les 3 derniers posts
      final recentPostsResponse = await supabase
          .from('posts')
          .select('*')
          .eq('user_id', widget.userId)
          .eq('status', 'approved')
          .order('posted_at', ascending: false)
          .limit(3);

      recentPosts = (recentPostsResponse as List).cast<Map<String, dynamic>>();

      setState(() => isLoading = false);
    } catch (e) {
      print('Erreur chargement profil: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> _toggleFollow() async {
    final currentUserId = supabase.auth.currentUser?.id;
    if (currentUserId == null) return;

    try {
      if (isFollowing) {
        // Unfollow
        await supabase
            .from('follows')
            .delete()
            .eq('follower_id', currentUserId)
            .eq('following_id', widget.userId);

        setState(() {
          isFollowing = false;
          followersCount--;
        });
      } else {
        // Follow
        await supabase.from('follows').insert({
          'follower_id': currentUserId,
          'following_id': widget.userId,
        });

        setState(() {
          isFollowing = true;
          followersCount++;
        });
      }
    } catch (e) {
      print('Erreur toggle follow: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showFollowersModal(bool isFollowersList) async {
    final currentUserId = supabase.auth.currentUser?.id;
    if (currentUserId == null) return;

    try {
      List<Map<String, dynamic>> users;

      if (isFollowersList) {
        // Abonnés (ceux qui suivent cet utilisateur)
        final response = await supabase
            .from('follows')
            .select('follower_id, profiles!follows_follower_id_fkey(username, avatar_url)')
            .eq('following_id', widget.userId);

        users = (response as List).map((item) {
          return {
            'id': item['follower_id'],
            'username': item['profiles']['username'],
            'avatar_url': item['profiles']['avatar_url'],
          };
        }).toList();
      } else {
        // Abonnements (ceux que cet utilisateur suit)
        final response = await supabase
            .from('follows')
            .select('following_id, profiles!follows_following_id_fkey(username, avatar_url)')
            .eq('follower_id', widget.userId);

        users = (response as List).map((item) {
          return {
            'id': item['following_id'],
            'username': item['profiles']['username'],
            'avatar_url': item['profiles']['avatar_url'],
          };
        }).toList();
      }

      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.grey[900],
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (context) => _FollowListModal(
          title: isFollowersList ? 'Abonnés' : 'Abonnements',
          users: users,
        ),
      );
    } catch (e) {
      print('Erreur chargement liste: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = supabase.auth.currentUser?.id;
    final isOwnProfile = currentUserId == widget.userId;

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Handle
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[700],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Avatar
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.white,
                    backgroundImage: avatarUrl != null && avatarUrl!.isNotEmpty
                        ? NetworkImage(avatarUrl!)
                        : null,
                    child: avatarUrl == null || avatarUrl!.isEmpty
                        ? Text(
                            widget.username[0].toUpperCase(),
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),

                  const SizedBox(height: 16),

                  // Username
                  Text(
                    widget.username,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Rang et points
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '#$rank • $totalPoints pts',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Abonnés / Abonnements
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildStatButton('$followersCount', 'Abonnés', () {
                        _showFollowersModal(true);
                      }),
                      const SizedBox(width: 32),
                      _buildStatButton('$followingCount', 'Abonnements', () {
                        _showFollowersModal(false);
                      }),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Bouton Follow (seulement si ce n'est pas son propre profil)
                  if (!isOwnProfile)
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _toggleFollow,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isFollowing ? Colors.grey[800] : Colors.white,
                          foregroundColor: isFollowing ? Colors.white : Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          isFollowing ? 'Abonné' : 'S\'abonner',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 32),

                  if (recentPosts.isNotEmpty) ...[
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Derniers posts',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: recentPosts.length,
                      itemBuilder: (context, index) {
                        final post = recentPosts[index];
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            post['media_url'],
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              color: Colors.grey[800],
                              child: const Icon(Icons.error, color: Colors.red),
                            ),
                          ),
                        );
                      },
                    ),
                  ] else ...[
                    Center(
                      child: Text(
                        'Aucun post pour le moment',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildStatButton(String value, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

// Modal pour afficher la liste des abonnés/abonnements
class _FollowListModal extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> users;

  const _FollowListModal({
    required this.title,
    required this.users,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          if (users.isEmpty)
            Center(
              child: Text(
                'Aucun utilisateur',
                style: TextStyle(color: Colors.grey[600]),
              ),
            )
          else
            ...users.map((user) => ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.white,
                    backgroundImage: user['avatar_url'] != null &&
                            user['avatar_url'].isNotEmpty
                        ? NetworkImage(user['avatar_url'])
                        : null,
                    child: user['avatar_url'] == null || user['avatar_url'].isEmpty
                        ? Text(
                            user['username'][0].toUpperCase(),
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  title: Text(
                    user['username'],
                    style: const TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => UserProfileModal(
                        userId: user['id'],
                        username: user['username'],
                      ),
                    );
                  },
                )),
        ],
      ),
    );
  }
}