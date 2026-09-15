import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class FirebaseService {
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      await Firebase.initializeApp();
    } on Exception catch (error) {
      if (kDebugMode) {
        debugPrint('Firebase initialization failed: $error');
      }
    }

    _initialized = true;
  }
}
