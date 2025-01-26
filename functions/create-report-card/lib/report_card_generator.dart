import 'dart:convert';

import 'package:gradebee_models/common.dart';
import 'package:dart_openai/dart_openai.dart';

class ReportCardGenerator {
  ReportCardGenerator(String apiKey) {
    OpenAI.apiKey = apiKey;
  }
}
