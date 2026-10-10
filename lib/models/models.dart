library;

import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/permissions.dart';

/// All Firestore models in one place (collections design: docs/01).
// ---------------------------------------------------------------- users
class UserDoc {
  final String uid;
  final String email;
  final String name;
  final String phone;
  final Role role;
  final bool active;
  final Map<String, dynamic> permissions;
  final Timestamp? createdAt;
  final String? createdBy;
  final Timestamp? lastLoginAt;

  UserDoc({
    required this.uid,
    required this.email,
    this.name = '',
    this.phone = '',
    this.role = Role.member,
    this.active = true,
    Map<String, dynamic>? permissions,
    this.createdAt,
    this.createdBy,
    this.lastLoginAt,
  }) : permissions = permissions ?? {};

  factory UserDoc.fromMap(Map<String, dynamic> m, String id) => UserDoc(
        uid: id,
        email: (m['email'] ?? '') as String,
        name: (m['name'] ?? '') as String,
        phone: (m['phone'] ?? '') as String,
        role: roleFromKey(m['role'] as String?),
        active: m['active'] != false,
        permissions: Map<String, dynamic>.from(m['permissions'] ?? {}),
        createdAt: m['createdAt'] as Timestamp?,
        createdBy: m['createdBy'] as String?,
        lastLoginAt: m['lastLoginAt'] as Timestamp?,
      );

  Map<String, dynamic> toMap() => {
        'email': email,
        'name': name,
        'phone': phone,
        'role': role.key,
        'active': active,
        'permissions': permissions,
        'createdAt': createdAt ?? FieldValue.serverTimestamp(),
        'createdBy': createdBy,
        'lastLoginAt': lastLoginAt,
      };

  bool get canInvest =>
      role.isAdmin || permissions[Perm.investment] == true;
  List<String> get extraAccounts =>
      (permissions[Perm.accounts] as List?)?.cast<String>() ?? const [];
}

// -------------------------------------------------------------- members
class Member {
  final String id;
  final int code; // 101, 102 ...
  final String name;
  final String phone;
  final Timestamp? joinedAt;
  final bool active;

  Member({
    required this.id,
    required this.code,
    required this.name,
    this.phone = '',
    this.joinedAt,
    this.active = true,
  });

  factory Member.fromMap(Map<String, dynamic> m, String id) => Member(
        id: id,
        code: (m['code'] as num?)?.toInt() ?? 0,
        name: (m['name'] ?? '') as String,
        phone: (m['phone'] ?? '') as String,
        joinedAt: m['joinedAt'] as Timestamp?,
        active: m['active'] != false,
      );

  Map<String, dynamic> toMap() => {
        'code': code,
        'name': name,
        'phone': phone,
        'joinedAt': joinedAt ?? FieldValue.serverTimestamp(),
        'active': active,
      };
}

// ------------------------------------------------------------- accounts
class Account {
  final String id;
  final String name; // '1st Account', '2nd Account'
  final int order;
  final bool memberVisible;
  final double expectedMonthly;
  final List<String> extraViewerUids;

  Account({
    required this.id,
    required this.name,
    this.order = 0,
    this.memberVisible = true,
    this.expectedMonthly = 4000,
    this.extraViewerUids = const [],
  });

  factory Account.fromMap(Map<String, dynamic> m, String id) => Account(
        id: id,
        name: (m['name'] ?? '') as String,
        order: (m['order'] as num?)?.toInt() ?? 0,
        memberVisible: m['memberVisible'] != false,
        expectedMonthly: (m['expectedMonthly'] as num?)?.toDouble() ?? 4000,
        extraViewerUids:
            (m['extraViewerUids'] as List?)?.cast<String>() ?? const [],
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'order': order,
        'memberVisible': memberVisible,
        'expectedMonthly': expectedMonthly,
        'extraViewerUids': extraViewerUids,
      };
}

// ------------------------------------------------------------- deposits
class Deposit {
  final String id;
  final String memberId;
  final int memberCode;
  final String memberName;
  final String accountId;
  final String accountName;
  final String period; // 'yyyy-MM'
  final Timestamp? date;
  final double amount;
  final String note;
  final String source; // 'app' | 'sheets'
  final String? createdBy;
  final Timestamp? createdAt;
  final String? updatedBy;
  final Timestamp? updatedAt;

