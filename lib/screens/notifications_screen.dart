import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../models/models.dart';
import '../services/repos.dart';
import '../state/hub.dart';
import '../state/session.dart';
import '../widgets/ui.dart';

/// Module 9 – Notification center (+ admin composer).
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  IconData _icon(String type) => switch (type) {
        'deposit' => Icons.savings_outlined,
        'reminder' => Icons.alarm_outlined,
        'investment' => Icons.trending_up,
        'balance' => Icons.account_balance_outlined,
        _ => Icons.campaign_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final hub = context.watch<DataHub>();
    final session = context.watch<Session>();
    final scheme = Theme.of(context).colorScheme;
    final list = hub.notificationsFor(session.user!.uid, session.role);

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      floatingActionButton: session.isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _compose(context),
              icon: const Icon(Icons.campaign_outlined),
              label: const Text('Announce'),
            )
          : null,
      body: list.isEmpty
          ? const EmptyState(
              icon: Icons.notifications_none,
              title: 'No notifications yet',
              message: 'Deposit updates, reminders and announcements appear here.')
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (ctx, i) {
                final n = list[i];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          AppTheme.brandBlue.withValues(alpha: 0.12),
                      child: Icon(_icon(n.type),
                          size: 19, color: AppTheme.brandBlue),
                    ),
                    title: Text(n.title,
                        style: const TextStyle(
                            fontSize: 13.5, fontWeight: FontWeight.w700)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 3),
                        Text(n.body,
                            style: const TextStyle(fontSize: 12)),
                        const SizedBox(height: 4),
                        Text(Fmt.dateTime(n.createdAt?.toDate()),
                            style: TextStyle(
                                fontSize: 10, color: scheme.onSurfaceVariant)),
                      ],
                    ),
                    isThreeLine: true,
                  ),
                );
              },
            ),
    );
  }

  Future<void> _compose(BuildContext context) async {
    final title = TextEditingController();
    final body = TextEditingController();
    String type = 'announcement';
    String audience = 'all';
    await showModalSheet(
      context,
      StatefulBuilder(
        builder: (ctx, setSt) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Send Announcement',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              TextField(
                  controller: title,
                  decoration: const InputDecoration(labelText: 'Title')),
              const SizedBox(height: 10),
              TextField(
                  controller: body,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Message')),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: type,
                decoration: const InputDecoration(labelText: 'Type'),
                items: const [
                  DropdownMenuItem(value: 'announcement', child: Text('Announcement')),
                  DropdownMenuItem(value: 'reminder', child: Text('Monthly reminder')),
                  DropdownMenuItem(value: 'deposit', child: Text('Deposit update')),
                  DropdownMenuItem(value: 'investment', child: Text('Investment update')),
                  DropdownMenuItem(value: 'balance', child: Text('Balance update')),
                ],
                onChanged: (v) => setSt(() => type = v!),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: audience,
                decoration: const InputDecoration(labelText: 'Audience'),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('Everyone')),
                  DropdownMenuItem(value: 'admins', child: Text('Admins only')),
                  DropdownMenuItem(
                      value: 'invest', child: Text('Investment-authorized only')),
                ],
                onChanged: (v) => setSt(() => audience = v!),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  if (title.text.trim().isEmpty) return;
                  Navigator.pop(ctx);
                  await Repos.postNotification(AppNotification(
                      id: '',
                      title: title.text.trim(),
                      body: body.text.trim(),
                      type: type,
                      audience: audience));
                  if (context.mounted) snack(context, 'Notification sent.');
                },
                child: const Text('Send'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
