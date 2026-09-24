import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/error/app_exception.dart';

/// Raw Supabase Edge Function access for `analyze-food`, streamed as
/// Server-Sent Events. Turning these into domain events is the
/// repository's job.
class FoodAnalysisRemoteDataSource {
  FoodAnalysisRemoteDataSource(this._client);

  final SupabaseClient _client;

  /// The `http.Client` backing the currently in-flight [streamAnalyzeFood]
  /// call, if any — kept around solely so [cancelInFlight] can force-abort
  /// it (closing a client mid-request throws in whatever `await`/stream
  /// read is pending on it), since cancelling the returned `Stream`'s
  /// subscription alone can't interrupt a single in-flight HTTP call.
  http.Client? _httpClient;

  /// Aborts the in-flight request started by [streamAnalyzeFood], if any.
  void cancelInFlight() {
    _httpClient?.close();
    _httpClient = null;
  }

  /// Streams decoded SSE payloads from the `analyze-food` function. Each
  /// yielded map is the event's JSON `data:` body, tagged with the SSE
  /// `event:` name under the `_event` key (`'meal_name' | 'item' | 'done' |
  /// 'error'`).
  Stream<Map<String, dynamic>> streamAnalyzeFood({
    required Uint8List imageBytes,
    required String mimeType,
  }) async* {
    final uri = Uri.parse('${SupabaseConfig.url}/functions/v1/analyze-food');
    final token =
        _client.auth.currentSession?.accessToken ?? SupabaseConfig.anonKey;

    final request = http.Request('POST', uri)
      ..headers.addAll({
        'Content-Type': 'application/json',
        'Accept': 'text/event-stream',
        'apikey': SupabaseConfig.anonKey,
        'Authorization': 'Bearer $token',
      })
      ..body = jsonEncode({
        'image': base64Encode(imageBytes),
        'mimeType': mimeType,
      });

    final httpClient = http.Client();
    _httpClient = httpClient;
    try {
      final response = await httpClient.send(request);
      if (response.statusCode != 200) {
        final body = await response.stream.bytesToString();
        throw FoodAnalysisException(
          edgeFunctionErrorMessage(
            body,
            fallback: "Couldn't analyze this photo. Try again.",
          ),
        );
      }

      String? currentEvent;
      final lines = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      await for (final line in lines) {
        if (line.isEmpty) {
          currentEvent = null;
          continue;
        }
        if (line.startsWith('event:')) {
          currentEvent = line.substring(6).trim();
        } else if (line.startsWith('data:')) {
          final payload = line.substring(5).trim();
          if (payload.isEmpty) continue;
          final decoded = jsonDecode(payload) as Map<String, dynamic>;
          yield {'_event': currentEvent ?? 'message', ...decoded};
        }
      }
    } finally {
      httpClient.close();
      if (identical(_httpClient, httpClient)) {
        _httpClient = null;
      }
    }
  }
}
