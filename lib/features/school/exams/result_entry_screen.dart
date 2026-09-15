import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:udaan_campus/models/student.dart';
import 'package:udaan_campus/services/attendance_service.dart';
import 'package:udaan_campus/services/auth_provider.dart';

class ResultEntryScreen extends StatefulWidget {
  const ResultEntryScreen({super.key});

  @override
  State<ResultEntryScreen> createState() => _ResultEntryScreenState();
}

class _ResultEntryScreenState extends State<ResultEntryScreen> {
  static const List<String> _examTypes = [
    'First Unit Test',
    'Second Unit Test',
    'Third Unit Test',
    'Half Yearly Exam',
    'Yearly Exam',
  ];

  static const List<String> _numericSubjects = [
    'English',
    'Hindi',
    'Mathematics',
    'Science',
    'Social Science',
  ];

  static const List<String> _gradeSubjects = [
    'Sanskrit',
    'Computer',
    'SUPW',
  ];

  static const List<String> _subjects = [
    ..._numericSubjects,
    ..._gradeSubjects,
  ];

  final AttendanceService _attendanceService = AttendanceService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _loading = true;
  bool _saving = false;
  bool _loadingStudents = false;
  String? _error;
  List<String> _classSectionOptions = [];
  String? _selectedClassSection;
  String _selectedExamType = _examTypes.first;
  List<Student> _students = [];

