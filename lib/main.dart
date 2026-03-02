import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

// Import Firebase config
import 'firebase_options.dart';

// Import theme
import 'theme/app_theme.dart';

// Import Services
import 'services/auth_service.dart';
import 'services/db_service.dart';

// Import Screens
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/event_list_screen.dart';
import 'screens/event_detail_screen.dart';
import 'screens/queue_status_screen.dart';
import 'screens/seat_selection_screen.dart';
import 'screens/reservation_confirmation_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => AuthService()),
        Provider<DbService>(create: (_) => DbService()),
      ],
      child: MaterialApp(
        title: 'TickFair Connect',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.getTheme(),
        initialRoute: LoginScreen.routeName,
        routes: {
          LoginScreen.routeName: (ctx) => const LoginScreen(),
          RegisterScreen.routeName: (ctx) => const RegisterScreen(),
          EventListScreen.routeName: (ctx) => const EventListScreen(),
          // note: EventDetailScreen handled in onGenerateRoute for dynamic id support
          QueueStatusScreen.routeName: (ctx) => const QueueStatusScreen(),
          SeatSelectionScreen.routeName: (ctx) => const SeatSelectionScreen(),
          ReservationConfirmationScreen.routeName: (ctx) => const ReservationConfirmationScreen(),
        },
        onGenerateRoute: (settings) {
          // support deep linking /event-detail/:id pattern
          final name = settings.name;
          if (name != null && name.startsWith('${EventDetailScreen.routeName}/')) {
            final id = name.substring('${EventDetailScreen.routeName}/'.length);
            return MaterialPageRoute(
              builder: (ctx) => EventDetailScreen(eventId: id),
              settings: settings,
            );
          }
          return null; // fall back to named routes
        },
      ),
    );
  }
}