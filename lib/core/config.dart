/// App-wide configuration constants.
library;

class AppConfig {
  AppConfig._();

  /// Organization name shown on dashboard / login.
  static const String orgName = 'Visionary';

  /// Currency symbol used across the app.
  static const String currencySymbol = '৳';

  /// Google Apps Script Web App URL (deploy steps: docs/03-google-sheets-integration.md).
  /// Leave empty to disable Sheets sync (app then works Firestore-only).
  static const String sheetsApiUrl = ''; // e.g. 'https://script.google.com/macros/s/AKfycb.../exec'

  /// Shared secret between the app and the Apps Script Web App.
  /// Change it to any long random string and set the SAME value in Code.gs.
  static const String sheetsApiToken = 'CHANGE_ME_SECRET_TOKEN';

  /// FCM topics.
  static const String topicAll = 'visionary-all';
  static const String topicAdmins = 'visionary-admins';
  static const String topicInvest = 'visionary-invest';
}
