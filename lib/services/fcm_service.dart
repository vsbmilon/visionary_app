import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../core/config.dart';
import 'repos.dart';

/// Module 9 – push notifications (FCM, free tier).
/// Devices subscribe to topics by role; Apps Script time-trigger sends
/// monthly reminders & Sheets-driven alerts to the same topics.
class FcmService {
  FcmService._();

  static final FirebaseMessaging _m = FirebaseMessaging.instance;

  static Future<void> init() async {
    final settings = await _m.requestPermission(alert: true, badge: true, sound: true);
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;
    FirebaseMessaging.onMessage.listen((m) {
      // Foreground messages: in-app notification center already shows them
      // (notifications collection). Keep console log for debugging.
      if (kDebugMode) print('FCM foreground: ${m.notification?.title}');
    });
  }

  static Future<void> subscribeForRole(bool isAdmin, bool canInvest) async {
    try {
      await _m.subscribeToTopic(AppConfig.topicAll);
      if (isAdmin) await _m.subscribeToTopic(AppConfig.topicAdmins);
      if (canInvest) await _m.subscribeToTopic(AppConfig.topicInvest);
      final token = await _m.getToken();
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (token != null && uid != null) {
        await Repos.users.doc(uid).collection('tokens').doc('android').set({
          'token': token,
          'platform': 'android',
          'updatedAt': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      if (kDebugMode) print('FCM subscribe failed: $e');
    }
  }

  static Future<void> unsubscribeAll() async {
    try {
      await _m.unsubscribeFromTopic(AppConfig.topicAll);
      await _m.unsubscribeFromTopic(AppConfig.topicAdmins);
      await _m.unsubscribeFromTopic(AppConfig.topicInvest);
    } catch (_) {}
  }
}
