/// Role & permission schema (Deliverable #8).
///
/// Roles stored in users/{uid}.role:
///   super_admin    – Founder. Everything, incl. managing admins. Cannot be
///                    demoted/locked by anyone but another super_admin.
///   admin          – Management. Data entry, members, reports, notifications,
///                    user management (except super_admin accounts).
///   member         – Regular member. Read-only on visible modules.
///   finance_viewer – Restricted financial viewer. Read-only financial data,
///                    no member management, no data entry.
library;

enum Role { superAdmin, admin, member, financeViewer }

extension RoleX on Role {
  String get key => switch (this) {
        Role.superAdmin => 'super_admin',
        Role.admin => 'admin',
        Role.member => 'member',
        Role.financeViewer => 'finance_viewer',
      };
  String get label => switch (this) {
        Role.superAdmin => 'Super Admin (Founder)',
        Role.admin => 'Admin',
        Role.member => 'Member',
        Role.financeViewer => 'Restricted Financial Viewer',
      };
  bool get isAdmin => this == Role.admin || this == Role.superAdmin;
}

Role roleFromKey(String? key) => switch (key) {
      'super_admin' => Role.superAdmin,
      'admin' => Role.admin,
      'finance_viewer' => Role.financeViewer,
      _ => Role.member,
    };

/// Per-user permission flags stored in users/{uid}.permissions.
class Perm {
  Perm._();
  static const String investment = 'investment'; // view Module 5
  static const String reports = 'reports'; // view Module 8 (non-admins)
  static const String accounts = 'accounts'; // List<String> extra account ids visible
}

/// Module ids used for navigation gating.
class Module {
  Module._();
  static const dashboard = 'dashboard';
  static const members = 'members';
  static const memberDetail = 'member_detail';
  static const dataEntry = 'data_entry';
  static const investment = 'investment';
  static const accounts = 'accounts';
  static const permissions = 'permissions';
  static const reports = 'reports';
  static const notifications = 'notifications';
  static const audit = 'audit';
}
