// =====================================================================
// PLACEHOLDER — replace this file by running:
//
//   dart pub global activate flutterfire_cli
//   flutterfire configure --project=<your-firebase-project-id>
//
// The CLI regenerates this file with your real keys in ~10 seconds.
// Keeping a placeholder here lets the repository compile-check without
// leaking real credentials.
// =====================================================================
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) throw UnsupportedError('Web is not supported.');
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
            'Run `flutterfire configure` to generate options for this platform.');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'PASTE_API_KEY',
    appId: 'PASTE_APP_ID',
    messagingSenderId: 'PASTE_SENDER_ID',
    projectId: 'PASTE_PROJECT_ID',
    storageBucket: 'PASTE_PROJECT_ID.appspot.com',
  );
}
