import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/splash_screen.dart';
import '../screens/username_screen.dart';
import '../screens/home_screen.dart';
import '../screens/upload_screen.dart';
import '../screens/result_screen.dart';
import '../screens/settings_screen.dart';
import 'constants.dart';

GoRouter buildRouter() => GoRouter(
      initialLocation: '/splash',
      routes: [
        GoRoute(
          path: '/splash',
          builder: (_, __) => const SplashScreen(),
        ),
        GoRoute(
          path: '/username',
          builder: (_, __) => const UsernameScreen(),
        ),
        GoRoute(
          path: '/home',
          builder: (_, __) => const HomeScreen(),
        ),
        GoRoute(
          path: '/upload',
          builder: (_, __) => const UploadScreen(),
        ),
        GoRoute(
          path: '/job/:id',
          builder: (_, state) =>
              ResultScreen(jobId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/settings',
          builder: (_, __) => const SettingsScreen(),
        ),
      ],
      redirect: (context, state) async {
  if (state.matchedLocation == '/splash') return null;

  final prefs = await SharedPreferences.getInstance();
  final username = prefs.getString(kPrefUsername);

  final goingToUsername = state.matchedLocation == '/username';
  final goingToSettings = state.matchedLocation == '/settings';

  if (username == null && !goingToUsername && !goingToSettings) {
    return '/username';
  }

  return null;
},
    );
