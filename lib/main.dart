import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/theme.dart';
import 'firebase_options.dart';
import 'screens/shell.dart';
import 'screens/splash_login.dart';
import 'services/fcm_service.dart';
import 'state/app_theme.dart';
import 'state/hub.dart';
import 'state/session.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Offline-first: persistent cache so the app is instant & low-data.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  await FcmService.init();

  runApp(const VisionaryApp());
}

class VisionaryApp extends StatelessWidget {
  const VisionaryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => Session()),
        ChangeNotifierProvider(create: (_) => AppThemeController()),
      ],
      child: Consumer<AppThemeController>(
        builder: (ctx, theme, _) => MaterialApp(
          title: 'Visionary',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: theme.dark ? ThemeMode.dark : ThemeMode.light,
          home: const AuthGate(),
        ),
      ),
    );
  }
}

/// Routes: splash -> login -> shell. Also hard-blocks deactivated users.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();

    if (!session.isAuthed) return const LoginScreen();

    if (session.loadingDoc || session.doc == null) {
      return const SplashScreen();
    }

    if (session.isBlocked) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_person_rounded,
                    size: 54, color: AppTheme.danger),
                const SizedBox(height: 16),
                const Text('Account locked',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(
                  'Your access was deactivated by an organization admin. Contact the founder to restore it.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => session.signOut(),
                  child: const Text('Sign Out'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Recreate the data cache whenever identity or sensitive permissions
    // change, so newly granted/revoked modules refresh immediately.
    final key = ValueKey(
        '${session.user!.uid}_${session.doc!.canInvest}_${session.doc!.role.isAdmin}');
    return ChangeNotifierProvider<DataHub>(
      key: key,
      create: (_) => DataHub(
        canInvest: session.doc!.canInvest,
        isAdmin: session.doc!.role.isAdmin,
      ),
      child: const ShellScreen(),
    );
  }
}
