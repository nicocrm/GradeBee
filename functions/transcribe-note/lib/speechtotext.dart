import 'dart:io';

import 'package:dart_openai/dart_openai.dart';

class Speechtotext {
  Speechtotext(String apiKey) {
    OpenAI.apiKey = apiKey;
  }

  Future<String> transcribe(List<String> names, File audio) async {
    String prompt = names.join(", ");
    final result = await OpenAI.instance.audio
        .createTranscription(file: audio, model: "whisper-1", prompt: prompt);
    return result.text;
  }
}
