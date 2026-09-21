import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/supabase_config.dart';

/// Raw Supabase Edge Function access for `ask-ai`, streamed as Server-Sent
/// Events. Turning these into domain events is the repository's job.
class AskAiRemoteDataSource {
  AskAiRemoteDataSource(this._client);

  final SupabaseClient _client;

  /// Streams decoded SSE payloads from the `ask-ai` function. Each yielded
  /// map is the event's JSON `data:` body, tagged with the SSE `event:`
  /// name under the `_event` key (`'delta' | 'done' | 'error'`).
  Stream<Map<String, dynamic>> streamAskAi({
    required String question,
    required List<Map<String, String>> history,
    required String dayStartUtc,
    required String dayEndUtc,
  }) async* {
    final uri = Uri.parse('${SupabaseConfig.url}/functions/v1/ask-ai');
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
        'question': question,
        'history': history,
        'dayStart': dayStartUtc,
        'dayEnd': dayEndUtc,
      });

    final response = await http.Client().send(request);
    if (response.statusCode != 200) {
      final body = await response.stream.bytesToString();
      throw Exception('ask-ai returned ${response.statusCode}: $body');
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
  }
}
