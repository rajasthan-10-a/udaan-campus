import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class ExternalBackendService {
  ExternalBackendService({
    http.Client? client,
    FirebaseAuth? auth,
    this.baseUrl = 'https://udaan-campus.onrender.com',
  })  : _client = client ?? http.Client(),
        _auth = auth ?? FirebaseAuth.instance;

  final http.Client _client;
  final FirebaseAuth _auth;
  final String baseUrl;

  Future<void> syncUser({
    required String displayName,
    required String email,
  }) async {
    final response = await _authorizedPost(
      '/v1/auth/sync-user',
      {'displayName': displayName, 'email': email},
    );
    _requireSuccess(response, 'User sync failed');
  }

  Future<String> linkParent({
    required String parentUid,
    required String studentUid,
  }) async {
    final response = await _authorizedPost(
      '/v1/parent-links',
      {'parentUid': parentUid, 'studentUid': studentUid},
    );
    _requireSuccess(response, 'Parent link failed');
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final linkId = data['linkId'];
    if (linkId is! String || linkId.isEmpty) {
      throw const FormatException('Parent link response did not include linkId');
    }
    return linkId;
  }

  Future<String> createParentAccount({
    required String email,
    required String password,
    required String displayName,
    required List<String> linkedChildren,
  }) async {
    final response = await _authorizedPost('/v1/parent-accounts', {
      'email': email,
      'password': password,
      'displayName': displayName,
      'linkedChildren': linkedChildren,
    });
    _requireSuccess(response, 'Parent account creation failed');
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final uid = data['uid'];
    if (uid is! String || uid.isEmpty) {
      throw const FormatException('Parent account response did not include uid');
    }
    return uid;
  }

  Future<void> createAuditLog({
    required String action,
    required String targetType,
    required String targetId,
    required String performedByRole,
    Map<String, dynamic>? oldValue,
    Map<String, dynamic>? newValue,
  }) async {
    final response = await _authorizedPost('/v1/audit-logs', {
      'action': action,
      'targetType': targetType,
      'targetId': targetId,
      'performedByRole': performedByRole,
      'oldValue': oldValue,
      'newValue': newValue,
    });
    _requireSuccess(response, 'Audit log failed');
  }

  Future<http.Response> _authorizedPost(
    String path,
    Map<String, dynamic> body,
  ) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('A signed-in Firebase user is required');
    }
    final token = await user.getIdToken(true);
    if (token == null || token.isEmpty) {
      throw StateError('Firebase ID token is unavailable');
    }
    return _client
        .post(
          Uri.parse('$baseUrl$path'),
          headers: <String, String>{
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 20));
  }

  void _requireSuccess(http.Response response, String operation) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    String detail = response.body;
    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      detail = data['error']?.toString() ?? detail;
    } catch (_) {
      // Preserve raw response when the backend does not return JSON.
    }
    throw StateError('$operation (${response.statusCode}): $detail');
  }
}
