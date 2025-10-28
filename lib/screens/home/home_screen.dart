import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'today_challenges_screen.dart';
import 'feed_screen.dart';
import 'leaderboard_screen.dart';
import 'profile_screen.dart';
import '/bonus/bonus_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final supabase = Supabase.instance.client;

  final List<Widget> _screens = [
    const FeedScreen(),
    const BonusScreen(),
    const TodayChallengesScreen(),
    const LeaderboardScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: Colors.grey[900]!, width: 1),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() => _currentIndex = index);
          },
          backgroundColor: Colors.black,
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.grey[600],
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          selectedFontSize: 12,
          unselectedFontSize: 11,
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.home, size: 24),
              label: 'Accueil',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.calendar_month, size: 24),
              label: 'Évènements',
            ),
            BottomNavigationBarItem(
              icon: Image.asset(
                'assets/icon/app_logo.png',
                height: 45,
              ),
              label: '',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.emoji_events, size: 24),
              label: 'Classement',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person, size: 24),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }
}
