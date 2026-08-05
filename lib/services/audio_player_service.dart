import 'package:just_audio/just_audio.dart';
import '../models/song_model.dart';

class AudioPlayerService {
  final AudioPlayer _player = AudioPlayer();
  ConcatenatingAudioSource? _playlistSource;

  AudioPlayer get player => _player;

  // প্লেলিস্ট লোড করা
  Future<void> setPlaylist(List<SongModel> playlist) async {
    if (playlist.isEmpty) {
      await _player.stop();
      _playlistSource = ConcatenatingAudioSource(children: []);
      return;
    }

    final audioSources = playlist
        .map((song) => AudioSource.uri(Uri.file(song.filePath)))
        .toList();

    try {
      _playlistSource = ConcatenatingAudioSource(
        children: audioSources,
        useLazyPreparation: true,
      );

      await _player.setAudioSource(_playlistSource!);
      await _player.setLoopMode(LoopMode.all);
    } catch (e) {
      print("Error setting playlist: $e");
    }
  }

  // গান সিলেক্ট করে প্লে করা
  Future<void> playSongAtIndex(int index) async {
    try {
      await _player.seek(Duration.zero, index: index);
      await _player.play();
    } catch (e) {
      print("Error playing song: $e");
    }
  }

  // প্লেলিস্ট থেকে গান রিমুভ করা
  Future<void> removeAudioSourceAt(int index) async {
    if (_playlistSource != null && index >= 0 && index < _playlistSource!.length) {
      await _playlistSource!.removeAt(index);
    }
  }

  Future<void> seekToNext() async {
    if (_player.hasNext) {
      await _player.seekToNext();
    }
  }

  Future<void> seekToPrevious() async {
    if (_player.hasPrevious) {
      await _player.seekToPrevious();
    }
  }

  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  void play() => _player.play();
  void pause() => _player.pause();
  void dispose() => _player.dispose();
}
