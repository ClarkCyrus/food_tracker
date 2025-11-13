import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:awesome_notifications/awesome_notifications.dart';

import 'pages/login_page.dart';
import 'pages/register_page.dart';
import 'pages/home_page.dart';
import 'pages/history_page.dart';
import 'pages/test.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

bool notificationsEnabled = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: 'assets/.env');

  await AwesomeNotifications().initialize(
    null, // icon for notifications, null = default app icon
    [
      NotificationChannel(
        channelKey: 'basic_channel',
        channelName: 'Basic Notifications',
        channelDescription: 'Notification channel for daily reminders',
        defaultColor: Colors.green,
        ledColor: Colors.white,
        importance: NotificationImportance.High,
      ),
    ],
  );

  bool isAllowed = await AwesomeNotifications().isNotificationAllowed();
  if (!isAllowed) {
    await AwesomeNotifications().requestPermissionToSendNotifications();
  }

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  // Register an auth state change listener to force-login when there is no user
  Supabase.instance.client.auth.onAuthStateChange.listen((event) {
    final session = event.session;
    final user = session?.user;
    // If user is null (signed out), navigate to login and clear stack
    if (user == null) {
      navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (r) => false);
    } else {
      // Optional: when user signs in, navigate to home
      navigatorKey.currentState?.pushNamedAndRemoveUntil('/home', (r) => false);
    }
  });

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
    final user = Supabase.instance.client.auth.currentUser;
    const protected = ['/home', '/history', '/test'];

    // If route requires auth but there's no user, send to LoginPage
    if (protected.contains(settings.name) && user == null) {
      return MaterialPageRoute(builder: (_) => const LoginPage(), settings: settings);
    }

    switch (settings.name) {
      case '/login':
        return MaterialPageRoute(builder: (_) => const LoginPage(), settings: settings);
      case '/register':
        return MaterialPageRoute(builder: (_) => const RegisterPage(), settings: settings);
      case '/home':
        return MaterialPageRoute(builder: (_) => const NutritionHomePage(), settings: settings);
      case '/history':
        return MaterialPageRoute(builder: (_) => const FoodHistoryPage(), settings: settings);
      case '/test':
        return MaterialPageRoute(builder: (_) => const TestApp(), settings: settings);
      default:
        // Fallback: if authenticated go home, else login
        return MaterialPageRoute(
            builder: (_) => user == null ? const LoginPage() : const NutritionHomePage(),
            settings: settings);
    }
  }

  @override
  Widget build(BuildContext context) {
    final initialRoute =
      Supabase.instance.client.auth.currentUser == null ? '/login' : '/home';

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Snap',
      theme: ThemeData(
        textTheme: GoogleFonts.nunitoTextTheme(
          Theme.of(context).textTheme,
        ),
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: Color.fromARGB(255, 3, 209, 110),
        ),
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: Colors.green,        // cursor in text fields
          selectionColor: Colors.greenAccent, // text selection highlight
          selectionHandleColor: Colors.green, // handles for selection
        ),
      ),
      initialRoute: initialRoute,
      onGenerateRoute: (_onGenerateRoute),
    );
  }
}