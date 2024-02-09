import 'package:just_audio/just_audio.dart';

class RecordingDetails {
  String path;
  AudioPlayer player = AudioPlayer();
  Duration duration = Duration.zero;
  Duration position = Duration.zero;
  bool isPlaying = false;

  RecordingDetails(this.path);

  void updatePosition(Duration newPosition) {
    position = newPosition;
  }
}
