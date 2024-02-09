import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'dart:io';

import 'globals.dart';


void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Record and Play Audio'),
        ),
        body:  const AudioRecorderPlayer(),
      ),
    );
  }
}


class AudioRecorderPlayer extends StatefulWidget {
  const AudioRecorderPlayer({Key? key}) : super(key: key);

  @override
  AudioRecorderPlayerState createState() => AudioRecorderPlayerState();
}

class AudioRecorderPlayerState extends State<AudioRecorderPlayer> {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  bool _isRecorderInitialized = false;
  bool _isRecording = false;
  final List<RecordingDetails> _recordings = [];

  @override
  void initState() {
    super.initState();
    _initRecorder();
  }

  Future<void> _initRecorder() async {
    await Permission.microphone.request();
    await Permission.storage.request();
    await _recorder.openRecorder();
    _isRecorderInitialized = true;
  }

  Future<void> _toggleRecording() async {
    if (!_isRecorderInitialized) return;

    if (_recorder.isRecording) {
      final path = await _recorder.stopRecorder();
      if (path != null) {
        _addRecording(path);
      }
    } else {
      final dir = await getApplicationDocumentsDirectory();
      final filePath =
          '${dir.path}/${DateTime.now().millisecondsSinceEpoch}.aac';
      await _recorder.startRecorder(toFile: filePath);
      setState(() {
        _isRecording = true;
      });
    }
  }

  void _addRecording(String path) async {
    final recordingDetails = RecordingDetails(path);
    await recordingDetails.player.setFilePath(path);
    recordingDetails.duration =
        recordingDetails.player.duration ?? Duration.zero;
    setState(() {
      _recordings.add(recordingDetails);
      _isRecording = false;
    });
  }

  _playPauseRecording(RecordingDetails recording) {
    if (recording.player.playing) {
      recording.player.pause();
    } else {
      recording.player.play();
      recording.player.positionStream.listen(
            (position) {
          setState(() {
            recording.updatePosition(position);
          });
        },
      );
    }

    print("duration --- ${recording.duration}");
    print("position --- ${recording.position}");

    setState(() {
      recording.player.playing == !recording.player.playing;
      // recording.togglePlaying();
    });
  }

  void _deleteRecording(int index) async {
    final recording = _recordings[index];
    await recording.player.dispose();
    final file = File(recording.path);
    if (await file.exists()) {
      await file.delete();
    }
    setState(() {
      _recordings.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: _toggleRecording,
          child: Text(_isRecording ? 'Stop Recording' : 'Start Recording'),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _recordings.length,
            itemBuilder: (context, index) {
              final recording = _recordings[index];
              final String totalDuration =
                  '${recording.duration.inMinutes.remainder(60).toString().padLeft(2, '0')}:${(recording.duration.inSeconds.remainder(60)).toString().padLeft(2, '0')}';
              final String currentPosition =
                  '${recording.position.inMinutes.remainder(60).toString().padLeft(2, '0')}:${(recording.position.inSeconds.remainder(60)).toString().padLeft(2, '0')}';
              return ListTile(
                title: Text('Recording ${index + 1}'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text("$currentPosition / $totalDuration"),
                        SizedBox(
                          width: 169,
                          child: Slider(
                            value: recording.position.inMilliseconds
                                .toDouble()
                                .clamp(
                                0.0,
                                recording.duration.inMilliseconds
                                    .toDouble()),
                            min: 0,
                            max: recording.duration.inMilliseconds.toDouble(),
                            onChanged: (value) {
                              setState(() {
                                recording.player.seek(
                                    Duration(milliseconds: value.toInt()));
                                recording.updatePosition(
                                    Duration(milliseconds: value.toInt()));
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                trailing: Wrap(
                  children: <Widget>[
                    IconButton(
                      icon: Icon(recording.player.playing
                          ? Icons.pause
                          : Icons.play_arrow),
                      onPressed: () => _playPauseRecording(recording),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => _deleteRecording(index),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _recordings.forEach((recording) async {
      await recording.player.dispose();
    });
    _recorder.closeRecorder();
    super.dispose();
  }
}
