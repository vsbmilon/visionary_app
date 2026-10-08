# Visionary — Private Members' Finance App (Android · Flutter · Firebase · Google Sheets)

A **free, private, sideload-only** Android app for the *Visionary* organization
(15 → 20 members) that tracks deposits, investments, profits and account
balances — built on top of the existing Google Sheet
*“Visionary Partners Monthly Deposits”* (Summary / Investment / 1st Account /
2nd Account tabs).

> **Cost: ৳ 0 / month.** Firebase Spark free tier + Apps Script free quota +
> sideloaded APK (no Play Store, no developer fee).

---

## Deliverables map

| # | Deliverable | Where |
|---|---|---|
| 1 | Complete Flutter source code | `lib/` + `android/` + `pubspec.yaml` |
| 2 | Firebase database structure | `docs/01-architecture-and-database.md` |
| 3 | Firestore collections design | `docs/01-architecture-and-database.md` §1.2 |
| 4 | Google Sheets integration method | `apps_script/Code.gs` + `docs/03-google-sheets-integration.md` |
| 5 | APK build instructions | `docs/04-build-and-apk-guide.md` |
| 6 | Admin setup guide | `docs/05-admin-setup-guide.md` |
| 7 | Database security rules | `firestore.rules` + `docs/02-role-schema-and-security.md` §2.4 |
| 8 | User role schema | `lib/core/permissions.dart` + `docs/02…` §2.1–2.2 |
| 9 | UI/UX wireframes | `docs/wireframes.html` (open in any browser) |
| 10 | Future scalability recommendations | `docs/06-scalability-roadmap.md` |

Plus: `firestore.indexes.json`, `docs/wireframes.html`, this README.

---

## Module coverage (all 10)

| Module | Screen | Access |
|---|---|---|
| 1 Dashboard | `dashboard_screen.dart` | all roles |
| 2 Member summary (search/sort) | `members_screen.dart` | all roles |
| 3 Member details (history, status, trend) | `members_screen.dart` → `MemberDetailScreen` | all roles |
| 4 Admin data entry + Sheets bulk import | `data_entry_screen.dart` | admin, super_admin |
| 5 Investment & profit (confidential) | `investment_screen.dart` | admins + granted users; **menu hidden otherwise** |
| 6 Accounts (visibility control, balances) | `accounts_screen.dart` | per-account visibility |
| 7 Permission management | `users_screen.dart` | admin, super_admin |
| 8 Reports (PDF + Excel) | `reports_screen.dart` | admins, finance_viewer, grantable |
| 9 Notifications (in-app + FCM push) | `notifications_screen.dart` | all; compose = admin |
| 10 Audit log (old → new values) | `audit_screen.dart` | admin, super_admin, finance_viewer |

## Roles
`super_admin` (founder) · `admin` · `member` · `finance_viewer`
— enforced **twice**: UI navigation (lib/state/session.dart) **and**
Firestore rules (firestore.rules). Deactivated users are locked out instantly.

## Quick start

```bash
# 1. tooling
flutter --version                      # 3.22+
dart pub global activate flutterfire_cli

# 2. wire Firebase (creates lib/firebase_options.dart + google-services.json)
cd visionary_app && flutter pub get
flutterfire configure --project=<your-project-id>

# 3. wire Google Sheets
#    deploy apps_script/Code.gs as Web App, then paste URL+TOKEN
#    into lib/core/config.dart

# 4. build & sideload
flutter build apk --release
#    → build/app/outputs/flutter-apk/app-release.apk
```

Full step-by-step (Firebase console, rules publish, first super-admin
bootstrap doc, Sheets deploy, triggers, distribution) —
**docs/04** and **docs/05**.

## Repository layout

```
visionary_app/
├── pubspec.yaml                  # deps: firebase, provider, fl_chart, pdf, excel…
├── firestore.rules               # role+permission security rules
├── firestore.indexes.json
├── android/                      # Gradle, manifest, launch theme (sideload-ready)
├── apps_script/Code.gs           # Sheets ⇄ Firestore bridge + FCM reminders
├── docs/                         # 6 guides + wireframes.html
└── lib/
    ├── main.dart                 # bootstrap, offline cache, AuthGate
    ├── firebase_options.dart     # placeholder → flutterfire configure
    ├── core/      config · theme (M3 blue/white + dark) · permissions · utils
    ├── models/    users, members, accounts, deposits, investments, profit,
    │              expenses, audit, notifications
    ├── services/  repos (CRUD+audit) · sheets_sync · reports (PDF/Excel)
    │              audit · fcm
    ├── state/     session (auth+roles) · hub (offline cache) · app_theme
    ├── widgets/   stat cards, chips, dialogs · fl_chart charts
    └── screens/   splash/login · shell · dashboard · members · data entry ·
                   investment · accounts · users · reports · audit ·
                   notifications · profile
```

## Design decisions worth knowing

* **Firestore = app database, Sheets = bookkeeping mirror.** Import is
  idempotent (deterministic doc ids like `dep_101_acct_1_2025-04`); export
  writes back into the monthly grids and refreshes totals — your sheet stays
  print-ready.
* **One DataHub subscription per collection** → instant open, tiny bandwidth,
  full offline cache (Firestore persistence ON, unlimited cache).
* **Balance formula** mirrors your sheet's draft calculation:
  `group balance = Σ deposits + Σ profit events − Σ expenses/handover`.
* **Payment status** (Paid / Partial / Missed) compares a month's deposit to
  the account's `expectedMonthly` (admin-editable, default ৳ 4,000).
* **Audit log is append-only by rule** — old & new values stored on every
  create/update/delete/import/permission change.

## Assumptions made (easy to change)

1. Backend = **Firebase preferred** option (Auth + Firestore) with the Sheets
   bridge; a Sheets-only variant would just drop Firestore and keep Code.gs.
2. UI language **English** (matches the sheet); Bengali strings can be added
   via ARB files later.
3. Release APK signed with debug keys for zero-friction sideloading; keystore
   steps included for hardening.
4. `expectedMonthly` defaults to ৳ 4,000 (2nd Account pattern); 1st Account
   history (3,000/4,000) is imported as-is and statuses follow the setting.
