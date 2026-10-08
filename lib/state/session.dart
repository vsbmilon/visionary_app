import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../core/permissions.dart';
import '../models/models.dart';
import '../services/fcm_service.dart';

/// Auth state + the signed-in user's role document.
/// Every permission decision in the UI goes through this object,
/// and Firestore rules enforce the same decisions server-side.
class Session extends ChangeNotifier {
  Session() {
    _authSub = FirebaseAuth.instance.userChanges().listen(_onAuth);
  }

  StreamSubscription<User?>? _authSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _docSub;

  User? user;
  UserDoc? doc;
  bool loadingDoc = false;

  void _onAuth(User? u) {
    user = u;
    _docSub?.cancel();
    if (u == null) {
      doc = null;
      loadingDoc = false;
      notifyListeners();
      return;
    }
    loadingDoc = true;
    notifyListeners();
    _docSub = FirebaseFirestore.instance
        .collection('users')
        .doc(u.uid)
        .snapshots()
        .listen((s) async {
      doc = s.exists ? UserDoc.fromMap(s.data()!, u.uid) : null;
      loadingDoc = false;
      if (s.exists && doc != null) {
        await FcmService.subscribeForRole(doc!.role.isAdmin, doc!.canInvest);
        // Record login time (fire & forget) — throttled so the write does
        // not re-trigger this listener in a loop.
        final last = doc!.lastLoginAt?.toDate();
        if (last == null ||
            DateTime.now().difference(last) > const Duration(hours: 1)) {
          FirebaseFirestore.instance
              .collection('users')
              .doc(u.uid)
              .set({'lastLoginAt': FieldValue.serverTimestamp()},
                  SetOptions(merge: true));
        }
      }
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _docSub?.cancel();
    super.dispose();
  }

  bool get isAuthed => user != null;
  bool get isBlocked => isAuthed && doc != null && !doc!.active;

  Role get role => doc?.role ?? Role.member;
  bool get isSuper => role == Role.superAdmin;
  bool get isAdmin => role.isAdmin;

  /// Module 5 gate: admins + explicitly granted users only.
  bool get canInvest => doc?.canInvest ?? false;

  /// Module 8 gate.
  bool get canReports =>
      isAdmin || role == Role.financeViewer || doc?.permissions[Perm.reports] == true;

  /// Module 7 gate.
  bool get canManageUsers => isAdmin;

  /// Module 10 gate.
  bool get canAudit => isAdmin || role == Role.financeViewer;

  /// Module 6: which accounts this user may see.
  List<Account> visibleAccounts(List<Account> all) {
    if (isAdmin) return all;
    final extra = doc?.extraAccounts ?? const [];
    return all
        .where((a) => a.memberVisible || extra.contains(a.id) ||
            a.extraViewerUids.contains(user?.uid))
        .toList();
  }

  // ------------------------------------------------------------- auth ops
  static Future<String?> signIn(String email, String password) async {
    try {
      await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email.trim(), password: password);
      return null;
    } on FirebaseAuthException catch (e) {
      return switch (e.code) {
        'invalid-email' => 'Invalid email address.',
        'user-not-found' ||
        'wrong-password' ||
        'invalid-credential' =>
          'Incorrect email or password.',
        'user-disabled' => 'This account is deactivated. Contact your admin.',
        'too-many-requests' => 'Too many attempts. Try again later.',
        _ => 'Sign-in failed: ${e.message}'
      };
    }
  }

  static Future<String?> sendReset(String email) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email.trim());
      return null;
    } catch (e) {
      return 'Could not send reset email.';
    }
  }

  Future<void> signOut() async {
    await FcmService.unsubscribeAll();
    await FirebaseAuth.instance.signOut();
  }
}