  Deposit({
    required this.id,
    required this.memberId,
    required this.memberCode,
    required this.memberName,
    required this.accountId,
    required this.accountName,
    required this.period,
    this.date,
    this.amount = 0,
    this.note = '',
    this.source = 'app',
    this.createdBy,
    this.createdAt,
    this.updatedBy,
    this.updatedAt,
  });

  factory Deposit.fromMap(Map<String, dynamic> m, String id) => Deposit(
        id: id,
        memberId: (m['memberId'] ?? '') as String,
        memberCode: (m['memberCode'] as num?)?.toInt() ?? 0,
        memberName: (m['memberName'] ?? '') as String,
        accountId: (m['accountId'] ?? '') as String,
        accountName: (m['accountName'] ?? '') as String,
        period: (m['period'] ?? '') as String,
        date: m['date'] as Timestamp?,
        amount: (m['amount'] as num?)?.toDouble() ?? 0,
        note: (m['note'] ?? '') as String,
        source: (m['source'] ?? 'app') as String,
        createdBy: m['createdBy'] as String?,
        createdAt: m['createdAt'] as Timestamp?,
        updatedBy: m['updatedBy'] as String?,
        updatedAt: m['updatedAt'] as Timestamp?,
      );

  Map<String, dynamic> toMap() => {
        'memberId': memberId,
        'memberCode': memberCode,
        'memberName': memberName,
        'accountId': accountId,
        'accountName': accountName,
        'period': period,
        'date': date ?? FieldValue.serverTimestamp(),
        'amount': amount,
        'note': note,
        'source': source,
        'createdAt': createdAt ?? FieldValue.serverTimestamp(),
        'createdBy': createdBy,
        'updatedAt': updatedAt,
        'updatedBy': updatedBy,
      };

  /// Deterministic id so Sheets re-imports upsert instead of duplicating.
  static String importId(int memberCode, String accountId, String period) =>
      'dep_${memberCode}_${accountId}_$period';
}

// ---------------------------------------------------------- investments
class Investment {
  final String id;
  final String memberId;
  final int memberCode;
  final String memberName;
  final double baseAmount;
  final double additionalCapital;
  final double profitShare;

  Investment({
    required this.id,
    required this.memberId,
    required this.memberCode,
    required this.memberName,
    this.baseAmount = 0,
    this.additionalCapital = 0,
    this.profitShare = 0,
  });

  double get totalPerPerson => baseAmount + additionalCapital;

