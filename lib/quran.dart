import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;

class QuranScreen extends StatefulWidget {
  const QuranScreen({super.key});

  @override
  State<QuranScreen> createState() => _QuranScreenState();
}

class _QuranScreenState extends State<QuranScreen> {
  final FlutterTts flutterTts = FlutterTts();
  String apiKey = dotenv.env['TRANS_API_KEY'] ?? '';
  String baseUrl = dotenv.env['BASE_URL'] ?? '';
  String editionUrl = dotenv.env['EDITION_URL'] ?? '';
  String? detectedFword, detectedLanguageCode, defaultEngine;
  List<dynamic>? availableTTS;
  bool isGoogleTTSDefault = false;

  @override
  initState() {
    super.initState();
    //* check the TTS engine whether it is available
    checkTtsEngine();
  }

  Future<void> checkTtsEngine() async {
    if (Platform.isAndroid) {
      availableTTS = await flutterTts.getEngines;
      defaultEngine = await flutterTts.getDefaultEngine;
      if (defaultEngine != null &&
          defaultEngine!.isNotEmpty &&
          defaultEngine!.contains("google")) {
        isGoogleTTSDefault = true;
        //* Fetch the fword and detect its language
        await fetchAndDetectFwordLanguages();
      } else {
        isGoogleTTSDefault = false;
      }
    } else {
      defaultEngine = "TTS engine check is only available on Android.";
    }
  }

  Future<void> fetchAndDetectFwordLanguages() async {
    try {
      String data = await rootBundle.loadString('assets/editions.json');
      List<dynamic> editions = jsonDecode(data);
      //* Use FOR-IN-LOOP to detect all the fword from the json & remove [0]
      //* For now, just use the first one
      // for (var edition in editions) {
      if (editions[0].containsKey('fword')) {
        detectedFword = editions[0]['fword'];
        detectedLanguageCode = await detectLanguage(detectedFword!);
        setState(() {});
      }
      // }
    } catch (e) {
      SnackBar(content: Text('Error: $e'), duration: Duration(seconds: 2));
    }
  }

  Future<void> speakText(String text, String langCode) async {
    await flutterTts.setLanguage(langCode);
    await flutterTts.setSpeechRate(0.5);
    await flutterTts.setPitch(1.0);
    await flutterTts.setVolume(1.0);
    await flutterTts.speak(text);
  }

  Future<String?> detectLanguage(String text) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'q': text}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final detection = data['data']['detections'][0][0];
        return detection['language'];
      } else {
        if (!mounted) return null;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Language detection error!'),
            duration: Duration(seconds: 2),
          ),
        );
        return null;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('API error!'),
          duration: Duration(seconds: 2),
        ),
      );
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(15.0),
          child: Column(
            spacing: 10,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Is Google TTS Default: $isGoogleTTSDefault'),
              Text('Available TTS: $availableTTS'),
              Text('Detected FWord: $detectedFword'),
              Text('Detected Language Code: $detectedLanguageCode'),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: 20,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      speakText(detectedFword!, detectedLanguageCode!);
                    },
                    child: Text("Speak FWord"),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      speakText("Hello, how are you?", "en-US");
                    },
                    child: Text("Test Speak"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
