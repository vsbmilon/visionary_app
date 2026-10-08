import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../core/permissions.dart';
import '../core/utils.dart';
import '../models/models.dart';
import '../services/repos.dart';

/// Single in-memory cache of every collection the signed-in user can read.
/// Backed by Firestore's offline persistence, so the app opens instantly
/// and works with flaky/low internet (requirement: low data usage).
class DataHub extends ChangeNotifier {
  DataHub({required this.canInvest, required this.isAdmin}) {
    _subs.add(Repos.members.snapshots().listen(_wrap((s) {
      members = s.docs.map((d) => Member.fromMap(d.data(), d.id)).toList()
        ..sort((a, b) => a.code.compareTo(b.code));
    })));
    _subs.add(Repos.accounts.snapshots().listen(_wrap((s) {
      accounts = s.docs.map((d) => Account.fromMap(d.data(), d.id)).toList()
        ..sort((a, b) => a.order.compareTo(b.order));
    })));
    _subs.add(Repos.deposits.snapshots().listen(_wrap((s) {
      deposits = s.docs.map((d) => Deposit.fromMap(d.data(), d.id)).toList();
    })));
    _subs.add(Repos.notifications
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .listen(_wrap((s) {
      notifications =
          s.docs.map((d) => AppNotification.fromMap(d.data(), d.id)).toList();
    })));
    if (isAdmin) {
      _subs.add(Repos.users.snapshots().listen(_wrap((s) {
        users = s.docs.map((d) => UserDoc.fromMap(d.data(), d.id)).toList();
      })));
    }
    if (canInvest) {
      _subs.add(Repos.investments.snapshots().listen(_wrap((s) {
        investments =
            s.docs.map((d) => Investment.fromMap(d.data(), d.id)).toList()
              ..sort((a, b) => a.memberCode.compareTo(b.memberCode));
      })));
      _subs.add(Repos.profitEvents.snapshots().listen(_wrap((s) {
        profitEvents =
            s.docs.map((d) => ProfitEvent.fromMap(d.data(), d.id)).toList()
              ..sort((a, b) => b.period.compareTo(a.period));
      })));
      _subs.add(Repos.expenses.snapshots().listen(_wrap((s) {
        expenses = s.docs.map((d) => Expense.fromMap(d.data(), d.id)).toList();
      })));
    }
  }

  final bool canInvest;
  final bool isAdmin;
  final List<StreamSubscription> _subs = [];

  List<Member> members = [];
  List<Account> accounts = [];
  List<Deposit> deposits = [];
  List<Investment> investments = [];
  List<ProfitEvent> profitEvents = [];
  List<Expense> expenses = [];
  List<UserDoc> users = [];
  List<AppNotification> notifications = [];

  void Function(QuerySnapshot<Map<String, dynamic>>) _wrap(
      void Function(QuerySnapshot<Map<String, dynamic>>) apply) {
    return (s) {
      apply(s);
      notifyListeners();
    };
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  // ------------------------------------------------------------ aggregates
  double depositTotal({String? memberId, String? accountId, String? period}) =>
      deposits
          .where((d) =>
              (memberId == null || d.memberId == memberId) &&
              (accountId == null || d.accountId == accountId) &&
              (period == null || d.period == period))
          .fold(0, (p, d) => p + d.amount);

  double get totalDeposits => depositTotal();
  double get totalProfit =>
      profitEvents.fold(0, (p, e) => p + e.totalProfit);
  double get totalExpenses => expenses.fold(0, (p, e) => p + e.amount);

  /// Group balance = deposits + profit - expenses (mirrors the sheet's
  /// draft calculation: encashment - handover - general expense).
  double get groupBalance => totalDeposits + totalProfit - totalExpenses;

  int get activeMembers => members.where((m) => m.active).length;

  String get currentPeriod => Fmt.currentPeriod();
  double get thisMonthCollection => depositTotal(period: currentPeriod);

  /// Monthly collection totals for the last [n] months (visible deposits only).
  Map<String, double> monthlyTotals(int n) {
    final out = {for (final p in Fmt.lastPeriods(n)) p: 0.0};
    for (final d in deposits) {
      if (out.containsKey(d.period)) out[d.period] = out[d.period]! + d.amount;
    }
    return out;
  }

  List<Deposit> depositsOf(String memberId) => deposits
      .where((d) => d.memberId == memberId)
      .toList()
    ..sort((a, b) => b.period.compareTo(a.period));

  /// Payment status per period for a member on one account.
  String statusFor(double paid, double expected) =>
      paid <= 0 ? 'Missed' : (paid >= expected ? 'Paid' : 'Partial');

  List<Deposit> recentDeposits([int n = 6]) {
    final l = [...deposits]
      ..sort((a, b) => (b.createdAt?.millisecondsSinceEpoch ?? 0)
          .compareTo(a.createdAt?.millisecondsSinceEpoch ?? 0));
    return l.take(n).toList();
  }

  Member? memberById(String id) {
    for (final m in members) {
      if (m.id == id) return m;
    }
    return null;
  }

  /// Notifications addressed to this user.
  List<AppNotification> notificationsFor(String uid, Role role) => notifications
      .where((n) =>
          n.audience == 'all' ||
          n.audience == uid ||
          (n.audience == 'admins' && role.isAdmin) ||
          (n.audience == 'invest' && role.isAdmin))
      .toList();
}
