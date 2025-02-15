// pubspec.yaml dependencies to add:
// flutter_tts: ^3.8.5
// speech_to_text: ^6.5.1
// provider: ^6.1.1
// permission_handler: ^11.0.1

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';

class VoiceProvider with ChangeNotifier {
  final FlutterTts _flutterTts = FlutterTts();
  final SpeechToText _speechToText = SpeechToText();
  bool _isSpeaking = false;
  bool _isListening = false;
  double _volume = 1.0;
  double _pitch = 1.0;
  double _rate = 0.5;
  String _lastWords = '';

  bool get isSpeaking => _isSpeaking;
  bool get isListening => _isListening;
  double get volume => _volume;
  double get pitch => _pitch;
  double get rate => _rate;
  String get lastWords => _lastWords;

  VoiceProvider() {
    _initTTS();
    _initSTT();
  }

  void _initTTS() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setVolume(_volume);
    await _flutterTts.setPitch(_pitch);
    await _flutterTts.setSpeechRate(_rate);
  }

  Future<bool> _initSTT() async {
    return await _speechToText.initialize();
  }

  Future<void> requestPermissions() async {
    await Permission.microphone.request();
  }

  Future<void> startListening(Function(String) onResult) async {
    await requestPermissions();

    if (!_speechToText.isAvailable) {
      bool initialized = await _initSTT();
      if (!initialized) {
        return; // Failed to initialize
      }
    }

    if (await Permission.microphone.isGranted) {
      _isListening = true;
      notifyListeners();

      await _speechToText.listen(
        onResult: (result) {
          _lastWords = result.recognizedWords;
          onResult(_lastWords);
          notifyListeners();
        },
        localeId: 'en_US',
      );
    }
  }

  Future<void> stopListening() async {
    _isListening = false;
    notifyListeners();
    await _speechToText.stop();
  }

  Future<void> speak(String text) async {
    if (text.isNotEmpty) {
      _isSpeaking = true;
      notifyListeners();
      await _flutterTts.speak(text);
      _isSpeaking = false;
      notifyListeners();
    }
  }

  Future<void> stop() async {
    _isSpeaking = false;
    notifyListeners();
    await _flutterTts.stop();
  }

  void updateVolume(double value) {
    _volume = value;
    _flutterTts.setVolume(value);
    notifyListeners();
  }

  void updatePitch(double value) {
    _pitch = value;
    _flutterTts.setPitch(value);
    notifyListeners();
  }

  void updateRate(double value) {
    _rate = value;
    _flutterTts.setSpeechRate(value);
    notifyListeners();
  }
}

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => VoiceProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Voice Converter',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _textController = TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice Converter'),
      ),
      body: Consumer<VoiceProvider>(
        builder: (context, voiceProvider, child) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  controller: _textController,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    hintText: 'Enter text or tap microphone to speak',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: voiceProvider.isSpeaking
                          ? () => voiceProvider.stop()
                          : () => voiceProvider.speak(_textController.text),
                      icon: Icon(
                        voiceProvider.isSpeaking ? Icons.stop : Icons.play_arrow,
                      ),
                      label: Text(
                        voiceProvider.isSpeaking ? 'Stop' : 'Speak',
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: voiceProvider.isListening
                          ? () => voiceProvider.stopListening()
                          : () => voiceProvider.startListening((text) {
                        _textController.text = text;
                      }),
                      icon: Icon(
                        voiceProvider.isListening
                            ? Icons.mic_off
                            : Icons.mic,
                      ),
                      label: Text(
                        voiceProvider.isListening ? 'Stop' : 'Listen',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: voiceProvider.isListening
                            ? Colors.red
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildSlider(
                  'Volume',
                  voiceProvider.volume,
                  voiceProvider.updateVolume,
                ),
                _buildSlider(
                  'Pitch',
                  voiceProvider.pitch,
                  voiceProvider.updatePitch,
                ),
                _buildSlider(
                  'Rate',
                  voiceProvider.rate,
                  voiceProvider.updateRate,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSlider(
      String label,
      double value,
      void Function(double) onChanged,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: value,
                min: 0.0,
                max: 1.0,
                onChanged: onChanged,
              ),
            ),
            Text(value.toStringAsFixed(2)),
          ],
        ),
      ],
    );
  }
}