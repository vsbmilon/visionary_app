import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/models.dart';

/// Module 10 – Audit log. Append-only trail of who changed what, when,
/// including old (before) and new (after) values.
class AuditService {
  AuditService._();

  static CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('auditLogs');

  static Future<void> log({
    required String action,
    required String entity,
    String entityId = '',
    String label = '',
    Map<String, dynamic>? before,
    Map<String, dynamic>? after,
  }) async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return;
    final name = u.displayName ?? u.email ?? u.uid;
    try {
      await _col.add(AuditLog(
        id: '',
        actorUid: u.uid,
        actorName: name,
        action: action,
        entity: entity,
        entityId: entityId,
        label: label,
        before: _clean(before),
        after: _clean(after),
      ).toMap());
    } catch (e) {
      // Audit must never break the main operation.
      // ignore: avoid_print
      print('audit write failed: $e');
    }
  }

  /// Firestore cannot store null/undefined inside maps reliably for rules
  /// comparisons — strip nulls and convert Timestamps to ISO strings.
  static Map<String, dynamic>? _clean(Map<String, dynamic>? m) {
    if (m == null) return null;
    final out = <String, dynamic>{};
    m.forEach((k, v) {
      if (v == null) return;
      if (v is Timestamp) {
        out[k] = v.toDate().toIso8601String();
      } else if (v is FieldValue) {
        return;
      } else {
        out[k] = v;
      }
    });
    return out;
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> stream({int limit = 300}) =>
      _col.orderBy('at', descending: true).limit(limit).snapshots();
}
