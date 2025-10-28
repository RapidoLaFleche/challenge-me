import 'package:flutter/material.dart';
import '../home/home_screen.dart';

class WelcomeAnimationScreen extends StatefulWidget {
  final String username;

  const WelcomeAnimationScreen({
    super.key,
    required this.username,
  });

  @override
  State<WelcomeAnimationScreen> createState() => _WelcomeAnimationScreenState();
}

class _WelcomeAnimationScreenState extends State<WelcomeAnimationScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _scaleController;

  late Animation<double> _fadeAnimation1;
  late Animation<double> _fadeAnimation2;
  late Animation<double> _fadeAnimation3;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // Controller pour les fades
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Controller pour le slide
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    // Controller pour le scale (bounce)
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    // Animations
    _fadeAnimation1 = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
      ),
    );

    _fadeAnimation2 = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: const Interval(0.3, 0.7, curve: Curves.easeIn),
      ),
    );

    _fadeAnimation3 = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: const Interval(0.6, 1.0, curve: Curves.easeIn),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _scaleController,
        curve: Curves.elasticOut,
      ),
    );

    _startAnimation();
  }

  Future<void> _startAnimation() async {
    // Démarrer les animations en séquence
    await Future.delayed(const Duration(milliseconds: 300));
    _fadeController.forward();

    await Future.delayed(const Duration(milliseconds: 500));
    _slideController.forward();

    await Future.delayed(const Duration(milliseconds: 800));
    _scaleController.forward();

    // Attendre la fin puis naviguer
    await Future.delayed(const Duration(milliseconds: 2500));

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icône animée
              ScaleTransition(
                scale: _scaleAnimation,
                child: const Icon(
                  Icons.casino,
                  size: 100,
                  color: Colors.white,
                ),
              ),

              const SizedBox(height: 60),

              // Premier texte : "Bienvenue sur ChallengeMe"
              FadeTransition(
                opacity: _fadeAnimation1,
                child: const Text(
                  'Bienvenue sur ChallengeMe.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                    letterSpacing: 0.5,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Deuxième texte : sous-titre
              FadeTransition(
                opacity: _fadeAnimation2,
                child: Text(
                  'Votre dose quotidienne de challenge.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 16,
                    height: 1.4,
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // Troisième texte : message personnalisé (avec slide)
              SlideTransition(
                position: _slideAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation3,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          '',
                          style: TextStyle(fontSize: 24),
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            'Content de vous revoir ${widget.username} !',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 60),

              // Indicateur de chargement subtil
              FadeTransition(
                opacity: _fadeAnimation3,
                child: SizedBox(
                  width: 30,
                  height: 30,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white.withOpacity(0.3),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}