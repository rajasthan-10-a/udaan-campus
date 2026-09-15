import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:udaan_campus/models/user_role.dart';
import 'package:udaan_campus/services/auth_provider.dart';
import 'package:udaan_campus/services/supabase_storage_service.dart';

class LearningScreen extends StatefulWidget {
  const LearningScreen({super.key});

  @override
  State<LearningScreen> createState() => _LearningScreenState();
}

class _LearningScreenState extends State<LearningScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _youtubeUrlController = TextEditingController();
  final TextEditingController _videoUrlController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _uploadingVideo = false;
  String? _error;
  PlatformFile? _selectedVideoFile;
  List<Map<String, dynamic>> _courses = [];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _youtubeUrlController.dispose();
    _videoUrlController.dispose();
    super.dispose();
  }

  bool get _canManageCourses {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.user;
    return user != null && UserRole.isAtLeastManager(user.role);
  }

  Future<void> _loadCourses() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final query = await _firestore
          .collection('learning_courses')
          .orderBy('createdAt', descending: true)
          .get();

      final courses = query.docs.map((doc) {
        final data = doc.data();
        final timestamp = data['createdAt'];
        return {
          'id': doc.id,
          'title': data['title'] ?? 'Course',
          'description': data['description'] ?? '',
          'youtubeUrl': data['youtubeUrl'] as String? ?? '',
          'videoUrl': data['videoUrl'] as String? ?? '',
          'createdAt': timestamp is Timestamp ? timestamp.toDate() : DateTime.now(),
          'createdBy': data['createdBy'] ?? 'School Admin',
        };
      }).toList();

      if (!mounted) return;
      setState(() {
        _courses = courses;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load learning courses.';
        _loading = false;
      });
    }
  }

  Future<String> _uploadSelectedVideo() async {
    if (_selectedVideoFile == null) {
      return '';
    }

    setState(() {
      _uploadingVideo = true;
    });

    try {
      final storage = SupabaseStorageService();
      final uploadedUrl = await storage.uploadVideo(
        file: _selectedVideoFile!,
        bucket: 'learning-videos',
        folder: 'courses',
      );

      if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
        _videoUrlController.text = uploadedUrl;
        return uploadedUrl;
      }

      throw StateError('Video upload failed.');
    } catch (_) {
      if (!mounted) return '';
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to upload video to Supabase.')),
      );
      return '';
    } finally {
      if (mounted) {
        setState(() {
          _uploadingVideo = false;
        });
      }
    }
  }

  Future<void> _pickVideoFile() async {
    final result = await FilePicker.pickFile(type: FileType.video);

    if (result == null) {
      return;
    }

    if (!mounted) return;
    setState(() {
      _selectedVideoFile = result;
      if (result.name.isNotEmpty) {
        _videoUrlController.clear();
      }
    });
  }

  Future<void> _submitCourse() async {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final youtubeUrl = _youtubeUrlController.text.trim();
    var videoUrl = _videoUrlController.text.trim();
    final messenger = ScaffoldMessenger.maybeOf(context);
    final navigator = Navigator.of(context);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.user;

    if (title.isEmpty) {
      if (!mounted) return;
      messenger?.showSnackBar(
        const SnackBar(content: Text('Course title is required.')),
      );
      return;
    }

    if (_selectedVideoFile != null) {
      videoUrl = await _uploadSelectedVideo();
    }

    if (youtubeUrl.isEmpty && videoUrl.isEmpty) {
      if (!mounted) return;
      messenger?.showSnackBar(
        const SnackBar(content: Text('Add at least one YouTube or MP4 link.')),
      );
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final createdBy = (user != null && user.displayName.trim().isNotEmpty) ? user.displayName : 'School Admin';

      await _firestore.collection('learning_courses').add({
        'title': title,
        'description': description,
        'youtubeUrl': youtubeUrl,
        'videoUrl': videoUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': createdBy,
      });

      if (!mounted) return;
      _titleController.clear();
      _descriptionController.clear();
      _youtubeUrlController.clear();
      _videoUrlController.clear();
      _selectedVideoFile = null;
      navigator.pop();
      await _loadCourses();
      if (!mounted) return;
      messenger?.showSnackBar(
        const SnackBar(content: Text('Learning course added successfully.')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to save learning course.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _openLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid link.')),
      );
      return;
    }

    if (!await canLaunchUrl(uri)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open this link.')),
      );
      return;
    }

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _showCreateCourseSheet() {
    if (!_canManageCourses) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only manager or super manager can add courses.')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 20,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Add Learning Course',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Course Title',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descriptionController,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _youtubeUrlController,
                  decoration: const InputDecoration(
                    labelText: 'YouTube Video URL',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _videoUrlController,
                  decoration: const InputDecoration(
                    labelText: 'MP4 Video URL',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _uploadingVideo ? null : _pickVideoFile,
                  icon: const Icon(Icons.upload_file),
                  label: Text(_uploadingVideo
                      ? 'Uploading...'
                      : (_selectedVideoFile == null ? 'Upload video to Supabase' : 'Change selected video')),
                ),
                if (_selectedVideoFile != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Selected: ${_selectedVideoFile!.name}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                ],
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: (_saving || _uploadingVideo) ? null : _submitCourse,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: Text(_saving ? 'Saving...' : 'Save Course'),
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
        title: const Text('Learning Hub'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCourses,
          ),
        ],
      ),
      floatingActionButton: _canManageCourses
          ? FloatingActionButton.extended(
              onPressed: _showCreateCourseSheet,
              icon: const Icon(Icons.add),
              label: const Text('Add Course'),
            )
          : null,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  )
                : _courses.isEmpty
                    ? const Center(
                        child: Text('No learning courses available right now.'),
                      )
                    : ListView.separated(
                        itemCount: _courses.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final course = _courses[index];
                          final title = course['title'] as String;
                          final description = course['description'] as String;
                          final youtubeUrl = course['youtubeUrl'] as String? ?? '';
                          final videoUrl = course['videoUrl'] as String? ?? '';
                          final createdAt = course['createdAt'] as DateTime;

                          return Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).colorScheme.primary.withAlpha((0.12 * 255).round()),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Icon(
                                          Icons.school,
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          title,
                                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  if (description.isNotEmpty)
                                    Text(
                                      description,
                                      style: Theme.of(context).textTheme.bodyLarge,
                                    ),
                                  const SizedBox(height: 12),
                                  if (youtubeUrl.isNotEmpty) ...[
                                    ElevatedButton.icon(
                                      onPressed: () => _openLink(youtubeUrl),
                                      icon: const Icon(Icons.play_circle_fill),
                                      label: const Text('Open YouTube Video'),
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                  if (videoUrl.isNotEmpty) ...[
                                    ElevatedButton.icon(
                                      onPressed: () => _openLink(videoUrl),
                                      icon: const Icon(Icons.video_library),
                                      label: const Text('Open MP4 Video'),
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'All registered users',
                                        style: TextStyle(
                                          color: Colors.grey.shade700,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        DateFormat('dd MMM yyyy').format(createdAt),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
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
