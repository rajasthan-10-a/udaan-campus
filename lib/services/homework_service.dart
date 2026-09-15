import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:udaan_campus/models/homework_model.dart';
import 'package:udaan_campus/models/homework_submission_model.dart';
import 'package:udaan_campus/models/audit_log_model.dart';
import 'package:udaan_campus/services/audit_service.dart';
import 'package:udaan_campus/services/homework_storage_service.dart';

class HomeworkService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final HomeworkStorageService _storageService = HomeworkStorageService();
  final AuditService _auditService = AuditService();

  static const int maxAttachmentBytes = 20 * 1024 * 1024;

  CollectionReference<Map<String, dynamic>> get homeworkCollection =>
      _firestore.collection('homework');

  CollectionReference<Map<String, dynamic>> get submissionsCollection =>
      _firestore.collection('homework_submissions');

  Future<void> createOrUpdateHomework(
    HomeworkModel homework,
    String performedBy,
    String performedByRole,
  ) async {
    final docRef = homeworkCollection.doc(homework.homeworkId);
    final snapshot = await docRef.get();
    final data = homework.toJson();
    data['updatedAt'] = FieldValue.serverTimestamp();
    if (!snapshot.exists) {
      data['createdAt'] = FieldValue.serverTimestamp();
    }
    await docRef.set(data, SetOptions(merge: true));

    await _auditService.createAuditLog(
      AuditLogModel(
        auditId: _auditService.buildAuditId('homework', homework.homeworkId, DateTime.now()),
        action: snapshot.exists ? 'HOMEWORK_UPDATED' : 'HOMEWORK_CREATED',
        targetType: 'homework',
        targetId: homework.homeworkId,
        performedBy: performedBy,
        performedByRole: performedByRole,
        newValue: data,
        timestamp: DateTime.now(),
      ),
    );
  }

  Future<void> publishHomework(
    HomeworkModel homework,
    String performedBy,
    String performedByRole,
  ) async {
    final published = homework.copyWith(
      status: 'PUBLISHED',
      publishedAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await createOrUpdateHomework(published, performedBy, performedByRole);
  }

  Future<void> closeHomework(
    HomeworkModel homework,
    String performedBy,
    String performedByRole,
  ) async {
    final closed = homework.copyWith(
      status: 'CLOSED',
      updatedAt: DateTime.now(),
    );
    await createOrUpdateHomework(closed, performedBy, performedByRole);
  }

  Future<List<HomeworkModel>> fetchHomeworkForClassSection({
    required String classId,
    required String section,
    String? status,
  }) async {
    var query = homeworkCollection
        .where('classId', isEqualTo: classId)
        .where('section', isEqualTo: section);
    if (status != null) {
      query = query.where('status', isEqualTo: status);
    }
    final snapshot = await query.orderBy('dueDate').get();
    return snapshot.docs.map((doc) => HomeworkModel.fromJson(doc.data())).toList();
  }

  Future<List<HomeworkModel>> fetchPublishedHomeworkForClassSection({
    required String classId,
    required String section,
  }) async {
    final query = await homeworkCollection
        .where('classId', isEqualTo: classId)
        .where('section', isEqualTo: section)
        .where('status', isEqualTo: 'PUBLISHED')
        .orderBy('dueDate')
        .get();
    return query.docs.map((doc) => HomeworkModel.fromJson(doc.data())).toList();
  }

  Future<List<HomeworkModel>> fetchHomeworkForTeacher(String teacherId) async {
    final snapshot = await homeworkCollection
        .where('teacherId', isEqualTo: teacherId)
        .orderBy('dueDate', descending: true)
        .get();
    return snapshot.docs.map((doc) => HomeworkModel.fromJson(doc.data())).toList();
  }

  Future<List<HomeworkModel>> fetchAllHomework() async {
    final snapshot = await homeworkCollection.orderBy('dueDate', descending: true).get();
    return snapshot.docs.map((doc) => HomeworkModel.fromJson(doc.data())).toList();
  }

  Future<HomeworkModel?> getHomeworkById(String homeworkId) async {
    final snapshot = await homeworkCollection.doc(homeworkId).get();
    if (!snapshot.exists || snapshot.data() == null) return null;
    return HomeworkModel.fromJson(snapshot.data()!);
  }

  Future<List<HomeworkSubmissionModel>> fetchSubmissionsForHomework(String homeworkId) async {
    final snapshot = await submissionsCollection
        .where('homeworkId', isEqualTo: homeworkId)
        .orderBy('submittedAt', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => HomeworkSubmissionModel.fromJson(doc.data()))
        .toList();
  }

  Future<HomeworkSubmissionModel?> fetchSubmissionForStudent(
    String homeworkId,
    String studentId,
  ) async {
    final snapshot = await submissionsCollection
        .where('homeworkId', isEqualTo: homeworkId)
        .where('studentId', isEqualTo: studentId)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    return HomeworkSubmissionModel.fromJson(snapshot.docs.first.data());
  }

  Future<void> saveSubmission(
    HomeworkSubmissionModel submission,
    String performedBy,
    String performedByRole,
  ) async {
    final docRef = submissionsCollection.doc(submission.submissionId);
    final snapshot = await docRef.get();
    final data = submission.toJson();
    data['updatedAt'] = FieldValue.serverTimestamp();
    if (!snapshot.exists) {
      data['createdAt'] = FieldValue.serverTimestamp();
    }
    await docRef.set(data, SetOptions(merge: true));

    await _auditService.createAuditLog(
      AuditLogModel(
        auditId: _auditService.buildAuditId('homework_submission', submission.submissionId, DateTime.now()),
        action: snapshot.exists ? 'SUBMISSION_UPDATED' : 'SUBMISSION_CREATED',
        targetType: 'homework_submission',
        targetId: submission.submissionId,
        performedBy: performedBy,
        performedByRole: performedByRole,
        newValue: data,
        timestamp: DateTime.now(),
      ),
    );
  }

  Future<void> reviewSubmission(
    HomeworkSubmissionModel submission,
    String status,
    String teacherRemark,
    String performedBy,
    String performedByRole,
  ) async {
    final reviewed = submission.copyWith(
      status: status,
      teacherRemark: teacherRemark,
      reviewedBy: performedBy,
      reviewedAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await saveSubmission(reviewed, performedBy, performedByRole);
  }

  Future<HomeworkSubmissionModel> markHomeworkCompleted(
    HomeworkModel homework,
    String studentId,
    String studentName,
  ) async {
    final id = '${homework.homeworkId}_$studentId';
    final existing = await fetchSubmissionForStudent(homework.homeworkId, studentId);
    final now = DateTime.now();
    final submission = HomeworkSubmissionModel(
      submissionId: id,
      homeworkId: homework.homeworkId,
      studentId: studentId,
      studentName: studentName,
      classId: homework.classId,
      section: homework.section,
      submittedAt: now,
      textResponse: null,
      attachments: [],
      status: 'COMPLETED',
      teacherRemark: existing?.teacherRemark,
      reviewedBy: existing?.reviewedBy,
      reviewedAt: existing?.reviewedAt,
      parentVisibleFeedback: true,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    await saveSubmission(submission, studentId, 'student');
    return submission;
  }

  Future<String> uploadAttachment(File file, String teacherId, String homeworkId, void Function(double progress)? onProgress) async {
    final storagePath = 'homework/$teacherId/$homeworkId/${DateTime.now().millisecondsSinceEpoch}_${file.uri.pathSegments.last}';
    return _storageService.uploadHomeworkAttachment(
      storagePath: storagePath,
      file: file,
      onProgress: onProgress,
    );
  }

  Future<Map<String, dynamic>> buildAttachmentData({
    required String filePath,
    required String fileName,
    required String fileType,
    required int fileSize,
    required String fileUrl,
  }) async {
    return {
      'filePath': filePath,
      'fileName': fileName,
      'fileType': fileType,
      'fileSize': fileSize,
      'fileUrl': fileUrl,
    };
  }

  bool validateFileSize(PlatformFile file) {
    return (file.lengthSync() ?? 0) <= maxAttachmentBytes;
  }
}
