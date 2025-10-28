import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';
import '../../models/challenge.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final supabase = Supabase.instance.client;
  List<PostWithLikes> posts = [];
  bool isLoading = true;
  Set<int> likedPostIds = {};

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    setState(() => isLoading = true);

    try {
      final currentUserId = supabase.auth.currentUser?.id;

      // Récupérer les posts approuvés avec les infos nécessaires
      final response = await supabase
          .from('posts')
          .select('''
            *,
            profiles:user_id(username, avatar_url),
            daily_challenges(defis(nom))
          ''')
          .eq('status', 'approved')
          .order('posted_at', ascending: false);

      // Pour chaque post, compter les likes
      List<PostWithLikes> allPosts = [];

      for (var item in response) {
        final postId = item['id'] as int;

        // Compter les likes
        final likesResponse = await supabase
            .from('post_likes')
            .select('id')
            .eq('post_id', postId);

        final likesCount = (likesResponse as List).length;

        // Vérifier si l'user actuel a liké
        bool isLiked = false;
        if (currentUserId != null) {
          final userLikeResponse = await supabase
              .from('post_likes')
              .select('id')
              .eq('post_id', postId)
              .eq('user_id', currentUserId)
              .maybeSingle();

          isLiked = userLikeResponse != null;
        }

        allPosts.add(PostWithLikes(
          post: Post(
            id: postId,
            userId: item['user_id'],
            username: item['profiles']?['username'] ?? 'Anonyme',
            avatarUrl: item['profiles']?['avatar_url'],
            challengeId: item['challenge_id'],
            mediaUrl: item['media_url'],
            mediaType: item['media_type'],
            status: item['status'],
            postedAt: DateTime.parse(item['posted_at']),
            challengeName: item['daily_challenges']?['defis']?['nom'] ?? 'Défi',
          ),
          likesCount: likesCount,
          isLikedByCurrentUser: isLiked,
        ));

        if (isLiked) {
          likedPostIds.add(postId);
        }
      }

      // Trier par nombre de likes décroissant
      allPosts.sort((a, b) => b.likesCount.compareTo(a.likesCount));

      setState(() {
        posts = allPosts;
        isLoading = false;
      });
    } catch (e) {
      print('Erreur chargement feed: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> _toggleLike(PostWithLikes postWithLikes) async {
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) return;

    final postId = postWithLikes.post.id;
    final isCurrentlyLiked = likedPostIds.contains(postId);

    try {
      if (isCurrentlyLiked) {
        // Unliker
        await supabase
            .from('post_likes')
            .delete()
            .eq('post_id', postId)
            .eq('user_id', currentUser.id);

        setState(() {
          likedPostIds.remove(postId);
          postWithLikes.likesCount--;
          postWithLikes.isLikedByCurrentUser = false;
        });
      } else {
        // Liker
        await supabase.from('post_likes').insert({
          'post_id': postId,
          'user_id': currentUser.id,
        });

        setState(() {
          likedPostIds.add(postId);
          postWithLikes.likesCount++;
          postWithLikes.isLikedByCurrentUser = true;
        });
      }

      // Re-trier la liste
      setState(() {
        posts.sort((a, b) => b.likesCount.compareTo(a.likesCount));
      });
    } catch (e) {
      print('Erreur toggle like: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
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
      body: RefreshIndicator(
        onRefresh: _loadPosts,
        color: Colors.white,
        backgroundColor: Colors.black,
        child: isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
            : _buildPostsList(),
      ),
    );
  }

  Widget _buildPostsList() {
    if (posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 110, color: const Color.fromARGB(255, 255, 255, 255)),
            const SizedBox(height: 20),
            Text(
              'Aucun post n\'a encore été publié aujour\'hui.',
              style: TextStyle(color: const Color.fromARGB(255, 255, 255, 255), fontSize: 16),
            ),
            Text(
              'Profitez-en pour vous lancer !',
              style: TextStyle(color: const Color.fromARGB(255, 255, 255, 255), fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: posts.length,
      itemBuilder: (context, index) => _buildPostCard(posts[index]),
    );
  }

  Widget _buildPostCard(PostWithLikes postWithLikes) {
    final post = postWithLikes.post;
    final timeDiff = DateTime.now().difference(post.postedAt);
    String timeAgo = timeDiff.inMinutes < 1
        ? 'À l\'instant'
        : (timeDiff.inHours < 1
            ? '${timeDiff.inMinutes}min'
            : '${timeDiff.inHours}h');

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.white,
                  backgroundImage: post.avatarUrl != null && post.avatarUrl!.isNotEmpty
                      ? NetworkImage(post.avatarUrl!)
                      : null,
                  child: post.avatarUrl == null || post.avatarUrl!.isEmpty
                      ? Text(
                          (post.username.isNotEmpty ? post.username[0] : '?').toUpperCase(),
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.username,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        post.challengeName,
                        style: TextStyle(color: Colors.grey[400], fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Text(
                  timeAgo,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),

          // Média (cliquable pour vidéo)
          GestureDetector(
            onTap: () {
              if (post.mediaType == 'video') {
                _openVideoPlayer(post.mediaUrl);
              }
            },
            child: post.mediaType == 'photo'
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(0),
                    child: Image.network(
                      post.mediaUrl,
                      width: double.infinity,
                      height: 400,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) =>
                          progress == null
                              ? child
                              : Container(
                                  height: 400,
                                  color: Colors.grey[800],
                                  child: const Center(
                                    child: CircularProgressIndicator(color: Colors.white),
                                  ),
                                ),
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 400,
                        color: Colors.grey[800],
                        child: const Center(
                          child: Icon(Icons.error, color: Colors.red, size: 50),
                        ),
                      ),
                    ),
                  )
                : Container(
                    height: 400,
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                    ),
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.play_circle_outline, color: Colors.white, size: 80),
                          SizedBox(height: 16),
                          Text(
                            'Clique pour lire la vidéo',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),

          // Actions (Like + Commentaires)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Bouton Like
                GestureDetector(
                  onTap: () => _toggleLike(postWithLikes),
                  child: Row(
                    children: [
                      Icon(
                        postWithLikes.isLikedByCurrentUser
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: postWithLikes.isLikedByCurrentUser
                            ? Colors.red
                            : Colors.white,
                        size: 28,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${postWithLikes.likesCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 24),

                // Bouton Commentaires
                GestureDetector(
                  onTap: () => _openComments(post),
                  child: Row(
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        color: Colors.white,
                        size: 26,
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openVideoPlayer(String url) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullScreenVideoPlayer(videoUrl: url),
      ),
    );
  }

  Future<void> _openComments(Post post) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color.fromARGB(186, 53, 53, 53),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: _CommentsSheet(
            supabase: supabase,
            post: post,
            onCommentAdded: _loadPosts,
          ),
        );
      },
    );
  }
}

