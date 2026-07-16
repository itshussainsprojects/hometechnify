import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/services/api_service.dart';
import '../models/job_post_model.dart';
import 'package:http_parser/http_parser.dart';

class RemoteJobRepository {
  final ApiService _apiService = ApiService();

  RemoteJobRepository();

  Future<JobPostModel> createJob(Map<String, dynamic> data, List<String> mediaPaths) async {
    debugPrint('[RemoteJobRepository] createJob called');
    debugPrint('[RemoteJobRepository] Data: $data');
    debugPrint('[RemoteJobRepository] MediaPaths: $mediaPaths');
    
    final formData = FormData.fromMap(data);

    // Add files
    for (var path in mediaPaths) {
      final file = File(path);
      String fileName = path.split('/').last;
      
      // Determine content type roughly or generic
      String? mimeType;
      if (fileName.endsWith('.mp4') || fileName.endsWith('.mov')) {
        mimeType = 'video/mp4';
      } else if (fileName.endsWith('.jpg') || fileName.endsWith('.jpeg')) {
        mimeType = 'image/jpeg';
      } else if (fileName.endsWith('.png')) {
        mimeType = 'image/png';
      } else if (fileName.endsWith('.m4a') || fileName.endsWith('.mp3') || fileName.endsWith('.aac')) {
        mimeType = 'audio/aac';
      }
      
      formData.files.add(MapEntry(
        'media',
        await MultipartFile.fromFile(
          file.path,
          filename: fileName,
          contentType: mimeType != null ? MediaType.parse(mimeType) : null,
        ),
      ));
    }

    debugPrint('[RemoteJobRepository] Sending POST /jobs...');
    final response = await _apiService.dio.post('/jobs', data: formData);
    debugPrint('[RemoteJobRepository] Response status: ${response.statusCode}');
    debugPrint('[RemoteJobRepository] Response data: ${response.data}');
    
    return JobPostModel.fromJson(response.data);
  }

  Future<List<JobPostModel>> getMyJobs() async {
    debugPrint('[RemoteJobRepository] getMyJobs called');
    final response = await _apiService.dio.get('/jobs/my-jobs');
    debugPrint('[RemoteJobRepository] getMyJobs response: ${response.data}');
    return (response.data as List).map((e) => JobPostModel.fromJson(e)).toList();
  }
  
  Future<List<JobPostModel>> getNearbyJobs({String? category}) async {
    final response = await _apiService.dio.get(
      '/jobs/nearby',
      queryParameters: category != null ? {'category': category} : null,
    );
     return (response.data as List).map((e) => JobPostModel.fromJson(e)).toList();
  }

  Future<void> deleteJob(String id) async {
    await _apiService.dio.delete('/jobs/$id');
  }

  Future<JobPostModel> updateJob(String id, Map<String, dynamic> data, List<String> newMediaPaths, {List<String>? mediaToDelete}) async {
    final formData = FormData.fromMap(data);

    // Send mediaToDelete as JSON string
    if (mediaToDelete != null && mediaToDelete.isNotEmpty) {
       // Using simpler list format "[ "a", "b" ]" manually to avoid import 'dart:convert' issues if not present
       // But better:
       String jsonStr = '[${mediaToDelete.map((e) => '"$e"').join(',')}]';
       debugPrint('[RemoteJobRepository] Sending mediaToDelete: $jsonStr');
       formData.fields.add(MapEntry('mediaToDelete', jsonStr));
    }

    // Add new files if any
    for (var path in newMediaPaths) {
      final file = File(path);
      String fileName = path.split('/').last;
      
      String? mimeType;
      // ... (existing mime logic)
      if (fileName.endsWith('.mp4') || fileName.endsWith('.mov')) {
        mimeType = 'video/mp4';
      } else if (fileName.endsWith('.jpg') || fileName.endsWith('.jpeg')) {
        mimeType = 'image/jpeg';
      } else if (fileName.endsWith('.png')) {
        mimeType = 'image/png';
      } else if (fileName.endsWith('.m4a') || fileName.endsWith('.mp3') || fileName.endsWith('.aac')) {
        mimeType = 'audio/aac';
      }
      
      formData.files.add(MapEntry(
        'media',
        await MultipartFile.fromFile(
          file.path,
          filename: fileName,
          contentType: mimeType != null ? MediaType.parse(mimeType) : null,
        ),
      ));
    }

    final response = await _apiService.dio.put('/jobs/$id', data: formData);
    return JobPostModel.fromJson(response.data);
  }

  Future<dynamic> acceptJob(String jobId, String price) async {
    final response = await _apiService.dio.post('/jobs/$jobId/accept', data: {'price': price});
    return response.data;
  }
}
