import 'package:flutter/material.dart';
import 'package:udaan_campus/models/student.dart';
import 'package:udaan_campus/services/attendance_service.dart';
import 'package:udaan_campus/features/school/attendance/student_qr_screen.dart';
import 'package:udaan_campus/features/school/attendance/add_student_screen.dart';

class QrStudentManagementScreen extends StatefulWidget {
  const QrStudentManagementScreen({super.key});

  @override
  State<QrStudentManagementScreen> createState() => _QrStudentManagementScreenState();
}

class _QrStudentManagementScreenState extends State<QrStudentManagementScreen> {
  final AttendanceService _attendanceService = AttendanceService();
  final TextEditingController _searchController = TextEditingController();
  List<Student> _students = [];
  List<Student> _filteredStudents = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStudents();
    _searchController.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchController.removeListener(_applyFilter);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStudents() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final snapshot = await _attendanceService.studentsCollection.orderBy('classId').orderBy('section').orderBy('rollNumber').get();
      final students = snapshot.docs
          .map((doc) {
            final data = Map<String, dynamic>.from(doc.data());
            data['id'] = doc.id;
            return Student.fromJson(data);
          })
          .toList();
      setState(() {
        _students = students;
        _filteredStudents = students;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Unable to load students.';
        _loading = false;
      });
    }
  }

  void _applyFilter() {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() {
        _filteredStudents = _students;
      });
      return;
    }

    setState(() {
      _filteredStudents = _students.where((student) {
        return student.name.toLowerCase().contains(query) ||
            student.rollNumber.toLowerCase().contains(query) ||
            (student.classId ?? '').toLowerCase().contains(query) ||
            (student.section ?? '').toLowerCase().contains(query) ||
            student.id.toLowerCase().contains(query);
      }).toList();
    });
  }

  void _openStudentQr(Student student) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => StudentQrScreen(studentId: student.id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Student Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            tooltip: 'Add student',
            onPressed: () async {
              final added = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => const AddStudentScreen()),
              );
              if (added == true) _loadStudents();
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStudents,
            tooltip: 'Refresh list',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          labelText: 'Search by name, roll, class, or section',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: _filteredStudents.isEmpty
                            ? const Center(child: Text('No students found.'))
                            : ListView.separated(
                                itemCount: _filteredStudents.length,
                                separatorBuilder: (context, _) => const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final student = _filteredStudents[index];
                                  return ListTile(
                                    leading: CircleAvatar(child: Text(student.name.isNotEmpty ? student.name[0] : '?')),
                                    title: Text(student.name),
                                    subtitle: Text('Class: ${student.classId ?? 'N/A'} - ${student.section ?? 'N/A'}\nRoll: ${student.rollNumber}'),
                                    isThreeLine: true,
                                    trailing: const Icon(Icons.arrow_forward),
                                    onTap: () => _openStudentQr(student),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
      ),
    );
  }
}
