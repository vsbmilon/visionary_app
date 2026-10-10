import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import '../core/config.dart';
import '../models/models.dart';
import 'audit_service.dart';
import 'repos.dart';

/// Google Sheets <-> Firestore synchronization (Deliverable #4).
/// The heavy lifting (parsing the monthly grids) happens in Apps Script
/// (apps_script/Code.gs); this client only moves JSON in and out.
class SheetsSync {
  SheetsSync._();

  static bool get configured => AppConfig.sheetsApiUrl.isNotEmpty;

  /// Bulk-import everything from the Google Sheet (idempotent upsert).
  static Future<String> importAll() async {
    if (!configured) throw Exception('Sheets API URL not configured.');
    final uri = Uri.parse(
        '${AppConfig.sheetsApiUrl}?action=export&token=${AppConfig.sheetsApiToken}');
    final res = await http.get(uri).timeout(const Duration(seconds: 60));
    if (res.statusCode != 200) {
      throw Exception('Sheets API error ${res.statusCode}: ${res.body}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final batch = FirebaseFirestore.instance.batch();
    int nMembers = 0, nAccounts = 0, nDeposits = 0, nInvest = 0;

    // accounts
    final accountIds = <String, String>{}; // name -> id
    for (final a in (data['accounts'] as List? ?? [])) {
      final m = Map<String, dynamic>.from(a);
      final id = 'acct_${m['order']}';
      accountIds[m['name'] as String] = id;
      batch.set(Repos.accounts.doc(id), {
        'name': m['name'],
        'order': m['order'],
        'memberVisible': m['memberVisible'] ?? true,
        'expectedMonthly': (m['expectedMonthly'] as num?)?.toDouble() ?? 4000,
        'extraViewerUids': [],
      }, SetOptions(merge: true));
      nAccounts++;
    }

    // members
    final memberIds = <int, String>{}; // code -> id
    for (final m0 in (data['members'] as List? ?? [])) {
      final m = Map<String, dynamic>.from(m0);
      final code = (m['code'] as num).toInt();
      final id = 'm_$code';
      memberIds[code] = id;
      batch.set(Repos.members.doc(id), {
        'code': code,
        'name': m['name'],
        'phone': m['phone'] ?? '',
        'active': true,
        'joinedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      nMembers++;
    }

    // deposits – deterministic ids => re-running import updates, never dupes
    for (final d0 in (data['deposits'] as List? ?? [])) {
      final d = Map<String, dynamic>.from(d0);
      final code = (d['memberCode'] as num).toInt();
      final acctName = d['accountName'] as String;
      final acctId = accountIds[acctName] ?? 'acct_1';
      final period = d['period'] as String;
      batch.set(Repos.deposits.doc(Deposit.importId(code, acctId, period)), {
        'memberId': memberIds[code] ?? 'm_$code',
        'memberCode': code,
        'memberName': d['memberName'],
        'accountId': acctId,
        'accountName': acctName,
        'period': period,
        'amount': (d['amount'] as num).toDouble(),
        'note': '',
        'source': 'sheets',
        'date': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      nDeposits++;
    }

    // investments
    for (final i0 in (data['investments'] as List? ?? [])) {
      final i = Map<String, dynamic>.from(i0);
      final code = (i['memberCode'] as num).toInt();
      batch.set(Repos.investments.doc('inv_$code'), {
        'memberId': memberIds[code] ?? 'm_$code',
        'memberCode': code,
        'memberName': i['memberName'],
        'baseAmount': (i['baseAmount'] as num).toDouble(),
        'additionalCapital': (i['additionalCapital'] as num).toDouble(),
        'investmentPerPerson':
            ((i['baseAmount'] as num) + (i['additionalCapital'] as num))
                .toDouble(),
        'profitShare': (i['profitShare'] as num).toDouble(),
      }, SetOptions(merge: true));
      nInvest++;
    }

    // expenses from the sheet's draft-calculation block
    for (final e0 in (data['expenses'] as List? ?? [])) {
      final e = Map<String, dynamic>.from(e0);
      final id = 'exp_${(e['title'] as String).toLowerCase().replaceAll(' ', '_')}';
      batch.set(Repos.expenses.doc(id), {
        'title': e['title'],
        'amount': (e['amount'] as num).toDouble(),
        'category': e['category'] ?? 'general',
        'date': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    await batch.commit();
    final summary =
        'Imported $nMembers members, $nAccounts accounts, $nDeposits deposits, $nInvest investments.';
    await AuditService.log(
      action: 'import',
      entity: 'sheets',
      label: summary,
    );
    return summary;
  }

  /// Write app deposits back into the Google Sheet monthly grids.
  static Future<String> exportToSheets(List<Deposit> deposits) async {
    if (!configured) throw Exception('Sheets API URL not configured.');
    final payload = jsonEncode({
      'token': AppConfig.sheetsApiToken,
      'action': 'importDeposits',
      'deposits': deposits
          .map((d) => {
                'memberCode': d.memberCode,
                'memberName': d.memberName,
                'accountName': d.accountName,
                'period': d.period,
                'amount': d.amount,
              })
          .toList(),
    });
    final res = await http
        .post(Uri.parse(AppConfig.sheetsApiUrl),
            headers: {'Content-Type': 'text/plain;charset=utf-8'},
            body: payload)
        .timeout(const Duration(seconds: 90));
    if (res.statusCode != 200) {
      throw Exception('Sheets API error ${res.statusCode}: ${res.body}');
    }
    await AuditService.log(
      action: 'export',
      entity: 'sheets',
      label: 'Pushed ${deposits.length} deposits to Google Sheets',
    );
    return 'Pushed ${deposits.length} deposit rows to Google Sheets.';
  }
}
