import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/permissions.dart';
import '../core/config.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../models/models.dart';
import '../services/repos.dart';
import '../services/sheets_sync.dart';
import '../state/app_theme.dart';
import '../state/session.dart';
import '../widgets/ui.dart';

/// Profile & settings: theme (dark mode), profile edit, sync status, logout.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    final theme = context.watch<AppThemeController>();
    final scheme = Theme.of(context).colorScheme;
    final doc = session.doc!;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile & Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppTheme.brandBlue.withValues(alpha: 0.12),
                    child: Text(
                        (doc.name.isNotEmpty ? doc.name[0] : doc.email[0])
                            .toUpperCase(),
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.brandBlue)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(doc.name.isNotEmpty ? doc.name : doc.email,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w800)),
                        Text(doc.email,
                            style: TextStyle(
                                fontSize: 12, color: scheme.onSurfaceVariant)),
                        const SizedBox(height: 6),
                        StatusChip(text: doc.role.label, color: AppTheme.brandBlue),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'Appearance',
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
            child: SwitchListTile(
              value: theme.dark,
              onChanged: (v) => theme.setDark(v),
              secondary: Icon(
                  theme.dark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                  color: AppTheme.brandBlue),
              title: const Text('Dark mode',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
              subtitle: const Text('Material 3 dynamic dark theme',
                  style: TextStyle(fontSize: 11)),
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'My Profile',
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _editProfile(context, doc),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit name & phone'),
                ),
                const SizedBox(height: 8),
                Text(
                    'Last login: ${Fmt.dateTime(doc.lastLoginAt?.toDate())}',
                    style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'Data & Sync',
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                        SheetsSync.configured
                            ? Icons.cloud_done_outlined
                            : Icons.cloud_off_outlined,
                        size: 18,
                        color: SheetsSync.configured
                            ? AppTheme.success
                            : AppTheme.warning),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                          SheetsSync.configured
                              ? 'Google Sheets sync connected'
                              : 'Google Sheets sync not configured (Firestore-only mode)',
                          style: const TextStyle(fontSize: 12.5)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                    'Data is cached on-device (Firestore offline persistence), so the app opens instantly and uses minimal internet.',
                    style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'About',
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${AppConfig.orgName} Members App • v1.0.0',
                    style: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                    'Private distribution build (sideload APK). Not published on Google Play.',
                    style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.danger,
                side: const BorderSide(color: AppTheme.danger)),
            onPressed: () async {
              final ok = await confirmDialog(context, 'Sign out?',
                  'You will need your email and password to sign back in.',
                  okLabel: 'Sign Out');
              if (ok) await session.signOut();
            },
            icon: const Icon(Icons.logout, size: 18),
            label: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  Future<void> _editProfile(BuildContext context, UserDoc doc) async {
    final name = TextEditingController(text: doc.name);
    final phone = TextEditingController(text: doc.phone);
    await showModalSheet(
      context,
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Edit Profile',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Full name')),
            const SizedBox(height: 10),
            TextField(controller: phone, keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone')),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () async {
                Navigator.pop(context);
                await Repos.updateUserDoc(
                  UserDoc(
                    uid: doc.uid,
                    email: doc.email,
                    name: name.text.trim(),
                    phone: phone.text.trim(),
                    role: doc.role,
                    active: doc.active,
                    permissions: doc.permissions,
                    createdAt: doc.createdAt,
                    createdBy: doc.createdBy,
                    lastLoginAt: doc.lastLoginAt,
                  ),
                  changeLabel: 'Profile self-update by ${doc.email}',
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
