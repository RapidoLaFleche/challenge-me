import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class BonusScreen extends StatefulWidget {
  const BonusScreen({Key? key}) : super(key: key);

  @override
  State<BonusScreen> createState() => _BonusScreenState();
}

class _BonusScreenState extends State<BonusScreen> {
  final supabase = Supabase.instance.client;
  
  bool isLoading = true;
  BonusChallenge? activeChallenge;
  List<BonusSubmission> submissions = [];
  bool hasUserSubmitted = false;

  @override
  void initState() {
    super.initState();
    _loadActiveChallenge();
  }

  Future<void> _loadActiveChallenge() async {
    setState(() => isLoading = true);

    try {
      final today = DateTime.now().toUtc().toIso8601String().split('T')[0];
      final currentUserId = supabase.auth.currentUser?.id;

      final challengeResponse = await supabase
          .from('bonus_challenges')
          .select('*, defis(*)')
          .eq('date', today)
          .eq('is_active', true)
          .maybeSingle();

      if (challengeResponse == null) {
        setState(() {
          activeChallenge = null;
          isLoading = false;
        });
        return;
      }

      final challengeId = challengeResponse['id'] as int;
      final defiName = challengeResponse['defis']?['nom'] ?? 'Défi bonus';
      final targetCount = 100;

      final submissionsResponse = await supabase
          .from('bonus_submissions')
          .select('*, profiles:user_id(username, avatar_url)')
          .eq('bonus_challenge_id', challengeId)
          .eq('status', 'approved')
          .order('submitted_at', ascending: true);

      final allSubmissions = (submissionsResponse as List).map((item) {
        return BonusSubmission(
          id: item['id'],
          userId: item['user_id'],
          username: item['profiles']?['username'] ?? 'Anonyme',
          avatarUrl: item['profiles']?['avatar_url'],
          mediaUrl: item['media_url'],
          mediaType: item['media_type'],
          status: item['status'],
          submittedAt: DateTime.parse(item['submitted_at']),
        );
      }).toList();

      bool userSubmitted = false;
      if (currentUserId != null) {
        final userSubmissionResponse = await supabase
            .from('bonus_submissions')
            .select('id')
            .eq('bonus_challenge_id', challengeId)
            .eq('user_id', currentUserId)
            .maybeSingle();

        userSubmitted = userSubmissionResponse != null;
      }

      setState(() {
        activeChallenge = BonusChallenge(
          id: challengeId,
          defiName: defiName,
          currentCount: allSubmissions.length,
          targetCount: targetCount,
        );
        submissions = allSubmissions;
        hasUserSubmitted = userSubmitted;
        isLoading = false;
      });
    } catch (e) {
      print('Erreur chargement bonus: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> _uploadSubmission() async {
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null || activeChallenge == null) return;

    // Choisir la source
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_library, color: Colors.white),
            title: const Text('Galerie', style: TextStyle(color: Colors.white)),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
          ListTile(
            leading: const Icon(Icons.camera_alt, color: Colors.white),
            title: const Text('Caméra', style: TextStyle(color: Colors.white)),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
        ],
      ),
    );

    if (source == null) return;

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );

    if (pickedFile == null) return;

    // Upload
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );

      final file = File(pickedFile.path);
      final bytes = await file.readAsBytes();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${currentUser.id}-${activeChallenge!.id}-$timestamp.jpg';

      await supabase.storage
          .from('posts-media')
          .uploadBinary(fileName, bytes);

      final mediaUrl = supabase.storage
          .from('posts-media')
          .getPublicUrl(fileName);

      // Créer la submission
      await supabase.from('bonus_submissions').insert({
        'bonus_challenge_id': activeChallenge!.id,
        'user_id': currentUser.id,
        'media_url': mediaUrl,
        'media_type': 'photo',
        'status': 'pending',
      });

      if (mounted) {
        Navigator.pop(context); // Fermer le loading
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Défi envoyé ! En attente de validation...'),
            backgroundColor: Colors.green,
          ),
        );
        _loadActiveChallenge();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showInfoModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Événements spéciaux',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Chaque jour, à un moment aléatoire, des défis exclusifs apparaissent :',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
            const SizedBox(height: 20),
            _buildEventTypeInfo(
              '• Défis communautaires',
              'Unissez vos forces ! Si 100 joueurs les relèvent, tout le monde gagne des points bonus.',
            ),
            const SizedBox(height: 16),
            _buildEventTypeInfo(
              '• Défis uniques',
              'Premier à réussir, premier récompensé.',
            ),
            const SizedBox(height: 20),
            const Text(
              'Reste attentif, ces défis disparaissent et apparaissent vite !',
              style: TextStyle(
                color: Colors.amber,
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Compris !',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventTypeInfo(String title, String description) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          description,
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 13,
          ),
        ),
      ],
    );
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
          : activeChallenge == null
              ? _buildNoEventScreen()
              : _buildActiveEventScreen(),
    );
  }

  Widget _buildNoEventScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/empty_box.png', // Tu peux utiliser une icône
              width: 120,
              height: 120,
              errorBuilder: (context, error, stackTrace) => Icon(
                Icons.inbox_outlined,
                size: 120,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Aucun évènement n\'est actif\npour le moment.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 40),
            TextButton(
              onPressed: _showInfoModal,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                side: const BorderSide(color: Colors.white, width: 1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'En savoir plus',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveEventScreen() {
    final challenge = activeChallenge!;
    final progress = challenge.currentCount / challenge.targetCount;

    return RefreshIndicator(
      onRefresh: _loadActiveChallenge,
      color: Colors.white,
      backgroundColor: Colors.black,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Carte du défi
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color.fromARGB(255, 70, 70, 70), width: 2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          challenge.defiName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${challenge.currentCount} / ${challenge.targetCount} challengeurs',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 12,
                      backgroundColor: Colors.grey[800],
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Bouton upload (si pas encore soumis)
            if (!hasUserSubmitted)
              GestureDetector(
                onTap: _uploadSubmission,
                child: Container(
                  width: double.infinity,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey[700]!, width: 2),
                  ),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo, color: Colors.white, size: 40),
                      ],
                    ),
                  ),
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.green[900],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.green, width: 2),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 40),
                    SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Défi soumis !\nEn attente de validation...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 32),

            if (submissions.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.people, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  Text(
                    'Challengeurs (${submissions.length})',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...submissions.map((submission) => _buildSubmissionCard(submission)),
            ] else ...[
              Center(
                child: Text(
                  'Aucune soumission validée pour le moment...',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSubmissionCard(BonusSubmission submission) {
    final timeDiff = DateTime.now().difference(submission.submittedAt);
    String timeAgo = timeDiff.inMinutes < 1
        ? 'À l\'instant'
        : (timeDiff.inHours < 1 ? '${timeDiff.inMinutes}min' : '${timeDiff.inHours}h');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color.fromARGB(255, 255, 255, 255), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.white,
                  backgroundImage: submission.avatarUrl != null &&
                          submission.avatarUrl!.isNotEmpty
                      ? NetworkImage(submission.avatarUrl!)
                      : null,
                  child: submission.avatarUrl == null || submission.avatarUrl!.isEmpty
                      ? Text(
                          submission.username[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    submission.username,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  timeAgo,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(12),
              bottomRight: Radius.circular(12),
            ),
            child: Image.network(
              submission.mediaUrl,
              width: double.infinity,
              height: 300,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) =>
                  progress == null
                      ? child
                      : Container(
                          height: 300,
                          color: Colors.grey[800],
                          child: const Center(
                            child: CircularProgressIndicator(color: Colors.white),
                          ),
                        ),
              errorBuilder: (context, error, stackTrace) => Container(
                height: 300,
                color: Colors.grey[800],
                child: const Center(
                  child: Icon(Icons.error, color: Colors.red, size: 50),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class BonusChallenge {
  final int id;
  final String defiName;
  final int currentCount;
  final int targetCount;

  BonusChallenge({
    required this.id,
    required this.defiName,
    required this.currentCount,
    required this.targetCount,
  });
}

class BonusSubmission {
  final int id;
  final String userId;
  final String username;
  final String? avatarUrl;
  final String mediaUrl;
  final String mediaType;
  final String status;
  final DateTime submittedAt;

  BonusSubmission({
    required this.id,
    required this.userId,
    required this.username,
    this.avatarUrl,
    required this.mediaUrl,
    required this.mediaType,
    required this.status,
    required this.submittedAt,
  });
}