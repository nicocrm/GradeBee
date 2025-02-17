import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Audio Recorder',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const AudioRecorderPage(),
    );
  }
}

class AudioRecorderPage extends StatefulWidget {
  const AudioRecorderPage({super.key});

  @override
  State<AudioRecorderPage> createState() => _AudioRecorderPageState();
}

class _AudioRecorderPageState extends State<AudioRecorderPage> {
  late AudioRecorder audioRecord;
  late AudioPlayer audioPlayer;
  bool isRecording = false;
  bool isPlaying = false;
  String? audioPath;

  @override
  void initState() {
    super.initState();
    audioRecord = AudioRecorder();
    audioPlayer = AudioPlayer();

    // Print available input devices
    _printInputDevices();

    // Add listener for player state changes
    audioPlayer.onPlayerComplete.listen((event) {
      setState(() {
        isPlaying = false;
      });
    });

    audioPlayer.onPlayerStateChanged.listen((state) {
      setState(() {
        isPlaying = state == PlayerState.playing;
      });
    });
  }

  @override
  void dispose() {
    audioRecord.dispose();
    audioPlayer.dispose();
    super.dispose();
  }

  Future<void> startRecording() async {
    try {
      if (await audioRecord.hasPermission()) {
        // final dir = await getTemporaryDirectory();
        // final filePath = '${dir.path}/audio_record2.wav';
        final filePath = 'audio_record.m4a';
        await audioRecord.start(
          RecordConfig(
            encoder: AudioEncoder.aacLc,
            // device: InputDevice(
            //     id: 'BuiltInMicrophoneDevice',
            //     label: 'BuiltInMicrophoneDevice'),
          ),
          path: filePath,
        );
        setState(() {
          isRecording = true;
          audioPath = filePath;
        });
      }
    } catch (e) {
      print('Error recording audio: $e');
    }
  }

  Future<void> stopRecording() async {
    try {
      String? path = await audioRecord.stop();
      setState(() {
        isRecording = false;
      });
      audioPath = path;
      print('Audio recorded to: $path');
    } catch (e) {
      print('Error stopping record: $e');
    }
  }

  Future<void> playRecording() async {
    try {
      if (audioPath != null) {
        Source urlSource = DeviceFileSource(audioPath!);
        await audioPlayer.play(urlSource);
      }
    } catch (e) {
      print('Error playing recording: $e');
    }
  }

  Future<void> _printInputDevices() async {
    try {
      final devices = await audioRecord.listInputDevices();
      print('Available input devices:');
      for (final device in devices) {
        print('- ${device.label} (ID: ${device.id})');
      }
    } catch (e) {
      print('Error getting input devices: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: const Text('Audio Recorder'),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          //
          // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
          // action in the IDE, or press "p" in the console), to see the
          // wireframe for each widget.
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Status text
            if (isRecording)
              const Text(
                '🔴 Recording...',
                style: TextStyle(fontSize: 20),
              )
            else if (isPlaying)
              const Text(
                '🎵 Playing...',
                style: TextStyle(fontSize: 20),
              ),
            const SizedBox(height: 20),
            // Buttons row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: isRecording ? null : startRecording,
                  icon: const Icon(Icons.mic),
                  label: const Text('Record'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        isRecording ? Colors.red.withOpacity(0.3) : null,
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: isRecording ? stopRecording : null,
                  icon: const Icon(Icons.stop),
                  label: const Text('Stop'),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: (isPlaying || isRecording || audioPath == null)
                      ? null
                      : playRecording,
                  icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                  label: Text(isPlaying ? 'Playing' : 'Play'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        isPlaying ? Colors.green.withOpacity(0.3) : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