// Widget pour lire la vidéo en plein écran
class _FullScreenVideoPlayer extends StatefulWidget {
  final String videoUrl;

  const _FullScreenVideoPlayer({required this.videoUrl});

  @override
  State<_FullScreenVideoPlayer> createState() => _FullScreenVideoPlayerState();
}

class _FullScreenVideoPlayerState extends State<_FullScreenVideoPlayer> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _isInitialized = true);
          _controller.play();
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: _isInitialized
            ? AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              )
            : const CircularProgressIndicator(color: Colors.white),
      ),
      floatingActionButton: _isInitialized
          ? FloatingActionButton(
              backgroundColor: Colors.white,
              onPressed: () {
                setState(() {
                  _controller.value.isPlaying ? _controller.pause() : _controller.play();
                });
              },
              child: Icon(
                _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.black,
              ),
            )
          : null,
    );
  }
}

// Classe pour stocker Post + Likes
class PostWithLikes {
  final Post post;
  int likesCount;
  bool isLikedByCurrentUser;

  PostWithLikes({
    required this.post,
    required this.likesCount,
    required this.isLikedByCurrentUser,
  });
}

// Sheet des commentaires
class _CommentsSheet extends StatefulWidget {
  final SupabaseClient supabase;
  final Post post;
  final VoidCallback? onCommentAdded;

  const _CommentsSheet({
    required this.supabase,
    required this.post,
    this.onCommentAdded,
  });

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  List<Map<String, dynamic>> comments = [];
  bool isLoading = true;
  bool isPosting = false;
  final TextEditingController _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchComments();
  }

  Future<void> _fetchComments() async {
    setState(() => isLoading = true);
    try {
      final resp = await widget.supabase
          .from('comments')
          .select('*, profiles:user_id(username, avatar_url)')
          .eq('post_id', widget.post.id)
          .order('created_at', ascending: true);

      comments = (resp as List).cast<Map<String, dynamic>>();
    } catch (e) {
      print('Erreur fetch comments: $e');
      comments = [];
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _postComment() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    final user = widget.supabase.auth.currentUser;
    if (user == null) return;

    setState(() => isPosting = true);
    try {
      await widget.supabase.from('comments').insert({
        'post_id': widget.post.id,
        'user_id': user.id,
        'content': text,
        'created_at': DateTime.now().toIso8601String(),
      });

      _ctrl.clear();
      await _fetchComments();
      widget.onCommentAdded?.call();
    } catch (e) {
      print('Erreur poster commentaire: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible d\'envoyer le commentaire'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isPosting = false);
    }
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'À l\'instant';
    if (diff.inHours < 1) return '${diff.inMinutes}min';
    return '${diff.inHours}h';
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.45,
      // Augmenter la hauteur pour laisser de la place au clavier
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[700],
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Commentaires',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.grey),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : comments.isEmpty
                    ? Center(
                        child: Text(
                          'Pas encore de commentaires',
                          style: TextStyle(color: Colors.grey[400]),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: comments.length,
                        itemBuilder: (context, index) {
                          final c = comments[index];
                          final username = c['profiles']?['username'] ?? 'Anonyme';
                          final avatarUrl = c['profiles']?['avatar_url'];
                          final content = c['content'] ?? '';
                          final createdAt = c['created_at'] != null
                              ? DateTime.tryParse(c['created_at'])
                              : null;
                          final time = createdAt != null ? _formatTimeAgo(createdAt) : '';

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                backgroundColor: Colors.white,
                                backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                                    ? NetworkImage(avatarUrl)
                                    : null,
                                child: avatarUrl == null || avatarUrl.isEmpty
                                    ? Text(
                                        username[0].toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.black,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          username,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          time,
                                          style: TextStyle(
                                            color: Colors.grey[500],
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      content,
                                      style: TextStyle(color: Colors.grey[200]),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                        separatorBuilder: (_, __) => const SizedBox(height: 16),
                      ),
          ),
          const Divider(color: Colors.grey),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    minLines: 1,
                    maxLines: 4,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Écrire un commentaire...',
                      hintStyle: TextStyle(color: Colors.grey[500]),
                      filled: true,
                      fillColor: Colors.grey[850],
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                isPosting
                    ? const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : IconButton(
                        icon: const Icon(Icons.send, color: Colors.green),
                        onPressed: _postComment,
                      ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}