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
      final extension = path.extension(fileName);
      final uniqueName = '${userId ?? 'user'}_${DateTime.now().millisecondsSinceEpoch}$extension';
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
  
  // ============== PROVIDER VERIFICATION ==============
  
  /// Submit provider verification request
  static Future<bool> submitVerificationRequest({
    required String providerId,
    required String name,
    required String email,
    required String phone,
    required String service,
    required String experience,
    required String cnicFrontUrl,
    required String cnicBackUrl,
    required String selfieUrl,
  }) async {
    try {
      final data = {
        'provider_id': providerId,
        'name': name,
        'email': email,
        'phone': phone,
        'service': service,
        'experience': experience,
        'cnic_front_url': cnicFrontUrl,
        'cnic_back_url': cnicBackUrl,
        'selfie_with_cnic_url': selfieUrl,
        'status': 'pending', // pending, approved, rejected
        'submitted_at': DateTime.now().toIso8601String(),
        'reviewed_at': null,
        'reviewed_by': null,
        'rejection_reason': null,
      };
      
      await _supabase
          .from('provider_verifications')
          .insert(data);
          
      return true;
    } catch (e) {
      debugPrint('Verification submission error: $e');
      return false;
    }
  }
  
  /// Get verification status for provider
  static Future<Map<String, dynamic>?> getVerificationStatus(String providerId) async {
    try {
      final response = await _supabase
          .from('provider_verifications')
          .select('*')
          .eq('provider_id', providerId)
          .order('submitted_at', ascending: false)
          .limit(1)
          .single();
          
      return response;
    } catch (e) {
      debugPrint('Get verification status error: $e');
      return null;
    }
  }
  
  /// Get all pending verifications (for admin)
  static Future<List<Map<String, dynamic>>> getPendingVerifications() async {
    try {
      final response = await _supabase
          .from('provider_verifications')
          .select('*')
          .eq('status', 'pending')
          .order('submitted_at');
          
      return response;
    } catch (e) {
      debugPrint('Get pending verifications error: $e');
      return [];
    }
  }
  
  /// Approve provider verification
  static Future<bool> approveVerification({
    required String providerId,
    required String adminId,
  }) async {
    try {
      await _supabase
          .from('provider_verifications')
          .update({
            'status': 'approved',
            'reviewed_at': DateTime.now().toIso8601String(),
            'reviewed_by': adminId,
          })
          .eq('provider_id', providerId)
          .eq('status', 'pending');
          
      return true;
    } catch (e) {
      debugPrint('Approve verification error: $e');
      return false;
    }
  }
  
  /// Reject provider verification
  static Future<bool> rejectVerification({
    required String providerId,
    required String adminId,
    required String reason,
  }) async {
    try {
      await _supabase
          .from('provider_verifications')
          .update({
            'status': 'rejected',
            'reviewed_at': DateTime.now().toIso8601String(),
            'reviewed_by': adminId,
            'rejection_reason': reason,
          })
          .eq('provider_id', providerId)
          .eq('status', 'pending');
          
      return true;
    } catch (e) {
      debugPrint('Reject verification error: $e');
      return false;
    }
  }
  
  // ============== REALTIME UPDATES ==============
  
  /// Listen for verification status changes
  static Stream<List<Map<String, dynamic>>> verificationStatusChanges() {
    return _supabase
        .from('provider_verifications')
        .stream(primaryKey: ['provider_id'])
        .eq('status', 'approved');
  }
}
