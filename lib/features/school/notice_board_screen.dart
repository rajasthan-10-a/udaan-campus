import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:udaan_campus/models/user_role.dart';
import 'package:udaan_campus/services/auth_provider.dart';

class NoticeBoardScreen extends StatefulWidget {
  const NoticeBoardScreen({super.key});

  @override
  State<NoticeBoardScreen> createState() => _NoticeBoardScreenState();
}

class _NoticeBoardScreenState extends State<NoticeBoardScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _imageUrlController = TextEditingController();
  final TextEditingController _attachmentUrlController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _error;
  String _selectedType = 'General';
  List<Map<String, dynamic>> _notices = [];

  static const List<String> _noticeTypes = [
    'General',
    'Meeting',
    'Exam',
    'Vacation',
    'Event',
  ];

  @override
  void initState() {
    super.initState();
    _loadNotices();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    _imageUrlController.dispose();
    _attachmentUrlController.dispose();
    super.dispose();
  }

  bool get _canPublishNotice {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.user;
    return user != null && (UserRole.isAtLeastManager(user.role) || UserRole.isTeacher(user.role));
  }

  Future<void> _loadNotices() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final query = await _firestore
          .collection('notifications')
          .orderBy('createdAt', descending: true)
          .get();

      final notices = query.docs.map((doc) {
        final data = doc.data();
        final timestamp = data['createdAt'];
        return {
          'id': doc.id,
          'title': data['title'] ?? 'Notice',
          'message': data['message'] ?? '',
          'imageUrl': data['imageUrl'] as String? ?? '',
          'attachmentUrl': data['attachmentUrl'] as String? ?? '',
          'createdAt': timestamp is Timestamp ? timestamp.toDate() : DateTime.now(),
          'targetType': data['targetType'] ?? 'general',
          'targetClassId': data['targetClassId'],
          'targetSection': data['targetSection'],
        };
      }).toList();

      setState(() {
        _notices = notices;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Unable to load notices.';
        _loading = false;
      });
    }
  }

  Future<void> _submitNotice() async {
    final title = _titleController.text.trim();
    final message = _messageController.text.trim();
    final imageUrl = _imageUrlController.text.trim();
    final attachmentUrl = _attachmentUrlController.text.trim();

    if (title.isEmpty || message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title and message are required.')),
      );
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await _firestore.collection('notifications').add({
        'title': title,
        'message': message,
        'imageUrl': imageUrl,
        'attachmentUrl': attachmentUrl,
        'targetType': _selectedType.toLowerCase(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      _titleController.clear();
      _messageController.clear();
      _imageUrlController.clear();
      _attachmentUrlController.clear();
      setState(() {
        _selectedType = 'General';
      });
      Navigator.pop(context);
      await _loadNotices();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notice published successfully.')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to publish notice.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _openAttachment(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !await canLaunchUrl(uri)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open attachment.')),
      );
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _showCreateNoticeSheet() {
    if (!_canPublishNotice) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only staff can publish notices.')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Publish Notice',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _selectedType,
                  items: _noticeTypes
                      .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedType = value;
                      });
                    }
                  },
                  decoration: const InputDecoration(
                    labelText: 'Type',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Notice Title',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _messageController,
                  minLines: 4,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    labelText: 'Message',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _imageUrlController,
                  decoration: const InputDecoration(
                    labelText: 'Image URL (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _attachmentUrlController,
                  decoration: const InputDecoration(
                    labelText: 'PDF / attachment URL (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _saving ? null : _submitNotice,
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Publish Notice'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notice Board'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadNotices,
          ),
        ],
      ),
      floatingActionButton: _canPublishNotice
          ? FloatingActionButton.extended(
              onPressed: _showCreateNoticeSheet,
              icon: const Icon(Icons.add),
              label: const Text('Add Notice'),
            )
          : null,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                : _notices.isEmpty
                    ? const Center(child: Text('No notices yet.'))
                    : ListView.separated(
                        itemCount: _notices.length,
                        separatorBuilder: (context, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final notice = _notices[index];
                          final createdAt = notice['createdAt'] as DateTime;
                          final title = notice['title'] as String;
                          final message = notice['message'] as String;
                          final targetType = (notice['targetType'] as String? ?? 'general').toUpperCase();
                          final imageUrl = notice['imageUrl'] as String? ?? '';
                          final attachmentUrl = notice['attachmentUrl'] as String? ?? '';
                          final classMeta = notice['targetClassId'] != null && notice['targetSection'] != null
                              ? 'For: ${notice['targetClassId']}-${notice['targetSection']}'
                              : '';

                          return Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).colorScheme.primary.withAlpha((0.12 * 255).round()),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Icon(
                                          Icons.campaign,
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          title,
                                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  if (imageUrl.isNotEmpty)
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.network(
                                        imageUrl,
                                        height: 180,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => Container(
                                          height: 180,
                                          color: Colors.grey.shade200,
                                          alignment: Alignment.center,
                                          child: const Text('Image unavailable'),
                                        ),
                                      ),
                                    ),
                                  if (imageUrl.isNotEmpty) const SizedBox(height: 12),
                                  Text(
                                    message,
                                    style: Theme.of(context).textTheme.bodyLarge,
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.shade100,
                                          borderRadius: BorderRadius.circular(999),
                                        ),
                                        child: Text(
                                          targetType,
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                                        ),
                                      ),
                                      Text(
                                        DateFormat('dd MMM yyyy, hh:mm a').format(createdAt),
                                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                      ),
                                    ],
                                  ),
                                  if (classMeta.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      classMeta,
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                    ),
                                  ],
                                  if (attachmentUrl.isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed: () => _openAttachment(attachmentUrl),
                                        icon: const Icon(Icons.attach_file),
                                        label: const Text('Open PDF / Attachment'),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}
