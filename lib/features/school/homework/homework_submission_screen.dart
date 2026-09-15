import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:udaan_campus/models/homework_model.dart';
import 'package:udaan_campus/models/homework_submission_model.dart';
import 'package:udaan_campus/services/auth_provider.dart';
import 'package:udaan_campus/services/homework_service.dart';

class HomeworkSubmissionScreen extends StatefulWidget {
  const HomeworkSubmissionScreen({super.key, required this.homework});

  final HomeworkModel homework;

  @override
  State<HomeworkSubmissionScreen> createState() => _HomeworkSubmissionScreenState();
}

class _HomeworkSubmissionScreenState extends State<HomeworkSubmissionScreen> {
  final HomeworkService _homeworkService = HomeworkService();
  final TextEditingController _textResponseController = TextEditingController();
  final List<HomeworkAttachment> _attachments = [];
  bool _submitting = false;
  String? _error;

  Future<void> _pickSubmissionAttachment() async {
    final result = await FilePicker.pickFiles();
    if (result.isEmpty) return;
    if (!mounted) return;

    final userUid = Provider.of<AuthProvider>(context, listen: false).user?.uid ?? 'unknown';
    for (final file in result) {
      if (!_homeworkService.validateFileSize(file)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('File is too large.')));
        continue;
      }
      final filePath = file.path;
      if (filePath == null || filePath.isEmpty) continue;
      final fileSize = await file.length();
      final localFile = File(filePath);
      final fileUrl = await _homeworkService.uploadAttachment(
        localFile,
        userUid,
        widget.homework.homeworkId,
        (progress) {},
      );
      if (!mounted) return;
      setState(() {
        _attachments.add(HomeworkAttachment(
          filePath: file.path!,
          fileName: file.name,
          fileType: file.extension ?? 'unknown',
          fileSize: fileSize,
          fileUrl: fileUrl,
        ));
      });
    }
  }

  Future<void> _submit() async {
    if (!_submitting) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final user = auth.user;
      if (user == null || !mounted) return;
      if (_textResponseController.text.trim().isEmpty && _attachments.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add a response or attachments.')));
        return;
      }
      final id = '${widget.homework.homeworkId}_${user.uid}';
      final submission = HomeworkSubmissionModel(
        submissionId: id,
        homeworkId: widget.homework.homeworkId,
        studentId: user.uid,
        studentName: user.displayName.isNotEmpty ? user.displayName : user.email,
        classId: widget.homework.classId,
        section: widget.homework.section,
        submittedAt: DateTime.now(),
        textResponse: _textResponseController.text.trim(),
        attachments: _attachments,
        status: 'SUBMITTED',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      setState(() {
        _submitting = true;
      });
      try {
        await _homeworkService.saveSubmission(submission, user.uid, user.role);
        if (!mounted) return;
        Navigator.pop(context);
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _error = 'Unable to submit homework.';
        });
      } finally {
        if (mounted) {
          setState(() {
            _submitting = false;
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _textResponseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Submit Homework')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.homework.title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            TextFormField(
              controller: _textResponseController,
              minLines: 4,
              maxLines: 8,
              decoration: const InputDecoration(labelText: 'Text Answer', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.attach_file),
              label: const Text('Add Attachment'),
              onPressed: _pickSubmissionAttachment,
            ),
            if (_attachments.isNotEmpty)
              Column(
                children: _attachments
                    .map((attachment) => ListTile(
                          title: Text(attachment.fileName),
                          subtitle: Text('${(attachment.fileSize / 1024).toStringAsFixed(1)} KB'),
                        ))
                    .toList(),
              ),
            const SizedBox(height: 16),
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
            ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting ? const CircularProgressIndicator() : const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }
}
