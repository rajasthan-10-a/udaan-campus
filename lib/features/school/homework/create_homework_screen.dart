import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:udaan_campus/models/homework_model.dart';
import 'package:udaan_campus/models/user_role.dart';
import 'package:udaan_campus/services/auth_provider.dart';
import 'package:udaan_campus/services/attendance_service.dart';
import 'package:udaan_campus/services/homework_service.dart';
import 'package:udaan_campus/utils/utils.dart';

class CreateHomeworkScreen extends StatefulWidget {
  const CreateHomeworkScreen({super.key});

  @override
  State<CreateHomeworkScreen> createState() => _CreateHomeworkScreenState();
}

class _CreateHomeworkScreenState extends State<CreateHomeworkScreen> {
  final HomeworkService _homeworkService = HomeworkService();
  final AttendanceService _attendanceService = AttendanceService();
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _classNameController = TextEditingController();
  final TextEditingController _sectionController = TextEditingController();

  String _homeworkType = 'HOMEWORK';
  String _priority = 'NORMAL';
  bool _allowSubmission = true;
  bool _allowLateSubmission = false;
  DateTime _assignedDate = DateTime.now();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 1));
  final List<HomeworkAttachment> _attachments = [];
  bool _saving = false;
  String? _selectedClassSection;
  List<String> _classSectionOptions = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSections());
  }

  Future<void> _loadSections() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.user;
    if (user == null) return;
    try {
      if (user.role == UserRole.teacher) {
        final options = await _attendanceService.getAssignedClassSections(
          userUid: user.uid,
          role: user.role,
        );
        setState(() {
          _classSectionOptions = options;
          if (options.isNotEmpty) {
            _selectedClassSection = options.first;
          }
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Unable to load class section list.';
      });
    }
  }

  Future<void> _selectAssignedDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _assignedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() {
        _assignedDate = date;
        if (_dueDate.isBefore(_assignedDate)) {
          _dueDate = _assignedDate.add(const Duration(days: 1));
        }
      });
    }
  }

  Future<void> _selectDueDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: _assignedDate,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() {
        _dueDate = date;
      });
    }
  }

  Future<void> _pickAttachment() async {
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
        'temp',
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

  Future<void> _saveHomework(String status) async {
    if (!_formKey.currentState!.validate()) return;
    if (_dueDate.isBefore(_assignedDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Due date cannot be before assigned date.')),
      );
      return;
    }
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.user;
    if (user == null) return;
    if (_selectedClassSection == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select class and section.')),
      );
      return;
    }

    final parts = _selectedClassSection!.split('-');
    final classId = parts[0];
    final section = parts.length > 1 ? parts[1] : '';

    final homework = HomeworkModel(
      homeworkId: 'hw_${DateTime.now().millisecondsSinceEpoch}',
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      classId: classId,
      className: _classNameController.text.trim().isEmpty ? classId : _classNameController.text.trim(),
      section: section,
      subjectId: _subjectController.text.trim(),
      subjectName: _subjectController.text.trim(),
      teacherId: user.uid,
      teacherName: user.displayName.isNotEmpty ? user.displayName : user.email,
      assignedDate: _assignedDate,
      dueDate: _dueDate,
      priority: _priority,
      status: status,
      homeworkType: _homeworkType,
      allowSubmission: _allowSubmission,
      allowLateSubmission: _allowLateSubmission,
      attachments: _attachments,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      publishedAt: status == 'PUBLISHED' ? DateTime.now() : null,
    );

    setState(() {
      _saving = true;
    });

    try {
      await _homeworkService.createOrUpdateHomework(homework, user.uid, user.role);
      if (status == 'PUBLISHED') {
        await _homeworkService.publishHomework(homework, user.uid, user.role);
      }
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unable to save homework.')));
    } finally {
      setState(() {
        _saving = false;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _subjectController.dispose();
    _classNameController.dispose();
    _sectionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Homework')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
                  validator: (value) => value?.trim().isEmpty ?? true ? 'Please enter homework title.' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                  validator: (value) => value?.trim().isEmpty ?? true ? 'Please enter description.' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _homeworkType,
                  items: const [
                    'HOMEWORK',
                    'CLASSWORK',
                    'PROJECT',
                    'PRACTICE',
                    'REVISION',
                    'ASSIGNMENT',
                    'READING',
                    'OTHER'
                  ].map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
                  onChanged: (value) => setState(() => _homeworkType = value ?? 'HOMEWORK'),
                  decoration: const InputDecoration(labelText: 'Homework Type', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _priority,
                  items: const ['LOW', 'NORMAL', 'HIGH', 'URGENT']
                      .map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
                  onChanged: (value) => setState(() => _priority = value ?? 'NORMAL'),
                  decoration: const InputDecoration(labelText: 'Priority', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                if (_classSectionOptions.isNotEmpty)
                  DropdownButtonFormField<String>(
                    initialValue: _selectedClassSection,
                    items: _classSectionOptions
                        .map((value) => DropdownMenuItem(value: value, child: Text(value.toUpperCase())))
                        .toList(),
                    onChanged: (value) => setState(() => _selectedClassSection = value),
                    decoration: const InputDecoration(labelText: 'Class & Section', border: OutlineInputBorder()),
                  ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _subjectController,
                  decoration: const InputDecoration(labelText: 'Subject', border: OutlineInputBorder()),
                  validator: (value) => value?.trim().isEmpty ?? true ? 'Please enter subject.' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _selectAssignedDate,
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'Assigned Date', border: OutlineInputBorder()),
                          child: Text(DateTimeUtils.formatDate(_assignedDate)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: _selectDueDate,
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'Due Date', border: OutlineInputBorder()),
                          child: Text(DateTimeUtils.formatDate(_dueDate)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Allow Submission'),
                  value: _allowSubmission,
                  onChanged: (value) => setState(() => _allowSubmission = value),
                ),
                SwitchListTile(
                  title: const Text('Allow Late Submission'),
                  value: _allowLateSubmission,
                  onChanged: (value) => setState(() => _allowLateSubmission = value),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.attach_file),
                  label: const Text('Add Attachment'),
                  onPressed: _pickAttachment,
                ),
                const SizedBox(height: 8),
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
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _saving ? null : () => _saveHomework('DRAFT'),
                  child: const Text('Save Draft'),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _saving ? null : () => _saveHomework('PUBLISHED'),
                  child: const Text('Publish Homework'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
