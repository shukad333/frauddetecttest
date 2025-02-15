import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';

// File: lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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

class VoiceProvider with ChangeNotifier {
  final FlutterTts _flutterTts = FlutterTts();
  final SpeechToText _speechToText = SpeechToText();
  bool _isSpeaking = false;
  bool _isListening = false;
  double _volume = 1.0;
  double _pitch = 1.0;
  double _rate = 0.5;
  String _lastWords = '';
  String _errorMessage = '';
  bool _isInitialized = false;

  bool get isSpeaking => _isSpeaking;
  bool get isListening => _isListening;
  bool get isInitialized => _isInitialized;
  double get volume => _volume;
  double get pitch => _pitch;
  double get rate => _rate;
  String get lastWords => _lastWords;
  String get errorMessage => _errorMessage;

  VoiceProvider() {
    _initTTS();
    _initializeSTT();
  }

  void _initTTS() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setVolume(_volume);
    await _flutterTts.setPitch(_pitch);
    await _flutterTts.setSpeechRate(_rate);
  }

  Future<void> _initializeSTT() async {
    try {
      var status = await Permission.microphone.status;
      if (status.isDenied) {
        _errorMessage = 'Microphone permission is required';
        notifyListeners();
        return;
      }

      _isInitialized = await _speechToText.initialize(
        onError: (error) {
          _errorMessage = "Error: ${error.errorMsg}";
          _isListening = false;
          notifyListeners();
        },
        debugLogging: true,
      );

      if (_isInitialized) {
        print("Speech to Text initialized successfully");
        var locales = await _speechToText.locales();
        print("Available locales: $locales");
      } else {
        _errorMessage = 'Failed to initialize speech recognition';
      }
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error initializing speech recognition: $e';
      _isInitialized = false;
      notifyListeners();
    }
  }

  Future<void> startListening(Function(String) onResult) async {
    _errorMessage = '';

    try {
      if (!_isInitialized) {
        await _initializeSTT();
      }

      if (!_speechToText.isAvailable) {
        _errorMessage = 'Speech recognition is not available on this device';
        notifyListeners();
        return;
      }

      if (await Permission.microphone.isGranted) {
        print("Starting listening...");
        _isListening = true;
        notifyListeners();

        await _speechToText.listen(
          onResult: (result) {
            print("Recognition result: ${result.recognizedWords}");
            _lastWords = result.recognizedWords;
            onResult(_lastWords);
            notifyListeners();
          },
          listenFor: Duration(seconds: 30),
          localeId: 'en_US',
          onSoundLevelChange: (level) {
            print("Sound level: $level");
          },
          cancelOnError: true,
          partialResults: true,
        );
      } else {
        _errorMessage = 'Microphone permission denied';
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'Error during listening: $e';
      _isListening = false;
      notifyListeners();
    }
  }

  Future<void> stopListening() async {
    try {
      _isListening = false;
      notifyListeners();
      await _speechToText.stop();
    } catch (e) {
      _errorMessage = 'Error stopping listening: $e';
      notifyListeners();
    }
  }

// ... rest of the provider methods remain the same ...
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _textController = TextEditingController();

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
                if (voiceProvider.errorMessage.isNotEmpty)
                  Container(
                    padding: EdgeInsets.all(8),
                    margin: EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error, color: Colors.red),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            voiceProvider.errorMessage,
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ),
                TextField(
                  controller: _textController,
                  maxLines: 5,
                  decoration: InputDecoration(
                    hintText: 'Enter text or tap microphone to speak',
                    border: OutlineInputBorder(),
                    suffixIcon: voiceProvider.isListening
                        ? Container(
                      margin: EdgeInsets.all(8),
                      child: CircularProgressIndicator(),
                    )
                        : null,
                  ),
                ),
                // ... rest of the UI remains the same ...
              ],
            ),
          );
        },
      ),
    );
  }
}