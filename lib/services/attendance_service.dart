import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:udaan_campus/models/attendance_model.dart';
import 'package:udaan_campus/models/attendance_report_model.dart';
import 'package:udaan_campus/models/attendance_summary_model.dart';
import 'package:udaan_campus/models/student.dart';
import 'package:udaan_campus/models/user_role.dart';

class AttendanceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get attendanceCollection =>
      _firestore.collection('attendance');

  CollectionReference<Map<String, dynamic>> get studentsCollection =>
      _firestore.collection('students');

  CollectionReference<Map<String, dynamic>> get usersCollection =>
      _firestore.collection('users');

  Future<List<String>> getAssignedClassSections({
    required String userUid,
    required String role,
  }) async {
    final userSnapshot = await usersCollection.doc(userUid).get();
    if (!userSnapshot.exists || userSnapshot.data() == null) {
      return [];
    }

    final data = userSnapshot.data()!;
    if (UserRole.isTeacher(role)) {
      return data['assignedClassSections'] != null
          ? List<String>.from(data['assignedClassSections'] as List<dynamic>)
          : [];
    }

    final query = await studentsCollection.get();
    final sections = <String>{};
    for (final doc in query.docs) {
      final student = doc.data();
      final classId = student['classId'] as String?;
      final section = student['section'] as String?;
      if (classId != null && section != null) {
        sections.add('$classId-$section');
      }
    }
    return sections.toList()..sort();
  }

  Future<List<Student>> getStudentsForClassSection({
    required String classId,
    required String section,
  }) async {
    final query = await studentsCollection
        .where('classId', isEqualTo: classId)
        .where('section', isEqualTo: section)
        .orderBy('rollNumber')
        .get();
    return query.docs
        .map((doc) {
          final json = Map<String, dynamic>.from(doc.data());
          json['id'] = doc.id;
          return Student.fromJson(json);
        })
        .toList();
  }

  Future<Student?> getStudentByEmail(String email) async {
    final query = await studentsCollection.where('email', isEqualTo: email).limit(1).get();
    if (query.docs.isEmpty) return null;
    final doc = query.docs.first;
    final data = Map<String, dynamic>.from(doc.data())..['id'] = doc.id;
    return Student.fromJson(data);
  }

  Future<List<Student>> getStudentsByIds(List<String> studentIds) async {
    if (studentIds.isEmpty) return [];
    final results = <Student>[];
    final chunkSize = 10;
    for (var start = 0; start < studentIds.length; start += chunkSize) {
      final chunk = studentIds.sublist(start, min(start + chunkSize, studentIds.length));
      final query = await studentsCollection
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final doc in query.docs) {
        final json = Map<String, dynamic>.from(doc.data())..['id'] = doc.id;
        results.add(Student.fromJson(json));
      }
    }
    return results;
  }

  Future<List<AttendanceModel>> getAttendanceForDate({
    required String classId,
    required String section,
    required DateTime date,
  }) async {
    final query = await attendanceCollection
        .where('classId', isEqualTo: classId)
        .where('section', isEqualTo: section)
        .where('date', isEqualTo: Timestamp.fromDate(DateTime(date.year, date.month, date.day)))
        .get();

    return query.docs
        .map((doc) => AttendanceModel.fromJson(doc.data()))
        .toList();
  }

  Future<bool> attendanceExists({
    required String studentId,
    required DateTime date,
  }) async {
    final attendanceId = attendanceDocId(studentId, date);
    final snapshot = await attendanceCollection.doc(attendanceId).get();
    return snapshot.exists;
  }

  String attendanceDocId(String studentId, DateTime date) {
    return _attendanceDocId(studentId, date);
  }

  Future<void> saveBulkAttendance({
    required List<AttendanceModel> records,
  }) async {
    final batch = _firestore.batch();
    final docs = records.map((record) => attendanceCollection.doc(record.attendanceId)).toList();
    final existing = await Future.wait(docs.map((doc) => doc.get()));

    for (var i = 0; i < records.length; i++) {
      final record = records[i];
      final docRef = docs[i];
      final docSnapshot = existing[i];
      final data = record.toJson();
      data['updatedAt'] = FieldValue.serverTimestamp();
      if (docSnapshot.exists) {
        data.remove('createdAt');
        batch.set(docRef, data, SetOptions(merge: true));
      } else {
        data['createdAt'] = FieldValue.serverTimestamp();
        batch.set(docRef, data);
      }
    }

    await batch.commit();
  }

  Future<AttendanceModel?> getAttendanceByStudentAndDate({
    required String studentId,
    required DateTime date,
  }) async {
    final docRef = attendanceCollection.doc(_attendanceDocId(studentId, date));
    final snapshot = await docRef.get();
    if (!snapshot.exists || snapshot.data() == null) return null;
    return AttendanceModel.fromJson(snapshot.data()!);
  }

  Future<List<AttendanceModel>> getStudentAttendanceHistory({
    required String studentId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final query = await attendanceCollection
        .where('studentId', isEqualTo: studentId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(DateTime(startDate.year, startDate.month, startDate.day)))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(DateTime(endDate.year, endDate.month, endDate.day)))
        .orderBy('date', descending: true)
        .get();

    return query.docs
        .map((doc) => AttendanceModel.fromJson(doc.data()))
        .toList();
  }

  Future<List<AttendanceModel>> getClassAttendanceHistory({
    required String classId,
    required String section,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final query = await attendanceCollection
        .where('classId', isEqualTo: classId)
        .where('section', isEqualTo: section)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(DateTime(startDate.year, startDate.month, startDate.day)))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(DateTime(endDate.year, endDate.month, endDate.day)))
        .orderBy('date', descending: true)
        .get();

    return query.docs
        .map((doc) => AttendanceModel.fromJson(doc.data()))
        .toList();
  }

  Future<List<AttendanceReportModel>> getMonthlyAttendanceReport({
    required String classId,
    required String section,
    required int month,
    required int year,
  }) async {
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 0);
    final query = await attendanceCollection
        .where('classId', isEqualTo: classId)
        .where('section', isEqualTo: section)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .get();

    final studentGroups = <String, List<AttendanceModel>>{};
    for (final doc in query.docs) {
      final model = AttendanceModel.fromJson(doc.data());
      studentGroups.putIfAbsent(model.studentId, () => []).add(model);
    }

    return studentGroups.entries.map((entry) {
      final reports = entry.value;
      final present = reports.where((r) => r.status == 'present').length;
      final absent = reports.where((r) => r.status == 'absent').length;
      final late = reports.where((r) => r.status == 'late').length;
      final halfDay = reports.where((r) => r.status == 'half_day').length;
      final leave = reports.where((r) => r.status == 'leave').length;
      final sample = reports.first;
      return AttendanceReportModel.fromCounts(
        studentId: sample.studentId,
        studentName: sample.className,
        present: present,
        absent: absent,
        late: late,
        halfDay: halfDay,
        leave: leave,
      );
    }).toList();
  }

  Future<List<Student>> getAbsentStudents({
    required String classId,
    required String section,
    required DateTime date,
  }) async {
    final query = await attendanceCollection
        .where('classId', isEqualTo: classId)
        .where('section', isEqualTo: section)
        .where('date', isEqualTo: Timestamp.fromDate(DateTime(date.year, date.month, date.day)))
        .where('status', isEqualTo: 'absent')
        .get();

    final studentIds = query.docs.map((doc) => doc.data()['studentId'] as String).toSet();
    if (studentIds.isEmpty) return [];

    final studentQuery = await studentsCollection.where(FieldPath.documentId, whereIn: studentIds.toList()).get();
    return studentQuery.docs
        .map((doc) => Student.fromJson(doc.data()..['id'] = doc.id))
        .toList();
  }

  Future<AttendanceSummaryModel> calculateSummaryFromStatuses(List<String> statuses) async {
    return AttendanceSummaryModel.fromStatuses(statuses);
  }

  String _attendanceDocId(String studentId, DateTime date) {
    final formatted = _formatDateKey(date);
    return '${studentId}_$formatted';
  }

  String _formatDateKey(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }
}
