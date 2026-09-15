import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseStorageService {
  SupabaseStorageService();

  SupabaseClient get client => Supabase.instance.client;

  bool get isConfigured {
    try {
      Supabase.instance.client;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<String?> uploadVideo({
    required PlatformFile file,
    required String bucket,
    required String folder,
    void Function(double progress)? onProgress,
  }) async {
    if (!isConfigured) {
      throw StateError('Supabase client is not configured.');
    }

    final path = '$folder/${DateTime.now().millisecondsSinceEpoch}_${file.name}';
    final bytes = await file.readAsBytes();

    final storage = client.storage.from(bucket);
    await storage.uploadBinary(
      path,
      bytes,
      fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
    );

    final publicUrl = storage.getPublicUrl(path);
    onProgress?.call(1.0);
    return publicUrl;
  }

  Future<String?> uploadFile({
    required PlatformFile file,
    required String bucket,
    required String folder,
  }) async {
    if (!isConfigured) {
      throw StateError('Supabase client is not configured.');
    }
    final path = '$folder/${DateTime.now().millisecondsSinceEpoch}_${file.name}';
    final storage = client.storage.from(bucket);
    await storage.uploadBinary(
      path,
      await file.readAsBytes(),
      fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
    );
    return storage.getPublicUrl(path);
  }
}
