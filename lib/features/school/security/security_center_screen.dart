import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:udaan_campus/models/user_role.dart';
import 'package:udaan_campus/services/auth_provider.dart';

class SecurityCenterScreen extends StatelessWidget {
  const SecurityCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).user;
    if (user?.role != UserRole.superManager) {
      return const Scaffold(
        body: Center(child: Text('Security Center is restricted to the super manager.')),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Security Center'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () {},
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('audit_logs')
            .orderBy('timestamp', descending: true)
            .limit(50)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const _SecurityState(
              icon: Icons.error_outline,
              message: 'Security events could not be loaded.',
            );
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const _SecurityState(
              icon: Icons.verified_user,
              message: 'No security events have been recorded yet.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final data = docs[index].data();
              final timestamp = data['timestamp'];
              final date = timestamp is Timestamp ? timestamp.toDate() : null;
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    child: const Icon(Icons.shield),
                  ),
                  title: Text(data['action']?.toString() ?? 'Security event'),
                  subtitle: Text(
                    '${data['targetType'] ?? 'record'}: ${data['targetId'] ?? '-'}\n'
                    'By: ${data['performedBy'] ?? '-'} (${data['performedByRole'] ?? '-'})'
                    '${date == null ? '' : '\n${date.toLocal()}'}',
                  ),
                  isThreeLine: true,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _SecurityState extends StatelessWidget {
  const _SecurityState({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 52, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 14),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
