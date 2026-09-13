import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:udaan_campus/models/user_role.dart';
import 'package:udaan_campus/services/auth_provider.dart';
import 'package:udaan_campus/services/supabase_paper_storage_service.dart';

class PaperBuilderScreen extends StatefulWidget {
  const PaperBuilderScreen({super.key});

  @override
  State<PaperBuilderScreen> createState() => _PaperBuilderScreenState();
}

class _PaperBuilderScreenState extends State<PaperBuilderScreen> {
  final _title = TextEditingController();
  final _subject = TextEditingController();
  final _content = TextEditingController();
  final _storage = SupabasePaperStorageService();
  final _papers = FirebaseFirestore.instance.collection('exam_papers');
  PlatformFile? _source;
  List<String> _questions = [];
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _subject.dispose();
    _content.dispose();
    super.dispose();
  }

  Future<void> _pickSource() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );
    if (result.isNotEmpty && mounted) {
      setState(() => _source = result.first);
    }
  }

  void _generateDraft() {
    final lines = _content.text
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.length > 10)
        .toList();
    setState(() {
      _questions = lines.isEmpty
          ? ['Review source content and add the first question manually.']
          : lines.take(30).map((line) => 'Explain: $line').toList();
      _error = null;
    });
  }

  Future<void> _saveDraft() async {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user == null ||
        !(user.role == UserRole.teacher ||
            user.role == UserRole.superManager)) {
      return;
    }
    if (_title.text.trim().isEmpty || _subject.text.trim().isEmpty) {
      setState(() => _error = 'Enter paper title and subject.');
      return;
    }
    if (_source == null && _content.text.trim().isEmpty) {
      setState(() => _error = 'Upload a PDF/photo or paste source content.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      String? sourceUrl;
      String? sourcePath;
      if (_source?.path != null) {
        final extension = _source!.extension?.toLowerCase() ?? 'pdf';
        final path = '${user.uid}/builder_${DateTime.now().millisecondsSinceEpoch}.$extension';
        final url = await _storage.uploadPaper(
          path: path,
          file: File(_source!.path!),
          contentType: extension == 'pdf'
              ? 'application/pdf'
              : extension == 'png'
                  ? 'image/png'
                  : 'image/jpeg',
        );
        sourceUrl = url;
        sourcePath = path;
      }
      final doc = _papers.doc();
      await doc.set({
        'paperId': doc.id,
        'title': _title.text.trim(),
        'subject': _subject.text.trim(),
        'questions': _questions,
        'sourceContent': _content.text.trim(),
        'sourceUrl': sourceUrl,
        'sourcePath': sourcePath,
        'uploadedBy': user.uid,
        'uploadedByRole': user.role,
        'status': 'DRAFT_REVIEW_REQUIRED',
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        await SharePlus.instance.share(
          ShareParams(
            subject: _title.text.trim(),
            text: 'Paper draft created: ${_title.text.trim()}\n'
                'Questions: ${_questions.length}\n'
                'Status: Review required before publishing.',
            previewThumbnail: null,
          ),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Paper draft saved for review.')),
          );
        }
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Unable to create paper draft.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Paper Builder')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Upload teacher content or paste text. The ERP creates a reviewable question draft.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _title,
            decoration: const InputDecoration(
              labelText: 'Paper title',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _subject,
            decoration: const InputDecoration(
              labelText: 'Subject',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _pickSource,
            icon: const Icon(Icons.upload_file),
            label: Text(_source == null
                ? 'Upload PDF or content photo'
                : _source!.name),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _content,
            minLines: 6,
            maxLines: 12,
            decoration: const InputDecoration(
              labelText: 'Paste content (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _generateDraft,
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Generate question draft'),
          ),
          if (_questions.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Generated questions (${_questions.length})',
                style: Theme.of(context).textTheme.titleMedium),
            for (var i = 0; i < _questions.length; i++)
              ListTile(
                leading: Text('${i + 1}.'),
                title: Text(_questions[i]),
              ),
          ],
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _busy ? null : _saveDraft,
            icon: const Icon(Icons.picture_as_pdf),
            label: Text(_busy ? 'Saving...' : 'Save draft and share'),
          ),
        ],
      ),
    );
  }
}
