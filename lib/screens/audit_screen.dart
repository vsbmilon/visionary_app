import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../models/models.dart';
import '../services/audit_service.dart';

/// Module 10 – Audit log: who added/edited what, when, old → new values.
class AuditScreen extends StatelessWidget {
  const AuditScreen({super.key});

  IconData _icon(String action) => switch (action) {
        'create' || 'import' => Icons.add_circle_outline,
        'update' => Icons.edit_outlined,
        'delete' => Icons.delete_outline,
        'permission' => Icons.admin_panel_settings_outlined,
        _ => Icons.info_outline,
      };

  Color _color(String action) => switch (action) {
        'create' || 'import' => AppTheme.success,
        'update' => AppTheme.brandBlue,
        'delete' => AppTheme.danger,
        'permission' => AppTheme.warning,
        _ => AppTheme.brandAccent,
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Audit Log')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: AuditService.stream(),
        builder: (ctx, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final logs =
              snap.data!.docs.map((d) => AuditLog.fromMap(d.data(), d.id)).toList();
          if (logs.isEmpty) {
            return const EmptyStateLite();
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            itemCount: logs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (ctx, i) {
              final l = logs[i];
              return Card(
                child: ListTile(
                  onTap: () => _detail(context, l),
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: _color(l.action).withValues(alpha: 0.12),
                    child: Icon(_icon(l.action), size: 17, color: _color(l.action)),
                  ),
                  title: Text(l.label.isEmpty ? '${l.action} ${l.entity}' : l.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w600)),
                  subtitle: Text(
                      '${l.actorName} • ${Fmt.dateTime(l.at?.toDate())}',
                      style:
                          TextStyle(fontSize: 10.5, color: scheme.onSurfaceVariant)),
                  trailing: Icon(Icons.chevron_right,
                      size: 18, color: scheme.onSurfaceVariant),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _detail(BuildContext context, AuditLog l) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l.label.isEmpty ? '${l.action} ${l.entity}' : l.label,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text('${l.actorName} • ${Fmt.dateTime(l.at?.toDate())} • ${l.action}',
                  style: TextStyle(
                      fontSize: 11.5,
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 14),
              if (l.before != null) ...[
                const Text('OLD VALUE',
                    style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.danger)),
                const SizedBox(height: 4),
                _json(l.before!),
                const SizedBox(height: 12),
              ],
              if (l.after != null) ...[
                const Text('NEW VALUE',
                    style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.success)),
                const SizedBox(height: 4),
                _json(l.after!),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _json(Map<String, dynamic> m) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: SelectableText(
          m.entries
              .map((e) => '${e.key}: ${e.value}')
              .join('\n'),
          style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
        ),
      );
}

class EmptyStateLite extends StatelessWidget {
  const EmptyStateLite({super.key});

  @override
  Widget build(BuildContext context) => const Center(
        child: Text('No audit entries yet.'),
      );
}
