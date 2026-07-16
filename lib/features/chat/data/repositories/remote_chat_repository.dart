import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/message_model.dart';
import '../../../../core/services/api_service.dart';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';

class RemoteChatRepository {
  final FirebaseFirestore _firestore;
  final ApiService _apiService = ApiService();

  RemoteChatRepository(this._firestore);

  Stream<List<MessageModel>> getMessages(String currentUserId, String otherUserId) {
    // Construct a unique chat ID based on user IDs to ensure privacy/uniqueness
    // A simple way is to sort the IDs and join them: "id1_id2"
    List<String> ids = [currentUserId, otherUserId];
    ids.sort();
    String chatId = ids.join('_');

    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => MessageModel.fromFirestore(doc)).toList();
    });
  }

  Future<void> sendMessage(MessageModel message, {Map<String, String>? userNames}) async {
    List<String> ids = [message.senderId, message.receiverId];
    ids.sort();
    String chatId = ids.join('_');

    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .add(message.toMap());

    // Update Chat Metadata with User Names
    Map<String, dynamic> updateData = {
      'users': ids,
      'lastMessage': message.text.isNotEmpty ? message.text : '[Media]',
      'lastTimestamp': message.timestamp,
      'lastSenderId': message.senderId,
    };

    if (userNames != null) {
       updateData['userNames'] = userNames;
    }

    await _firestore.collection('chats').doc(chatId).set(updateData, SetOptions(merge: true));
  }

  Future<String> uploadMedia(File file) async {
    String fileName = file.path.split('/').last;
    
    // Determine content type roughly
    String? mimeType;
    if (fileName.endsWith('.jpg') || fileName.endsWith('.jpeg')) {
      mimeType = 'image/jpeg';
    } else if (fileName.endsWith('.png')) {
      mimeType = 'image/png';
    } else if (fileName.endsWith('.mp4') || fileName.endsWith('.mov')) {
      mimeType = 'video/mp4';
    } else if (fileName.endsWith('.m4a') || fileName.endsWith('.mp3')) {
      mimeType = 'audio/aac';
    }

    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
         file.path, 
         filename: fileName,
         contentType: mimeType != null ? MediaType.parse(mimeType) : null,
      ),
    });

    final response = await _apiService.dio.post('/upload', data: formData);
    // Response format: { success: true, data: { url: '/assets/uploads/...' } }
    if (response.statusCode == 200 && response.data['success'] == true) {
       return response.data['data']['url']; 
    } else {
       throw Exception('Upload failed: ${response.data['message']}');
    }
  }
  Future<void> deleteChat(String chatId, String userId) async {
    // Remove user from the 'users' array to hide the chat for them
    await _firestore.collection('chats').doc(chatId).update({
      'users': FieldValue.arrayRemove([userId]),
    });
  }

  Future<void> deleteMessage(String chatId, String messageId) async {
    // Hard delete the message document
    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .delete();
  }
}
