import 'package:just_audio/just_audio.dart';
import '../models/song_model.dart';

class AudioPlayerService {
  final AudioPlayer _player = AudioPlayer();

  AudioPlayer get player => _player;

  // পুরো প্লেলিস্ট জাস্ট অডিও প্লেয়ারে সেট করা
  Future<void> setPlaylist(List<SongModel> playlist) async {
    if (playlist.isEmpty) return;

    final audioSources = playlist
        .map((song) => AudioSource.uri(Uri.file(song.filePath)))
        .toList();

    try {
      await _player.setAudioSource(
        ConcatenatingAudioSource(children: audioSources),
      );
    } catch (e) {
      print("Error setting playlist: $e");
    }
  }

  // নির্দিষ্ট ইনডেক্সের গান প্লে করা
  Future<void> playSongAtIndex(int index) async {
    try {
      await _player.seek(Duration.zero, index: index);
      await _player.play();
    } catch (e) {
      print("Error playing song: $e");
    }
  }

  void play() => _player.play();
  void pause() => _player.pause();
  void dispose() => _player.dispose();
}
