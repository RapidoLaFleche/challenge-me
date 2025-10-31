import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

class AdminPostsScreen extends StatefulWidget {
  const AdminPostsScreen({super.key});

  @override
  State<AdminPostsScreen> createState() => _AdminPostsScreenState();
}

class _AdminPostsScreenState extends State<AdminPostsScreen> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _posts = [];

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  // -------------------------
  // CHARGER LES POSTS
  // -------------------------
  Future<void> _loadPosts() async {
    setState(() => _isLoading = true);
    try {
      final response = await supabase
          .from('posts')
          .select('*, profiles(onesignal_id)')
          .order('posted_at', ascending: false);

      setState(() {
        _posts = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      print('Erreur chargement posts: $e');
      setState(() => _isLoading = false);
    }
  }

  // Maj du statut du post
  Future<void> _updateStatus(String postId, String status, String? playerId) async {
    try {
      await supabase
          .from('posts')
          .update({'status': status})
          .eq('id', postId);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Post mis à jour ($status)')),
      );

      _loadPosts(); // Rafraîchir la liste
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  // -------------------------
  // APERCU MEDIA
  // -------------------------
  Widget _buildMediaPreview(String? url) {
    if (url == null || url.isEmpty) {
      return const Text(
        'Pas de contenu',
        style: TextStyle(color: Colors.white70, fontSize: 14),
      );
    }

    if (url.endsWith('.mp4')) {
      final controller = VideoPlayerController.network(url);
      final chewieController = ChewieController(
        videoPlayerController: controller,
        autoPlay: false,
        looping: false,
        showControls: true,
      );

      return SizedBox(
        height: 200,
        child: Chewie(controller: chewieController),
      );
    } else {
      return CachedNetworkImage(
        imageUrl: url,
        placeholder: (context, url) =>
            const Center(child: CircularProgressIndicator(color: Colors.white)),
        errorWidget: (context, url, error) =>
            const Icon(Icons.error, color: Colors.red),
        fit: BoxFit.cover,
        height: 200,
        width: double.infinity,
      );
    }
  }

  // -------------------------
  // BUILD UI
  // -------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin - Tous les posts'),
        backgroundColor: Colors.black,
      ),
      backgroundColor: Colors.black,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : ListView.builder(
              itemCount: _posts.length,
              itemBuilder: (context, index) {
                final post = _posts[index];
                final playerId = post['profiles']?['onesignal_id'];

                return Card(
                  color: post['status'] == 'pending'
                      ? const Color.fromARGB(255, 46, 46, 46)
                      : Colors.green[800],
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        _buildMediaPreview(post['media_url']),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Statut: ${post['status']}',
                              style: const TextStyle(color: Colors.white70),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (post['status'] != 'approved')
                                  IconButton(
                                    icon: const Icon(Icons.check,
                                        color: Colors.white),
                                    onPressed: () => _updateStatus(
                                      post['id'].toString(),
                                      'approved',
                                      playerId,
                                    ),
                                  ),
                                if (post['status'] != 'pending')
                                  IconButton(
                                    icon: const Icon(Icons.pause,
                                        color: Colors.white),
                                    onPressed: () => _updateStatus(
                                      post['id'].toString(),
                                      'pending',
                                      playerId,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
