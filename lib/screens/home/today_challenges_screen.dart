import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';
import '../../models/challenge.dart';
import '../challenge/challenge_upload_screen.dart';


class TodayChallengesScreen extends StatefulWidget {
  const TodayChallengesScreen({super.key});

  @override
  State<TodayChallengesScreen> createState() => _TodayChallengesScreenState();
}

class _TodayChallengesScreenState extends State<TodayChallengesScreen>
    with TickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  List<Challenge> todayChallenges = [];
  bool isLoading = true;
  bool hasSpunToday = false;
  bool isSpinning = false;
  int? _justCompletedIndex;

  late AnimationController _wheelController;
  late Animation<double> _wheelAnimation;
  
  AnimationController? _slideController;
  Animation<Offset>? _slideAnimation;

  @override
  void initState() {
    super.initState();
    _wheelController = AnimationController(
      duration: const Duration(seconds: 6),
      vsync: this,
    );
    _wheelAnimation = CurvedAnimation(
      parent: _wheelController,
      curve: Curves.easeOutCubic,
    );
    _loadTodayChallenges();
  }

  @override
  void dispose() {
    _wheelController.dispose();
    _slideController?.dispose();
    super.dispose();
  }

  Future<void> _loadTodayChallenges({int? completedChallengeId}) async {
    setState(() => isLoading = true);

    try {
      final userId = supabase.auth.currentUser!.id;
      final today = DateTime.now().toIso8601String().split('T')[0];

      final response = await supabase
          .from('daily_challenges')
          .select('*, defis(*)')
          .eq('user_id', userId)
          .eq('date', today);

      if (response.isNotEmpty) {
        final challenges = (response as List).map((item) {
          return Challenge(
            id: item['defis']['id'],
            nom: item['defis']['nom'],
            description: item['defis']['description'],
            imageUrl: item['defis']['image_url'],
            dailyChallengeId: item['id'],
            completed: item['completed'] ?? false,
          );
        }).toList();

        // Si on a un défi qui vient d'être complété, trouver son index
        if (completedChallengeId != null) {
          _justCompletedIndex = challenges.indexWhere(
            (c) => c.dailyChallengeId == completedChallengeId,
          );
        }

        setState(() {
          hasSpunToday = true;
          todayChallenges = challenges;
          isLoading = false;
        });

        // Lancer l'animation slide si nécessaire
        if (_justCompletedIndex != null && _justCompletedIndex! >= 0) {
          _startSlideAnimation();
        }
      } else {
        setState(() {
          hasSpunToday = false;
          isLoading = false;
        });
      }
    } catch (e) {
      print('Erreur chargement challenges: $e');
      setState(() => isLoading = false);
    }
  }

  void _startSlideAnimation() {
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(-1.5, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController!,
      curve: Curves.easeOutCubic,
    ));

    _slideController!.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() => _justCompletedIndex = null);
        }
      });
    });
  }

  Future<void> _spinWheel() async {
  if (isSpinning) return;

  setState(() => isSpinning = true);

  _wheelController.reset();
  _wheelController.forward();

  await Future.delayed(const Duration(seconds: 6)); // temps du spin

  try {
    final userId = supabase.auth.currentUser!.id;
    final today = DateTime.now().toIso8601String().split('T')[0];

    final allDefis = await supabase.from('defis').select();
    final random = Random();
    final selectedDefis = <Map<String, dynamic>>[];
    final availableDefis = List<Map<String, dynamic>>.from(allDefis);

    for (int i = 0; i < 3 && availableDefis.isNotEmpty; i++) {
      final index = random.nextInt(availableDefis.length);
      selectedDefis.add(availableDefis.removeAt(index));
    }

    for (var defi in selectedDefis) {
      await supabase.from('daily_challenges').insert({
        'user_id': userId,
        'defi_id': defi['id'],
        'date': today,
        'completed': false,
      });
    }

    await _loadTodayChallenges();

    setState(() => isSpinning = false);
  } catch (e) {
    print('Erreur spin: $e');
    setState(() => isSpinning = false);
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
          : !hasSpunToday
              ? _buildWheelScreen()
              : _buildChallengesList(),
    );
  }

  Widget _buildWheelScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Fais tourner la roue !',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Et découvre tes 3 challenges du jour',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 60),
          RotationTransition(
            turns: Tween<double>(begin: 0, end: 10)
                .animate(CurvedAnimation(
              parent: _wheelController,
              curve: Curves.easeOutQuart,
            )),
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
                gradient: SweepGradient(
                  colors: [
                    Colors.white,
                    Colors.grey[800]!,
                    Colors.white,
                    Colors.grey[800]!,
                  ],
                ),
              ),
              child: const Icon(
                Icons.casino,
                size: 100,
                color: Colors.black,
              ),
            ),
          ),
          const SizedBox(height: 60),
          GestureDetector(
            onTap: isSpinning ? null : _spinWheel,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 16),
              decoration: BoxDecoration(
                color: isSpinning ? Colors.grey[800] : Colors.white,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Text(
                isSpinning ? 'En cours...' : 'SPIN !',
                style: TextStyle(
                  color: isSpinning ? Colors.grey[600] : Colors.black,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChallengesList() {
    int completed = todayChallenges.where((c) => c.completed).length;

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Progression du jour',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$completed / 3 challenges',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '+ ${completed * 3}',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: todayChallenges.length,
            itemBuilder: (context, index) {
              final challenge = todayChallenges[index];
              final bool isJustCompleted = _justCompletedIndex == index;
              
              return _buildChallengeCard(challenge, isJustCompleted);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildChallengeCard(Challenge challenge, bool isJustCompleted) {
    Widget card = Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: challenge.completed ? Colors.green[900] : Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: challenge.completed ? Colors.green : Colors.grey[800]!,
          width: 2,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            image: challenge.imageUrl != null
                ? DecorationImage(
                    image: NetworkImage(challenge.imageUrl!),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: challenge.imageUrl == null
              ? Icon(
                  challenge.completed ? Icons.check : Icons.emoji_events,
                  color: challenge.completed ? Colors.white : Colors.white,
                  size: 28,
                )
              : null,
        ),
        title: Text(
          challenge.nom,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: challenge.description != null
            ? Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  challenge.description!,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 13,
                  ),
                ),
              )
            : null,
        trailing: challenge.completed
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  '+3 pts',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              )
            : const Icon(
                Icons.arrow_forward_ios,
                color: Colors.white,
                size: 20,
              ),
        onTap: challenge.completed
            ? null
            : () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChallengeUploadScreen(
                      challenge: challenge,
                      onCompleted: () {
                        _loadTodayChallenges(
                          completedChallengeId: challenge.dailyChallengeId,
                        );
                      },
                    ),
                  ),
                );
              },
      ),
    );

    // Si c'est le défi qui vient d'être complété, ajouter l'animation slide
    if (isJustCompleted && _slideAnimation != null) {
      return SlideTransition(
        position: _slideAnimation!,
        child: card,
      );
    }

    return card;
  }
}