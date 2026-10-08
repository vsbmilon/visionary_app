import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/permissions.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../services/repos.dart';
import '../state/hub.dart';
import '../state/session.dart';
import '../widgets/ui.dart';

/// Module 7 – Permission management.
/// Create users (secondary Firebase app so the admin stays signed in),
/// change roles, promote/demote admins, grant/revoke investment view,
/// lock/unlock accounts.
class UsersScreen extends StatelessWidget {
  const UsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final hub = context.watch<DataHub>();
    final session = context.watch<Session>();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Users & Permissions'),
        actions: [
          IconButton(
            tooltip: 'Create user',
            icon: const Icon(Icons.person_add_alt),
            onPressed: () => _createUser(context),
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: hub.users.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (ctx, i) {
          final u = hub.users[i];
          final isSelf = u.uid == session.user?.uid;
          final protected = u.role == Role.superAdmin;
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 19,
                        backgroundColor:
                            AppTheme.brandBlue.withValues(alpha: 0.12),
                        child: Text(
                            u.name.isNotEmpty
                                ? u.name[0].toUpperCase()
                                : u.email[0].toUpperCase(),
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: AppTheme.brandBlue)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                u.name.isNotEmpty
                                    ? u.name
                                    : u.email,
                                style: const TextStyle(
                                    fontSize: 13.5, fontWeight: FontWeight.w700)),
                            Text(u.email,
                                style: TextStyle(
                                    fontSize: 11,
                                    color: scheme.onSurfaceVariant)),
                          ],
                        ),
                      ),
                      StatusChip(
                        text: u.role.label.split(' ').first,
                        color: protected
                            ? AppTheme.brandBlueDark
                            : u.role.isAdmin
                                ? AppTheme.brandBlue
                                : u.role == Role.financeViewer
                                    ? AppTheme.warning
                                    : scheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      StatusChip(
                          text: u.active ? 'ACTIVE' : 'LOCKED',
                          color: u.active ? AppTheme.success : AppTheme.danger),
                      if (u.permissions[Perm.investment] == true ||
                          u.role.isAdmin)
                        const StatusChip(
                            text: 'INVESTMENT ACCESS', color: AppTheme.warning),
                      if (isSelf)
                        const StatusChip(text: 'YOU', color: AppTheme.brandAccent),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: (protected && !session.isSuper) ||
                              (protected && isSelf)
                          ? null
                          : () => _manage(context, u, session),
                      icon: const Icon(Icons.manage_accounts_outlined, size: 18),
                      label: const Text('Manage',
                          style: TextStyle(fontSize: 12.5)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _manage(
      BuildContext context, UserDoc u, Session session) async {
    Role role = u.role;
    bool active = u.active;
    bool invest = u.permissions[Perm.investment] == true;
    bool reports = u.permissions[Perm.reports] == true;
    await showModalSheet(
      context,
      StatefulBuilder(
        builder: (ctx, setSt) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(u.name.isNotEmpty ? u.name : u.email,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              DropdownButtonFormField<Role>(
                initialValue: role,
                decoration: const InputDecoration(labelText: 'Role'),
                items: [
                  for (final r in Role.values)
                    if (r != Role.superAdmin || session.isSuper)
                      DropdownMenuItem(value: r, child: Text(r.label)),
                ],
                onChanged: (v) => setSt(() => role = v!),
              ),
              const SizedBox(height: 4),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: invest,
                title: const Text('Investment & profit viewing rights',
                    style: TextStyle(fontSize: 13)),
                subtitle: const Text('Module 5 — confidential',
                    style: TextStyle(fontSize: 11)),
                onChanged: (v) => setSt(() => invest = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: reports,
                title: const Text('Reports access',
                    style: TextStyle(fontSize: 13)),
                onChanged: (v) => setSt(() => reports = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: active,
                title: Text(active ? 'Account active' : 'Account locked',
                    style: const TextStyle(fontSize: 13)),
                subtitle: Text(
                    active
                        ? 'User can sign in and use the app.'
                        : 'User is blocked from the app immediately.',
                    style: const TextStyle(fontSize: 11)),
                onChanged: (v) => setSt(() => active = v),
              ),
              const SizedBox(height: 10),
              FilledButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  final perms = Map<String, dynamic>.from(u.permissions);
                  perms[Perm.investment] = invest;
                  perms[Perm.reports] = reports;
                  await Repos.updateUserDoc(
                    UserDoc(
                      uid: u.uid,
                      email: u.email,
                      name: u.name,
                      phone: u.phone,
                      role: role,
                      active: active,
                      permissions: perms,
                      createdAt: u.createdAt,
                      createdBy: u.createdBy,
                      lastLoginAt: u.lastLoginAt,
                    ),
                    changeLabel:
                        'Permissions for ${u.email}: role=${role.key}, active=$active, investment=$invest, reports=$reports',
                  );
                  if (context.mounted) snack(context, 'Permissions updated.');
                },
                child: const Text('Save Changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Creates the Firebase Auth account through a SECONDARY Firebase app so
  /// the admin's own session is never disturbed, then writes the profile doc.
  Future<void> _createUser(BuildContext context) async {
    final name = TextEditingController();
    final email = TextEditingController();
    final pass = TextEditingController();
    Role role = Role.member;
    await showModalSheet(
      context,
      StatefulBuilder(
        builder: (ctx, setSt) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Create Approved User',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(
                  'Only people created here can ever sign in (Firestore rules reject unknown accounts).',
                  style: TextStyle(
                      fontSize: 11.5,
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 12),
              TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Full name')),
              const SizedBox(height: 10),
              TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email')),
              const SizedBox(height: 10),
              TextField(
                  controller: pass,
                  decoration: const InputDecoration(
                      labelText: 'Temporary password (min 6 chars)')),
              const SizedBox(height: 10),
              DropdownButtonFormField<Role>(
                initialValue: role,
                decoration: const InputDecoration(labelText: 'Role'),
                items: [
                  for (final r in Role.values)
                    DropdownMenuItem(value: r, child: Text(r.label)),
                ],
                onChanged: (v) => setSt(() => role = v!),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  if (email.text.trim().isEmpty || pass.text.length < 6) {
                    snack(context, 'Valid email + 6-char password required.',
                        error: true);
                    return;
                  }
                  Navigator.pop(ctx);
                  try {
                    final app = await Firebase.initializeApp(
                        name: 'user-mgmt-${DateTime.now().millisecondsSinceEpoch}',
                        options: Firebase.app().options);
                    final auth = FirebaseAuth.instanceFor(app: app);
                    final cred = await auth.createUserWithEmailAndPassword(
                        email: email.text.trim(), password: pass.text);
                    await Repos.createUserDoc(
                        uid: cred.user!.uid,
                        email: email.text.trim(),
                        name: name.text.trim(),
                        role: role);
                    await auth.signOut();
                    await app.delete();
                    if (context.mounted) {
                      snack(context, 'User created. Share the credentials securely.');
                    }
                  } catch (e) {
                    if (context.mounted) {
                      snack(context, 'Create failed: $e', error: true);
                    }
                  }
                },
                child: const Text('Create User'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