  factory Investment.fromMap(Map<String, dynamic> m, String id) => Investment(
        id: id,
        memberId: (m['memberId'] ?? '') as String,
        memberCode: (m['memberCode'] as num?)?.toInt() ?? 0,
        memberName: (m['memberName'] ?? '') as String,
        baseAmount: (m['baseAmount'] as num?)?.toDouble() ?? 0,
        additionalCapital: (m['additionalCapital'] as num?)?.toDouble() ?? 0,
        profitShare: (m['profitShare'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'memberId': memberId,
        'memberCode': memberCode,
        'memberName': memberName,
        'baseAmount': baseAmount,
        'additionalCapital': additionalCapital,
        'investmentPerPerson': baseAmount + additionalCapital,
        'profitShare': profitShare,
      };
}

class ProfitEvent {
  final String id;
  final String period;
  final String title;
  final double totalProfit;
  final List<Map<String, dynamic>> distribution; // [{memberId,memberName,amount}]
  final Timestamp? createdAt;
  final String? createdBy;

  ProfitEvent({
    required this.id,
    required this.period,
    this.title = '',
    this.totalProfit = 0,
    this.distribution = const [],
    this.createdAt,
    this.createdBy,
  });

  factory ProfitEvent.fromMap(Map<String, dynamic> m, String id) => ProfitEvent(
        id: id,
        period: (m['period'] ?? '') as String,
        title: (m['title'] ?? '') as String,
        totalProfit: (m['totalProfit'] as num?)?.toDouble() ?? 0,
        distribution: (m['distribution'] as List?)
                ?.map((e) => Map<String, dynamic>.from(e))
                .toList() ??
            const [],
        createdAt: m['createdAt'] as Timestamp?,
        createdBy: m['createdBy'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'period': period,
        'title': title,
        'totalProfit': totalProfit,
        'distribution': distribution,
        'createdAt': createdAt ?? FieldValue.serverTimestamp(),
        'createdBy': createdBy,
      };
}

class Expense {
  final String id;
  final String title;
  final double amount;
  final String category; // 'land' | 'operational' | 'general'
  final Timestamp? date;
  final String? createdBy;
  final Timestamp? createdAt;

  Expense({
    required this.id,
    required this.title,
    this.amount = 0,
    this.category = 'general',
    this.date,
    this.createdBy,
    this.createdAt,
  });

  factory Expense.fromMap(Map<String, dynamic> m, String id) => Expense(
        id: id,
        title: (m['title'] ?? '') as String,
        amount: (m['amount'] as num?)?.toDouble() ?? 0,
        category: (m['category'] ?? 'general') as String,
        date: m['date'] as Timestamp?,
        createdBy: m['createdBy'] as String?,
        createdAt: m['createdAt'] as Timestamp?,
      );

  Map<String, dynamic> toMap() => {
        'title': title,
        'amount': amount,
        'category': category,
        'date': date ?? FieldValue.serverTimestamp(),
        'createdAt': createdAt ?? FieldValue.serverTimestamp(),
        'createdBy': createdBy,
      };
}

// ------------------------------------------------------------ audit log
class AuditLog {
  final String id;
  final String actorUid;
  final String actorName;
  final String action; // create | update | delete | import | login | permission
  final String entity; // deposit | member | account | user | investment ...
  final String entityId;
  final String label;
  final Map<String, dynamic>? before;
  final Map<String, dynamic>? after;
  final Timestamp? at;

  AuditLog({
    required this.id,
    required this.actorUid,
    required this.actorName,
    required this.action,
    required this.entity,
    this.entityId = '',
    this.label = '',
    this.before,
    this.after,
    this.at,
  });

  factory AuditLog.fromMap(Map<String, dynamic> m, String id) => AuditLog(
        id: id,
        actorUid: (m['actorUid'] ?? '') as String,
        actorName: (m['actorName'] ?? '') as String,
        action: (m['action'] ?? '') as String,
        entity: (m['entity'] ?? '') as String,
        entityId: (m['entityId'] ?? '') as String,
        label: (m['label'] ?? '') as String,
        before: (m['before'] as Map?)?.cast<String, dynamic>(),
        after: (m['after'] as Map?)?.cast<String, dynamic>(),
        at: m['at'] as Timestamp?,
      );

  Map<String, dynamic> toMap() => {
        'actorUid': actorUid,
        'actorName': actorName,
        'action': action,
        'entity': entity,
        'entityId': entityId,
        'label': label,
        'before': before,
        'after': after,
        'at': at ?? FieldValue.serverTimestamp(),
      };
}

// -------------------------------------------------------- notifications
class AppNotification {
  final String id;
  final String title;
  final String body;
  final String type; // deposit | reminder | investment | balance | announcement
  final String audience; // all | admins | invest | <uid>
  final Timestamp? createdAt;
  final String? createdBy;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    this.type = 'announcement',
    this.audience = 'all',
    this.createdAt,
    this.createdBy,
  });

  factory AppNotification.fromMap(Map<String, dynamic> m, String id) =>
      AppNotification(
        id: id,
        title: (m['title'] ?? '') as String,
        body: (m['body'] ?? '') as String,
        type: (m['type'] ?? 'announcement') as String,
        audience: (m['audience'] ?? 'all') as String,
        createdAt: m['createdAt'] as Timestamp?,
        createdBy: m['createdBy'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'title': title,
        'body': body,
        'type': type,
        'audience': audience,
        'createdAt': createdAt ?? FieldValue.serverTimestamp(),
        'createdBy': createdBy,
      };
}