  final Map<String, Map<String, TextEditingController>> _subjectControllers = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadClassSections());
  }

  @override
  void dispose() {
    for (final studentMap in _subjectControllers.values) {
      for (final controller in studentMap.values) {
        controller.dispose();
      }
    }
    super.dispose();
  }

  String _examKey(String examName) {
    return examName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll(RegExp(r'_$'), '');
  }

  bool _isGradeSubject(String subject) {
    return _gradeSubjects.contains(subject);
  }

  int _maxMarksForSelectedExam() {
    final exam = _selectedExamType.toLowerCase();
    if (exam.contains('half yearly') || exam.contains('yearly')) {
      return 80;
    }
    return 10;
  }

  int _totalMarksForSelectedExam() {
    return _numericSubjects.length * _maxMarksForSelectedExam();
  }

  Future<void> _loadClassSections() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.user;
    if (user == null) {
      setState(() {
        _error = 'Unable to load user information.';
        _loading = false;
      });
      return;
    }

    try {
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

      if (_selectedClassSection != null) {
        await _loadStudentsForClass();
      }
    } catch (_) {
      setState(() {
        _error = 'Unable to load class sections.';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _loadStudentsForClass() async {
    if (_selectedClassSection == null) {
      setState(() {
        _students = [];
        _subjectControllers.clear();
      });
      return;
    }

    final parts = _selectedClassSection!.split('-');
    if (parts.length != 2) {
      setState(() {
        _error = 'Please select a valid class and section.';
      });
      return;
    }

    setState(() {
      _loadingStudents = true;
      _error = null;
    });

    try {
      final classId = parts[0].trim();
      final section = parts[1].trim();
      final students = await _attendanceService.getStudentsForClassSection(
        classId: classId,
        section: section,
      );

      final studentControllers = <String, Map<String, TextEditingController>>{};
      for (final student in students) {
        final existing = await _loadSavedMarks(student.id);
        final map = <String, TextEditingController>{};
        for (final subject in _subjects) {
            final value = existing[subject];
            if (_isGradeSubject(subject)) {
              map[subject] = TextEditingController(text: value is String ? value : '');
            } else {
              map[subject] = TextEditingController(
                text: value != null ? value.toString() : '',
              );
            }
          }
          studentControllers[student.id] = map;
        }

      setState(() {
        _students = students;
        _subjectControllers.clear();
        _subjectControllers.addAll(studentControllers);
      });
    } catch (_) {
      setState(() {
        _error = 'Unable to load students for selected class.';
      });
    } finally {
      setState(() {
        _loadingStudents = false;
      });
    }
  }

  Future<Map<String, dynamic>> _loadSavedMarks(String studentId) async {
    try {
      final doc = await _firestore.collection('students').doc(studentId).get();
      final data = doc.data();
      if (data == null || data['marksheets'] is! Map) {
        return {};
      }

      final marksheets = Map<String, dynamic>.from(data['marksheets'] as Map);
      final examKey = _examKey(_selectedExamType);
      final examData = marksheets[examKey];
      if (examData is! Map) {
        return {};
      }

      final subjects = Map<String, dynamic>.from(examData['subjects'] ?? const {});
      final result = <String, dynamic>{};
      for (final subject in _subjects) {
        final value = subjects[subject];
        if (_isGradeSubject(subject) && value is String) {
          result[subject] = value;
        } else if (value is num) {
          result[subject] = value.toDouble();
        }
      }
      return result;
    } catch (_) {
      return {};
    }
  }

  double _calculateTotalForStudent(String studentId) {
    final controls = _subjectControllers[studentId] ?? {};
    var total = 0.0;
    for (final subject in _numericSubjects) {
      final value = double.tryParse(controls[subject]?.text.trim() ?? '') ?? 0;
      total += value;
    }
    return total;
  }

  Future<void> _saveMarks() async {
    if (!mounted) return;
    if (_selectedClassSection == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a class and section first.')),
      );
      return;
    }

    final maxMarks = _maxMarksForSelectedExam();
    final batch = _firestore.batch();
    for (final student in _students) {
      final controls = _subjectControllers[student.id] ?? {};
      final subjectScores = <String, dynamic>{};
      var total = 0.0;

      for (final subject in _subjects) {
        final raw = controls[subject]?.text.trim() ?? '';

        if (_isGradeSubject(subject)) {
          final grade = raw.isEmpty ? '' : raw.toUpperCase();
          if (grade.isNotEmpty && !['A+', 'A', 'B+', 'B', 'C+', 'C', 'D', 'E', 'F'].contains(grade)) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Invalid grade for ${student.name} in $subject. Use A+, A, B+, B, C+, C, D, E, or F.')),
            );
            return;
          }
          subjectScores[subject] = grade;
          continue;
        }

        final value = double.tryParse(raw) ?? 0.0;
        if (value < 0 || value > maxMarks) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Marks for ${student.name} in $subject must be between 0 and $maxMarks.')),
          );
          return;
        }
        subjectScores[subject] = value;
        total += value;
      }

      final studentRef = _firestore.collection('students').doc(student.id);
      final snapshot = await studentRef.get();
      final existingData = snapshot.data() ?? {};
      final marksheets = Map<String, dynamic>.from(existingData['marksheets'] is Map ? existingData['marksheets'] as Map : const {});
      marksheets[_examKey(_selectedExamType)] = {
        'subjects': subjectScores,
        'total': total,
        'outOf': _totalMarksForSelectedExam(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      batch.update(studentRef, {'marksheets': marksheets});
    }

    setState(() {
      _saving = true;
    });

    try {
      await batch.commit();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Result saved for $_selectedExamType')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to save marksheet. Please try again.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Widget _buildStudentCard(Student student) {
    final total = _calculateTotalForStudent(student.id);
    final maxTotal = _totalMarksForSelectedExam();

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    student.name,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Total: ${total.toStringAsFixed(1)}/$maxTotal',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('Roll No: ${student.rollNumber}'),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 2.5,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _subjects.length,
              itemBuilder: (context, index) {
                final subject = _subjects[index];
                final controller = _subjectControllers[student.id]?[subject];
                final isGradeSubject = _isGradeSubject(subject);
                return TextFormField(
                  controller: controller,
                  keyboardType: isGradeSubject ? TextInputType.text : const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: isGradeSubject
                      ? [FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z+\-]'))]
                      : [FilteringTextInputFormatter.allow(RegExp(r'\d*\.?\d*'))],
                  decoration: InputDecoration(
                    labelText: isGradeSubject ? '$subject (Grade)' : '$subject (0-${_maxMarksForSelectedExam()})',
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Result')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _selectedExamType,
                    items: _examTypes
                        .map((exam) => DropdownMenuItem(value: exam, child: Text(exam)))
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _selectedExamType = value;
                      });
                      if (_selectedClassSection != null) {
                        _loadStudentsForClass();
                      }
                    },
                    decoration: const InputDecoration(
                      labelText: 'Select Exam',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedClassSection,
                    items: _classSectionOptions
                        .map((option) => DropdownMenuItem(value: option, child: Text(option.toUpperCase())))
                        .toList(),
                    onChanged: (value) async {
                      if (value == null) return;
                      setState(() {
                        _selectedClassSection = value;
                      });
                      await _loadStudentsForClass();
                    },
                    decoration: const InputDecoration(
                      labelText: 'Select Class',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_error != null)
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  if (_loadingStudents)
                    const Expanded(child: Center(child: CircularProgressIndicator())),
                  if (!_loadingStudents && _students.isNotEmpty) ...[
                    Expanded(
                      child: ListView(
                        children: _students.map((student) => _buildStudentCard(student)).toList(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _saving ? null : _saveMarks,
                      child: _saving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save Result'),
                    ),
                  ],
                  if (!_loadingStudents && _students.isEmpty && _selectedClassSection != null && _error == null)
                    const Expanded(
                      child: Center(child: Text('No students found in this class.')),
                    ),
                ],
              ),
      ),
    );
  }
}
