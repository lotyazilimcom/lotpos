import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

class MediaUploadResult {
  final String bucket;
  final String objectPath;
  final String publicUrl;
  final String? mimeType;
  final int sizeBytes;

  const MediaUploadResult({
    required this.bucket,
    required this.objectPath,
    required this.publicUrl,
    required this.mimeType,
    required this.sizeBytes,
  });
}

abstract class MediaStoreService {
  Future<MediaUploadResult> uploadBytes({
    required String bucket,
    required String objectPath,
    required Uint8List bytes,
    required String contentType,
    required bool upsert,
  });
}

class SupabaseMediaStoreService implements MediaStoreService {
  final SupabaseClient client;

  const SupabaseMediaStoreService({required this.client});

  @override
  Future<MediaUploadResult> uploadBytes({
    required String bucket,
    required String objectPath,
    required Uint8List bytes,
    required String contentType,
    required bool upsert,
  }) async {
    final storage = client.storage.from(bucket);
    await storage.uploadBinary(
      objectPath,
      bytes,
      fileOptions: FileOptions(contentType: contentType, upsert: upsert),
    );
    final publicUrl = storage.getPublicUrl(objectPath);

    return MediaUploadResult(
      bucket: bucket,
      objectPath: objectPath,
      publicUrl: publicUrl,
      mimeType: contentType,
      sizeBytes: bytes.length,
    );
  }
}

