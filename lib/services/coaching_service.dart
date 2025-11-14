/// Provides a communication interface between the Flutter app and the
/// AI backend server. It sends user messages, profile data, and history,
/// then streams back real-time AI coaching responses using SSE-like chunks.
///
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
/// Base URL of the AI backend server
class CoachingService {
  /// For physical device, use: 'http://YOUR_COMPUTER_IP:8000'
  static const String baseUrl = 'http://0.0.0.0:8000';

  /// Stream AI coaching responses from backend
  Stream<String> streamCoachResponse({
    required String userId,
    required String message,
    Map<String, dynamic>? userProfile,
    List<Map<String, String>>? conversationHistory,
  }) async* {
    try {
      final request = http.Request('POST', Uri.parse('$baseUrl/coach'));
      request.headers['Content-Type'] = 'application/json';

      final body = {
        'userId': userId,
        'message': message,
        if (userProfile != null) 'userProfile': userProfile,
        if (conversationHistory != null) 'conversationHistory': conversationHistory,
      };

      /// Encode body to JSON
      request.body = jsonEncode(body);

      /// Send the request as a streamed HTTP response
      final streamedResponse = await request.send();

      if (streamedResponse.statusCode != 200) {
        final errorBody = await streamedResponse.stream.bytesToString();
        throw Exception('Backend error: ${streamedResponse.statusCode} - $errorBody');
      }

      await for (var chunk in streamedResponse.stream.transform(utf8.decoder)) {
        // Parse Server-Sent Events format
        final lines = chunk.split('\n');

        for (var line in lines) {
          if (line.startsWith('data: ')) {
            final dataStr = line.substring(6).trim();
            if (dataStr == '[DONE]') {
              break;
            }
            try {
              final data = jsonDecode(dataStr);
              if (data.containsKey('error')) {
                throw Exception(data['error']);
              }
              if (data.containsKey('content')) {
                yield data['content'] as String;
              }
            } catch (e) {
              // Skip malformed JSON chunks
              continue;
            }
          }
        }
      }
    } catch (e) {
      throw Exception('Coaching service error: $e');
    }
  }
}