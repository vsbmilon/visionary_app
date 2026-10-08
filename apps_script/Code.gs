/**
 * =====================================================================
 * VISIONARY – Google Sheets ⇄ App integration layer (free, no server)
 * =====================================================================
 * Deploy: Extensions ▸ Apps Script ▸ paste this file ▸ Deploy ▸ New deployment
 *         ▸ Web app ▸ Execute as: Me ▸ Who has access: Anyone ▸ Deploy.
 * Copy the /exec URL into lib/core/config.dart (sheetsApiUrl) and keep
 * TOKEN identical in both places.
 *
 * What it does
 *  - GET  ?action=export&token=...   → full JSON snapshot of the workbook
 *        (members, accounts, monthly deposit grids, investments, expenses)
 *  - POST {action:'importDeposits'}  → writes app deposits back into the
 *        monthly grids (creates month columns / member rows as needed)
 *  - sendMonthlyReminder()           → FCM push to topic (time-trigger)
 *
 * Parsed layout (matches the live workbook):
 *  Summary      : ID | Name | 1st Account Amount | 2nd Account Amount
 *  1st Account  : ID | Name | Total Amount | Apr-2025 | May-2025 | ...
 *  2nd Account  : ID | Name | Total Amount | Aug-2026 | Sep-2026 | ...
 *  Investment   : ID | Name | Base Amount | Additional Capital Contribution
 *                 | Investment Per Person | Profit Share (ROI) per person
 *                 + draft-calculation block (Total Encashment, Cash Handover
 *                   for Land, New Account Deposite, Genarel Expance)
 */

var TOKEN = 'CHANGE_ME_SECRET_TOKEN';           // must match the app
var PROJECT_ID = 'PASTE_FIREBASE_PROJECT_ID';   // for FCM push
var FCM_TOPIC = 'visionary-all';

var MONTHS = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];

// ------------------------------------------------------------------ HTTP
function doGet(e) {
  var action = (e && e.parameter && e.parameter.action) || 'ping';
  var token = e && e.parameter && e.parameter.token;
  if (action !== 'ping' && token !== TOKEN) return _json({ error: 'unauthorized' }, 401);
  try {
    if (action === 'export') return _json({ ok: true, data: exportAll() });
    return _json({ ok: true, service: 'visionary-sheets', time: new Date().toISOString() });
  } catch (err) {
    return _json({ error: String(err) }, 500);
  }
}

function doPost(e) {
  var body = JSON.parse(e.postData.contents);
  if (body.token !== TOKEN) return _json({ error: 'unauthorized' }, 401);
  try {
    if (body.action === 'importDeposits') {
      return _json({ ok: true, written: importDeposits(body.deposits || []) });
    }
    return _json({ error: 'unknown action' }, 400);
  } catch (err) {
    return _json({ error: String(err) }, 500);
  }
}

function _json(obj, code) {
  return ContentService
    .createTextOutput(JSON.stringify(obj))
    .setMimeType(ContentService.MimeType.JSON);
}

// ---------------------------------------------------------------- helpers
function _accountSheets() {
  return SpreadsheetApp.getActiveSpreadsheet().getSheets().filter(function (s) {
    var n = s.getName().toLowerCase();
    return n.indexOf('account') >= 0 && n.indexOf('summary') < 0;
  });
}

function _monthLabelToPeriod(label) {
  var s = String(label).trim();
  for (var i = 0; i < 12; i++) {
    if (s.toLowerCase().indexOf(MONTHS[i].toLowerCase()) === 0) {
      var y = s.match(/(20\d{2})/);
      if (y) return y[1] + '-' + ('0' + (i + 1)).slice(-2);
    }
  }
  return null;
}

function _periodToMonthLabel(period) {
  var p = period.split('-');
  return MONTHS[parseInt(p[1], 10) - 1] + '-' + p[0];
}

function _num(v) {
  var n = Number(String(v).replace(/[, ]/g, ''));
  return isFinite(n) ? n : 0;
}

