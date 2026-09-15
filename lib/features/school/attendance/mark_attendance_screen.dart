import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:udaan_campus/models/attendance_model.dart';
import 'package:udaan_campus/models/audit_log_model.dart';
import 'package:udaan_campus/models/attendance_summary_model.dart';
import 'package:udaan_campus/models/student.dart';
import 'package:udaan_campus/services/attendance_service.dart';
import 'package:udaan_campus/services/audit_service.dart';
import 'package:udaan_campus/services/auth_provider.dart';
import 'package:udaan_campus/utils/utils.dart';

class MarkAttendanceScreen extends StatefulWidget {
  const MarkAttendanceScreen({
    super.key,
    required this.classId,
    required this.className,
    required this.section,
    required this.selectedDate,
  });

  final String classId;
  final String className;
  final String section;
  final DateTime selectedDate;

  @override
  State<MarkAttendanceScreen> createState() => _MarkAttendanceScreenState();
}

class _MarkAttendanceScreenState extends State<MarkAttendanceScreen> {
  final AttendanceService _attendanceService = AttendanceService();
  final AuditService _auditService = AuditService();
  List<Student> _students = [];
  final Map<String, String> _attendanceStatus = {};
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final students = await _attendanceService.getStudentsForClassSection(
        classId: widget.classId,
        section: widget.section,
      );
      final attendance = await _attendanceService.getAttendanceForDate(
        classId: widget.classId,
        section: widget.section,
        date: widget.selectedDate,
      );

      setState(() {
        _students = students;
        _attendanceStatus.clear();
        for (final student in students) {
          final entry = attendance.firstWhere(
            (record) => record.studentId == student.id,
            orElse: () => AttendanceModel(
              attendanceId: '',
              studentId: student.id,
              classId: widget.classId,
              className: widget.className,
              section: widget.section,
              date: widget.selectedDate,
              status: 'unmarked',
              markedBy: '',
              markedByRole: '',
              method: 'manual',
              remarks: null,
              timestamp: widget.selectedDate,
              createdAt: widget.selectedDate,
              updatedAt: widget.selectedDate,
            ),
          );
          _attendanceStatus[student.id] = entry.status;
        }
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Unable to load students for attendance.';
        _loading = false;
      });
    }
  }

  void _markAllPresent() {
    setState(() {
      for (final student in _students) {
        _attendanceStatus[student.id] = 'present';
      }
    });
  }

  void _updateStatus(String studentId, String status) {
    setState(() {
      _attendanceStatus[studentId] = status;
    });
  }

  AttendanceSummaryModel _buildSummary() {
    return AttendanceSummaryModel.fromStatuses(_attendanceStatus.values.toList());
  }

  Future<void> _saveAttendance() async {
    final summary = _buildSummary();
    if (_students.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No students found to mark attendance.')));
      return;
    }
    if (summary.unmarked > 0) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Incomplete Attendance'),
          content: const Text('Please mark attendance for all students before saving.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Review')),
          ],
        ),
      );
      if (confirmed != true) return;
      return;
    }

    setState(() {
      _saving = true;
    });

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.user;
    if (user == null) {
      setState(() {
        _error = 'Unable to identify authenticated user.';
        _saving = false;
      });
      return;
    }

    try {
      final records = _students.map((student) {
        final status = _attendanceStatus[student.id] ?? 'unmarked';
        final attendanceId = _attendanceService.attendanceDocId(student.id, widget.selectedDate);
        return AttendanceModel(
          attendanceId: attendanceId,
          studentId: student.id,
          classId: widget.classId,
          className: widget.className,
          section: widget.section,
          date: widget.selectedDate,
          status: status,
          markedBy: user.uid,
          markedByRole: user.role,
          method: 'manual',
          remarks: null,
          timestamp: DateTime.now(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      }).toList();

      await _attendanceService.saveBulkAttendance(records: records);

      final auditId = _auditService.buildAuditId('attendance', widget.classId, DateTime.now());
      try {
        await _auditService.createAuditLog(
          AuditLogModel(
            auditId: auditId,
            action: 'ATTENDANCE_UPDATED',
            targetType: 'attendance',
            targetId: widget.classId,
            performedBy: user.uid,
            performedByRole: user.role,
            oldValue: null,
            newValue: {'statusSummary': summary.toJson()},
            timestamp: DateTime.now(),
          ),
        );
      } catch (_) {
        // Attendance is already persisted; audit logging must not make the save look unsuccessful.
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Attendance saved successfully.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Attendance could not be saved completely. Please retry.')));
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Widget _buildStatusButton(String studentId, String status, String label, Color color) {
    final selected = _attendanceStatus[studentId] == status;
    return Expanded(
      child: OutlinedButton(
        onPressed: () => _updateStatus(studentId, status),
        style: OutlinedButton.styleFrom(
          backgroundColor: selected ? color.withAlpha((0.12 * 255).round()) : null,
          side: BorderSide(color: selected ? color : Colors.grey.shade300),
        ),
        child: Text(label, style: TextStyle(color: selected ? color : Colors.black87)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final summary = _buildSummary();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mark Attendance'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!))
                : Column(
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 12),
                      _buildSummaryCard(summary),
                      const SizedBox(height: 12),
                      Expanded(child: _buildStudentList()),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _markAllPresent,
                              child: const Text('MARK ALL PRESENT'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _saving ? null : _saveAttendance,
                              child: _saving
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Text('SAVE ATTENDANCE'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Class: ${widget.className}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text('Section: ${widget.section}', style: const TextStyle(fontSize: 14, color: Colors.grey)),
        const SizedBox(height: 4),
        Text('Date: ${DateTimeUtils.formatDate(widget.selectedDate)}', style: const TextStyle(fontSize: 14, color: Colors.grey)),
      ],
    );
  }

  Widget _buildSummaryCard(AttendanceSummaryModel summary) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSummaryTile('Total', summary.totalStudents.toString()),
            _buildSummaryTile('Present', summary.present.toString()),
            _buildSummaryTile('Absent', summary.absent.toString()),
            _buildSummaryTile('Late', summary.late.toString()),
            _buildSummaryTile('Half Day', summary.halfDay.toString()),
            _buildSummaryTile('Leave', summary.leave.toString()),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryTile(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildStudentList() {
    return ListView.separated(
      itemCount: _students.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final student = _students[index];
        final status = _attendanceStatus[student.id] ?? 'unmarked';
        return Card(
          elevation: 1,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${index + 1}. ${student.name}', style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('Roll No: ${student.rollNumber}', style: TextStyle(color: Colors.grey[700])),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildStatusButton(student.id, 'present', 'Present', Colors.green),
                    const SizedBox(width: 6),
                    _buildStatusButton(student.id, 'absent', 'Absent', Colors.red),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _buildStatusButton(student.id, 'late', 'Late', Colors.orange),
                    const SizedBox(width: 6),
                    _buildStatusButton(student.id, 'half_day', 'Half Day', Colors.purple),
                    const SizedBox(width: 6),
                    _buildStatusButton(student.id, 'leave', 'Leave', Colors.blue),
                  ],
                ),
                if (status == 'unmarked')
                  const Padding(
                    padding: EdgeInsets.only(top: 8.0),
                    child: Text('Status: Unmarked', style: TextStyle(color: Colors.redAccent)),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
