import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/permissions.dart';
import '../models/models.dart';
import 'audit_service.dart';

/// Firestore repositories (CRUD + audit trail).
/// All reads in the UI go through DataHub (state/hub.dart) for offline cache.
class Repos {
  Repos._();

  static final FirebaseFirestore db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get members =>
      db.collection('members');
  static CollectionReference<Map<String, dynamic>> get accounts =>
      db.collection('accounts');
  static CollectionReference<Map<String, dynamic>> get deposits =>
      db.collection('deposits');
  static CollectionReference<Map<String, dynamic>> get investments =>
      db.collection('investments');
  static CollectionReference<Map<String, dynamic>> get profitEvents =>
      db.collection('profitEvents');
  static CollectionReference<Map<String, dynamic>> get expenses =>
      db.collection('expenses');
  static CollectionReference<Map<String, dynamic>> get users =>
      db.collection('users');
  static CollectionReference<Map<String, dynamic>> get notifications =>
      db.collection('notifications');

  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  // ------------------------------------------------------------ members
  static Future<void> saveMember(Member m, {bool isNew = false}) async {
    await members.doc(m.id.isEmpty ? null : m.id).set(m.toMap());
    final id = m.id.isEmpty ? m.name : m.id;
    await AuditService.log(
      action: isNew ? 'create' : 'update',
      entity: 'member',
      entityId: id.toString(),
      label: 'Member ${m.code} – ${m.name}',
      after: m.toMap(),
    );
  }

  static Future<void> deleteMember(Member m) async {
    await members.doc(m.id).delete();
    await AuditService.log(
      action: 'delete',
      entity: 'member',
      entityId: m.id,
      label: 'Member ${m.code} – ${m.name}',
      before: m.toMap(),
    );
  }

  // ----------------------------------------------------------- deposits
  static Future<void> saveDeposit(Deposit d, {bool isNew = false}) async {
    final ref = d.id.isEmpty ? deposits.doc() : deposits.doc(d.id);
    Map<String, dynamic>? before;
    if (!isNew) {
      final snap = await ref.get();
      before = snap.exists ? snap.data() : null;
    }
    final map = d.toMap();
    if (isNew) {
      map['createdBy'] = _uid;
    } else {
      map['updatedBy'] = _uid;
      map['updatedAt'] = FieldValue.serverTimestamp();
    }
    await ref.set(map, SetOptions(merge: true));
    await AuditService.log(
      action: isNew ? 'create' : 'update',
      entity: 'deposit',
      entityId: ref.id,
      label:
          'Deposit ${d.memberName} • ${d.accountName} • ${d.period} • ${d.amount.toStringAsFixed(0)}',
      before: before,
      after: map,
    );
  }

  static Future<void> deleteDeposit(Deposit d) async {
    await deposits.doc(d.id).delete();
    await AuditService.log(
      action: 'delete',
      entity: 'deposit',
      entityId: d.id,
      label: 'Deposit ${d.memberName} • ${d.accountName} • ${d.period}',
      before: d.toMap(),
    );
  }

  // ----------------------------------------------------------- accounts
  static Future<void> saveAccount(Account a) async {
    await accounts.doc(a.id).set(a.toMap(), SetOptions(merge: true));
    await AuditService.log(
      action: 'update',
      entity: 'account',
      entityId: a.id,
      label: 'Account ${a.name} (memberVisible=${a.memberVisible})',
      after: a.toMap(),
    );
  }

  // -------------------------------------------------------- investments
  static Future<void> saveInvestment(Investment i) async {
    await investments.doc(i.id).set(i.toMap(), SetOptions(merge: true));
    await AuditService.log(
      action: 'update',
      entity: 'investment',
      entityId: i.id,
      label: 'Investment ${i.memberName}',
      after: i.toMap(),
    );
  }

  static Future<void> addProfitEvent(ProfitEvent p) async {
    final ref = await profitEvents.add({
      ...p.toMap(),
      'createdBy': _uid,
    });
    await AuditService.log(
      action: 'create',
      entity: 'profit',
      entityId: ref.id,
      label: 'Profit ${p.period} – ${p.totalProfit.toStringAsFixed(0)}',
      after: p.toMap(),
    );
  }

  static Future<void> addExpense(Expense e) async {
    final ref = await expenses.add({...e.toMap(), 'createdBy': _uid});
    await AuditService.log(
      action: 'create',
      entity: 'expense',
      entityId: ref.id,
      label: 'Expense ${e.title} – ${e.amount.toStringAsFixed(0)}',
      after: e.toMap(),
    );
  }

  static Future<void> deleteExpense(Expense e) async {
    await expenses.doc(e.id).delete();
    await AuditService.log(
      action: 'delete',
      entity: 'expense',
      entityId: e.id,
      label: 'Expense ${e.title}',
      before: e.toMap(),
    );
  }

  // -------------------------------------------------------------- users
  static Future<void> createUserDoc({
    required String uid,
    required String email,
    required String name,
    Role role = Role.member,
    String? createdBy,
  }) async {
    await users.doc(uid).set(UserDoc(
      uid: uid,
      email: email,
      name: name,
      role: role,
      createdBy: createdBy ?? _uid,
    ).toMap());
    await AuditService.log(
      action: 'create',
      entity: 'user',
      entityId: uid,
      label: 'User $email (${role.key})',
    );
  }

  static Future<void> updateUserDoc(
    UserDoc u, {
    String changeLabel = '',
  }) async {
    await users.doc(u.uid).set(u.toMap(), SetOptions(merge: true));
    await AuditService.log(
      action: 'permission',
      entity: 'user',
      entityId: u.uid,
      label: changeLabel.isEmpty
          ? 'User ${u.email} updated (role=${u.role.key}, active=${u.active})'
          : changeLabel,
      after: {
        'role': u.role.key,
        'active': u.active,
        'permissions': u.permissions,
      },
    );
  }

  // ------------------------------------------------------ notifications
  static Future<void> postNotification(AppNotification n) async {
    await notifications.add({...n.toMap(), 'createdBy': _uid});
  }
}