// ----------------------------------------------------------------- export
function exportAll() {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var out = { members: [], accounts: [], deposits: [], investments: [], expenses: [] };

  // ---- members from Summary
  var summary = ss.getSheetByName('Summary');
  if (summary) {
    var sv = summary.getDataRange().getValues();
    for (var r = 1; r < sv.length; r++) {
      var code = _num(sv[r][0]);
      var name = String(sv[r][1] || '').trim();
      if (!code || !name || name.toLowerCase() === 'name') continue;
      if (/total/i.test(name)) break;
      out.members.push({ code: code, name: name, phone: '' });
    }
  }

  // ---- accounts + monthly deposit grids
  var sheets = _accountSheets();
  sheets.forEach(function (sh, order) {
    var v = sh.getDataRange().getValues();
    var months = [];               // {col, period}
    for (var c = 3; c < v[0].length; c++) {
      var period = _monthLabelToPeriod(v[0][c]);
      if (period) months.push({ col: c, period: period });
      else if (String(v[0][c]).trim() === '') break;
    }
    out.accounts.push({
      name: sh.getName(),
      order: order + 1,
      memberVisible: order === 0,          // 1st Account visible by default
      expectedMonthly: 4000,
    });
    for (var r = 1; r < v.length; r++) {
      var code = _num(v[r][0]);
      var name = String(v[r][1] || '').trim();
      if (!code || !name || /total|sms|profit|balance/i.test(name)) continue;
      months.forEach(function (m) {
        var amount = _num(v[r][m.col]);
        if (amount > 0) {
          out.deposits.push({
            memberCode: code,
            memberName: name,
            accountName: sh.getName(),
            period: m.period,
            amount: amount,
          });
        }
      });
    }
  });

  // ---- investments + draft calculation expenses
  var inv = ss.getSheetByName('Investment');
  if (inv) {
    var iv = inv.getDataRange().getValues();
    for (var r = 1; r < iv.length; r++) {
      var code = _num(iv[r][0]);
      var name = String(iv[r][1] || '').trim();
      if (code && name) {
        out.investments.push({
          memberCode: code,
          memberName: name,
          baseAmount: _num(iv[r][2]),
          additionalCapital: _num(iv[r][3]),
          profitShare: _num(iv[r][5]),
        });
      }
      // draft-calculation block: label in col B, value in col C
      var label = String(iv[r][1] || '').trim();
      var value = _num(iv[r][2]);
      if (label && value > 0 && /handover|expance|expense|deposite|deposit/i.test(label)
          && !/total encashment/i.test(label)) {
        out.expenses.push({
          title: label,
          amount: value,
          category: /land/i.test(label) ? 'land'
            : /deposite|deposit/i.test(label) ? 'transfer' : 'general',
        });
      }
    }
  }
  return out;
}

// ----------------------------------------------------------------- import
/** Writes deposits coming from the app back into the monthly grids. */
function importDeposits(deposits) {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var written = 0;
  deposits.forEach(function (d) {
    var sh = ss.getSheetByName(d.accountName);
    if (!sh) return;
    var v = sh.getDataRange().getValues();

    // locate member row by code (col A)
    var row = -1;
    for (var r = 1; r < v.length; r++) {
      if (_num(v[r][0]) === d.memberCode) { row = r + 1; break; }
    }
    if (row < 0) {                       // append new member row
      row = sh.getLastRow() + 1;
      sh.getRange(row, 1).setValue(d.memberCode);
      sh.getRange(row, 2).setValue(d.memberName);
    }

    // locate month column (row 1), create if missing
    var label = _periodToMonthLabel(d.period);
    var col = -1;
    for (var c = 4; c <= sh.getLastColumn(); c++) {
      if (String(sh.getRange(1, c).getValue()).trim() === label) { col = c; break; }
    }
    if (col < 0) {
      col = sh.getLastColumn() + 1;
      sh.getRange(1, col).setValue(label);
    }
    sh.getRange(row, col).setValue(d.amount);
    written++;
  });
  _recalcTotals();
  return written;
}

/** Refreshes the "Total Amount" column and the Total row of each account. */
function _recalcTotals() {
  _accountSheets().forEach(function (sh) {
    var last = sh.getLastColumn();
    var v = sh.getDataRange().getValues();
    var totalRow = -1;
    for (var r = 1; r < v.length; r++) {
      if (/^total$/i.test(String(v[r][1]).trim())) { totalRow = r + 1; break; }
    }
    for (var r = 1; r < v.length; r++) {
      if (!_num(v[r][0]) || !String(v[r][1]).trim()) continue;
      var sum = 0;
      for (var c = 3; c < last; c++) sum += _num(v[r][c]);
      sh.getRange(r + 1, 3).setValue(sum);
    }
    if (totalRow > 0) {
      var grand = 0;
      for (var r = 1; r < totalRow - 1; r++) grand += _num(sh.getRange(r + 1, 3).getValue());
      sh.getRange(totalRow, 3).setValue(grand);
    }
  });
}

// ------------------------------------------------------------- push (FCM)
/** Monthly deposit reminder – attach a time-driven trigger (see below). */
function sendMonthlyReminder() {
  var now = new Date();
  var title = 'Monthly deposit reminder';
  var body = MONTHS[now.getMonth()] + ' ' + now.getFullYear() +
    ' deposit is due. Please confirm your payment with the admin.';
  _push(FCM_TOPIC, title, body);
}

function pushAnnouncement(title, body) {
  _push(FCM_TOPIC, title, body);
}

function _push(topic, title, body) {
  var url = 'https://fcm.googleapis.com/v1/projects/' + PROJECT_ID + '/messages:send';
  var payload = {
    message: {
      topic: topic,
      notification: { title: title, body: body },
    },
  };
  var res = UrlFetchApp.fetch(url, {
    method: 'post',
    contentType: 'application/json',
    headers: { Authorization: 'Bearer ' + ScriptApp.getOAuthToken() },
    payload: JSON.stringify(payload),
    muteHttpExceptions: true,
  });
  Logger.log('FCM ' + res.getResponseCode() + ' ' + res.getContentText());
}

/** Run once from the editor: creates the 1st-of-month reminder trigger. */
function installTriggers() {
  ScriptApp.getProjectTriggers().forEach(function (t) {
    if (t.getHandlerFunction() === 'sendMonthlyReminder') ScriptApp.deleteTrigger(t);
  });
  ScriptApp.newTrigger('sendMonthlyReminder')
    .timeBased()
    .onMonthDay(1)
    .atHour(10)
    .create();
}
