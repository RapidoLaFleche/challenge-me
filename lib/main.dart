import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://qwwrfqwbdkbwnqgbkibb.supabase.co',  // ← Garde tes vraies valeurs
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF3d3JmcXdiZGtid25xZ2JraWJiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjEzODY5NDgsImV4cCI6MjA3Njk2Mjk0OH0.52DbUgrAOWRF3rXAdtBmubCiSJ7xry1LeolEhVnvQA8',
  );

  runApp(const MyApp());
}

final supabase = Supabase.instance.client;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ChallengeMe.',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        primaryColor: Colors.white,
        colorScheme: ColorScheme.dark(
          primary: Colors.white,
          secondary: Colors.grey[800]!,
        ),
      ),
      home: const AuthChecker(),
    );
  }
}

class AuthChecker extends StatefulWidget {
  const AuthChecker({super.key});

  @override
  State<AuthChecker> createState() => _AuthCheckerState();
}

class _AuthCheckerState extends State<AuthChecker> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    await Future.delayed(const Duration(seconds: 1));
    
    if (mounted) {
      final session = supabase.auth.currentSession;
      
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => session != null 
              ? const HomeScreen() 
              : const LoginScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.casino, size: 80, color: Colors.white),
            SizedBox(height: 20),
            Text(
              'ChallengeMe.',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 40),
            CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}