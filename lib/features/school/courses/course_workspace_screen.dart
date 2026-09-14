import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:udaan_campus/models/user_role.dart';
import 'package:udaan_campus/services/auth_provider.dart';

class CourseWorkspaceScreen extends StatelessWidget {
  const CourseWorkspaceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).user;
    final canManage = user != null &&
        (user.role == UserRole.superManager || user.role == UserRole.manager);
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Courses & Learning'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.menu_book), text: 'Courses'),
              Tab(icon: Icon(Icons.video_library), text: 'Resources'),
              Tab(icon: Icon(Icons.quiz), text: 'Mock Tests'),
            ],
          ),
        ),
        floatingActionButton: canManage
            ? Builder(
                builder: (context) => FloatingActionButton.extended(
                  onPressed: () => _showCreateCourse(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Create course'),
                ),
              )
            : null,
        body: TabBarView(
          children: [
            _CourseList(canManage: canManage),
            _ResourceList(canManage: canManage),
            _MockTestList(canManage: canManage),
          ],
        ),
      ),
    );
  }

  Future<void> _showCreateCourse(BuildContext context) async {
    final title = TextEditingController();
    final subject = TextEditingController();
    final description = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Create course'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: title,
                  decoration: const InputDecoration(labelText: 'Course title'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a course title'
                      : null,
                ),
                TextFormField(
                  controller: subject,
                  decoration: const InputDecoration(labelText: 'Subject'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a subject'
                      : null,
                ),
                TextFormField(
                  controller: description,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final user = Provider.of<AuthProvider>(context, listen: false).user;
              if (user == null) return;
              final ref = FirebaseFirestore.instance.collection('courses').doc();
              await ref.set({
                'courseId': ref.id,
                'title': title.text.trim(),
                'subject': subject.text.trim(),
                'description': description.text.trim(),
                'status': 'DRAFT',
                'createdBy': user.uid,
                'createdAt': FieldValue.serverTimestamp(),
                'updatedAt': FieldValue.serverTimestamp(),
              });
              if (dialogContext.mounted) Navigator.pop(dialogContext, true);
            },
            child: const Text('Save draft'),
          ),
        ],
      ),
    );
    title.dispose();
    subject.dispose();
    description.dispose();
    if (result == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Course draft created.')),
      );
    }
  }
}

class _CourseList extends StatelessWidget {
  const _CourseList({required this.canManage});

  final bool canManage;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('courses')
          .where('status', isEqualTo: canManage ? 'DRAFT' : 'PUBLISHED')
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const _EmptyState(message: 'Unable to load courses.');
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) return const _EmptyState(message: 'No courses published yet.');
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final data = docs[index].data();
            return Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.menu_book)),
                title: Text(data['title']?.toString() ?? 'Untitled course'),
                subtitle: Text(
                  '${data['subject'] ?? 'General'}\n${data['description'] ?? ''}',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                isThreeLine: true,
                trailing: Text(data['status']?.toString() ?? ''),
              ),
            );
          },
        );
      },
    );
  }
}

class _ResourceList extends StatelessWidget {
  const _ResourceList({required this.canManage});

  final bool canManage;

  @override
  Widget build(BuildContext context) {
    return _CollectionList(
      collection: 'course_resources',
      canManage: canManage,
      emptyMessage: 'No video or study resources published yet.',
      icon: Icons.video_library,
      titleKey: 'title',
      subtitleKeys: const ['type', 'url'],
    );
  }
}

class _MockTestList extends StatelessWidget {
  const _MockTestList({required this.canManage});

  final bool canManage;

  @override
  Widget build(BuildContext context) {
    return _CollectionList(
      collection: 'mock_tests',
      canManage: canManage,
      emptyMessage: 'No mock tests published yet.',
      icon: Icons.quiz,
      titleKey: 'title',
      subtitleKeys: const ['subject', 'questionCount'],
    );
  }
}

class _CollectionList extends StatelessWidget {
  const _CollectionList({
    required this.collection,
    required this.canManage,
    required this.emptyMessage,
    required this.icon,
    required this.titleKey,
    required this.subtitleKeys,
  });

  final String collection;
  final bool canManage;
  final String emptyMessage;
  final IconData icon;
  final String titleKey;
  final List<String> subtitleKeys;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection(collection)
          .where('status', isEqualTo: canManage ? 'DRAFT' : 'PUBLISHED')
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _EmptyState(message: 'Unable to load $collection.'),
              if (canManage)
                _CreateLearningButton(collection: collection),
            ],
          );
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _EmptyState(message: emptyMessage),
              if (canManage)
                _CreateLearningButton(collection: collection),
            ],
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (canManage)
              Align(
                alignment: Alignment.centerRight,
                child: _CreateLearningButton(collection: collection),
              ),
            ...docs.map((doc) {
              final data = doc.data();
              final subtitle = subtitleKeys
                  .map((key) => data[key]?.toString())
                  .whereType<String>()
                  .where((value) => value.isNotEmpty)
                  .join(' • ');
              return Card(
                child: ListTile(
                  leading: CircleAvatar(child: Icon(icon)),
                  title: Text(data[titleKey]?.toString() ?? 'Untitled'),
                  subtitle: Text(subtitle.isEmpty ? 'Review required' : subtitle),
                  trailing: Text(data['status']?.toString() ?? ''),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

class _CreateLearningButton extends StatelessWidget {
  const _CreateLearningButton({required this.collection});

  final String collection;

  @override
  Widget build(BuildContext context) {
    final isResource = collection == 'course_resources';
    return FilledButton.icon(
      onPressed: () => _showLearningEntryDialog(context, collection),
      icon: Icon(isResource ? Icons.video_call : Icons.quiz),
      label: Text(isResource ? 'Add video/resource' : 'Create mock test'),
    );
  }
}

Future<void> _showLearningEntryDialog(
  BuildContext context,
  String collection,
) async {
  final title = TextEditingController();
  final subject = TextEditingController();
  final linkOrCount = TextEditingController();
  final isResource = collection == 'course_resources';
  final formKey = GlobalKey<FormState>();
  final saved = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(isResource ? 'Add video/resource' : 'Create mock test'),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: title,
              decoration: const InputDecoration(labelText: 'Title'),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Enter a title' : null,
            ),
            TextFormField(
              controller: subject,
              decoration: const InputDecoration(labelText: 'Subject'),
            ),
            TextFormField(
              controller: linkOrCount,
              keyboardType: isResource ? TextInputType.url : TextInputType.number,
              decoration: InputDecoration(
                labelText: isResource ? 'Video/resource URL' : 'Question count',
              ),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'This field is required' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
        FilledButton(
          onPressed: () async {
            if (!formKey.currentState!.validate()) return;
            final user = Provider.of<AuthProvider>(context, listen: false).user;
            if (user == null) return;
            final ref = FirebaseFirestore.instance.collection(collection).doc();
            await ref.set({
              'id': ref.id,
              'title': title.text.trim(),
              'subject': subject.text.trim(),
              if (isResource) 'url': linkOrCount.text.trim(),
              if (isResource) 'type': 'VIDEO_OR_RESOURCE',
              if (!isResource)
                'questionCount': int.tryParse(linkOrCount.text.trim()) ?? 0,
              'status': 'DRAFT',
              'createdBy': user.uid,
              'createdAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            });
            if (dialogContext.mounted) Navigator.pop(dialogContext, true);
          },
          child: const Text('Save draft'),
        ),
      ],
    ),
  );
  title.dispose();
  subject.dispose();
  linkOrCount.dispose();
  if (saved == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Learning draft created for review.')),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}
