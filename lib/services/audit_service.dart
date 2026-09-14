import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:udaan_campus/models/audit_log_model.dart';
import 'package:udaan_campus/services/external_backend_service.dart';

class AuditService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ExternalBackendService _backend = ExternalBackendService();

  CollectionReference<Map<String, dynamic>> get auditLogs =>
      _firestore.collection('audit_logs');

  Future<void> createAuditLog(AuditLogModel auditLog) async {
    await _backend.createAuditLog(
      action: auditLog.action,
      targetType: auditLog.targetType,
      targetId: auditLog.targetId,
      performedByRole: auditLog.performedByRole,
      oldValue: auditLog.oldValue,
      newValue: auditLog.newValue,
    );
  }

  String buildAuditId(String targetType, String targetId, DateTime timestamp) {
    final key = timestamp.toUtc().millisecondsSinceEpoch;
    return '${targetType}_${targetId}_$key';
  }
}
