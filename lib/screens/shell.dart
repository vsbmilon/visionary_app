import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/permissions.dart';
import '../core/config.dart';
import '../state/session.dart';
import '../widgets/ui.dart';
import 'accounts_screen.dart';
import 'audit_screen.dart';
import 'dashboard_screen.dart';
import 'data_entry_screen.dart';
import 'investment_screen.dart';
import 'members_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';
import 'reports_screen.dart';
import 'users_screen.dart';

/// App shell. Bottom navigation shows only modules this user may see;
/// restricted modules (e.g. Investment for unauthorized users) do not even
/// appear in any menu (Module 5 requirement).
class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int _index = 0;

  List<_Dest> _primary(Session s) => [
        _Dest('Home', Icons.space_dashboard_outlined, Icons.space_dashboard,
            const DashboardScreen()),
        _Dest('Members', Icons.group_outlined, Icons.group,
            const MembersScreen()),
        _Dest('Accounts', Icons.account_balance_wallet_outlined,
            Icons.account_balance_wallet, const AccountsScreen()),
        _Dest('Alerts', Icons.notifications_none_outlined,
            Icons.notifications, const NotificationsScreen()),
      ];

  List<_Dest> _more(Session s) => [
        if (s.canInvest)
          _Dest('Investment & Profit', Icons.trending_up_outlined,
              Icons.trending_up, const InvestmentScreen()),
        if (s.isAdmin)
          _Dest('Data Entry', Icons.edit_note_outlined, Icons.edit_note,
              const DataEntryScreen()),
        if (s.canReports)
          _Dest('Reports', Icons.description_outlined, Icons.description,
              const ReportsScreen()),
        if (s.canManageUsers)
          _Dest('Users & Permissions', Icons.admin_panel_settings_outlined,
              Icons.admin_panel_settings, const UsersScreen()),
        if (s.canAudit)
          _Dest('Audit Log', Icons.history_outlined, Icons.history,
              const AuditScreen()),
        _Dest('Profile & Settings', Icons.settings_outlined, Icons.settings,
            const ProfileScreen()),
      ];

  void _openMore(Session s) async {
    final picked = await showModalSheet<_Dest>(
      context,
      SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Modules',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onSurface)),
            const SizedBox(height: 14),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              childAspectRatio: 0.95,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              children: [
                for (final d in _more(s))
                  Card(
                    child: InkWell(
                      onTap: () => Navigator.pop(context, d),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(d.icon, size: 26),
                            const SizedBox(height: 8),
                            Text(d.label,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 10.5, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
    if (picked != null && mounted) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => picked.screen));
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    if (session.doc == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final dests = _primary(session);
    final safeIndex = _index.clamp(0, dests.length - 1);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppConfig.orgName, style: const TextStyle(fontSize: 17)),
            Text(
              session.doc!.role.label,
              style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            icon: const Icon(Icons.notifications_none),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const NotificationsScreen()),
            ),
          ),
        ],
      ),
      body: dests[safeIndex].screen,
      bottomNavigationBar: NavigationBar(
        selectedIndex: safeIndex,
        onDestinationSelected: (i) {
          if (i == dests.length) {
            _openMore(session);
            return;
          }
          setState(() => _index = i);
        },
        destinations: [
          for (final d in dests)
            NavigationDestination(
                icon: Icon(d.icon),
                selectedIcon: Icon(d.iconFilled),
                label: d.label),
          const NavigationDestination(
              icon: Icon(Icons.grid_view_outlined),
              selectedIcon: Icon(Icons.grid_view),
              label: 'More'),
        ],
      ),
    );
  }
}

class _Dest {
  final String label;
  final IconData icon;
  final IconData iconFilled;
  final Widget screen;
  _Dest(this.label, this.icon, this.iconFilled, this.screen);
}
