import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../auth/login_screen.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'AdminPostsScreen.dart';

const int kPointsPerChallenge = 3;

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final supabase = Supabase.instance.client;

  UserProfileData? _profileData;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUserStats();
  }

  Future<void> _loadUserStats() async {
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Utilisateur non connecté';
        _isLoading = false;
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final userId = currentUser.id;
      final today = DateTime.now().toUtc().toIso8601String().split('T')[0];
      final tempData = UserProfileData();

      // --- PROFIL UTILISATEUR ---
      try {
        final profileResponse = await supabase
            .from('profiles')
            .select('username, avatar_url')
            .eq('id', userId)
            .maybeSingle();

        if (profileResponse != null) {
          tempData.username = profileResponse['username']?.toString() ?? 'Anonyme';
          tempData.avatarUrl = profileResponse['avatar_url']?.toString();
        } else {
          tempData.username = 'Anonyme';
          tempData.avatarUrl = null;
        }
      } catch (e) {
        print('Erreur profil: $e');
        tempData.username = 'Anonyme';
        tempData.avatarUrl = null;
      }

      // --- REQUÊTES PARALLÈLES ---
      final results = await Future.wait([
        // Posts approuvés
        supabase
            .from('posts')
            .select('id')
            .eq('user_id', userId)
            .eq('status', 'approved')
            .count(CountOption.exact),

        // Posts en attente
        supabase
            .from('posts')
            .select('id')
            .eq('user_id', userId)
            .eq('status', 'pending')
            .count(CountOption.exact),

        // challenges complétés aujourd’hui
        supabase
            .from('daily_challenges')
            .select('id')
            .eq('user_id', userId)
            .eq('date', today)
            .eq('completed', true)
            .count(CountOption.exact),
      ]);

      // --- EXTRACTION DES COUNTS ---
      final approvedCount = results[0].count ?? 0;
      final pendingCount = results[1].count ?? 0;
      final todayCount = results[2].count ?? 0;

      tempData.totalCompleted = approvedCount;
      tempData.totalPending = pendingCount;
      tempData.todayCompleted = todayCount;
      tempData.totalPoints = approvedCount * kPointsPerChallenge;

      if (!mounted) return;
      setState(() {
        _profileData = tempData;
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      print('Erreur chargement stats: $e');
      print('StackTrace: $stackTrace');

      if (!mounted) return;
      setState(() {
        _errorMessage = 'Impossible de charger les statistiques';
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Réessayer',
              textColor: Colors.white,
              onPressed: _loadUserStats,
            ),
          ),
        );
      }
    }
  }

  Future<void> _logout() async {
    try {
      await supabase.auth.signOut();
      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur de déconnexion: $e'),
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
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: Colors.grey[900],
                  title: const Text(
                    'Déconnexion',
                    style: TextStyle(color: Colors.white),
                  ),
                  content: const Text(
                    'Veux-tu vraiment te déconnecter ?',
                    style: TextStyle(color: Colors.grey),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Annuler',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _logout();
                      },
                      child: const Text(
                        'Oui',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (_errorMessage != null || _profileData == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 60),
            const SizedBox(height: 20),
            Text(
              _errorMessage ?? 'Erreur inconnue',
              style: TextStyle(color: Colors.grey[400], fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadUserStats,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
              ),
              child: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }

    final data = _profileData!;

    return RefreshIndicator(
      onRefresh: _loadUserStats,
      color: Colors.white,
      backgroundColor: Colors.black,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Avatar et nom
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.white,
                    backgroundImage: data.avatarUrl != null && data.avatarUrl!.isNotEmpty
                        ? NetworkImage(data.avatarUrl!)
                        : null,
                    child: (data.avatarUrl == null || data.avatarUrl!.isEmpty)
                        ? Text(
                            data.username.isNotEmpty ? data.username[0].toUpperCase() : '?',
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    data.username,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Bouton changer avatar
                  SizedBox(
                    width: 170,
                    child: TextButton.icon(
                      onPressed: () async {
                        final user = Supabase.instance.client.auth.currentUser;
                        if (user == null) return;

                        final picker = ImagePicker();

                        final source = await showModalBottomSheet<ImageSource>(
                          context: context,
                          builder: (context) => Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ListTile(
                                leading: const Icon(Icons.photo_library),
                                title: const Text('Galerie'),
                                onTap: () => Navigator.pop(context, ImageSource.gallery),
                              ),
                              ListTile(
                                leading: const Icon(Icons.camera_alt),
                                title: const Text('Caméra'),
                                onTap: () => Navigator.pop(context, ImageSource.camera),
                              ),
                            ],
                          ),
                        );

                        if (source == null) return;

                        final pickedFile = await picker.pickImage(source: source);
                        if (pickedFile == null) return;

                        final file = File(pickedFile.path);

                        try {
                          await Supabase.instance.client
                              .storage
                              .from('avatars')
                              .uploadBinary(
                                'avatars/${user.id}.png',
                                await file.readAsBytes(),
                                fileOptions: const FileOptions(contentType: 'image/png'),
                              );

                          final publicUrl = Supabase.instance.client
                              .storage
                              .from('avatars')
                              .getPublicUrl('avatars/${user.id}.png');

                          await Supabase.instance.client
                              .from('profiles')
                              .update({'avatar_url': publicUrl})
                              .eq('id', user.id);

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Avatar mis à jour !'),
                              backgroundColor: Colors.green,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        } catch (e) {
                          print('Erreur upload avatar: $e');
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Erreur lors de la mise à jour de l\'avatar'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.add, color: Colors.black),
                      label: const Text(
                        'Ajouter une photo',
                        style: TextStyle(color: Colors.black),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Total des points (GROS)
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.white, Colors.grey[300]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Text(
                    '🏆 POINTS TOTAUX',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${data.totalPoints}',
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 60,
                      fontWeight: FontWeight.bold,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${data.totalCompleted} challenges validés',
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Stats du jour
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.green, width: 2),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.today,
                        color: Colors.green,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'AUJOURD\'HUI',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildTodayStat(
                        'Complétés',
                        '${data.todayCompleted} / 3',
                        Icons.check_circle,
                      ),
                      Container(
                        width: 1,
                        height: 50,
                        color: Colors.grey[800],
                      ),
                      _buildTodayStat(
                        'Points',
                        '+${data.todayCompleted * kPointsPerChallenge}',
                        Icons.star,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Statistiques globales
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Total validés',
                    '${data.totalCompleted}',
                    Icons.verified,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'En attente',
                    '${data.totalPending}',
                    Icons.hourglass_empty,
                    Colors.orange,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Ranking badge
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: data.getRankColor(),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      data.getRankIcon(),
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data.getRankTitle(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          data.getRankDescription(),
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // Bouton de déconnexion
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                onPressed: _logout,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.grey[800]!, width: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Se déconnecter',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            if (supabase.auth.currentUser?.email == 'junioryovo2002@gmail.com') ...[
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AdminPostsScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    side: BorderSide(color: const Color.fromARGB(255, 194, 193, 193), width: 2),
                    backgroundColor: Colors.blueAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Voir tous les posts',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTodayStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.green, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3), width: 2),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class UserProfileData {
  String username = 'Anonyme';
  String? avatarUrl;
  int totalPoints = 0;
  int todayCompleted = 0;
  int totalCompleted = 0;
  int totalPending = 0;

  Color getRankColor() {
    if (totalPoints >= 100) return Colors.purple;
    if (totalPoints >= 50) return Colors.amber;
    if (totalPoints >= 20) return Colors.blue;
    return Colors.grey;
  }

  IconData getRankIcon() {
    if (totalPoints >= 100) return Icons.emoji_events;
    if (totalPoints >= 50) return Icons.military_tech;
    if (totalPoints >= 20) return Icons.stars;
    return Icons.rocket_launch;
  }

  String getRankTitle() {
    if (totalPoints >= 100) return 'Légende 👑';
    if (totalPoints >= 50) return 'Expert 🔥';
    if (totalPoints >= 20) return 'Pro ⭐';
    return 'Débutant 🚀';
  }

  String getRankDescription() {
    if (totalPoints >= 100) return 'Tu es une légende vivante !';
    if (totalPoints >= 50) return 'Continue comme ça champion !';
    if (totalPoints >= 20) return 'Tu progresses bien !';
    return 'Continue à relever des challenges !';
  }
}
