// Supabase Service - Free Database + Storage
// For provider document verification

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'package:path/path.dart' as path;

class SupabaseService {
  static final SupabaseClient _supabase = Supabase.instance.client;
  
  // ============== AUTHENTICATION ==============
  
  static SupabaseClient get client => _supabase;
  
  // ============== DOCUMENT STORAGE ==============
  
  /// Upload provider verification document to Supabase Storage
  static Future<String?> uploadDocument({
    required File file,
    required String fileName,
    required String folder, // e.g., 'provider-docs/cnic' or 'provider-docs/selfies'
    String? userId,
  }) async {
    try {
      // The base name (e.g. 'cnic_front' vs 'cnic_back') used to be thrown
      // away here — only the extension was kept, so the "unique" name was
      // just userId + a millisecond timestamp. Registration uploads CNIC
      // front/back/selfie concurrently (Future.wait), and two of those calls
      // landing in the same millisecond is common enough in practice — they
      // then collide on the exact same storage path in the same folder, and
      // Supabase rejects the second write, silently leaving that document
      // empty (this is why CNIC Back would intermittently end up missing
      // while Front and Selfie saved fine). Including the base name makes
      // front/back/selfie paths structurally distinct, so they can never
      // collide with each other regardless of timing.
      final extension = path.extension(fileName);
      final baseName = path.basenameWithoutExtension(fileName);
      final uniqueName = '${userId ?? 'user'}_${baseName}_${DateTime.now().millisecondsSinceEpoch}$extension';
      final filePath = '$folder/$uniqueName';
      
      await _supabase.storage
          .from('documents')
          .upload(filePath, file);
      
      // Get public URL
      final url = _supabase.storage
          .from('documents')
          .getPublicUrl(filePath);
          
      return url;
    } catch (e) {
      debugPrint('Upload Error: $e');
      return null;
    }
  }
  
  /// Upload CNIC Front Image
  static Future<String?> uploadCnicFront({
    required File image,
    required String userId,
  }) async {
    return await uploadDocument(
      file: image,
      fileName: 'cnic_front.jpg',
      folder: 'provider-docs/cnic',
      userId: userId,
    );
  }
  
  /// Upload CNIC Back Image
  static Future<String?> uploadCnicBack({
    required File image,
    required String userId,
  }) async {
    return await uploadDocument(
      file: image,
      fileName: 'cnic_back.jpg',
      folder: 'provider-docs/cnic',
      userId: userId,
    );
  }
  
  /// Upload Selfie with CNIC
  static Future<String?> uploadSelfieWithCnic({
    required File image,
    required String userId,
  }) async {
    return await uploadDocument(
      file: image,
      fileName: 'selfie_cnic.jpg',
      folder: 'provider-docs/selfies',
      userId: userId,
    );
  }

  /// Upload a before/after work photo for a booking
  static Future<String?> uploadWorkPhoto({
    required File image,
    required String bookingId,
    required String stage, // 'before' or 'after'
  }) async {
    return await uploadDocument(
      file: image,
      fileName: '${stage}_$bookingId.jpg',
      folder: 'work-photos/$stage',
      userId: bookingId,
    );
  }

  /// Upload a provider's live verification selfie
  static Future<String?> uploadLiveSelfie({
    required File image,
    required String userId,
  }) async {
    return await uploadDocument(
      file: image,
      fileName: 'live_selfie.jpg',
      folder: 'provider-docs/live-selfies',
      userId: userId,
    );
  }
  
}
