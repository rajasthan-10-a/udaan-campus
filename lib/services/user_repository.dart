import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';

class UserRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get users => _firestore.collection('users');

  Future<AppUser?> fetchUser(String uid) async {
    final snapshot = await users.doc(uid).get();
    if (!snapshot.exists || snapshot.data() == null) return null;
    return AppUser.fromJson(snapshot.data()!);
  }

  Future<void> saveUser(AppUser user) async {
    final data = user.toJson();
    data.remove('role');
    data['updatedAt'] = FieldValue.serverTimestamp();
    await users.doc(user.uid).set(data, SetOptions(merge: true));
  }

  Future<void> createUser({
    required String uid,
    required String email,
    required String displayName,
    required String role,
    List<String>? assignedClassSections,
    String? studentClassId,
    String? studentSection,
    List<String>? linkedChildren,
  }) async {
    final user = AppUser(
      uid: uid,
      email: email,
      displayName: displayName,
      role: 'student',
      assignedClassSections: assignedClassSections,
      studentClassId: studentClassId,
      studentSection: studentSection,
      linkedChildren: linkedChildren,
    );
    await users.doc(uid).set({
      ...user.toJson(),
      'normalizedRole': 'student',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
