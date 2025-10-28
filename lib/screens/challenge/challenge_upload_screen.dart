import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import '../../models/challenge.dart';

class ChallengeUploadScreen extends StatefulWidget {
  final Challenge challenge;
  final VoidCallback onCompleted;

  const ChallengeUploadScreen({
    super.key,
    required this.challenge,
    required this.onCompleted,
  });

  @override
  State<ChallengeUploadScreen> createState() => _ChallengeUploadScreenState();
}

class _ChallengeUploadScreenState extends State<ChallengeUploadScreen> {
  final supabase = Supabase.instance.client;
  final ImagePicker _picker = ImagePicker();
  
  XFile? _selectedMedia;
  bool _isUploading = false;
  String? _mediaType;

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );

    if (image != null) {
      setState(() {
        _selectedMedia = image;
        _mediaType = 'photo';
      });
    }
  }

  Future<void> _pickImageFromGallery() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );

    if (image != null) {
      setState(() {
        _selectedMedia = image;
        _mediaType = 'photo';
      });
    }
  }

  Future<void> _pickVideo() async {
    final XFile? video = await _picker.pickVideo(
      source: ImageSource.camera,
      maxDuration: const Duration(seconds: 30),
    );

    if (video != null) {
      setState(() {
        _selectedMedia = video;
        _mediaType = 'video';
      });
    }
  }

  Future<void> _pickVideoFromGallery() async {
    final XFile? video = await _picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(seconds: 30),
    );

    if (video != null) {
      setState(() {
        _selectedMedia = video;
        _mediaType = 'video';
      });
    }
  }

  Future<void> _uploadAndSubmit() async {
    if (_selectedMedia == null || _mediaType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sélectionne une photo ou vidéo !'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final userId = supabase.auth.currentUser!.id;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = _selectedMedia!.path.split('.').last;
      final fileName = '$userId-${widget.challenge.id}-$timestamp.$extension';

      // 1. Upload du fichier dans Supabase Storage
      final bytes = await File(_selectedMedia!.path).readAsBytes();
      
      await supabase.storage
          .from('posts-media')
          .uploadBinary(fileName, bytes);

      // 2. Récupérer l'URL publique
      final mediaUrl = supabase.storage
          .from('posts-media')
          .getPublicUrl(fileName);

      // 3. Créer le post dans la DB
      await supabase.from('posts').insert({
        'user_id': userId,
        'challenge_id': widget.challenge.dailyChallengeId,
        'media_url': mediaUrl,
        'media_type': _mediaType,
        'status': 'pending',
      });

      // 4. Marquer le défi comme complété
      await supabase
          .from('daily_challenges')
          .update({'completed': true})
          .eq('id', widget.challenge.dailyChallengeId!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Défi envoyé ! En attente de validation...'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        widget.onCompleted();
        Navigator.pop(context);
      }
    } catch (e) {
      print('Erreur upload: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
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
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Envoyer un preuve du défi',
          style: const TextStyle(color: Colors.white, fontSize: 18),
        ),
      ),
      body: Column(
        children: [
          // Titre du défi
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Icon(
                  Icons.emoji_events,
                  color: Colors.white,
                  size: 60,
                ),
                const SizedBox(height: 16),
                Text(
                  widget.challenge.nom,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (widget.challenge.description != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    widget.challenge.description!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 14,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Preview du média sélectionné
          if (_selectedMedia != null)
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: _mediaType == 'photo'
                      ? Image.file(
                          File(_selectedMedia!.path),
                          fit: BoxFit.cover,
                        )
                      : Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.videocam,
                                color: Colors.white,
                                size: 60,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Vidéo sélectionnée',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _selectedMedia!.path.split('/').last,
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 12,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                ),
              ),
            )
          else
            Expanded(
              child: Center(
                child: Text(
                  'Aucun média sélectionné',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                  ),
                ),
              ),
            ),

          // Boutons d'action
          Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Boutons de sélection
                Row(
                  children: [
                    Expanded(
                      child: _buildActionButton(
                        icon: Icons.camera_alt,
                        label: 'Photo',
                        onTap: _pickImage,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildActionButton(
                        icon: Icons.photo_library,
                        label: 'Galerie',
                        onTap: _pickImageFromGallery,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildActionButton(
                        icon: Icons.videocam,
                        label: 'Vidéo',
                        onTap: _pickVideo,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildActionButton(
                        icon: Icons.video_library,
                        label: 'Vidéo galerie',
                        onTap: _pickVideoFromGallery,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                
                // Bouton d'envoi
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isUploading ? null : _uploadAndSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isUploading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : const Text(
                            'ENVOYER LE DÉFI',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[800]!, width: 1),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}