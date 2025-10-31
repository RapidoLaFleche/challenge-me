import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

// -------------------------
// SUPABASE CLIENT GLOBAL
// -------------------------
final supabase = Supabase.instance.client;

// -------------------------
// MAIN
// -------------------------
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialisation Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialisation Supabase
  await Supabase.initialize(
    url: 'https://qwwrfqwbdkbwnqgbkibb.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF3d3JmcXdiZGtid25xZ2JraWJiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjEzODY5NDgsImV4cCI6MjA3Njk2Mjk0OH0.52DbUgrAOWRF3rXAdtBmubCiSJ7xry1LeolEhVnvQA8',
  );

  // Initialisation OneSignal
  OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
  OneSignal.initialize("d326d334-6f87-492d-983f-9d6e1ca5df89");
  await OneSignal.Notifications.requestPermission(true);

  // Lancer l'application
  runApp(const MyApp());
}

// -------------------------
// FONCTION POUR ENREGISTRER LE TOKEN FCM
// -------------------------
Future<void> saveFcmToken(String userId, String fcmToken) async {
  try {
    await supabase.from('profiles').update({
      'fcm_token': fcmToken,
    }).eq('id', userId);
    print("✅ Token FCM sauvegardé: $fcmToken");
  } catch (e) {
    print("❌ Erreur sauvegarde FCM token : $e");
  }
}

// -------------------------
// FONCTION POUR ENREGISTRER LE ONESIGNAL ID
// -------------------------
Future<void> saveOneSignalId(String userId, String oneSignalId) async {
  try {
    await supabase.from('profiles').update({
      'onesignal_id': oneSignalId,
    }).eq('id', userId);
    print("✅ OneSignal ID sauvegardé: $oneSignalId");
  } catch (e) {
    print("❌ Erreur sauvegarde OneSignal ID : $e");
  }
}

// -------------------------
// WIDGET PRINCIPAL
// -------------------------
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String? _fcmToken;
  String? _oneSignalId;

  @override
  

  void initState() {
    super.initState();
    _initNotifications();
    _listenToOneSignalSubscription();
  }

  void _listenToOneSignalSubscription() {
    // Écouter les changements de subscription (plus fiable que permission observer)
    OneSignal.User.pushSubscription.addObserver((state) async {
      print("🔔 Subscription OneSignal changée - ID: ${state.current.id}, Status: ${state.current.optedIn}");
      
      if (state.current.optedIn) {
        // L'utilisateur a accepté les notifications
        await Future.delayed(const Duration(milliseconds: 500));
        
        final oneSignalId = await OneSignal.User.getOnesignalId();
        print("📱 OneSignal ID (subscribed): $oneSignalId");
        
        setState(() => _oneSignalId = oneSignalId);
        
        // Si l'utilisateur est connecté, sauvegarder immédiatement
        final session = supabase.auth.currentSession;
        if (session != null && oneSignalId != null) {
          await saveOneSignalId(session.user.id, oneSignalId);
        }
      }
    });
  }

  Future<void> _initNotifications() async {
    try {
      // Écouter les notifications en foreground
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print("🔔 Notification reçue: ${message.notification?.title} - ${message.notification?.body}");
      });

      // Gérer les notifications tapées depuis le background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        print("📬 Notification ouverte: ${message.notification?.title}");
      });
    } catch (e) {
      print("❌ Erreur init notifications : $e");
    }
  }

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

// -------------------------
// AUTH CHECKER
// -------------------------
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

      // Si connecté, sauvegarde les tokens
      if (session != null) {
        final userId = session.user.id;
        
        // Récupérer et sauvegarder FCM token
        try {
          final fcmToken = await FirebaseMessaging.instance.getToken();
          if (fcmToken != null) {
            await saveFcmToken(userId, fcmToken);
          }
        } catch (e) {
          print("⚠️ Erreur FCM: $e");
        }
        
        // Récupérer et sauvegarder OneSignal ID
        try {
          final oneSignalId = await OneSignal.User.getOnesignalId();
          if (oneSignalId != null) {
            await saveOneSignalId(userId, oneSignalId);
          }
        } catch (e) {
          print("⚠️ Erreur OneSignal: $e");
        }
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) =>
              session != null ? const HomeScreen() : const LoginScreen(),
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